#!/usr/bin/env bash
# Drives examples/example_mod in a game beside this modkit through horizon-ctl: each concept file logs an
# `EXAMPLE ...` line when its concept runs, and every one is expected (the feather used in the air, on a block,
# on a mob; the lamp lit, dimmed by its tick, placed and broken; a mob spawned, fed, hit and killed; the chat,
# the commands, the effects, the timer, the settings file, a death).
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
$CTL command "gamerule do_mob_spawning false" >/dev/null
$CTL command "kill @e[type=!player]" >/dev/null; sleep 0.5
$CTL command "clear" >/dev/null; sleep 1
# A stone platform high up, so nothing else is around.
P=$($CTL state | j 'p=d["player"]["position"]; print(int(p[0]//1), int(p[2]//1))'); set -- $P; CX=$1; CZ=$2; CY=200
$CTL command "fill $((CX-5)) $((CY-1)) $((CZ-5)) $((CX+5)) $((CY-1)) $((CZ+5)) minecraft:stone" >/dev/null
$CTL command "fill $((CX-5)) $CY $((CZ-5)) $((CX+5)) $((CY+6)) $((CZ+5)) minecraft:air" >/dev/null
$CTL command "tp @s $CX $CY $CZ" >/dev/null; sleep 2

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
$CTL command "kill @e[type=example_mod:example_mob]" >/dev/null; sleep 1
$CTL chat "/example spawn 1" >/dev/null; sleep 1.5
$CTL command "kill @e[type=example_mod:example_mob]" >/dev/null; sleep 0.5

echo "--- the lamp: set, lit by a click, dimmed by its block entity, lit by a random then a scheduled tick, broken; one placed (block.lua, players.lua)"
$CTL command "setblock $((CX+3)) $CY $CZ example_mod:example_block" >/dev/null; sleep 0.5
$CTL look-at $((CX+3)) $CY $CZ >/dev/null
$CTL interact $((CX+3)) $CY $CZ up | j 'print("lamp clicked:", d.get("ok", d.get("error")))'; sleep 0.5
$CTL block $((CX+3)) $CY $CZ | j 'print("lamp state:", d.get("state"))'
sleep 6
$CTL block $((CX+3)) $CY $CZ | j 'print("lamp state after 100 ticks:", d.get("state"))'
# Random ticks come fast for a moment, so one reaches the lamp.
$CTL command "gamerule random_tick_speed 1000" >/dev/null; sleep 4
$CTL command "gamerule random_tick_speed 3" >/dev/null
$CTL block $((CX+3)) $CY $CZ | j 'print("lamp state after the random ticks:", d.get("state"))'
$CTL look-at $((CX+3)) $CY $CZ >/dev/null
$CTL break $((CX+3)) $CY $CZ --timeout 10 | j 'print("lamp broken:", d.get("block_before", d.get("error")))'; sleep 1
$CTL chat "/example lamp" >/dev/null; sleep 0.5
$CTL select example_mod:example_block >/dev/null
$CTL look-at $((CX-3)) $((CY-1)) $CZ >/dev/null
$CTL place $((CX-3)) $CY $CZ | j 'print("lamp placed:", d.get("ok", d.get("error")))'; sleep 1

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
[ "$FEATHERS" -ge 2 ] 2>/dev/null || { echo "MISSING: the feathers from /example feather (carried $FEATHERS)"; failed=1; }
[ -f "$GAME_DIR/config/example_mod.json" ] && grep -q greeting "$GAME_DIR/config/example_mod.json" || { echo "MISSING: config/example_mod.json with the greeting"; failed=1; }
echo "$LINES" | grep 'lua:example_mod.*error' | head -5 | cut -c1-200
echo "$LINES" | grep -q 'lua:example_mod.*error' && { echo "script errors in the example mod"; failed=1; }
[ $failed = 0 ] && echo "EXAMPLE OK: every concept seen" || echo "EXAMPLE FAILED"
exit $failed
