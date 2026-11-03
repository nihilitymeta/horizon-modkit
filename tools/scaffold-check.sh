#!/usr/bin/env bash
# Scaffolds a mod with `cargo horizon-mod new --template lua`, builds it, runs the registry's check on the
# .hmod, then runs it in a game beside this modkit through horizon-ctl: the wand is given and used, and its
# on_use is seen in the chat and the log.
#
#   HORIZON=/path/to/horizon RESOURCES=<26.3 folder> GAME_DIR=~/horizon-dev tools/scaffold-check.sh
#
# HORIZON is the fork checkout, built (`target/fast/horizon-client`, `horizon-ctl` and `cargo-horizon-mod`,
# the last with `cargo build -p cargo-horizon-mod`); WORLD defaults to "New World".
set -u
HERE=$(cd "$(dirname "$0")/.." && pwd)
: "${HORIZON:?the fork checkout}" "${RESOURCES:?the prepared 26.3 folder}" "${GAME_DIR:?the game dir}"
WORLD=${WORLD:-New World}
SOCK=${SOCK:-/tmp/horizon-scaffold-check.sock}
TOOL=${TOOL:-$HORIZON/target/debug/cargo-horizon-mod}
CTL="${GAME_BUILD:-$HORIZON/target/fast}/horizon-ctl --socket $SOCK"
# The game writes logs/ under HORIZON_HOME when it is set: keep that the game dir, so the log is here.
export HORIZON_HOME="$GAME_DIR"
LOG="$GAME_DIR/logs/latest.log"
WORK=${WORK:-$(mktemp -d /tmp/horizon-scaffold.XXXXXX)}
j() { python3 -c "import sys,json; d=json.load(sys.stdin); $1"; }
echo "--- scaffold, build and check in $WORK"
(cd "$WORK" && "$TOOL" horizon-mod new my-wand --template lua --name "My Wand") || exit 1
(cd "$WORK/my-wand" && "$TOOL" horizon-mod build && "$TOOL" horizon-mod check target/horizon-mod/my_wand.hmod --game "${GAME_BUILD:-$HORIZON/target/fast}/horizon-client" --dev-mod "$HERE") || exit 1
if command -v luau-lsp >/dev/null; then
  # The scaffold's .luaurc names ../horizon-modkit; here the modkit is this checkout.
  sed -i.bak "s|../horizon-modkit/scripts/modkit|$HERE/scripts/modkit|" "$WORK/my-wand/.luaurc"
  OUT=$(cd "$WORK/my-wand" && luau-lsp analyze --definitions "@horizon=$HERE/types/horizon.d.lua" --platform=standard scripts 2>&1) && echo "luau-lsp analyze: clean on the scaffold" || { echo "$OUT" | grep -v '^\['; echo "luau-lsp analyze: errors on the scaffold (above)"; exit 1; }
fi
echo "--- in a game beside the modkit"
[ -f "$GAME_DIR/options.txt" ] && sed -i.bak 's/^soundCategory_master:.*/soundCategory_master:0.0/' "$GAME_DIR/options.txt" && rm -f "$GAME_DIR/options.txt.bak"
$CTL launch --game "${GAME_BUILD:-$HORIZON/target/fast}/horizon-client" --wait --game-dir "$GAME_DIR" --resources "$RESOURCES" \
  --world "$WORLD" --offscreen --dev-tools --dev-mod "$HERE" --dev-mod "$WORK/my-wand" >/dev/null
$CTL wait-ready 180 >/dev/null
for i in $(seq 1 20); do
  S=$($CTL state)
  echo "$S" | grep -q '"screen":"dead"' && { $CTL click-button Respawn >/dev/null; sleep 1; continue; }
  echo "$S" | grep -q '"player"' && break
  $CTL close >/dev/null 2>&1; $CTL key esc tap >/dev/null 2>&1; sleep 1
done
$CTL command "gamemode creative" >/dev/null
$CTL command "clear" >/dev/null; sleep 0.5
$CTL give my_wand:wand 1 | j 'print("given:", d.get("ok", d.get("error")))'
sleep 0.5
$CTL select my_wand:wand | j 'print("holding:", d.get("held", {}).get("item", d.get("error")))'
$CTL look 0 -60 >/dev/null
$CTL use-item | j 'print("used:", d.get("ok", d.get("error")))'; sleep 1
# Read before the quit: the log is rotated then.
LINES=$(grep 'Lua mod my_wand\|waves the wand\|lua:my_wand' "$LOG")
$CTL quit >/dev/null; sleep 2
echo "$LINES" | cut -c1-160
echo "$LINES" | grep -q 'Lua mod my_wand running' || { echo "the scaffold did not load as a Lua mod"; exit 1; }
echo "$LINES" | grep -q 'waves the wand' || { echo "the wand's on_use did not run"; exit 1; }
echo "$LINES" | grep -q 'lua:my_wand.*error' && { echo "script errors in the scaffold"; exit 1; }
echo "SCAFFOLD OK: my_wand loaded, the wand used, its on_use seen"
rm -rf "$WORK"
