#!/usr/bin/env bash
# Drives a game through the hooks tools/hook-probe listens to, with the probe
# logging each beside this modkit and examples/example_mod, and reports the
# ones that did not fire. tools/modkit-probe rides along: every modkit
# callback of those hooks, each expected too. The reference (Event Horizon's
# docs/api/hook-points.md) lists every hook that reaches Lua, far more than
# this script can drive; the undriven rest is reported as a count with a
# pointer, which is informational, not a failure. A driven hook that did not
# fire fails the check.
#
#   HORIZON=/path/to/horizon RESOURCES=<26.3 folder> GAME_DIR=~/horizon-dev tools/hook-coverage.sh
#
# HORIZON is the fork checkout, built (`target/fast/horizon-client`, `horizon-ctl` and
# `target/debug/cargo-horizon-mod`, docs/api/hook-points.md); WORLD defaults to "New World".
set -u
HERE=$(cd "$(dirname "$0")/.." && pwd)
: "${HORIZON:?the fork checkout}" "${RESOURCES:?the prepared 26.3 folder}" "${GAME_DIR:?the game dir}"
MODKIT=$HERE
MOD="$HERE/examples/example_mod"
# The check's own world, made afresh each run unless WORLD names another: a reused one opens with the player
# where the last run left them (the platform in the sky) and keeps every run's mobs and items.
WORLD=${WORLD:-modkit-check}
[ "$WORLD" = modkit-check ] && rm -rf "$GAME_DIR/saves/modkit-check"
SOCK=${SOCK:-/tmp/horizon-hook-coverage.sock}
CTL="$HORIZON/target/fast/horizon-ctl --socket $SOCK"
# The game writes logs/ under HORIZON_HOME when it is set: keep that the game dir, so the log is here.
export HORIZON_HOME="$GAME_DIR"
LOG="$GAME_DIR/logs/latest.log"
j() { python3 -c "import sys,json; d=json.load(sys.stdin); $1"; }
# The id of the nearest mob of a kind, waiting up to three seconds for it.
mob_id() {
  for i in 1 2 3 4 5 6; do
    local id; id=$($CTL entities 8 | j "es=[e for e in d['entities'] if e.get('type')=='$1']; print(es[0]['id'] if es else '')")
    [ -n "$id" ] && { echo "$id"; return; }
    sleep 0.5
  done
}
say() { echo "--- $*"; }
# The scripts first, headlessly (`cargo horizon-mod check`, as tools/check.sh runs it): a script that fails to
# load stops here, with its line, before a game is started.
TOOL=${TOOL:-$HORIZON/target/debug/cargo-horizon-mod}
for m in "$MOD" "$HERE/tools/hook-probe" "$HERE/tools/step-probe" "$HERE/tools/modkit-probe" "$HERE/tools/hud-probe"; do
  "$TOOL" horizon-mod check "$m" --game "$HORIZON/target/fast/horizon-client" --dev-mod "$MODKIT" >/dev/null || { echo "the scripts of $m do not load; see above"; exit 1; }
done
echo "scripts load: the example mod and the probes"
# With luau-lsp installed: the scripts analyzed against the modkit's types (a misspelled function or hook, a nil
# used as a number), before any game.
if command -v luau-lsp >/dev/null; then
  for m in "$MOD" "$HERE/tools/hook-probe" "$HERE/tools/step-probe" "$HERE/tools/modkit-probe" "$HERE/tools/hud-probe"; do
    OUT=$(cd "$m" && luau-lsp analyze --definitions "@horizon=$MODKIT/types/horizon.d.lua" --platform=standard scripts 2>&1) || { echo "$OUT" | grep -v '^\['; echo "luau-lsp analyze: errors in $m (above)"; exit 1; }
  done
  echo "luau-lsp analyze: clean"
fi
# Quiet: the game's master volume off in the game dir's options, read at launch (it has no mute flag).
[ -f "$GAME_DIR/options.txt" ] && sed -i.bak 's/^soundCategory_master:.*/soundCategory_master:0.0/' "$GAME_DIR/options.txt" && rm -f "$GAME_DIR/options.txt.bak"
$CTL launch --game "$HORIZON/target/fast/horizon-client" --wait --game-dir "$GAME_DIR" --resources "$RESOURCES" \
  --world "$WORLD" --offscreen --dev-tools --dev-mod "$MODKIT" --dev-mod "$MOD" --dev-mod "$HERE/tools/hook-probe" --dev-mod "$HERE/tools/modkit-probe" >/dev/null
