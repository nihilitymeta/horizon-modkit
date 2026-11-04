#!/usr/bin/env bash
# Drives examples/example_mod in a game beside this modkit through horizon-ctl: each concept file logs an
# `EXAMPLE ...` line when its concept runs, and every one is expected (the feather used in the air, on a block,
# on a mob; the lamp lit, dimmed by its tick, placed and broken; a mob spawned, fed, hit and killed; the chat,
# the commands, the effects, the timer, the settings file, a death; the nest grown, bred and spent, kept from a
# bare hand and hoed; the lure used and a zombie turned with it; a zombie converted beside an example mob; a
# keeper named after three feedings and suffixed in the chat; the bed refused; the cull by the settings).
#
#   HORIZON=/path/to/horizon RESOURCES=<26.3 folder> GAME_DIR=~/horizon-dev tools/example-check.sh
#
# HORIZON is the fork checkout, built (`target/fast/horizon-client` and `horizon-ctl`); WORLD defaults to "New World".
set -u
HERE=$(cd "$(dirname "$0")/.." && pwd)
: "${HORIZON:?the fork checkout}" "${RESOURCES:?the prepared 26.3 folder}" "${GAME_DIR:?the game dir}"
MOD="$HERE/examples/example_mod"
WORLD=${WORLD:-New World}
SOCK=${SOCK:-/tmp/horizon-example-check.sock}
CTL="${GAME_BUILD:-$HORIZON/target/fast}/horizon-ctl --socket $SOCK"
# The game writes logs/ under HORIZON_HOME when it is set: keep that the game dir, so the log is here.
export HORIZON_HOME="$GAME_DIR"
LOG="$GAME_DIR/logs/latest.log"
j() { python3 -c "import sys,json; d=json.load(sys.stdin); $1"; }
mob_id() { for i in 1 2 3 4 5 6; do local id; id=$($CTL entities 12 | j "es=[e for e in d['entities'] if e.get('type')=='$1']; print(es[0]['id'] if es else '')"); [ -n "$id" ] && { echo "$id"; return; }; sleep 0.5; done; }
# The settings, written before the game reads them at load: a nest is spent after one example mob, so the
# check sees it turn to sculk within the run (the other keys are filled in with their defaults).
mkdir -p "$GAME_DIR/config"
printf '{"nest_breeds": 1}\n' > "$GAME_DIR/config/example_mod.json"
# Quiet: the master volume off in the game dir's options.
[ -f "$GAME_DIR/options.txt" ] && sed -i.bak 's/^soundCategory_master:.*/soundCategory_master:0.0/' "$GAME_DIR/options.txt" && rm -f "$GAME_DIR/options.txt.bak"
echo "--- the example mod in a game beside the modkit"
$CTL launch --game "${GAME_BUILD:-$HORIZON/target/fast}/horizon-client" --wait --game-dir "$GAME_DIR" --resources "$RESOURCES" \
  --world "$WORLD" --offscreen --dev-tools --dev-mod "$HERE" --dev-mod "$MOD" >/dev/null
$CTL wait-ready 180 >/dev/null
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
# Night, and kept there: a zombie stands in it, and a bed takes a player only at night.
$CTL command "time set 18000" >/dev/null
$CTL command "kill @e[type=!player]" >/dev/null; sleep 0.5
$CTL command "clear" >/dev/null; sleep 1
# A stone platform high up, so nothing else is around.
P=$($CTL state | j 'p=d["player"]["position"]; print(int(p[0]//1), int(p[2]//1))'); set -- $P; CX=$1; CZ=$2; CY=200
$CTL command "fill $((CX-5)) $((CY-1)) $((CZ-5)) $((CX+5)) $((CY-1)) $((CZ+5)) minecraft:stone" >/dev/null
$CTL command "fill $((CX-5)) $CY $((CZ-5)) $((CX+5)) $((CY+6)) $((CZ+5)) minecraft:air" >/dev/null
$CTL command "tp @s $CX $CY $CZ" >/dev/null; sleep 2

