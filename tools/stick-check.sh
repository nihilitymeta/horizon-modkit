#!/usr/bin/env bash
# Drives the inspect stick (scripts/registry.lua, scripts/init.lua) in a game started WITHOUT --dev-tools, beside
# the example mod: a mob's pages forward and, sneaking, back; a villager inspected and not traded with; a chest's
# block window instead of its screen; a button not pressed; an example mod block. Then in survival the stick is any
# stick: the chest opens. Each step is judged by what the game tells the player (the action bar line the engine
# sends) and the screen and block state; the windows themselves are egui, so it saves a screenshot of each to look at.
#
#   HORIZON=/path/to/horizon RESOURCES=<26.3 folder> GAME_DIR=<scratch game dir> tools/stick-check.sh
#
# HORIZON is the fork checkout, built (`target/fast/horizon-client` and `horizon-ctl`). The game quits at the end;
# a check stopped half way leaves it running: quit it with `horizon-ctl --socket /tmp/horizon-stick-check.sock quit`.
set -u
HERE=$(cd "$(dirname "$0")/.." && pwd)
: "${HORIZON:?the fork checkout}" "${RESOURCES:?the prepared 26.3 folder}" "${GAME_DIR:?the game dir}"
MOD="$HERE/examples/example_mod"
WORLD=${WORLD:-stick-check}
SOCK=${SOCK:-/tmp/horizon-stick-check.sock}
SHOTS=${SHOTS:-$GAME_DIR/stick-check}
CTL="${GAME_BUILD:-$HORIZON/target/fast}/horizon-ctl --socket $SOCK"
export HORIZON_HOME="$GAME_DIR" HORIZON_NO_AUDIO=1
j() { python3 -c "import sys,json; d=json.load(sys.stdin); $1"; }
failed=0
bar() { $CTL messages | j 'print(d.get("actionbar") or "")'; }
# The action bar after a click must hold $1.
want() {
  local got; got=$(bar)
  case "$got" in *"$1"*) echo "ok: $2 ($got)";; *) echo "FAILED: $2: wanted \"$1\", the action bar says \"$got\""; failed=1;; esac
}
screen() { $CTL state | j 'print(d["screen"])'; }
# The sneak key as the game dir's options bind it (key.keyboard.left.shift unless changed).
SNEAK=$(sed -n 's/^key_key.sneak:key.keyboard.//p' "$GAME_DIR/options.txt" 2>/dev/null)
case "${SNEAK:-left.shift}" in left.shift|right.shift) SNEAK=shift;; esac
mkdir -p "$SHOTS"

echo "--- the modkit and the example mod in a game without --dev-tools"
$CTL launch --game "${GAME_BUILD:-$HORIZON/target/fast}/horizon-client" --wait --game-dir "$GAME_DIR" \
  --resources "$RESOURCES" --world "$WORLD" --creative --offscreen --dev-mod "$HERE" --dev-mod "$MOD" >/dev/null
$CTL wait-ready 180 >/dev/null
$CTL command "gamemode creative" >/dev/null
$CTL command "gamerule spawn_mobs false" >/dev/null
$CTL command "kill @e[type=!player]" >/dev/null
$CTL command "clear" >/dev/null
# A glass platform high up, so nothing else is in reach.
$CTL command "fill -5 199 -5 5 199 5 minecraft:glass" >/dev/null
$CTL command "fill -5 200 -5 5 205 5 minecraft:air" >/dev/null
$CTL command "tp @s 0.5 200 0.5 0 20" >/dev/null; sleep 1
$CTL chat "/give @s horizon_modkit:inspect_stick" >/dev/null; sleep 0.5
$CTL select horizon_modkit:inspect_stick | j 'print("holding:", d.get("held", {}).get("item", d.get("error")))'

echo "--- a mob: data, then its goals; sneaking, back to its data and round to its path"
$CTL command "summon minecraft:pig 0.5 200 2.5 {NoAI:1b}" >/dev/null; sleep 1
PIG=$($CTL entities | j 'es=[e for e in d["entities"] if e["type"]=="minecraft:pig"]; print(es[0]["id"])')
$CTL interact-entity "$PIG" >/dev/null; sleep 0.5; want "/inspect, page 1 of 4" "the first click shows the data"
$CTL interact-entity "$PIG" >/dev/null; sleep 0.5; want "/goals, page 2 of 4" "the same mob again turns the page"
$CTL screenshot "$SHOTS/goals.png" >/dev/null
$CTL key "$SNEAK" down >/dev/null; sleep 0.5
$CTL interact-entity "$PIG" >/dev/null; sleep 0.5; want "/inspect, page 1 of 4" "sneaking turns it back"
$CTL interact-entity "$PIG" >/dev/null; sleep 0.5; want "/nav, page 4 of 4" "and round to the last"
$CTL key "$SNEAK" up >/dev/null; sleep 0.5
$CTL command "kill @e[type=minecraft:pig]" >/dev/null

