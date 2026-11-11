#!/usr/bin/env bash
# One game session that shows one observable per step of the modding API
# (reads, items, events, timers and saved data, effects and commands,
# spawning, the mob's model, the world and player helpers; the hook
# reference's own check is tools/hook-coverage.sh): the probe mod
# tools/step-probe logs the reads, data and effects, examples/example_mod
# does the rest (the lure, the nest, the keeper's feeding, /example max,
# the bed refused), tools/modkit-probe every modkit callback.
#
#   HORIZON=/path/to/horizon RESOURCES=<26.3 folder> GAME_DIR=~/horizon-dev tools/steps-check.sh
#
# The spawn step counts the example mobs a fresh world's chunks came with (a
# creature spawns mostly at generation) and listens for one at midnight.
set -u
HERE=$(cd "$(dirname "$0")/.." && pwd)
: "${HORIZON:?the fork checkout}" "${RESOURCES:?the prepared 26.3 folder}" "${GAME_DIR:?the game dir}"
MODKIT=$HERE
MOD="$HERE/examples/example_mod"
# The check's own world, made afresh each run unless WORLD names another: a reused one opens with the player
# where the last run left them (the platform in the sky) and keeps every run's mobs and items.
WORLD=${WORLD:-modkit-check}
[ "$WORLD" = modkit-check ] && rm -rf "$GAME_DIR/saves/modkit-check"
SOCK=${SOCK:-/tmp/horizon-steps-check.sock}
SHOT=${SHOT:-/tmp/horizon-steps-check.png}
CTL="$HORIZON/target/fast/horizon-ctl --socket $SOCK"
# The game writes logs/ under HORIZON_HOME when it is set: keep that the game dir, so the log is here.
export HORIZON_HOME="$GAME_DIR"
LOG="$GAME_DIR/logs/latest.log"
j() { python3 -c "import sys,json; d=json.load(sys.stdin); $1"; }
mob_id() { for i in 1 2 3 4 5 6; do local id; id=$($CTL entities 8 | j "es=[e for e in d['entities'] if e.get('type')=='$1']; print(es[0]['id'] if es else '')"); [ -n "$id" ] && { echo "$id"; return; }; sleep 0.5; done; }
# The example mod's settings, written before the game reads them at load:
# a nest is spent after one example mob, so the check sees it turn to sculk.
mkdir -p "$GAME_DIR/config"
printf '{"max_mobs": 2, "nest_breeds": 1}\n' > "$GAME_DIR/config/example_mod.json"
rm -f "$GAME_DIR/config/step_probe.json"
# The scripts first, headlessly (`cargo horizon-mod check`, the modkit's tools/check.sh): a script that fails to
# load stops here, with its line, before a game is started.
TOOL=${TOOL:-$HORIZON/target/debug/cargo-horizon-mod}
for m in "$MOD" "$HERE/tools/hook-probe" "$HERE/tools/step-probe" "$HERE/tools/modkit-probe" "$HERE/tools/hud-probe"; do
  OUT=$("$TOOL" horizon-mod check "$m" --game "$HORIZON/target/fast/horizon-client" --dev-mod "$MODKIT" 2>&1) || { echo "$OUT"; echo "the checks of $m fail (above)"; exit 1; }