echo "--- the nest: set dormant, bone mealed to growing then mature; it charges 400 ticks, breeds once and is spent while the rest runs (nest.lua)"
NX=$((CX+3)); NZ=$((CZ-3))
$CTL command "setblock $NX $CY $NZ example_mod:example_nest[stage=dormant]" >/dev/null; sleep 0.5
$CTL give minecraft:bone_meal 4 >/dev/null; sleep 0.5
$CTL select minecraft:bone_meal | j 'print("holding:", d.get("held", {}).get("item", d.get("error")))'
for stage in growing mature; do
  $CTL look-at $NX $CY $NZ >/dev/null
  $CTL interact $NX $CY $NZ up | j 'print("bone meal on the nest:", d.get("ok", d.get("error")))'; sleep 0.7
  $CTL block $NX $CY $NZ | j 'print("nest state:", d.get("state"))'
done

echo "--- commands: /example feather, where, report (command.lua, timers_and_data.lua)"
$CTL chat "/example feather 2" >/dev/null; sleep 0.5
$CTL chat "/example where" >/dev/null; sleep 0.5
$CTL chat "/example report" >/dev/null; sleep 0.5
$CTL messages 6 | j 'print("said:", [c for c in d.get("chat", []) if "feather" in c or " is at " in c or "report" in c])'
FEATHERS=$($CTL inventory | j 'print(sum(s["count"] for k in ("hotbar","main") for s in d.get(k, []) if s.get("item")=="example_mod:example_item"))')
echo "feathers carried: $FEATHERS"

echo "--- the feather: used in the air, on a block (item.lua)"
$CTL select example_mod:example_item | j 'print("holding:", d.get("held", {}).get("item", d.get("error")))'
$CTL look 0 -60 >/dev/null
$CTL use-item | j 'print("used in the air:", d.get("ok", d.get("error")))'; sleep 1
$CTL look-at $((CX+2)) $((CY-1)) $((CZ+2)) >/dev/null
$CTL interact $((CX+2)) $((CY-1)) $((CZ+2)) up | j 'print("used on the stone:", d.get("ok", d.get("error")))'; sleep 1

echo "--- the mob: summoned, fed wheat, hit with the feather, killed (mob.lua, spawning.lua)"
$CTL command "summon example_mod:example_mob $CX $CY $((CZ+3))" >/dev/null; sleep 1
MID=$(mob_id example_mod:example_mob); echo "mob id: ${MID:-none}"
$CTL give minecraft:wheat 4 >/dev/null; sleep 0.5
$CTL select minecraft:wheat >/dev/null
[ -n "$MID" ] && { $CTL look-at-entity "$MID" >/dev/null; $CTL interact-entity "$MID" | j 'print("fed:", d.get("ok", d.get("error")))'; sleep 1; }
$CTL select example_mod:example_item >/dev/null
[ -n "$MID" ] && { $CTL look-at-entity "$MID" >/dev/null; $CTL attack | j 'print("hit:", d.get("ok", d.get("error")))'; sleep 1; }
echo "--- the keeper: two more feedings make three, the chat carries it (mob.lua, players.lua)"
$CTL select minecraft:wheat >/dev/null
for n in 2 3; do [ -n "$MID" ] && { $CTL look-at-entity "$MID" >/dev/null; $CTL interact-entity "$MID" | j 'print("fed again:", d.get("ok", d.get("error")))'; sleep 0.7; }; done
$CTL chat "hello from a keeper" >/dev/null; sleep 0.7
$CTL messages 3 | j 'print("the chat said:", d.get("chat"))'
$CTL command "kill @e[type=example_mod:example_mob]" >/dev/null; sleep 1
$CTL chat "/example spawn 1" >/dev/null; sleep 1.5
$CTL command "kill @e[type=example_mod:example_mob]" >/dev/null; sleep 0.5

echo "--- the conversion: a zombie beside an example mob for three seconds becomes one (conversion.lua)"
$CTL command "summon example_mod:example_mob $((CX+1)) $CY $CZ {NoAI:1b}" >/dev/null
$CTL command "summon minecraft:zombie $((CX+1)) $CY $((CZ+1))" >/dev/null
for i in $(seq 1 12); do sleep 1; grep -q "EXAMPLE conversion" "$LOG" && break; done
echo "mobs after the wait: $($CTL entities 12 | j 'print(sorted(e.get("type") for e in d["entities"] if e.get("type") not in ("minecraft:item",)))')"
$CTL command "kill @e[type=example_mod:example_mob]" >/dev/null
$CTL command "kill @e[type=minecraft:zombie]" >/dev/null; sleep 0.5

