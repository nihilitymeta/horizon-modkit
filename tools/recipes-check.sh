#!/usr/bin/env bash
# Starts one game with tools/recipes-probe beside this modkit and checks in it
# that a Lua mod changes the game's recipes through the `data_pack_files` hook:
#
#   replace  the mod pushes `recipe/minecraft:stick` with a result of 7; the
#            game's crafting grid makes 7 sticks, not vanilla's 4
#   remove   the mod pushes a `recipe_filter/...` file that removes
#            minecraft:stone_pickaxe; `/recipe give` says the recipe is unknown
#   add      the mod pushes `recipe/recipes_probe:probe_item` (one dirt makes
#            one diamond); the grid makes a diamond
#   control  minecraft:oak_planks, which the mod does not name, still makes its
#            vanilla 4 from one log, so nothing else vanished
#
# The game is asked through `horizon-ctl`: `screen` shows the result slot with
# the items in the grid, `inventory` counts what the craft put in it, and
# `command` carries the reply to `/recipe give` (the owner's chat). Each fact
# is one RECIPE line, printed here from those answers; a missing line, a
# `RECIPE ... BAD` line, a craft that did not happen, or a probe line at WARN or
# ERROR fails the run. `/reload` runs the hook once more, so the files judged
# are the ones a reload pushed.
#
# The control socket sits in the game dir, and the game this script started is
# quit on every exit, a Ctrl-C included.
#
#   HORIZON=/path/to/horizon RESOURCES=<26.3 folder> GAME_DIR=~/horizon-dev tools/recipes-check.sh
set -u
HERE=$(cd "$(dirname "$0")/.." && pwd)
: "${HORIZON:?the fork checkout}" "${RESOURCES:?the prepared 26.3 folder}" "${GAME_DIR:?the game dir}"
WORLD=${WORLD:-recipes-check}
SOCK=${SOCK:-$GAME_DIR/ctl.sock}
if [ ${#SOCK} -gt 100 ]; then
  SOCK=/tmp/horizon-recipes-check.sock
  echo "the socket path is over 100 bytes: using $SOCK"
fi
CTL="$HORIZON/target/fast/horizon-ctl --socket $SOCK"
PROBE="$HERE/tools/recipes-probe"
export HORIZON_HOME="$GAME_DIR"
LOG="$GAME_DIR/logs/latest.log"
GAME_PID=
GAME_STOPPED=0
stop_game() {
  [ "$GAME_STOPPED" = 1 ] && return 0
  GAME_STOPPED=1
  if [ -n "$GAME_PID" ] && kill -0 "$GAME_PID" 2>/dev/null; then
    $CTL quit >/dev/null 2>&1
    for i in $(seq 1 20); do kill -0 "$GAME_PID" 2>/dev/null || break; sleep 0.5; done
    if kill -0 "$GAME_PID" 2>/dev/null; then
      echo "the game did not quit; killing pid $GAME_PID"
      kill "$GAME_PID" 2>/dev/null
      for i in $(seq 1 10); do kill -0 "$GAME_PID" 2>/dev/null || break; sleep 0.5; done
      kill -0 "$GAME_PID" 2>/dev/null && kill -9 "$GAME_PID" 2>/dev/null
    fi
  fi
  rm -f "$SOCK"
}
trap 'status=$?; stop_game; exit $status' EXIT
trap 'echo "interrupted: stopping the game"; exit 130' INT
trap 'echo "terminated: stopping the game"; exit 143' TERM
# The scripts first, headlessly: a script that fails to load stops here.
TOOL=${TOOL:-$HORIZON/target/debug/cargo-horizon-mod}
"$TOOL" horizon-mod check "$PROBE" --game "$HORIZON/target/fast/horizon-client" --dev-mod "$HERE" >/dev/null \
  || { echo "the recipes probe does not load; see above"; exit 1; }
echo "scripts load: the recipes probe"
[ "$WORLD" = recipes-check ] && rm -rf "$GAME_DIR/saves/recipes-check"
[ -f "$GAME_DIR/options.txt" ] && sed -i.bak 's/^soundCategory_master:.*/soundCategory_master:0.0/' "$GAME_DIR/options.txt" && rm -f "$GAME_DIR/options.txt.bak"
LAUNCH=$($CTL launch --game "$HORIZON/target/fast/horizon-client" --game-dir "$GAME_DIR" --resources "$RESOURCES" \
  --world "$WORLD" --offscreen --dev-tools --dev-mod "$HERE" --dev-mod "$PROBE")
GAME_PID=$(printf '%s' "$LAUNCH" | python3 -c 'import json, sys; print(json.load(sys.stdin).get("pid", ""))' 2>/dev/null || true)
[ -n "$GAME_PID" ] || { printf '%s\n' "$LAUNCH" | cut -c1-300; echo "FAILED: the game did not start"; exit 1; }
$CTL wait-ready 180 >/dev/null
for i in $(seq 1 20); do
  S=$($CTL state)
  echo "$S" | grep -q '"screen":"dead"' && { $CTL click-button Respawn >/dev/null; sleep 1; continue; }
  echo "$S" | grep -q '"player"' && break
  $CTL close >/dev/null 2>&1; $CTL key esc tap >/dev/null 2>&1; sleep 1
done

# ---- what the game says, as small readers over its JSON replies ------------
# The count of ITEM in the inventory, carried stack included.
item_count() {
  python3 -c 'import json, sys; print(json.load(sys.stdin).get("counts", {}).get(sys.argv[1], 0))' "$1"
}
# The slot holding ITEM, or -1.
slot_holding() {
  python3 -c '
import json, sys
d = json.load(sys.stdin)
for part in ("hotbar", "main"):
    for s in d.get(part, []):
        if s.get("item") == sys.argv[1] and s.get("count", 0) > 0:
            print(s["slot"])
            raise SystemExit
print(-1)' "$1"
}
# `yes` when the 2x2 crafting grid is empty, else `no: <items>`.
grid_empty() {
  python3 -c '
import json, sys
d = json.load(sys.stdin)
left = [s for s in d.get("slots", []) if 100 <= s.get("slot", 0) <= 103 and s.get("item")]
print("yes" if not left else "no: " + ",".join(s["item"] for s in left))'
}
# The crafting result slot (200) as `item count`, or `- 0` when empty.
result_stack() {
  python3 -c '
import json, sys
for s in json.load(sys.stdin).get("slots", []):
    if s.get("slot") == 200:
        print(s.get("item") or "-", s.get("count", 0))
        raise SystemExit
print("-", 0)'
}
# The stack on the cursor as `item`, or `-` when the hand is empty.
carried_item() {
  python3 -c '
import json, sys
c = json.load(sys.stdin).get("carried")
print(c.get("item") if c else "-")'
}
# put_grid ITEM SLOT...: give one ITEM per slot and put one in each. Fails
# when a screen other than the inventory opens or the grid holds something, so
# a leftover cannot pass for a craft. Every read polls: the client's copy of
# the inventory follows the server a tick or two behind the command.
put_grid() {
  local item=$1 try i
  shift
  $CTL close >/dev/null 2>&1
  $CTL give "$item" "$#" >/dev/null || return 1
  try=$($CTL open-inventory | python3 -c 'import json, sys; print(json.load(sys.stdin).get("screen"))')
  [ "$try" = inventory ] || { echo "the inventory did not open: $try"; return 1; }
  try=$($CTL screen | grid_empty)
  [ "$try" = yes ] || { echo "the crafting grid is not empty: $try"; return 1; }
  for i in $(seq 1 20); do
    try=$($CTL inventory | slot_holding "$item")
    [ "$try" -ge 0 ] && break
    sleep 0.3
  done
  [ "$try" -ge 0 ] || { echo "no $item in the inventory"; return 1; }
  $CTL click-slot "$try" >/dev/null
  for slot in "$@"; do $CTL click-slot "$slot" right >/dev/null; done
  for i in $(seq 1 20); do
    try=$($CTL inventory | carried_item)
    [ "$try" = "-" ] && break
    sleep 0.3
  done
  [ "$try" = "-" ] || { echo "the hand still holds $try"; return 1; }
}
# take_result: take slot 200 with shift, as a player would, and wait a tick.
take_result() {
  $CTL click-slot 200 shift >/dev/null
  sleep 1
}
# wait_result ITEM COUNT: the result slot (200) as `item count`, polled for up
# to eight seconds: the server answers the click a tick or two after it lands.
wait_result() {
  local want="$1 $2" shown=""
  for i in $(seq 1 16); do
    shown=$($CTL screen | result_stack)
    [ "$shown" = "$want" ] && break
    sleep 0.5
  done
  printf '%s' "$shown"
}

# Each judgment is one RECIPE line; `need` below requires it.
LINES=()
say() { LINES+=("$*"); echo "$*"; }
ok=0
need() {
  local line
  for line in "${LINES[@]}"; do case "$line" in *"$1"*) return 0 ;; esac; done
  echo "FAILED: no line: $1"
  ok=1
}

# The first world open pushes the files already; `/reload` pushes them again,
# and the line after that is the load this check judges. Nothing is left to
# chance on the first load's log: the wait counts the reload's own line.
pushes=$(grep -c 'RECIPE push ok' "$LOG" 2>/dev/null || true)
pushes=${pushes:-0}
$CTL command "reload" >/dev/null
for i in $(seq 1 60); do
  now=$(grep -c 'RECIPE push ok' "$LOG" 2>/dev/null || true)
  [ "${now:-0}" -gt "$pushes" ] && break
  sleep 0.5
done
if [ "${now:-0}" -le "$pushes" ]; then
  echo "FAILED: /reload did not run the data_pack_files hook again"
  ok=1
fi
sleep 2

# ---- replace: 2 planks in a column make 7 sticks, not vanilla's 4 ----------
# The game has to say 7 twice: the result slot shows the new count, and the
# craft puts that many sticks in the inventory.
$CTL close >/dev/null 2>&1
before=$($CTL inventory | item_count minecraft:stick)
put_grid minecraft:oak_planks 100 102 || echo "FAILED: could not fill the grid for the stick recipe"
shown=$(wait_result minecraft:stick 7)
take_result
after=$($CTL inventory | item_count minecraft:stick)
made=$((after - before))
if [ "$shown" = "minecraft:stick 7" ] && [ "$made" = 7 ]; then
  say "RECIPE replace ok result=7 shown=$shown made=$made"
else
  say "RECIPE replace BAD shown=$shown made=$made"
fi

# ---- add: a recipe the mod made up, one dirt makes one diamond ------------
put_grid minecraft:dirt 100 || echo "FAILED: could not fill the grid for the probe recipe"
shown=$(wait_result minecraft:diamond 1)
before=$($CTL inventory | item_count minecraft:diamond)
take_result
after=$($CTL inventory | item_count minecraft:diamond)
made=$((after - before))
if [ "$shown" = "minecraft:diamond 1" ] && [ "$made" = 1 ]; then
  say "RECIPE add ok result=minecraft:diamond 1 shown=$shown made=$made"
else
  say "RECIPE add BAD shown=$shown made=$made"
fi

# ---- control: a recipe the mod does not name still makes its vanilla 4 ----
put_grid minecraft:oak_log 100 || echo "FAILED: could not fill the grid for the control recipe"
shown=$(wait_result minecraft:oak_planks 4)
before=$($CTL inventory | item_count minecraft:oak_planks)
take_result
after=$($CTL inventory | item_count minecraft:oak_planks)
made=$((after - before))
if [ "$shown" = "minecraft:oak_planks 4" ] && [ "$made" = 4 ]; then
  say "RECIPE control ok result=minecraft:oak_planks 4 shown=$shown made=$made"
else
  say "RECIPE control BAD shown=$shown made=$made"
fi
$CTL close >/dev/null 2>&1

# ---- remove: the filtered recipe is unknown to /recipe give ---------------
said=$($CTL command "recipe give @s minecraft:stone_pickaxe" \
  | python3 -c 'import json, sys; print(" | ".join(json.load(sys.stdin).get("chat") or []))')
case "$said" in
  *"Unknown recipe: minecraft:stone_pickaxe"*) say "RECIPE remove ok said=$said" ;;
  *) say "RECIPE remove BAD said=$said" ;;