done
echo "scripts load and pass their checks (formatting, lint, types): the example mod and the probes"
# Quiet: the game's master volume off in the game dir's options, read at launch (it has no mute flag).
[ -f "$GAME_DIR/options.txt" ] && sed -i.bak 's/^soundCategory_master:.*/soundCategory_master:0.0/' "$GAME_DIR/options.txt" && rm -f "$GAME_DIR/options.txt.bak"
$CTL launch --game "$HORIZON/target/fast/horizon-client" --wait --game-dir "$GAME_DIR" --resources "$RESOURCES" --world "$WORLD" --offscreen --dev-tools --dev-mod "$MODKIT" --dev-mod "$MOD" --dev-mod "$HERE/tools/step-probe" --dev-mod "$HERE/tools/modkit-probe" >/dev/null
$CTL wait-ready 180 >/dev/null
# A world saved on the death screen opens on it, one saved in a bed opens asleep: respawn or get up, and wait
# for the player to be in the world.
for i in $(seq 1 20); do
  S=$($CTL state)
  echo "$S" | grep -q '"screen":"dead"' && { $CTL click-button Respawn >/dev/null; sleep 1; continue; }
  echo "$S" | grep -q '"player"' && break
  $CTL close >/dev/null 2>&1; $CTL key esc tap >/dev/null 2>&1; sleep 1