echo "--- the lure: used on the stone (an example mob climbs out), a zombie hit with it (lure.lua)"
$CTL chat "/example lure 2" >/dev/null; sleep 0.5
$CTL select example_mod:example_lure | j 'print("holding:", d.get("held", {}).get("item", d.get("error")))'
$CTL look-at $((CX-2)) $((CY-1)) $((CZ-2)) >/dev/null
$CTL interact $((CX-2)) $((CY-1)) $((CZ-2)) up | j 'print("lure used on the stone:", d.get("ok", d.get("error")))'; sleep 1
echo "example mobs after the lure: $($CTL entities 12 | j 'print(sum(1 for e in d["entities"] if e.get("type")=="example_mod:example_mob"))')"
$CTL command "kill @e[type=example_mod:example_mob]" >/dev/null; sleep 0.5
$CTL command "summon minecraft:zombie $CX $CY $((CZ-3)) {NoAI:1b}" >/dev/null; sleep 1
ZID=$(mob_id minecraft:zombie); echo "zombie id: ${ZID:-none}"
[ -n "$ZID" ] && { $CTL look-at-entity "$ZID" >/dev/null; $CTL attack "$ZID" | j 'print("hit with the lure:", d.get("hit", d.get("error")))'; sleep 1; }
echo "mobs after the blow: $($CTL entities 12 | j 'print(sorted(e.get("type") for e in d["entities"] if e.get("type") not in ("minecraft:item",)))')"
$CTL command "kill @e[type=example_mod:example_mob]" >/dev/null
$CTL command "kill @e[type=minecraft:zombie]" >/dev/null; sleep 0.5

echo "--- the lamp: set, lit by a click, dimmed by its block entity, lit by a random then a scheduled tick, broken; one placed (block.lua, players.lua)"
$CTL command "setblock $((CX+3)) $CY $CZ example_mod:example_block" >/dev/null; sleep 0.5
$CTL look-at $((CX+3)) $CY $CZ >/dev/null
$CTL interact $((CX+3)) $CY $CZ up | j 'print("lamp clicked:", d.get("ok", d.get("error")))'; sleep 0.5
$CTL block $((CX+3)) $CY $CZ | j 'print("lamp state:", d.get("state"))'
sleep 6
$CTL block $((CX+3)) $CY $CZ | j 'print("lamp state after 100 ticks:", d.get("state"))'
# Random ticks come fast for a moment, so one reaches the lamp, and a dormant nest grows on its own (then
# it goes, before it breeds).
$CTL command "setblock $((CX-3)) $CY $((CZ+3)) example_mod:example_nest[stage=dormant]" >/dev/null
$CTL command "gamerule random_tick_speed 1000" >/dev/null; sleep 4
$CTL command "gamerule random_tick_speed 3" >/dev/null
$CTL block $((CX+3)) $CY $CZ | j 'print("lamp state after the random ticks:", d.get("state"))'
$CTL block $((CX-3)) $CY $((CZ+3)) | j 'print("nest state after the random ticks:", d.get("state"))'
$CTL command "setblock $((CX-3)) $CY $((CZ+3)) minecraft:air" >/dev/null
$CTL look-at $((CX+3)) $CY $CZ >/dev/null
$CTL break $((CX+3)) $CY $CZ --timeout 10 | j 'print("lamp broken:", d.get("block_before", d.get("error")))'; sleep 1
$CTL chat "/example lamp" >/dev/null; sleep 0.5
$CTL select example_mod:example_block >/dev/null
$CTL look-at $((CX-3)) $((CY-1)) $CZ >/dev/null
$CTL place $((CX-3)) $CY $CZ | j 'print("lamp placed:", d.get("ok", d.get("error")))'; sleep 1