echo "--- a villager: inspected, not traded with"
$CTL command "summon minecraft:villager 0.5 200 2.5 {NoAI:1b,VillagerData:{profession:\"minecraft:farmer\",level:2,type:\"minecraft:plains\"}}" >/dev/null; sleep 1
VIL=$($CTL entities | j 'es=[e for e in d["entities"] if e["type"]=="minecraft:villager"]; print(es[0]["id"])')
$CTL interact-entity "$VIL" >/dev/null; sleep 0.5
want "/nav, page 4 of 4" "a villager has a mob's pages and keeps the page"
[ "$(screen)" = playing ] && echo "ok: no trading screen" || { echo "FAILED: the villager's screen opened"; failed=1; $CTL close >/dev/null; }
$CTL command "kill @e[type=minecraft:villager]" >/dev/null

echo "--- a chest, a button and a mod block: the block window, and nothing else"
$CTL command "setblock 1 200 2 minecraft:chest" >/dev/null
$CTL command "setblock -1 200 2 minecraft:stone_button[face=floor]" >/dev/null
$CTL command "setblock 0 200 3 example_mod:example_nest" >/dev/null; sleep 0.5
$CTL interact 1 200 2 >/dev/null; sleep 0.5; want "the block window" "a chest's block window"
[ "$(screen)" = playing ] && echo "ok: the chest stayed shut" || { echo "FAILED: the chest opened"; failed=1; $CTL close >/dev/null; }
$CTL screenshot "$SHOTS/chest.png" >/dev/null
BUTTON=$($CTL interact -1 200 2 | j 'print(d["block"]["state"])')
case "$BUTTON" in *powered=false*) echo "ok: the button stayed up";; *) echo "FAILED: the button was pressed ($BUTTON)"; failed=1;; esac
$CTL interact 0 200 3 >/dev/null; sleep 0.5; want "the block window" "an example mod block's window"
$CTL screenshot "$SHOTS/nest.png" >/dev/null

echo "--- without the stick nothing is inspected and clicks go through"
$CTL give minecraft:stick 1 >/dev/null; sleep 0.5
$CTL select minecraft:stick | j 'print("holding:", d.get("held", {}).get("item", d.get("error")))'
# A chest: it opens instead of the block window (an open screen means no
# inspect window took the click).
$CTL interact 1 200 2 >/dev/null; sleep 0.5
[ "$(screen)" != playing ] && echo "ok: the chest opened with a plain stick" || { echo "FAILED: the chest stayed shut with a plain stick (the click was cancelled)"; failed=1; }
$CTL close >/dev/null 2>&1
# A button: it is pressed, so the click was not cancelled either.
BUTTON=$($CTL interact -1 200 2 | j 'print(d["block"]["state"])')
case "$BUTTON" in *powered=true*) echo "ok: the button was pressed with a plain stick";; *) echo "FAILED: the button stayed up with a plain stick ($BUTTON)"; failed=1;; esac
# A villager: the trading screen opens instead of a mob's pages.
$CTL command "summon minecraft:villager 0.5 200 2.5 {NoAI:1b,VillagerData:{profession:\"minecraft:farmer\",level:2,type:\"minecraft:plains\"}}" >/dev/null; sleep 1
VIL=$($CTL entities | j 'es=[e for e in d["entities"] if e["type"]=="minecraft:villager"]; print(es[0]["id"])')
$CTL interact-entity "$VIL" >/dev/null; sleep 0.5
[ "$(screen)" != playing ] && echo "ok: trading opened with a plain stick" || { echo "FAILED: no trading screen with a plain stick (the click was cancelled)"; failed=1; }
$CTL close >/dev/null 2>&1
$CTL command "kill @e[type=minecraft:villager]" >/dev/null

echo "--- in survival the stick is a stick: the chest opens"
$CTL command "gamemode survival" >/dev/null; sleep 1
$CTL interact 1 200 2 >/dev/null; sleep 1
[ "$(screen)" != playing ] && echo "ok: the chest opened" || { echo "FAILED: the chest stayed shut in survival"; failed=1; }
$CTL close >/dev/null 2>&1

grep 'lua:horizon_modkit.*error' "$GAME_DIR/logs/latest.log" | head -5 | cut -c1-200
grep -q 'lua:horizon_modkit.*error' "$GAME_DIR/logs/latest.log" && { echo "script errors in the modkit"; failed=1; }
echo "screenshots: $SHOTS"
$CTL quit >/dev/null
[ $failed = 0 ] && echo "STICK OK" || echo "STICK FAILED"
exit $failed
