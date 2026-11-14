#!/usr/bin/env bash
# Starts one game with the three probes of tools/gates-probe beside this
# modkit, and checks the engine's capability gates and world writes in a real
# game, not only in the Lua test harness (a host double):
#
#   gates-probe/gates_denied  declares only `scripts`: every helper that needs
#                             `world-settings` or `server-admin` must fail at
#                             the call, naming the helper and the capability,
#                             and change nothing
#   gates-probe/gates_allowed declares both capabilities: a game-rule write,
#                             the day time and a scoreboard display slot must
#                             take effect, the allow-list still refuses, a
#                             cancelled `every` stops, and a kick of a name
#                             nobody has is a no-op
#   gates-probe/gates_client  adds one icon marker and draws one world
#                             primitive: both calls must be accepted
#
# Each fact is one GATE line. A missing line, a `GATE ... BAD` line, or any
# [lua:gates_*] line at WARN or ERROR fails the run.
#
#   HORIZON=/path/to/horizon RESOURCES=<26.3 folder> GAME_DIR=~/horizon-dev tools/gates-check.sh
set -u
HERE=$(cd "$(dirname "$0")/.." && pwd)
: "${HORIZON:?the fork checkout}" "${RESOURCES:?the prepared 26.3 folder}" "${GAME_DIR:?the game dir}"
WORLD=${WORLD:-gates-check}
SOCK=${SOCK:-/tmp/horizon-gates-check.sock}
CTL="$HORIZON/target/fast/horizon-ctl --socket $SOCK"
PROBE="$HERE/tools/gates-probe"
export HORIZON_HOME="$GAME_DIR"
LOG="$GAME_DIR/logs/latest.log"
# A reused world opens with the player where the last run left them, and with
# the last run's rules: this check wants a fresh one.
[ "$WORLD" = gates-check ] && rm -rf "$GAME_DIR/saves/gates-check"
# The scripts first, headlessly: a script that fails to load stops here.
TOOL=${TOOL:-$HORIZON/target/debug/cargo-horizon-mod}
for m in "$PROBE/gates_allowed" "$PROBE/gates_denied" "$PROBE/gates_client"; do
  "$TOOL" horizon-mod check "$m" --game "$HORIZON/target/fast/horizon-client" --dev-mod "$HERE" >/dev/null || { echo "the probe $m does not load; see above"; exit 1; }
done
echo "scripts load: the gates probe's three mods"
[ -f "$GAME_DIR/options.txt" ] && sed -i.bak 's/^soundCategory_master:.*/soundCategory_master:0.0/' "$GAME_DIR/options.txt" && rm -f "$GAME_DIR/options.txt.bak"
$CTL launch --game "$HORIZON/target/fast/horizon-client" --wait --game-dir "$GAME_DIR" --resources "$RESOURCES" \
  --world "$WORLD" --offscreen --dev-tools --dev-mod "$HERE" \
  --dev-mod "$PROBE/gates_allowed" --dev-mod "$PROBE/gates_denied" --dev-mod "$PROBE/gates_client" >/dev/null
$CTL wait-ready 180 >/dev/null
for i in $(seq 1 20); do
  S=$($CTL state)
  echo "$S" | grep -q '"screen":"dead"' && { $CTL click-button Respawn >/dev/null; sleep 1; continue; }
  echo "$S" | grep -q '"player"' && break
  $CTL close >/dev/null 2>&1; $CTL key esc tap >/dev/null 2>&1; sleep 1
done
# The console's own `time set` first, so a day-time write that slipped through
# the denied mod's gate would show as a jump to 6000 rather than as a tick.
$CTL command "time set 1000" >/dev/null
$CTL command "gatesdenied" >/dev/null
for i in $(seq 1 40); do grep -q 'GATE denied unchanged' "$LOG" 2>/dev/null && break; sleep 0.5; done
$CTL command "gatesallowed" >/dev/null
# The display, the timer and the client's marker arrive over the next ticks
# and frames; poll instead of sleeping a fixed while.
for i in $(seq 1 40); do
  grep -q 'GATE timer cancel' "$LOG" 2>/dev/null && grep -q 'GATE display' "$LOG" 2>/dev/null && grep -q 'GATE client markers' "$LOG" 2>/dev/null && break
  sleep 1
done
$CTL quit >/dev/null; sleep 3
echo "--- the GATE lines"
grep -o 'GATE .*' "$LOG" | cut -c1-200
ok=0
need() { grep -q "$1" "$LOG" || { echo "FAILED: no line: $1"; ok=1; }; }
for helper in level_set_day_time level_set_weather set_game_mode level_set_game_rule kick whitelist_add whitelist_remove; do
  need "GATE denied $helper ok"
done
need "GATE rule write ok keep_inventory=true"
need "GATE rule allow-list ok"
need "GATE rule allow-list unchanged ok mob_griefing=true"
need "GATE rule type ok"
need "GATE kick unknown ok"
need "GATE timer handles ok"
need "GATE timer cancel ok count=2 first=true again=false"
need "GATE display ok shown=gates_allowed.pts cleared=nil"
need "GATE client markers ok"
# The unchanged line says the three reads held; judge the numbers here too, so
# a probe that logged `ok` over a changed world still fails the check.
UNCHANGED=$(grep -o 'GATE denied unchanged .*' "$LOG" | tail -1)
if UNCHANGED="$UNCHANGED" python3 -c '
import os, re, sys
line = os.environ.get("UNCHANGED", "")
m = re.search(r"GATE denied unchanged (ok|BAD) day=(-?\d+)->(-?\d+) mode=(-?\d+)->(-?\d+) rule=(\w+)->(\w+)", line)
if not m:
    print("FAILED: no parsable unchanged line:", line.strip() or "(none)")
    sys.exit(1)
verdict, day0, day1, mode0, mode1, rule0, rule1 = m.groups()
problems = []
if verdict != "ok":
    problems.append("the probe judged it BAD")
if int(day1) - int(day0) > 5:
    problems.append("the day clock ran %s -> %s" % (day0, day1))
if int(day1) >= 3000:
    problems.append("day %s looks like the denied 6000 write" % day1)
if mode0 != mode1:
    problems.append("the game mode changed %s -> %s" % (mode0, mode1))
if rule0 != rule1:
    problems.append("keep_inventory changed %s -> %s" % (rule0, rule1))
if problems:
    print("FAILED: the denied writes changed something:", "; ".join(problems))
    sys.exit(1)
print("denied writes changed nothing:", line.strip())
'; then :; else ok=1; fi
# A write that the probe itself judged short of its target.
bad=$(grep -E 'GATE .* BAD' "$LOG" | cut -c1-200 | head -5 || true)
[ -n "$bad" ] && { echo "$bad"; echo "FAILED: a GATE line says BAD"; ok=1; }
# The log's level field (`[thread/LEVEL]:`), not an "error" substring: a
# refused marker is a WARN, and a failed handler an ERROR.
bad=$(grep -E "/(WARN|ERROR)\]: \[lua:gates_" "$LOG" | cut -c1-200 | head -5 || true)
[ -n "$bad" ] && { echo "$bad"; echo "FAILED: script warnings or errors in the gates probes"; ok=1; }
[ "$ok" = 0 ] || { echo "FAILED: the in-game gates check"; exit 1; }
echo "GATES OK: the capability gates refuse and allow as documented, the game-rule write, the day time and the display slot take effect, the cancelled timer stops, and the client marker and world primitive were accepted"