echo "--- a mature nest: kept from a bare hand, hoed in survival (wheat, not the nest: loot by stage) (nest.lua)"
BX=$((CX-3)); BZ=$((CZ-3))
$CTL command "setblock $BX $CY $BZ example_mod:example_nest[stage=mature]" >/dev/null; sleep 0.5
$CTL select minecraft:wheat >/dev/null
$CTL look-at $BX $CY $BZ >/dev/null
$CTL break $BX $CY $BZ --timeout 5 | j 'print("broken with wheat in hand:", d.get("block_before", d.get("error")))'; sleep 0.7
$CTL block $BX $CY $BZ | j 'print("nest after the refused break:", d.get("block"))'
$CTL give minecraft:netherite_hoe 1 >/dev/null; sleep 0.5
$CTL command "gamemode survival" >/dev/null; sleep 0.5
$CTL select minecraft:netherite_hoe | j 'print("holding:", d.get("held", {}).get("item", d.get("error")))'
$CTL look-at $BX $CY $BZ >/dev/null
$CTL break $BX $CY $BZ --timeout 10 | j 'print("hoed:", d.get("block_before", d.get("error")))'; sleep 1
WHEAT=$($CTL entities 8 | j 'print(sum(e["item"]["count"] for e in d["entities"] if e.get("type")=="minecraft:item" and e["item"]["item"]=="minecraft:wheat"))')
echo "wheat on the ground from the mature nest: $WHEAT"
$CTL command "gamemode creative" >/dev/null
$CTL command "kill @e[type=minecraft:item]" >/dev/null; sleep 0.5

echo "--- the chat, the effects, a dropped feather, the snack (players.lua, effects.lua, item.lua)"
$CTL chat "ping" >/dev/null; sleep 0.5
$CTL messages 3 | j 'print("the chat said:", d.get("chat"))'
$CTL chat "/example show" >/dev/null; sleep 1
$CTL select example_mod:example_item >/dev/null; sleep 0.3
$CTL drop | j 'print("dropped:", d.get("dropped_from", d.get("error")))'; sleep 0.5
$CTL give example_mod:example_snack 1 >/dev/null; sleep 0.5
$CTL select example_mod:example_snack >/dev/null
$CTL look 0 -60 >/dev/null
$CTL use-item --hold 1.5 | j 'print("snack:", d.get("ok", d.get("error")))'; sleep 1

echo "--- the bed, refused while an example mob roams (players.lua)"
$CTL command "kill @e[type=!player]" >/dev/null
$CTL command "setblock $((CX+3)) $CY $((CZ+3)) minecraft:red_bed[facing=east,part=foot]" >/dev/null
$CTL command "setblock $((CX+4)) $CY $((CZ+3)) minecraft:red_bed[facing=east,part=head]" >/dev/null
$CTL command "summon example_mod:example_mob $((CX-2)) $CY $((CZ+3)) {NoAI:1b}" >/dev/null; sleep 0.5
$CTL command "tp @s $((CX+2)) $CY $((CZ+1))" >/dev/null; sleep 1
$CTL select minecraft:wheat >/dev/null
for try in 1 2 3; do
  $CTL look-at $((CX+3)) $CY $((CZ+3)) >/dev/null
  $CTL interact $((CX+3)) $CY $((CZ+3)) up | j 'print("bed clicked:", d.get("ok", d.get("error")))'; sleep 1
  grep -q "may not sleep" "$LOG" && break
  $CTL close >/dev/null 2>&1; sleep 0.5
done
echo "action bar: $($CTL messages | j 'print(d.get("action_bar"))')"
$CTL command "kill @e[type=example_mod:example_mob]" >/dev/null
$CTL command "tp @s $CX $CY $CZ" >/dev/null; sleep 0.5

echo "--- the cull: /example max 1 saved, three example mobs, the minute timer kills the rest (timers_and_data.lua)"
$CTL chat "/example max 1" >/dev/null; sleep 0.5
grep -q '"max_mobs": 1' "$GAME_DIR/config/example_mod.json" && echo "settings saved: $(tr -d '\n ' < "$GAME_DIR/config/example_mod.json")"
for i in 1 2 3; do $CTL command "summon example_mod:example_mob $((CX+i)) $CY $((CZ+2)) {NoAI:1b}" >/dev/null; done
for i in $(seq 1 80); do sleep 1; grep -q "EXAMPLE cull" "$LOG" && break; done
sleep 1
LEFT=$($CTL entities 12 | j 'print(sum(1 for e in d["entities"] if e.get("type")=="example_mod:example_mob"))')
echo "example mobs after the minute: $LEFT"
$CTL command "kill @e[type=example_mod:example_mob]" >/dev/null; sleep 0.5

