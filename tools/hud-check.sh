#!/usr/bin/env bash
# Starts a game with tools/hud-probe beside this modkit and checks that both
# draw hooks fired and their draws were accepted: the probe logs once per
# hook after its batch.* calls returned, so a log line means the draws ran.
# Either hook silent, or any [lua:hud_probe] line at WARN or ERROR, fails the
# run: an offscreen run that never draws fails too (drive the probe in a
# window with --dev-mod tools/hud-probe, then point this check at that game
# dir's log).
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
# The first frame can be late offscreen: poll the log until both hooks showed,
# up to about forty seconds, instead of sleeping a fixed while.
HUD=0
LAYER=0
for i in $(seq 1 40); do
  HUD=$(grep -c "PROBE hud hud" "$LOG" 2>/dev/null || true); HUD=${HUD:-0}
  LAYER=$(grep -c "PROBE hud gui_layer_post" "$LOG" 2>/dev/null || true); LAYER=${LAYER:-0}
  [ "$HUD" -gt 0 ] && [ "$LAYER" -gt 0 ] && break
  sleep 1
done
$CTL quit >/dev/null; sleep 3
echo "hud handlers ran: hud=$HUD gui_layer_post=$LAYER"
grep "PROBE hud gui_layer_post" "$LOG" | cut -c1-160 | head -3
[ "$HUD" -gt 0 ] || { echo "FAILED: the hud hook did not fire"; exit 1; }
[ "$LAYER" -gt 0 ] || { echo "FAILED: the gui_layer_post hook did not fire"; exit 1; }
# The log's level field (`[thread/LEVEL]:`), not an "error" substring: a draw
# that fails is WARN or ERROR, and so is anything else the probe did wrong.
bad=$(grep -E "/(WARN|ERROR)\]: \[lua:hud_probe\]" "$LOG" || true)
[ -n "$bad" ] && { echo "$bad" | cut -c1-200 | head -5; echo "FAILED: script warnings or errors in the hud probe"; exit 1; }
echo "HUD OK: both draw hooks ran and their draw calls were accepted"
