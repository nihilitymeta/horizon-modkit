#!/usr/bin/env bash
# Loads the modkit's scripts, and a mod's written with it, headlessly in the game's Lua runtime
# (`cargo horizon-mod check <folder> --game <horizon-client> --dev-mod <this modkit>`): a script that
# fails to load, a hook horizon.on does not know, a command that errors when declared, each with its
# file and line, and a non-zero exit. No world is opened.
#
#   HORIZON=/path/to/horizon tools/check.sh [mod folder]...     # the modkit itself, then each folder given
#   HORIZON=/path/to/horizon tools/check.sh --self-test         # also: a mod with a misspelled hook must fail
#
# With RESOURCES set to the prepared 26.3 folder, each mod's content is also layered on it as the game does at
# start (`--resources`): a data file the game would refuse, which leaves every content mod out of the world,
# fails the check. The self-test then also checks that a misnamed add_spawns field is refused.
#
# HORIZON is the fork checkout, built: target/fast/horizon-client and target/debug/cargo-horizon-mod
# (`cargo build -p cargo-horizon-mod`). With no folders given, examples/example_mod and the probes the
# in-game checks run (tools/hook-probe, tools/step-probe, tools/modkit-probe) are checked.
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
if [ ${#mods[@]} = 0 ]; then
  mods=("$HERE/examples/example_mod" "$HERE/tools/hook-probe" "$HERE/tools/step-probe" "$HERE/tools/modkit-probe" "$HERE/tools/hud-probe" "$HERE/tools/viewless-probe")
fi
failed=0
res=()
[ -n "${RESOURCES:-}" ] && res=(--resources "$RESOURCES")
check() {
  echo "--- $1"
  if "$TOOL" horizon-mod check "$1" --game "$GAME" --dev-mod "$HERE" ${res[@]+"${res[@]}"}; then echo "ok: $1"; else echo "FAILED: $1"; failed=1; fi
}
check "$HERE"
for m in "${mods[@]}"; do check "$m"; done
# The types for an editor: this copy equal to the engine's generated one, and luau-lsp (when installed) clean
# on the modkit's scripts and on each mod's (its .luaurc names this modkit for `require("@modkit")`).
if ! cmp -s "$HERE/types/horizon.d.lua" "$HORIZON/docs/api/horizon.d.lua"; then
  echo "FAILED: types/horizon.d.lua differs from $HORIZON/docs/api/horizon.d.lua (copy it)"; failed=1
else
  echo "ok: types/horizon.d.lua is the engine's"
fi
if command -v luau-lsp >/dev/null; then
  for m in "$HERE" "${mods[@]}"; do
    echo "--- luau-lsp analyze $m"
    if (cd "$m" && luau-lsp analyze --definitions "@horizon=$HERE/types/horizon.d.lua" --platform=standard scripts 2>&1 | grep -v '^\['); then :; fi
    (cd "$m" && luau-lsp analyze --definitions "@horizon=$HERE/types/horizon.d.lua" --platform=standard scripts >/dev/null 2>&1) && echo "ok: analyze $m" || { echo "FAILED: analyze $m"; failed=1; }
  done
else
  echo "luau-lsp not installed: the scripts are not analyzed (install it for completion and this check)"
fi
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
  if command -v luau-lsp >/dev/null; then
    # The same misspelling, and a misspelled function, caught by the editor's analysis before any game.
    printf 'horizon.brodcast("x")\n' >> "$W/broken/scripts/init.lua"
    sed -i.bak "s|../horizon-modkit/scripts/modkit|$HERE/scripts/modkit|" "$W/broken/.luaurc"
    OUT=$(cd "$W/broken" && luau-lsp analyze --definitions "@horizon=$HERE/types/horizon.d.lua" --platform=standard scripts 2>&1 | grep -v '^\[')
    echo "$OUT" | grep -q 'player_jioned' && echo "$OUT" | grep -q 'brodcast' && echo "ok: luau-lsp reports the misspelled hook and function: $(echo "$OUT" | grep -c 'TypeError') errors" || { echo "FAILED: luau-lsp did not report both misspellings: $OUT"; failed=1; }
  fi
  # A mod that asks for a modkit newer than this one is refused, with what was found.
  (cd "$W" && "$TOOL" horizon-mod new tooold --template lua >/dev/null) || exit 1
  sed -i.bak 's/^depends = .*/depends = ["horizon_modkit >= 99.0"]/' "$W/tooold/horizon-mod.toml"
  if OUT=$("$TOOL" horizon-mod check "$W/tooold" --game "$GAME" --dev-mod "$HERE" 2>&1); then
    echo "FAILED: a mod needing horizon_modkit >= 99.0 passed"; failed=1
  else
    echo "$OUT" | grep -q 'found horizon_modkit' && echo "ok: refused for the version: $(echo "$OUT" | grep -o 'depends on [^,]*, found [^ ]* [0-9.]*' | head -1)" || { echo "FAILED: refused, but not for the version: $OUT"; failed=1; }
  fi
  if [ -n "${RESOURCES:-}" ]; then
    # A spawn modifier with the fields misnamed: the game would refuse every content mod, so the check must.
    (cd "$W" && "$TOOL" horizon-mod new spawny --template lua >/dev/null) || exit 1
    id=$(sed -n 's/^id = "\(.*\)"/\1/p' "$W/spawny/horizon-mod.toml")
    mkdir -p "$W/spawny/data/$id/neoforge/biome_modifier"
    printf '{"type":"neoforge:add_spawns","biomes":"#minecraft:is_overworld","spawners":[{"type":"minecraft:zombie","weight":5,"min_count":1,"max_count":2}]}\n' \
      > "$W/spawny/data/$id/neoforge/biome_modifier/bad.json"
    if OUT=$("$TOOL" horizon-mod check "$W/spawny" --game "$GAME" --dev-mod "$HERE" "${res[@]}" 2>&1); then
      echo "FAILED: a mod with min_count in add_spawns passed"; failed=1
    else
      echo "$OUT" | grep -q 'would not load in a game.*minCount' && echo "ok: refused before a game: $(echo "$OUT" | grep -o 'would not load in a game.*' | head -1)" || { echo "FAILED: refused, but not for the spawner: $OUT"; failed=1; }
    fi
  fi
  rm -rf "$W"
fi
exit $failed