echo "--- a death (players.lua)"
$CTL command "kill @s" >/dev/null; sleep 1.5
$CTL click-button Respawn >/dev/null 2>&1; sleep 1

# Read before the quit: the log is rotated then.
LINES=$(grep 'Lua mod example_mod\|EXAMPLE\|lua:example_mod' "$LOG")
$CTL quit >/dev/null; sleep 2
echo "$LINES" | grep -o 'EXAMPLE [a-z]* [a-z]*' | sort | uniq -c | sort -rn | head -40
failed=0
expect() { echo "$LINES" | grep -q "$1" || { echo "MISSING: $1"; failed=1; }; }
expect 'Lua mod example_mod running'
expect 'EXAMPLE timer: two seconds'
expect 'EXAMPLE player joined'
expect 'EXAMPLE command feather'
expect 'EXAMPLE item used by'
expect 'EXAMPLE item used on minecraft:stone'
expect 'EXAMPLE mob spawned at'
expect 'EXAMPLE mob fed by'
expect 'EXAMPLE item hit a example_mod:example_mob'
expect 'EXAMPLE mob died'
expect 'EXAMPLE block lit by Player'
expect 'EXAMPLE block dimmed after 100 ticks'
expect 'EXAMPLE block lit by its scheduled tick'
expect 'EXAMPLE block broken by'
expect 'EXAMPLE player broke example_mod:example_block'
expect 'EXAMPLE block placed by'
expect 'EXAMPLE player placed example_mod:example_block'
expect 'EXAMPLE chat from'
expect 'EXAMPLE effects shown to'
expect 'EXAMPLE item dropped'
expect 'EXAMPLE snack eaten'
expect 'EXAMPLE player died'
expect 'EXAMPLE nest bone mealed to growing by Player'
expect 'EXAMPLE nest bone mealed to mature by Player'
expect 'EXAMPLE nest bred an example mob (1 so far)'
expect 'EXAMPLE nest spent after 1'
expect 'EXAMPLE nest grew to'
expect 'EXAMPLE nest kept from Player.*: no hoe'
expect 'EXAMPLE nest broken by Player.* while mature'
expect 'EXAMPLE keeper: Player.* fed three example mobs'
expect 'EXAMPLE keeper chat from Player'
expect 'EXAMPLE conversion: a zombie became an example mob'
expect 'EXAMPLE lure used on minecraft:stone by Player'
expect 'EXAMPLE lure turned a zombie'
expect 'EXAMPLE player Player.* may not sleep: 1 example mob(s) roam'
expect 'EXAMPLE command max 1 by Player'
expect 'EXAMPLE cull: 2 example mob(s) over 1'
[ "$WHEAT" -ge 2 ] 2>/dev/null || { echo "MISSING: the wheat a mature nest drops instead of itself (found $WHEAT)"; failed=1; }
[ "$LEFT" = 1 ] 2>/dev/null || { echo "MISSING: one example mob left by the cull (found $LEFT)"; failed=1; }
[ "$FEATHERS" -ge 2 ] 2>/dev/null || { echo "MISSING: the feathers from /example feather (carried $FEATHERS)"; failed=1; }
[ -f "$GAME_DIR/config/example_mod.json" ] && grep -q greeting "$GAME_DIR/config/example_mod.json" || { echo "MISSING: config/example_mod.json with the greeting"; failed=1; }
echo "$LINES" | grep 'lua:example_mod.*error' | head -5 | cut -c1-200
echo "$LINES" | grep -q 'lua:example_mod.*error' && { echo "script errors in the example mod"; failed=1; }
[ $failed = 0 ] && echo "EXAMPLE OK: every concept seen" || echo "EXAMPLE FAILED"
exit $failed