$CTL wait-ready 180 >/dev/null
# A world saved on the death screen opens on it, one saved in a bed opens asleep: respawn or get up, and wait
# for the player to be in the world.
for i in $(seq 1 20); do
  S=$($CTL state)
  echo "$S" | grep -q '"screen":"dead"' && { $CTL click-button Respawn >/dev/null; sleep 1; continue; }
  echo "$S" | grep -q '"player"' && break
  $CTL close >/dev/null 2>&1; $CTL key esc tap >/dev/null 2>&1; sleep 1
done
$CTL command "gamemode creative" >/dev/null
# 26.3 names: spawn_mobs is the old doMobSpawning, advance_time the old doDaylightCycle.
$CTL command "gamerule spawn_mobs false" >/dev/null
$CTL command "gamerule advance_time false" >/dev/null
$CTL command "time set 18000" >/dev/null
# Random ticks a hundred times the usual, so the nest ticks within seconds; put back at the end.
$CTL command "gamerule random_tick_speed 300" >/dev/null
$CTL command "kill @e[type=!player,distance=..64]" >/dev/null
$CTL command "clear" >/dev/null
sleep 1
say "a stone platform in the sky, the items in the hotbar"
P=$($CTL state | j 'p=d["player"]["position"]; print(int(p[0]//1), int(p[2]//1))'); set -- $P; CX=$1; CZ=$2; CY=200
$CTL command "fill $((CX-5)) $((CY-1)) $((CZ-5)) $((CX+5)) $((CY-1)) $((CZ+5)) minecraft:stone" >/dev/null
$CTL command "fill $((CX-5)) $CY $((CZ-5)) $((CX+5)) $((CY+6)) $((CZ+5)) minecraft:air" >/dev/null
$CTL command "tp @s $CX $CY $CZ" >/dev/null
sleep 1
for item in stone stick apple netherite_sword snowball oak_log; do $CTL give minecraft:$item 4 >/dev/null; done
sleep 1
say "blocks: a nest for the block ticks, the probe block for its block entity"
$CTL command "setblock $((CX+2)) $CY $((CZ+2)) example_mod:example_nest[stage=dormant]" >/dev/null
$CTL command "setblock $((CX+2)) $CY $((CZ-2)) hook_probe:probe" >/dev/null
say "blocks: place and break stone, right-click it with a stick, use the stick in the air"
SX=$((CX-2)); SZ=$CZ
for try in 1 2 3; do
  $CTL select stone | j 'print("holding:", d.get("held", {}).get("item", d.get("error")))'
  $CTL look-at $SX $((CY-1)) $SZ >/dev/null
  $CTL place $SX $CY $SZ | j 'print("placed:", (d.get("block") or {}).get("block", d.get("error")))'
  sleep 0.5
  $CTL select stick | j 'print("holding:", d.get("held", {}).get("item", d.get("error")))'
  $CTL look-at $SX $CY $SZ >/dev/null
  $CTL interact $SX $CY $SZ east | j 'print("right-clicked:", d.get("ok", d.get("error")))'
  $CTL look-at $SX $CY $SZ >/dev/null
  $CTL break $SX $CY $SZ --timeout 10 | j 'print("broke:", d.get("block_before", d.get("error")))'
  grep -q "PROBE hook destroy_block" "$LOG" && break
  $CTL command "setblock $SX $CY $SZ minecraft:air" >/dev/null; sleep 1
