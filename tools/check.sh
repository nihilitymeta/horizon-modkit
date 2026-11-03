#!/usr/bin/env bash
# Loads the modkit's scripts, and a mod's written with it, headlessly in the game's Lua runtime
# (`cargo horizon-mod check <folder> --game <horizon-client> --dev-mod <this modkit>`): a script that
# fails to load, a hook horizon.on does not know, a command that errors when declared, each with its
# file and line, and a non-zero exit. No world is opened.
#
#   HORIZON=/path/to/horizon tools/check.sh [mod folder]...     # the modkit itself, then each folder given
#   HORIZON=/path/to/horizon tools/check.sh --self-test         # also: a mod with a misspelled hook must fail
#
# HORIZON is the fork checkout, built: target/fast/horizon-client and target/debug/cargo-horizon-mod
# (`cargo build -p cargo-horizon-mod`). With no folders given, the parasite's tools/modkit-probe beside this
# checkout is checked when it is there.
set -u
HERE=$(cd "$(dirname "$0")/.." && pwd)
: "${HORIZON:?the fork checkout}"
TOOL=${TOOL:-$HORIZON/target/debug/cargo-horizon-mod}
GAME=${GAME:-$HORIZON/target/fast/horizon-client}
self_test=false
mods=()
for a in "$@"; do
  case "$a" in --self-test) self_test=true ;; *) mods+=("$a") ;; esac
done
if [ ${#mods[@]} = 0 ] && [ -d "$HERE/../horizon-parasite-mod/tools/modkit-probe" ]; then
  mods=("$HERE/../horizon-parasite-mod/tools/modkit-probe")
fi
failed=0
check() {
  echo "--- $1"
  if "$TOOL" horizon-mod check "$1" --game "$GAME" --dev-mod "$HERE"; then echo "ok: $1"; else echo "FAILED: $1"; failed=1; fi
}
check "$HERE"
for m in "${mods[@]}"; do check "$m"; done
if $self_test; then
  echo "--- self-test: a mod with a misspelled hook must fail with its line"
  W=$(mktemp -d /tmp/horizon-check-self.XXXXXX)
  (cd "$W" && "$TOOL" horizon-mod new broken --template lua >/dev/null) || exit 1
  printf 'horizon.on("player_jioned", function() end)\n' >> "$W/broken/scripts/init.lua"
  if OUT=$("$TOOL" horizon-mod check "$W/broken" --game "$GAME" --dev-mod "$HERE" 2>&1); then
    echo "FAILED: the broken mod passed"; failed=1
  else
    echo "$OUT" | grep -q 'init.lua"\]:[0-9]*:.*no such hook' && echo "ok: refused with its line: $(echo "$OUT" | grep -o 'init.lua"\]:[0-9]*:[^;]*' | head -1)" || { echo "FAILED: refused, but not with the line and the hook: $OUT"; failed=1; }
  fi
  rm -rf "$W"
fi
exit $failed
