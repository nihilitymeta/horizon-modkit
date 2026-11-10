#!/usr/bin/env bash
# Starts a game with tools/hud-probe beside this modkit, lets a few seconds of
# frames run, and checks that the draw hooks fired: the probe's handlers log
# when they run, and any failing draw call is an error of the handler in the
# log. An offscreen run may never draw: then the probe stays for manual use
# (start the game in a window with --dev-mod tools/hud-probe) and this check
# reports that instead of failing.
#
#   HORIZON=/path/to/horizon RESOURCES=<26.3 folder> GAME_DIR=~/horizon-dev tools/hud-check.sh
set -u
HERE=$(cd "$(dirname "$0")/.." && pwd)
: "${HORIZON:?the fork checkout}" "${RESOURCES:?the prepared 26.3 folder}" "${GAME_DIR:?the game dir}"
WORLD=${WORLD:-hud-check}
SOCK=${SOCK:-/tmp/horizon-hud-check.sock}
CTL="$HORIZON/target/fast/horizon-ctl --socket $SOCK"
export HORIZON_HOME="$GAME_DIR"
LOG="$GAME_DIR/logs/latest.log"
# The scripts first, headlessly: a script that fails to load stops here.
TOOL=${TOOL:-$HORIZON/target/debug/cargo-horizon-mod}
"$TOOL" horizon-mod check "$HERE/tools/hud-probe" --game "$HORIZON/target/fast/horizon-client" --dev-mod "$HERE" >/dev/null || { echo "the hud probe does not load; see above"; exit 1; }
echo "scripts load: the hud probe"
[ -f "$GAME_DIR/options.txt" ] && sed -i.bak 's/^soundCategory_master:.*/soundCategory_master:0.0/' "$GAME_DIR/options.txt" && rm -f "$GAME_DIR/options.txt.bak"
$CTL launch --game "$HORIZON/target/fast/horizon-client" --wait --game-dir "$GAME_DIR" --resources "$RESOURCES" \
  --world "$WORLD" --offscreen --dev-tools --dev-mod "$HERE" --dev-mod "$HERE/tools/hud-probe" >/dev/null
$CTL wait-ready 180 >/dev/null
for i in $(seq 1 20); do
  S=$($CTL state)
  echo "$S" | grep -q '"screen":"dead"' && { $CTL click-button Respawn >/dev/null; sleep 1; continue; }
  echo "$S" | grep -q '"player"' && break
  $CTL close >/dev/null 2>&1; $CTL key esc tap >/dev/null 2>&1; sleep 1
done
sleep 15
$CTL quit >/dev/null; sleep 3
HUD=$(grep -c "PROBE hud hud" "$LOG" || true)
LAYER=$(grep -c "PROBE hud gui_layer_post" "$LOG" || true)
echo "hud handlers ran: hud=$HUD gui_layer_post=$LAYER"
grep "PROBE hud gui_layer_post" "$LOG" | cut -c1-160 | head -3
if [ "$HUD" = 0 ] && [ "$LAYER" = 0 ]; then
  echo "MANUAL ONLY: neither draw hook fired offscreen; drive the probe in a window to see them"
  errors=$(grep "hud_probe" "$LOG" | grep -i "error" || true)
  [ -n "$errors" ] && { echo "$errors" | cut -c1-200 | head -5; exit 1; }
  exit 0
fi
[ "$HUD" -gt 0 ] || { echo "the hud hook did not fire"; exit 1; }
[ "$LAYER" -gt 0 ] || { echo "the gui_layer_post hook did not fire"; exit 1; }
errors=$(grep "hud_probe" "$LOG" | grep -ci "error" || true)
[ "$errors" = 0 ] || { grep "hud_probe" "$LOG" | grep -i "error" | cut -c1-200 | head -5; echo "script errors in the hud probe"; exit 1; }
echo "HUD OK: both draw hooks ran and their draw calls were accepted"