done
# The example mobs the fresh world's chunks came with, counted before the setup kills everything (step 6 reads it).
GEN=$($CTL entities 128 | j 'print(sum(1 for e in d.get("entities", []) if e.get("type") == "example_mod:example_mob"))')
$CTL command "gamemode creative" >/dev/null
# 26.3 names: spawn_mobs is the old doMobSpawning, advance_time the old doDaylightCycle.
$CTL command "gamerule spawn_mobs false" >/dev/null
$CTL command "gamerule advance_time false" >/dev/null
$CTL command "time set 18000" >/dev/null
$CTL command "kill @e[type=!player]" >/dev/null
sleep 1
$CTL command "kill @e[type=!player]" >/dev/null
$CTL command "clear" >/dev/null
sleep 2
G=$($CTL state | j 'p=d["player"]["position"]; print(int(p[0]//1), int(p[1]//1), int(p[2]//1))'); set -- $G; GX=$1; GY=$2; GZ=$3
P=$($CTL state | j 'p=d["player"]["position"]; print(int(p[0]//1), int(p[2]//1))'); set -- $P; CX=$1; CZ=$2; CY=200
$CTL command "fill $((CX-5)) $((CY-1)) $((CZ-5)) $((CX+5)) $((CY-1)) $((CZ+5)) minecraft:stone" >/dev/null
$CTL command "fill $((CX-5)) $CY $((CZ-5)) $((CX+5)) $((CY+6)) $((CZ+5)) minecraft:air" >/dev/null
$CTL command "tp @s $CX $CY $CZ" >/dev/null; sleep 1
for item in example_mod:example_lure example_mod:example_mob_spawn_egg; do $CTL give $item 4 >/dev/null; done; sleep 1
echo "--- step 2: the lure used on the platform summons an example mob (item_use_on through M:item)"
$CTL select example_mod:example_lure | j 'print("holding:", d.get("held", {}).get("item", d.get("error")))'
$CTL look-at $((CX-2)) $((CY-1)) $CZ >/dev/null
$CTL interact $((CX-2)) $((CY-1)) $CZ up >/dev/null; sleep 1
echo "example mobs after the lure: $($CTL entities 8 | j 'print(sum(1 for e in d["entities"] if e.get("type")=="example_mod:example_mob"))')  lures left: $($CTL inventory | j 'print(d["counts"].get("example_mod:example_lure"))')"
echo "--- step 6: the spawn egg"
$CTL select example_mod:example_mob_spawn_egg | j 'print("holding:", d.get("held", {}).get("item", d.get("error")))'
$CTL look-at $((CX+2)) $((CY-1)) $CZ >/dev/null
$CTL interact $((CX+2)) $((CY-1)) $CZ up >/dev/null; sleep 1
echo "example mobs after the egg: $($CTL entities 8 | j 'print(sum(1 for e in d["entities"] if e.get("type")=="example_mod:example_mob"))')"
echo "--- step 7: a close look at the example mob's model"
$CTL command "kill @e[type=example_mod:example_mob]" >/dev/null; sleep 1
$CTL command "summon example_mod:example_mob $CX $CY $((CZ+3)) {NoAI:1b}" >/dev/null; sleep 1
PID=$(mob_id example_mod:example_mob)
$CTL look-at-entity "$PID" >/dev/null; sleep 0.5
$CTL screenshot $SHOT | j 'print("screenshot:", d.get("ok", d.get("error")))'
echo "--- step 3: damage dealt, as the hook hears it and as the mob's health shows it"
$CTL command "damage @e[type=example_mod:example_mob,limit=1,sort=nearest] 5 minecraft:generic" >/dev/null; sleep 1
echo "example mob health after 5 damage: $($CTL entities 8 | j 'print([e.get("health") for e in d["entities"] if e.get("type")=="example_mod:example_mob"])')"
echo "--- step 3 and 5: an example mob killed by the player is announced; the fx command"
$CTL command "stepfx" | j 'print("command:", d.get("chat"))'
sleep 0.5
echo "title shown: $($CTL messages | j 'print(d.get("title"), "|", d.get("subtitle"), "|", d.get("action_bar"))')"
$CTL command "kill @e[type=example_mod:example_mob,limit=1,sort=nearest]" >/dev/null; sleep 1
$CTL command "example report" | j 'print("/example report:", d.get("chat"))'
echo "--- step 5: a command with an argument (/example lure <count:integer>)"
$CTL command "clear" >/dev/null; sleep 0.5
$CTL command "example lure 3" | j 'print("/example lure 3:", d.get("chat"))'
sleep 1
LURES=$($CTL inventory | j 'print(d["counts"].get("example_mod:example_lure", 0))')
echo "lures in the inventory: $LURES"
[ "$LURES" = 3 ] || { echo "STEP5 argument: expected 3 lures"; exit 1; }
echo "STEP5 argument: 3 lures from the count argument"
$CTL command "probeadd 2 0.5 total" | j 'print("/probeadd 2 0.5 total:", d.get("chat"))'
$CTL command "probeadd x 1" | j 'print("/probeadd x 1 (a bad integer):", d.get("chat")); import sys; sys.exit(0 if any("integer" in c for c in d.get("chat", [])) else 1)' || { echo "STEP5: a bad integer was not refused"; exit 1; }
echo "--- the helpers (the second goal's step 1): blocks, items, effects, experience, a nickname, the console, settings"
$CTL command "clear" >/dev/null; sleep 0.5
$CTL command "tp @s $CX $CY $CZ" >/dev/null; sleep 1
$CTL command "probehelpers" | j 'print("/probehelpers:", d.get("chat"))'
sleep 3
echo "set_block: $($CTL block $((CX+2)) $CY $((CZ+2)) | j 'print(d)')"
echo "set_block with a property: $($CTL block $((CX+2)) $CY $((CZ+3)) | j 'print(d)')"
echo "fill: $($CTL blocks $((CX-3)) $CY $((CZ-3)) $((CX-1)) $((CY+1)) $((CZ-1)) | j 'print(d)')"
echo "dropped and fallen: $($CTL entities 8 | j 'print([e for e in d["entities"] if e.get("type") in ("minecraft:item", "minecraft:falling_block", "minecraft:zombie")])')"
echo "effects: $($CTL effects | j 'print(d)')"
$CTL effects | j 'import sys; sys.exit(0 if any(e.get("id") in ("speed", "minecraft:speed") for e in d.get("effects", {}).get("active", [])) else 1)' || { echo "STEP9: the player did not get speed from horizon.effect"; exit 1; }
echo "STEP9 effect on the player: speed"
$CTL command "data get entity @e[type=minecraft:zombie,limit=1,sort=nearest] active_effects" | j 'print("zombie effects:", d.get("chat")); import sys; sys.exit(0 if any("glowing" in c for c in d.get("chat", [])) else 1)' || { echo "STEP9: the zombie did not get glowing from horizon.effect by id"; exit 1; }
echo "STEP9 effect on a mob by id: glowing"
echo "bread (3 given, 1 taken, next tick): $($CTL inventory | j 'print(d["counts"].get("minecraft:bread", 0))')"
BREAD=$($CTL inventory | j 'print(d["counts"].get("minecraft:bread", 0))')
[ "$BREAD" = 2 ] || { echo "STEP9: expected 2 bread from give_items and take_items to a named player"; exit 1; }
echo "STEP9 named player: 2 bread in the inventory"
GOLD=$($CTL blocks $((CX-3)) $CY $((CZ-3)) $((CX-1)) $((CY+1)) $((CZ-1)) | j 'print(d.get("counts", {}).get("minecraft:gold_block", 0))')
[ "$GOLD" = 18 ] || { echo "STEP9: expected 18 gold blocks from fill, got $GOLD"; exit 1; }
echo "STEP9 fill: 18 gold blocks"
$CTL block $((CX+2)) $CY $((CZ+2)) | grep -q glowstone || { echo "STEP9: set_block did not place glowstone"; exit 1; }
echo "STEP9 set_block: glowstone placed"
echo "falling block, landed: $($CTL block $CX $CY $((CZ-3)) | j 'print(d)')"
$CTL block $CX $CY $((CZ-3)) | grep -q 'minecraft:sand' || { echo "STEP9: the falling sand did not land"; exit 1; }
EMERALDS=$($CTL entities 8 | j 'print(sum(e["item"]["count"] for e in d["entities"] if e.get("type")=="minecraft:item" and e["item"]["item"]=="minecraft:emerald"))')
[ "$EMERALDS" = 3 ] || { echo "STEP9: expected 3 dropped emeralds, got $EMERALDS"; exit 1; }
echo "STEP9 falling_block and drop_item: sand landed, 3 emeralds on the ground"
# The glowstone set above, broken in survival: its loot, with the block named from its state.
$CTL command "gamemode survival" >/dev/null; sleep 0.5
$CTL look-at $((CX+2)) $CY $((CZ+2)) >/dev/null
$CTL break $((CX+2)) $CY $((CZ+2)) --timeout 10 | j 'print("glowstone broken:", d.get("block_before", d.get("error")))'; sleep 1
$CTL command "gamemode creative" >/dev/null
grep -q 'STEP9 loot: minecraft:glowstone state=minecraft:glowstone table=minecraft:blocks/glowstone drops=[1-9]' "$LOG" || { echo "STEP9: no loot_drops line for the broken glowstone"; exit 1; }
echo "STEP9 loot_drops: $(grep -o 'STEP9 loot: .*' "$LOG" | tail -1)"
ID=$(grep '^id' "$HERE/tools/step-probe/horizon-mod.toml" | cut -d'"' -f2)
grep -q '"limit": 16' "$GAME_DIR/config/$ID.json" || { echo "STEP9: no settings file $GAME_DIR/config/$ID.json with limit 16"; exit 1; }
echo "STEP9 config: $GAME_DIR/config/$ID.json written at load: $(tr -d '\n ' < "$GAME_DIR/config/$ID.json")"
echo "--- the example mod's use of them: feeding (heal, the feeder's saved count), /example max (settings), a spent nest (replace, drop, light)"
$CTL command "example max 3" | j 'print("/example max 3:", d.get("chat"))'
grep -q '"max_mobs": 3' "$GAME_DIR/config/example_mod.json" || { echo "STEP9: /example max did not save the settings"; exit 1; }
echo "STEP9 example settings saved: $(tr -d '\n ' < "$GAME_DIR/config/example_mod.json")"
$CTL command "kill @e[type=example_mod:example_mob]" >/dev/null; sleep 1
$CTL command "summon example_mod:example_mob $CX $CY $((CZ+3)) {NoAI:1b}" >/dev/null; sleep 1
PID=$(mob_id example_mod:example_mob)
$CTL give minecraft:wheat 4 >/dev/null; sleep 1
$CTL select minecraft:wheat | j 'print("holding:", d.get("held", {}).get("item", d.get("error")))'
$CTL look-at-entity "$PID" >/dev/null; sleep 0.5
$CTL interact-entity "$PID" >/dev/null; sleep 1
echo "fed example mob: $($CTL entities 8 | j 'print([(e.get("health"), e.get("effects")) for e in d["entities"] if e.get("type")=="example_mod:example_mob"])')"
grep -q 'EXAMPLE mob fed by' "$LOG" || { echo "STEP9: the wheat did not feed the example mob"; exit 1; }
# Per-mob saved data: the click above counted into this mob's own table; the
# tick below receives a player whose uuid is the one player online (a
# two-player difference is not drivable by the harness, which runs one
# player: the line cannot separate acting_player from players()[1]).
grep -q "MODKIT mobdata example_mod:example_mob [0-9]* clicks=1" "$LOG" || { echo "STEP9: no per-mob count from the click"; exit 1; }
echo "STEP9 per-mob data: $(grep -o 'MODKIT mobdata [a-z_:]* [0-9]* clicks=[0-9]*' "$LOG" | tail -1)"
grep -q "MODKIT tick: .* match=true" "$LOG" || { echo "STEP9: P:on_tick did not hand the callback a player (single player: uuid matches players()[1])"; exit 1; }
echo "STEP9 ticking player: $(grep -o 'MODKIT tick: [^ ]* first=[^ ]* match=true' "$LOG" | tail -1)"
$CTL command "setblock $((CX+3)) $CY $((CZ-3)) example_mod:example_nest[stage=mature]" >/dev/null
echo "a mature nest, set to breed one example mob then turn to sculk (400 ticks)"
for i in $(seq 1 30); do sleep 1; $CTL block $((CX+3)) $CY $((CZ-3)) | grep -q 'minecraft:sculk' && break; done
echo "nest block now: $($CTL block $((CX+3)) $CY $((CZ-3)) | j 'print(d)')"
$CTL block $((CX+3)) $CY $((CZ-3)) | grep -q 'minecraft:sculk' || { echo "STEP9: the spent nest did not turn to sculk"; exit 1; }
echo "STEP9 spent nest: sculk, wheat: $($CTL entities 8 | j 'print([e for e in d["entities"] if e.get("type")=="minecraft:item"])')"
echo "--- the hooks (the second goal's step 2), as the example mod uses them: a soft landing, no sleep while example mobs roam"
$CTL command "kill @e[type=example_mod:example_mob]" >/dev/null; sleep 0.5
$CTL command "summon example_mod:example_mob $CX $((CY+12)) $((CZ+3))" >/dev/null; sleep 3
FALLEN=$($CTL entities 16 | j 'print([(round(e["pos"][1]), e.get("health")) for e in d["entities"] if e.get("type")=="example_mod:example_mob"])')
echo "example mob dropped from 12 blocks up, now (y, health): $FALLEN"
echo "$FALLEN" | grep -q "($CY, 16.0)" || { echo "STEP10: the example mob did not land at full health (on_fall did not cancel the damage)"; exit 1; }
echo "STEP10 on_fall: full health after a 12-block fall"
# The bed hears the mods only at night in the overworld (the vanilla checks come first).
$CTL command "time set night" >/dev/null
$CTL command "setblock $((CX+4)) $CY $((CZ-4)) minecraft:red_bed[facing=east,part=foot]" >/dev/null
$CTL command "setblock $((CX+5)) $CY $((CZ-4)) minecraft:red_bed[facing=east,part=head]" >/dev/null; sleep 0.5
$CTL command "time set 18000" >/dev/null
$CTL command "tp @s $((CX+3)) $CY $((CZ-2))" >/dev/null; sleep 1
# With wheat in hand: the lure's own use on the bed would summon.
$CTL select minecraft:wheat >/dev/null
$CTL look-at $((CX+4)) $CY $((CZ-4)) >/dev/null
$CTL interact $((CX+4)) $CY $((CZ-4)) up | j 'print("bed clicked:", d.get("ok", d.get("error")))'; sleep 1
echo "action bar: $($CTL messages | j 'print(d.get("action_bar"))')"
grep -q 'may not sleep: [1-9][0-9]* example mob' "$LOG" || { echo "STEP10: the bed was not refused by on_sleep"; exit 1; }
echo "STEP10 on_sleep: the bed refused with example mobs roaming: $(grep -o '[A-Za-z0-9_]* may not sleep: [0-9]* example mob(s) roam' "$LOG" | tail -1)"
echo "--- the hooks' modkit callbacks (tools/modkit-probe), every one"
$CTL command "gamemode survival" >/dev/null
# A five-block drop in survival (Players:on_fall).
$CTL command "tp @s $CX $((CY+5)) $CZ" >/dev/null; sleep 2.5
$CTL chat "hello from steps-check" >/dev/null; sleep 0.5
$CTL command "damage @s 1 minecraft:generic" >/dev/null; sleep 0.5
$CTL give minecraft:stick 2 >/dev/null; sleep 0.5
$CTL select minecraft:stick >/dev/null; sleep 0.5
# The hand tracking follows the selected slot (the probe logs each change of
# the acting player's held stack; one player is all the harness drives, so
# only the one map is shown here, not two players' slots staying apart).
for i in $(seq 1 10); do sleep 0.5; grep -q "MODKIT held: minecraft:stick" "$LOG" && break; done
grep -q "MODKIT held: minecraft:stick" "$LOG" || { echo "STEP10: the held stack did not follow the selected slot"; exit 1; }
echo "STEP10 held: $(grep -o 'MODKIT held: [a-z_:]*' "$LOG" | tail -3 | tr '\n' ',' | sed 's/,$//')"
$CTL drop >/dev/null; sleep 1
$CTL give minecraft:snowball 2 >/dev/null; sleep 0.5
$CTL select minecraft:snowball >/dev/null; sleep 0.5
$CTL look-at $((CX+4)) $CY $((CZ+4)) >/dev/null
$CTL use-item >/dev/null; sleep 1.5
$CTL command "summon minecraft:tnt $((CX+3)) $((CY+1)) $((CZ+3)) {fuse:20}" >/dev/null
for i in 1 2 3 4 5 6; do sleep 1; grep -q "MODKIT cb M:on explosion" "$LOG" && break; done
# A husk's blow pushes the player (their on_knockback); an orb is picked up (on_exp); a heal (mob_heal).
$CTL command "summon minecraft:husk $((CX+2)) $CY $((CZ+1))" >/dev/null
for i in $(seq 1 12); do sleep 1; grep -q "MODKIT cb Players:on_knockback" "$LOG" && break; done
$CTL command "kill @e[type=!player,distance=..24]" >/dev/null
$CTL command "summon minecraft:experience_orb $CX $((CY+1)) $CZ {Value:3}" >/dev/null; sleep 1.5
$CTL command "effect give @s minecraft:instant_health 1 0" >/dev/null; sleep 0.5
# A zombie dropped from six blocks (Entity:on_fall), armed (Entity:on_equip), hit with a stick (Item:on_hurt_enemy,
# Entity:on_knockback) and killed with a sword (Entity:on_drops).
$CTL command "summon minecraft:zombie $((CX-2)) $((CY+6)) $((CZ-2))" >/dev/null; sleep 2
$CTL command "item replace entity @e[type=minecraft:zombie,limit=1,sort=nearest] weapon.mainhand with minecraft:iron_sword" >/dev/null; sleep 1
ZID=$(mob_id minecraft:zombie)
$CTL give minecraft:stick 1 >/dev/null; $CTL give minecraft:netherite_sword 1 >/dev/null; sleep 0.5
$CTL select minecraft:stick >/dev/null
for try in 1 2 3 4; do $CTL look-at-entity "$ZID" >/dev/null; $CTL attack "$ZID" >/dev/null; sleep 0.7; grep -q "MODKIT cb Item:on_hurt_enemy" "$LOG" && break; done
$CTL select minecraft:netherite_sword >/dev/null
for try in 1 2 3 4 5 6; do $CTL look-at-entity "$ZID" >/dev/null; R=$($CTL attack "$ZID"); echo "$R" | grep -q '"alive":false' && break; sleep 0.7; done
# An apple eaten (Item:on_use_start; use-item --hold, as tools/example-check.sh eats its snack: a raw mouse
# hold started the use but did not always finish it), planks crafted in the survival inventory's grid
# (Item:on_crafted).
$CTL give minecraft:apple 1 >/dev/null; sleep 0.5
$CTL select minecraft:apple >/dev/null
$CTL look 0 -60 >/dev/null
for try in 1 2 3; do $CTL use-item --hold 3 >/dev/null; sleep 0.5; grep -q "MODKIT cb Item:on_use_start" "$LOG" && break; done
$CTL give minecraft:oak_log 1 >/dev/null; sleep 0.5
LOGSLOT=$($CTL inventory | j '
slots = [(s["slot"], s) for s in d.get("main", []) + d.get("hotbar", [])]
print(next((n for n, s in slots if s.get("item") == "minecraft:oak_log"), ""))')
$CTL open-inventory >/dev/null; sleep 0.3
[ -n "$LOGSLOT" ] && $CTL click-slot "$LOGSLOT" >/dev/null && $CTL click-slot 100 >/dev/null && sleep 0.5 && $CTL click-slot 200 >/dev/null && sleep 0.3 && $CTL click-slot "$LOGSLOT" >/dev/null
$CTL close >/dev/null; sleep 0.5
$CTL command "gamemode creative" >/dev/null
# A chest opened (Players:on_open_menu), a command typed in chat (Players:on_command), a trip to the Nether and
# back (Players:on_change_dimension), and a bed with no example mob alive (Players:on_sleep: the example mod's
# own on_sleep refuses first while any roams, and a cancel ends the dispatch before the probe is asked).
$CTL command "setblock $((CX-3)) $CY $((CZ+3)) minecraft:chest" >/dev/null; sleep 0.5
$CTL look-at $((CX-3)) $CY $((CZ+3)) >/dev/null
$CTL interact $((CX-3)) $CY $((CZ+3)) up >/dev/null; sleep 1
$CTL close >/dev/null; sleep 0.5
$CTL chat "/example report" >/dev/null; sleep 0.5
$CTL command "execute in minecraft:the_nether run tp @s 0 100 0" >/dev/null; sleep 2
$CTL command "execute in minecraft:overworld run tp @s $CX $CY $CZ" >/dev/null; sleep 2
$CTL command "kill @e[type=example_mod:example_mob]" >/dev/null
$CTL command "kill @e[type=!player,distance=..24]" >/dev/null; sleep 0.5
# On a free row of the platform (the gold box of the helpers step stands at the other corner).
$CTL command "time set night" >/dev/null
$CTL command "setblock $((CX+4)) $CY $((CZ-1)) minecraft:red_bed[facing=east,part=foot]" >/dev/null
$CTL command "setblock $((CX+5)) $CY $((CZ-1)) minecraft:red_bed[facing=east,part=head]" >/dev/null; sleep 0.5
$CTL command "tp @s $((CX+3)) $CY $CZ" >/dev/null; sleep 1
$CTL select minecraft:stick >/dev/null
for try in 1 2 3; do $CTL look-at $((CX+4)) $CY $((CZ-1)) >/dev/null; $CTL interact $((CX+4)) $CY $((CZ-1)) up >/dev/null; sleep 1.5; grep -q "MODKIT cb Players:on_sleep" "$LOG" && break; $CTL close >/dev/null 2>&1; sleep 0.5; done
$CTL close >/dev/null 2>&1
for cb in "Players:on_tick" "Players:on_hurt" "Players:on_fall" "Players:on_knockback" "Players:on_chat" "Players:on_command" \
  "Players:on_change_dimension" "Players:on_sleep" "Players:on_exp" "Players:on_open_menu" \
  "Entity:on_fall" "Entity:on_knockback" "Entity:on_equip" "Entity:on_drops" "Block:on_drops" \
  "Item:on_crafted" "Item:on_dropped" "Item:on_hurt_enemy" "Item:on_use_start" \
  "M:on explosion" "M:on entity_joined" "M:on projectile_launched" "M:on projectile_impact" "M:on mob_heal" "M:on projectile_launched" "M:on projectile_impact" "M:on entity_joined" "M:on explosion"; do
  grep -q "MODKIT cb $cb" "$LOG" || { echo "STEP10: the modkit callback $cb did not run"; exit 1; }
done
echo "STEP10 modkit callbacks: $(grep -o 'MODKIT cb [A-Za-z:_]*\( [a-z_]*\)\?' "$LOG" | sed 's/MODKIT cb //' | sort -u | tr '\n' ',' | sed 's/,$//')"
echo "--- step 3: the player dies and respawns"
$CTL command "kill @s" >/dev/null
for i in 1 2 3 4 5 6; do sleep 1; $CTL state | grep -q '"screen":"dead"' && break; done
$CTL click-button Respawn | j 'print("respawn:", d.get("clicked", d.get("error")))'
for i in 1 2 3 4 5 6; do sleep 1; $CTL state | grep -q '"screen":"dead"' || break; done
$CTL command "gamemode creative" >/dev/null
echo "--- step 6: natural spawning (the biome modifier): the mobs the fresh world's chunks came with, then midnight"
$CTL command "tp @s $GX $GY $GZ" >/dev/null; sleep 2
echo "example mobs the world generated near the spawn: $GEN"
$CTL command "difficulty normal" >/dev/null
$CTL command "gamerule spawn_mobs true" >/dev/null
$CTL command "gamerule spawn_monsters true" >/dev/null
$CTL command "time set midnight" >/dev/null
for i in $(seq 1 12); do sleep 5; grep -q 'STEP6 spawned example_mod:example_mob natural=true' "$LOG" && break; done
echo "natural example mob spawns logged: $(grep -c 'STEP6 spawned example_mod:example_mob natural=true' "$LOG")"
# A creature spawns mostly as its chunk is generated (the engine tells no mob_spawned for those), rarely after, so
# the count is the proof and the log line a bonus.
if [ "${GEN:-0}" -gt 0 ] 2>/dev/null || grep -q 'STEP6 spawned example_mod:example_mob natural=true' "$LOG"; then
  echo "STEP6 natural spawning: the biome modifier adds the example mob to the overworld"
else
  echo "STEP6: no example mob from the biome modifier (none generated near the spawn, none spawned at midnight)"; $CTL quit >/dev/null; exit 1
fi
$CTL quit >/dev/null; sleep 2
echo "--- log lines per step (screenshot of the model at $SHOT)"
grep -n "STEP[0-9]\|lua:.*error" "$LOG" | cut -c1-200
grep -q "lua:.*error" "$LOG" && exit 1
for n in "STEP1" "STEP3 hurt" "STEP3 died" "STEP3 respawned" "STEP4 data" "STEP4 timer" "STEP5" "STEP6" "STEP9 config: runs=1 limit=16" "STEP9 summon: zombie id=[0-9]" "STEP9 reads: light=" "STEP9 data: stick recipe type=minecraft:crafting_shaped" "STEP9 named player: bread=2 stacks=[1-9].* time_of_day=600[0-9]" "EXAMPLE nest spent after 1"; do grep -q "$n" "$LOG" || { echo "no $n line"; exit 1; }; done
exit 0