done
$CTL look 0 -60 >/dev/null
$CTL use-item | j 'print("used in the air:", d.get("ok", d.get("error")))'
say "mobs: an example mob spawned, hurt, clicked twice and killed by command"
$CTL command "summon example_mod:example_mob $CX $CY $((CZ+2)) {NoAI:1b}" >/dev/null
sleep 1
$CTL command "damage @e[type=example_mod:example_mob,limit=1,sort=nearest] 1 minecraft:generic" >/dev/null
PID=$(mob_id example_mod:example_mob)
$CTL select 9 >/dev/null
# Two clicks on the same mob: its own saved table counts 1 then 2 (tools/modkit-probe).
[ -n "$PID" ] && $CTL interact-entity "$PID" | j 'print("clicked the example mob:", d.get("ok", d.get("error")))'
sleep 0.5
[ -n "$PID" ] && $CTL interact-entity "$PID" | j 'print("clicked the example mob again:", d.get("ok", d.get("error")))'
sleep 0.5
$CTL command "kill @e[type=example_mod:example_mob]" >/dev/null
say "mobs: a zombie clicked once, hit with the stick, then killed with a sword"
$CTL command "summon minecraft:zombie $CX $CY $((CZ-2)) {NoAI:1b}" >/dev/null
sleep 1
ZID=$(mob_id minecraft:zombie)
# One click on another mob: its own saved table counts its own 1 (tools/modkit-probe).
[ -n "$ZID" ] && $CTL interact-entity "$ZID" | j 'print("clicked the zombie:", d.get("ok", d.get("error")))'
sleep 0.5
$CTL select stick >/dev/null
for try in 1 2 3 4; do
  $CTL look-at-entity "$ZID" >/dev/null
  $CTL attack "$ZID" | j 'print("hit with the stick:", d.get("hit", d.get("error")), "health:", d.get("health_before"), "->", d.get("health"))'
  sleep 0.7
  grep -q "PROBE hook attack_entity" "$LOG" && break
done
$CTL select netherite_sword >/dev/null
for try in 1 2 3 4 5 6; do
  R=$($CTL attack "$ZID")
  echo "$R" | j 'print("hit with the sword:", d.get("hit", d.get("error")), "health:", d.get("health_before"), "->", d.get("health"), "alive:", d.get("alive"))'
  echo "$R" | grep -q '"alive":false' && break
  sleep 0.7