esac
# A recipe nobody crafted still unlocks, so the command answers both ways.
said=$($CTL command "recipe give @s minecraft:torch" \
  | python3 -c 'import json, sys; print(" | ".join(json.load(sys.stdin).get("chat") or []))')
case "$said" in
  *"Unlocked"*) say "RECIPE remove control ok said=$said" ;;
  *) say "RECIPE remove control BAD said=$said" ;;
esac

stop_game
echo "--- the RECIPE lines of the log"
grep -o 'RECIPE push ok .*' "$LOG" | cut -c1-200
echo "--- the RECIPE verdicts"
printf '%s\n' "${LINES[@]}"
need "RECIPE replace ok result=7"
need "RECIPE add ok result=minecraft:diamond 1"
need "RECIPE control ok result=minecraft:oak_planks 4"
need "RECIPE remove ok said="
need "RECIPE remove control ok said="
# The probe's own line: a load pushed its files, and that is the load the
# crafts above used.
grep -q 'RECIPE push ok files=' "$LOG" || { echo "FAILED: the probe pushed nothing"; ok=1; }
# A craft judged short of its target, or a file the game refused.
bad=$(printf '%s\n' "${LINES[@]}" | grep -E '^RECIPE .* BAD' || true)
[ -n "$bad" ] && { echo "$bad"; echo "FAILED: a RECIPE line says BAD"; ok=1; }
# The log's level field (`[thread/LEVEL]:`), not an "error" substring.
bad=$(grep -E "/(WARN|ERROR)\]: \[lua:recipes_probe\]" "$LOG" | cut -c1-200 | head -5 || true)
[ -n "$bad" ] && { echo "$bad"; echo "FAILED: script warnings or errors in the recipes probe"; ok=1; }
[ "$ok" = 0 ] || { echo "FAILED: the in-game recipes check"; exit 1; }
echo "RECIPES OK: a Lua mod replaces, removes and adds recipes the game then uses, and the control recipe is untouched"