done
say "the second goal's hooks: a fall, a snowball thrown, a stick dropped, planks crafted, a chest opened, a bed, an orb, tnt"
$CTL command "gamemode survival" >/dev/null
$CTL command "tp @s $CX $((CY+5)) $CZ" >/dev/null; sleep 2.5
# A zombie dropped beside the player falls (its on_fall). A husk at their side hits them: a mob's own melee
# push on the player (a zombie never does here: the example mod's stalking goal keeps it at a distance).
$CTL command "summon minecraft:zombie $((CX+1)) $((CY+6)) $((CZ+1))" >/dev/null; sleep 2
$CTL command "summon minecraft:husk $((CX+2)) $CY $((CZ+1))" >/dev/null
for i in $(seq 1 15); do sleep 1; grep -q "MODKIT cb Players:on_knockback" "$LOG" && break; done
echo "pushed by a husk's blow: $(grep -q "MODKIT cb Players:on_knockback" "$LOG" && echo yes || echo no)"
$CTL command "kill @e[type=!player,distance=..24]" >/dev/null
# A stone block broken in survival with a pickaxe: its loot (a creative break rolls none).
$CTL give minecraft:netherite_pickaxe 1 >/dev/null
$CTL command "setblock $((CX-4)) $CY $((CZ+1)) minecraft:stone" >/dev/null; sleep 0.5
$CTL select minecraft:netherite_pickaxe >/dev/null
$CTL look-at $((CX-4)) $CY $((CZ+1)) >/dev/null
$CTL break $((CX-4)) $CY $((CZ+1)) --timeout 10 | j 'print("stone broken in survival:", d.get("block_before", d.get("error")))'; sleep 1
$CTL command "gamemode creative" >/dev/null
$CTL select minecraft:snowball | j 'print("holding:", d.get("held", {}).get("item", d.get("error")))'
$CTL look-at $((CX+4)) $CY $((CZ+4)) >/dev/null
$CTL use-item | j 'print("snowball thrown:", d.get("ok", d.get("error")))'; sleep 1.5
$CTL select minecraft:stick >/dev/null; sleep 0.5
$CTL drop | j 'print("dropped:", d.get("dropped_from", d.get("error")))'; sleep 1
echo "sticks on the ground (the server threw them): $($CTL entities 6 | j 'print([e["item"] for e in d["entities"] if e.get("type")=="minecraft:item" and e["item"]["item"]=="minecraft:stick"])')"
# The survival inventory has the 2x2 grid (the creative one has the tabs).
$CTL command "gamemode survival" >/dev/null; sleep 0.5
# The log's slot as click-slot numbers the inventory screen: the inventory's own index (hotbar 0 to 8, main 9 to 35).
LOGSLOT=$($CTL inventory | j '
slots = [(s["slot"], s) for s in d.get("main", []) + d.get("hotbar", [])]
print(next((n for n, s in slots if s.get("item") == "minecraft:oak_log"), ""))')
$CTL open-inventory >/dev/null; sleep 0.3
echo "oak log in slot $LOGSLOT; crafting planks in the 2x2 grid"
carried() { $CTL inventory | j 'print(d.get("carried") or d.get("cursor") or "nothing")'; }
[ -n "$LOGSLOT" ] && $CTL click-slot "$LOGSLOT" | j 'print("picked the log:", d.get("ok", d.get("error")))' && echo "carried: $(carried)" && $CTL click-slot 100 >/dev/null && sleep 0.5 && echo "carried after the grid: $(carried)" && $CTL click-slot 200 >/dev/null && sleep 0.3 && echo "carried after the result: $(carried)" && $CTL click-slot "$LOGSLOT" >/dev/null
echo "planks crafted: $($CTL inventory | j 'print(d["counts"].get("minecraft:oak_planks", 0))')"
$CTL close >/dev/null; sleep 0.5
$CTL command "gamemode creative" >/dev/null
# A chest set and opened (the owner's menus are heard as a guest's are).
$CTL command "setblock $((CX-3)) $CY $((CZ+3)) minecraft:chest" >/dev/null; sleep 0.5
$CTL look-at $((CX-3)) $CY $((CZ+3)) >/dev/null
$CTL interact $((CX-3)) $CY $((CZ+3)) up | j 'print("chest opened:", d.get("ok", d.get("error")))'; sleep 1
echo "screen: $($CTL state | j 'print(d.get("screen"))')"
$CTL close >/dev/null; sleep 0.5
# No monster within 8 blocks, or the bed refuses; no example mob anywhere, or the example mod's own
# on_sleep refuses first and the probes behind it are not asked.
# The nest first: grown by the raised random ticks, it breeds an example mob now and then, and one roaming
# example mob makes the example mod refuse the bed before the probes are asked.
$CTL command "setblock $((CX+2)) $CY $((CZ+2)) minecraft:air" >/dev/null
$CTL command "kill @e[type=!player,distance=..24]" >/dev/null
$CTL command "kill @e[type=example_mod:example_mob]" >/dev/null; sleep 0.5
# At night: the game's own checks (night, no monster near) come before the hook, and a saved world's time drifts.
$CTL command "time set night" >/dev/null
$CTL command "setblock $((CX-3)) $CY $((CZ-3)) minecraft:red_bed[facing=east,part=foot]" >/dev/null
$CTL command "setblock $((CX-2)) $CY $((CZ-3)) minecraft:red_bed[facing=east,part=head]" >/dev/null; sleep 0.5
$CTL select minecraft:stick >/dev/null
$CTL look-at $((CX-3)) $CY $((CZ-3)) >/dev/null
for try in 1 2 3; do
  echo "screen before the bed: $($CTL state | j 'print(d.get("screen"), d.get("dialog"))')"
  $CTL look-at $((CX-3)) $CY $((CZ-3)) >/dev/null
  $CTL interact $((CX-3)) $CY $((CZ-3)) up | j 'print("bed entered:", d.get("ok", d.get("error")))'; sleep 1.5
  grep -q "PROBE hook player_bed_enter" "$LOG" && break
  echo "the bed said: $($CTL messages 3 | j 'print(d.get("chat"))')"
  $CTL close >/dev/null 2>&1; $CTL key esc tap >/dev/null 2>&1; sleep 1
done
echo "sleeping: $($CTL state | j 'print(d.get("player", {}).get("sleeping", d.get("screen")))')"
$CTL command "gamemode creative" >/dev/null; sleep 0.5
$CTL command "gamemode survival" >/dev/null
$CTL command "summon minecraft:experience_orb $CX $((CY+1)) $CZ {Value:3}" >/dev/null; sleep 1.5
$CTL command "damage @s 1 minecraft:generic" >/dev/null; sleep 0.5
$CTL command "effect give @s minecraft:instant_health 1 0" >/dev/null; sleep 0.5
$CTL command "gamemode creative" >/dev/null
$CTL command "summon minecraft:zombie $((CX+3)) $CY $((CZ-3)) {NoAI:1b}" >/dev/null; sleep 0.5
$CTL command "item replace entity @e[type=minecraft:zombie,limit=1,sort=nearest] weapon.mainhand with minecraft:iron_sword" | j 'print("zombie armed:", d.get("chat"))'; sleep 1
$CTL command "summon minecraft:tnt $((CX+4)) $((CY+2)) $((CZ+4)) {fuse:20}" >/dev/null; sleep 2.5
$CTL command "execute in minecraft:the_nether run tp @s 0 100 0" >/dev/null; sleep 2
$CTL command "execute in minecraft:overworld run tp @s $CX $CY $CZ" >/dev/null; sleep 2
# The nest's random ticks are long done: back to the usual rate, or the slowed server never gets through the 32
# ticks of eating within the hold.
$CTL command "gamerule random_tick_speed 3" >/dev/null
say "items: a pickup, an apple eaten, a command"
$CTL command "summon minecraft:item $CX $((CY+1)) $CZ {Item:{id:\"minecraft:slime_ball\",count:3}}" >/dev/null
sleep 2
$CTL select apple | j 'print("holding:", d.get("held", {}).get("item", d.get("error")))'
$CTL look 0 -60 >/dev/null
# Eating takes 32 server ticks; the raised random tick speed slows the server, so hold long and retry
# (use-item --hold, as tools/example-check.sh eats its snack: a raw mouse hold started the use but
# did not always finish it).
for try in 1 2 3; do
  $CTL use-item --hold 3 >/dev/null; sleep 0.5
  grep -q "PROBE hook living_entity_use_item_finish" "$LOG" && break
done
# As typed in the chat box, so the mods hear it as a player's command (the console's own path does not tell them).
$CTL chat "/probe" >/dev/null; sleep 0.5
$CTL chat "hello from the probe" >/dev/null; sleep 0.5
say "scripts reloaded, player died and respawned"
$CTL command "reload" >/dev/null
sleep 2
$CTL command "kill @s" >/dev/null
for i in 1 2 3 4 5 6; do sleep 1; $CTL state | grep -q '"screen":"dead"' && break; done
$CTL click-button Respawn | j 'print("respawn:", d.get("clicked", d.get("error")))'
for i in 1 2 3 4 5 6; do sleep 1; $CTL state | grep -q '"screen":"dead"' || break; done
$CTL command "gamemode creative" >/dev/null
$CTL command "gamerule random_tick_speed 3" >/dev/null
sleep 1
$CTL quit >/dev/null
sleep 3
python3 - "$LOG" "$HORIZON/docs/api/hook-points.md" <<'PY'
import re, sys
log = open(sys.argv[1], errors="replace").read()
seen = set(re.findall(r"PROBE hook (\S+)", log))
# The hooks the drive above exercises, by their native names: every one must
# have fired. `perform_command` shares one proof with the probe's `/probe`
# command declared and typed; `data_pack_files` is the scripts reloading on
# `/reload`.
driven = ["server_tick", "world_lifecycle", "player_logged_in", "player_logged_out",
    "player_respawned", "player_died", "tick_block", "right_click_block", "block_entity_tick", "random_tick",
    "mob_spawned", "mob_ai_register", "register_goals", "entity_tick_post", "living_incoming_damage",
    "mob_died", "mob_killed", "interact_entity", "use_item", "use_item_on", "inventory_tick", "item_crafted",
    "item_dropped", "destroy_block", "place_block", "living_heal", "attack_entity", "living_fall",
    "living_knockback", "living_equipment_change", "hurt_enemy", "living_entity_use_item_start",
    "living_entity_use_item_finish", "loot_drops", "player_tick", "player_command", "player_chat",
    "explosion_detonate", "player_changed_dimension", "player_bed_enter", "player_exp_change",
    "player_container_open", "player_item_held", "projectile_impact", "projectile_launch", "entity_join_level",
    "perform_command", "register_commands", "data_pack_files"]
evidence = {"perform_command": "command"}
# Hooks the engine's docs give to dedicated servers or LAN guests only; empty while the
# single-player owner, a guest of their own hub, is heard too.
dedicated_only = set()
listed = []
# The reference has two tables: the hooks (Hook | API | Taken | Lua | What) and the helpers a mod may call
# (Helper | API | Lua | What). Only a hook fires, so only its table is read; a cell's `\|` is an escaped pipe,
# not a column break. A hook reaches Lua when its Lua cell is filled; the two
# declaration-served hooks have filled cells but take no `horizon.on`
# registration.
table = None
for line in open(sys.argv[2]):
    if line.startswith("| Hook |"):
        table = "hooks"
        continue
    if line.startswith("| Helper |"):
        table = "helpers"
        continue
    if line.startswith("| `") and table == "hooks":
        c = [x.strip().replace("\\|", "|") for x in re.split(r"(?<!\\)\|", line.strip().strip("|"))]
        if len(c) >= 5 and c[3]:
            listed.append(c[0].strip("`"))
declared_only = {"block_entity", "block_entity_ticks"}
missing = []
for hook in driven:
    if hook in dedicated_only:
        continue
    if hook == "data_pack_files":
        ok = "Lua mod hook_probe reloaded" in log
    else:
        ok = evidence.get(hook, hook) in seen
    if not ok:
        missing.append(hook)
not_driven = [h for h in listed if h not in driven and h not in dedicated_only and h not in declared_only]
print(f"{len(listed)} hooks reach Lua by the reference; {len(driven) - len(missing)} of {len(driven)} driven hooks fired in game")
print("driven and fired:", " ".join(h for h in driven if h not in missing and h not in dedicated_only))
print("driven but silent:", " ".join(missing) if missing else "none")
print(f"reaches Lua but not driven here: {len(not_driven)} (the reference lists them: docs/api/hook-points.md)")
print("guests and dedicated servers only, not checked here:", " ".join(sorted(dedicated_only)))
print("declaration-served, no handler to drive:", " ".join(sorted(declared_only)))
# The modkit's callbacks for the same hooks (tools/modkit-probe), each written as a mod writes it.
callbacks = ["Players:on_tick", "Players:on_hurt", "Players:on_fall", "Players:on_knockback", "Players:on_chat",
    "Players:on_command", "Players:on_change_dimension", "Players:on_sleep", "Players:on_exp", "Players:on_open_menu",
    "Entity:on_fall", "Entity:on_knockback", "Entity:on_equip", "Entity:on_drops", "Entity:on_interact",
    "Block:on_drops", "Block:on_use",
    "Item:on_crafted", "Item:on_dropped", "Item:on_hurt_enemy", "Item:on_use_start",
    "M:on explosion", "M:on entity_joined", "M:on projectile_launched", "M:on projectile_impact", "M:on mob_heal"]
ran = set(re.findall(r"MODKIT cb (\S+(?: \S+)?)", log))
missing_callbacks = [c for c in callbacks if c not in ran]
print(f"{len(callbacks)} modkit callbacks; {len(callbacks) - len(missing_callbacks)} ran in game")
print("modkit callbacks missing:", " ".join(missing_callbacks) if missing_callbacks else "none")
missing += missing_callbacks
# The new helper reads (issue 48), asserted in game. Per-mob data: one
# example mob clicked twice counts 1 then 2 in its own table, and a zombie
# counts its own. The acting player's hand in a click is what they hold (the
# drive right-clicks stone holding a stick). P:on_tick names the ticking
# player. A two-player run would tell acting_player from players()[1] apart;
# the harness drives one player, so that difference is not shown here.
by_id = {}
for m in re.finditer(r"MODKIT mobdata example_mod:example_mob (\d+) clicks=(\d+)", log):
    by_id.setdefault(m.group(1), []).append(int(m.group(2)))
if not any(1 in v and 2 in v for v in by_id.values()):
    missing.append("mob.data persists across two clicks of one example mob")
if not re.search(r"MODKIT mobdata minecraft:zombie \d+ zclicks=1", log):
    missing.append("mob.data of a second mob counts its own")
if not re.search(r"MODKIT blockuse held=minecraft:stick", log):
    missing.append("acting held in a click is what the player holds")
tick = re.search(r"MODKIT tick: (\S+) first=(\S+) match=true", log)
if not tick or tick.group(1) != tick.group(2):
    missing.append("P:on_tick names the ticking player")
errors = [l for l in log.splitlines() if "[lua:" in l and "error" in l]
print("script errors:", len(errors))
for l in errors[:5]: print("  " + l[:200])
sys.exit(1 if missing or errors else 0)
PY
