#!/bin/bash
# Q001: the repeatable health check. Runs against a fresh clone of main, on the real GPU, and writes
# docs/qa/health-<date>.md and .json (raw logs in docs/qa/logs-<date>/, stills in docs/screens/qa-<date>/).
#   tools/qa/health_check.sh [--write-baseline | --add-baseline]
# --write-baseline: store this run's numbers in docs/qa/baseline.json (thresholds there are kept).
# --add-baseline: add only the scenes and bot sets the baseline has no entry for; every other number stays.
# Exit: 0 report written, nothing red; 1 report written, something red; 2 no report.
# Env, for debugging the check itself: QA_WINDOWS (frame-time windows per scene, default 2),
# QA_SECONDS (default 30), QA_RUNS (bot runs per case, default 12), QA_POLL_S (300), QA_WAIT_MAX_S (7200),
# QA_SOURCE (what to clone, default origin), QA_KEEP_WORK=1 (keep the temp folder).
set -u
# launchd and non-login shells leave out some of these (lsof and sysctl live in /usr/sbin).
export PATH="$HOME/.local/grave-rats-bin:$PATH:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-$(command -v godot || echo /Applications/Godot.app/Contents/MacOS/Godot)}"
export GODOT
DATE="$(date +%F)"
WINDOWS="${QA_WINDOWS:-2}"
SECONDS_WINDOW="${QA_SECONDS:-30}"
RUNS="${QA_RUNS:-12}"
POLL_S="${QA_POLL_S:-300}"
WAIT_MAX_S="${QA_WAIT_MAX_S:-7200}"
WRITE_BASELINE=""
case "${1:-}" in --write-baseline|--add-baseline) WRITE_BASELINE="$1" ;; esac

WORK="$(mktemp -d /tmp/grave-rats-qa.XXXXXX)"
RAW="$WORK/raw"; CLONE="$WORK/clone"; mkdir -p "$RAW"
cleanup() { [ -n "${QA_KEEP_WORK:-}" ] && echo "kept $WORK" || rm -rf "$WORK"; }
trap cleanup EXIT

say() { echo "[$(date +%H:%M:%S)] $*"; }
meta() { printf '%s=%s\n' "$1" "$2" >> "$RAW/meta.txt"; }
loadavg() { sysctl -n vm.loadavg | tr -d '{}' | awk '{print $1, $2, $3}'; }

# limited <seconds> <log> <command...>: runs it with a hang guard; returns its exit code.
limited() {
  local secs="$1" log="$2"; shift 2
  "$@" >"$log" 2>&1 </dev/null &
  local pid=$!
  ( sleep "$secs" && { echo "health_check: killed after ${secs}s" >>"$log"; kill "$pid" 2>/dev/null; } ) </dev/null >/dev/null 2>&1 &
  local watch=$!
  wait "$pid"; local code=$?
  # The guard first, then its sleep: the other order would let it log a false "killed".
  local kids; kids="$(pgrep -P "$watch")"
  kill "$watch" 2>/dev/null; [ -n "$kids" ] && kill $kids 2>/dev/null
  wait "$watch" 2>/dev/null
  return "$code"
}

# Is a Godot process running from the code lane's clone? Its command line may just say `--path .`, so check cwd too.
code_lane_busy() {
  local pid exe cwd cmd
  for pid in $(pgrep -if godot); do
    exe="$(ps -o comm= -p "$pid" 2>/dev/null)"
    case "$(basename "$exe" | tr 'A-Z' 'a-z')" in godot*) ;; *) continue ;; esac
    cwd="$(lsof -a -p "$pid" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p')"
    cmd="$(ps -o command= -p "$pid" 2>/dev/null)"
    case "$cwd $cmd" in *grave-rats-code*) return 0 ;; esac
  done
  return 1
}

WAITED=0
UNDER_LOAD=""
wait_for_code_lane() {
  while code_lane_busy; do
    if [ "$WAITED" -ge "$WAIT_MAX_S" ]; then
      UNDER_LOAD="$1"
      say "code lane still busy after ${WAITED}s; measuring $1 under load"
      return
    fi
    say "code lane busy; waiting ${POLL_S}s (${WAITED}s so far)"
    sleep "$POLL_S"
    WAITED=$((WAITED + POLL_S))
  done
}

STARTED=$(date +%s)
step_done() { meta "seconds_$1" "$(( $(date +%s) - $2 ))"; }
meta date "$DATE"
meta started "$(date '+%F %T')"
meta godot "$("$GODOT" --version 2>/dev/null | tail -1)"
meta chip "$(sysctl -n machdep.cpu.brand_string)"
meta macos "$(sw_vers -productVersion)"
meta thermal_start "$(pmset -g therm 2>/dev/null | tr '\n' ' ')"
meta remote_desktop "$(pgrep -q remoting_me2me && echo running || echo none)"

wait_for_code_lane "the whole run"

# --- Fresh clone ---------------------------------------------------------------------------------
T=$(date +%s); say "cloning main"
SOURCE="${QA_SOURCE:-$(git -C "$ROOT" remote get-url origin)}"
if ! limited 900 "$RAW/clone.log" git clone --depth 1 --branch main --single-branch "$SOURCE" "$CLONE"; then
  meta clone_fallback "$SOURCE failed; used the local clone's main"
  SOURCE="file://$ROOT"; rm -rf "$CLONE"
  limited 900 "$RAW/clone.log" git clone --depth 1 --branch main --single-branch "$SOURCE" "$CLONE"
fi
meta clone_source "$SOURCE"
if [ ! -f "$CLONE/project.godot" ]; then
  say "clone failed; see $RAW/clone.log"; cat "$RAW/clone.log"; exit 2
fi
meta commit "$(git -C "$CLONE" log -1 --format='%h %s')"
step_done clone "$T"
# The Q001 tools may not be on main yet; these runs always use this checkout's copy.
mkdir -p "$CLONE/tools/qa"; cp "$ROOT"/tools/qa/*.gd "$CLONE/tools/qa/"

T=$(date +%s); say "importing"
limited 900 "$RAW/import.log" "$GODOT" --headless --path "$CLONE" --import
meta import_rc "$?"
meta import_files "$(find "$CLONE" -name '*.import' -not -path '*/.godot/*' | wc -l | tr -d ' ')"
meta imported_count "$(ls "$CLONE/.godot/imported" 2>/dev/null | wc -l | tr -d ' ')"
step_done import "$T"

# --- Frame time (before the tests and bots, whose CPU use would show in the load average) ----------
capture() { # capture <scene> <out> <seconds> <log>
  CAPTURE_ONLY=none CAPTURE_SIZE=1920x1080 limited $(( $3 + 180 )) "$4" "$CLONE/tools/capture.sh" "$1" "$2" "$3"
}
# shift_deck: no session under capture, three stalkers hunting, CUSTODIAN awake (its _demo_step).
FRAME_SCENES="scenes/pirates/pirate_deck.tscn scenes/enemies/stalker_deck.tscn scenes/shift/shift_deck.tscn"
T=$(date +%s)
mkdir -p "$RAW/frame"
: > "$RAW/frame/windows.txt"
# A fresh clone has no pipeline cache: one short throwaway run of each scene so compiles don't land in the windows.
for SCENE in $FRAME_SCENES; do
  say "warming $SCENE"
  capture "$SCENE" "$WORK/warm" 5 "$RAW/frame/warm_$(basename "$SCENE" .tscn).log"
  # A screen of 1080 points (a remote desktop session sets one) leaves a titled window short of 1080 pixels. Borderless
  # fits, through an override in the clone only, for the windows and flicker alike. Otherwise the numbers aren't comparable.
  if [ ! -f "$CLONE/override.cfg" ] && ! grep -q '"resolution": "1920x1080"' "$WORK/warm/frametime.json" 2>/dev/null; then
    printf '[display]\n\nwindow/size/borderless=true\n' > "$CLONE/override.cfg"
    meta borderless "yes"
    say "titled window fell short of 1920x1080; using a borderless window"
    capture "$SCENE" "$WORK/warm" 5 "$RAW/frame/warm_$(basename "$SCENE" .tscn).log"
  fi
done
sleep 20
W=1
while [ "$W" -le "$WINDOWS" ]; do
  for SCENE in $FRAME_SCENES; do
    NAME="$(basename "$SCENE" .tscn)"
    wait_for_code_lane "frame time"
    OUT="$RAW/frame/${NAME}_$W"
    LOAD_BEFORE="$(loadavg)"
    say "frame time: $NAME window $W (${SECONDS_WINDOW}s), load $LOAD_BEFORE"
    capture "$SCENE" "$OUT" "$SECONDS_WINDOW" "$RAW/frame/${NAME}_$W.log"
    echo "$NAME $W rc=$? before=$LOAD_BEFORE after=$(loadavg)" >> "$RAW/frame/windows.txt"
  done
  W=$((W + 1))
done
ps -Ao %cpu,comm -r | head -7 | sed 's#/.*/##' > "$RAW/frame/top_cpu.txt"
meta thermal_end "$(pmset -g therm 2>/dev/null | tr '\n' ' ')"
step_done frame "$T"
SHOTS="$ROOT/docs/screens/qa-$DATE"; mkdir -p "$SHOTS"
for NAME in pirate_deck stalker_deck shift_deck; do
  [ -f "$RAW/frame/${NAME}_1/$NAME.png" ] && \
    sips -s format jpeg -s formatOptions 70 "$RAW/frame/${NAME}_1/$NAME.png" --out "$SHOTS/$NAME.jpg" >/dev/null 2>&1
done

# --- Tests, three times ----------------------------------------------------------------------------
T=$(date +%s)
for I in 1 2 3; do
  say "tests, run $I of 3"
  limited 900 "$RAW/tests_$I.log" "$GODOT" --headless --path "$CLONE" -s tests/run_tests.gd
  meta "tests_${I}_rc" "$?"
done
step_done tests "$T"

# --- Bots ------------------------------------------------------------------------------------------
T=$(date +%s)
say "T006 stalker bots"
limited 900 "$RAW/t006.log" "$GODOT" --headless --path "$CLONE" --fixed-fps 60 -s tools/qa/t006_seeded.gd "--" "$RUNS"
meta t006_rc "$?"
say "T007 pirate bots"
limited 900 "$RAW/t007.log" "$GODOT" --headless --path "$CLONE" --fixed-fps 60 -s tools/qa/t007_seeded.gd "--" "$RUNS"
meta t007_rc "$?"
# Fixed step: repeatable, the regression signal. Real time: the tool's documented usage, noisier, comparable with T003-T009's tables.
say "foot slide, fixed step"
limited 300 "$RAW/footslide_fixed.log" "$GODOT" --headless --path "$CLONE" --fixed-fps 60 -s tools/t003_footslide.gd
meta footslide_fixed_rc "$?"
for I in 1 2 3; do
  say "foot slide, real time, run $I of 3"
  limited 300 "$RAW/footslide_$I.log" "$GODOT" --headless --path "$CLONE" -s tools/t003_footslide.gd
  meta "footslide_${I}_rc" "$?"
done
step_done bots "$T"

# --- Shift, session and CUSTODIAN bots (Q002) ---------------------------------------------------------
# Together, so they fit the packet's 10 minutes: T014 alone is 24 min in one process. Fixed step, so load doesn't
# move the numbers. T014 stays split the same way every run: its numbers depend on what ran earlier in the process.
bot_job() { # bot_job <log> <tool> <args...>
  local log="$1" tool="$2"; shift 2
  limited 900 "$RAW/$log.log" "$GODOT" --headless --path "$CLONE" --fixed-fps 60 -s "$tool" "--" "$@"
  meta "${log}_rc" "$?"
}
T=$(date +%s)
say "T012, T014, T015 bots, together"
bot_job t012 tools/t012_bots.gd "$RUNS" "$RAW/t012.json" &
bot_job t015_shift tools/t015_shift_bots.gd "$RUNS" "$RAW/t015_shift.json" &
bot_job t015 tools/t015_bots.gd "$RUNS" "$RAW/t015.json" &
T014_EACH=$(( RUNS / 4 )); [ "$T014_EACH" -lt 1 ] && T014_EACH=1
F=0
while [ "$F" -lt "$RUNS" ]; do
  bot_job "t014_$F" tools/t014_bots.gd "$T014_EACH" "$RAW/t014.part$F.json" "$F" &
  F=$((F + T014_EACH))
done
wait
step_done session_bots "$T"

# --- Flicker ---------------------------------------------------------------------------------------
T=$(date +%s)
wait_for_code_lane "flicker"
say "flicker frames"
limited 1200 "$RAW/flicker.log" "$GODOT" --path "$CLONE" --fixed-fps 60 -s tools/t008_flicker.gd -- "--out=$WORK/flicker"
meta flicker_rc "$?"
limited 600 "$RAW/flicker_diff.log" python3 "$CLONE/tools/t008_flicker_diff.py" "$WORK/flicker"
meta flicker_diff_rc "$?"
step_done flicker "$T"

meta waited_s "$WAITED"
meta under_load "$UNDER_LOAD"
meta seconds_total "$(( $(date +%s) - STARTED ))"

# --- Report ----------------------------------------------------------------------------------------
say "writing report"
LOGS="$ROOT/docs/qa/logs-$DATE"; mkdir -p "$LOGS"
cp "$RAW"/*.log "$RAW"/meta.txt "$RAW"/frame/windows.txt "$RAW"/frame/top_cpu.txt "$LOGS"/ 2>/dev/null
# These run to hundreds of KB of known noise; the report counts their errors. Kept only if the run failed.
for I in 1 2 3; do grep -q '^tests_'$I'_rc=0$' "$RAW/meta.txt" && rm -f "$LOGS/tests_$I.log"; done
grep -q '^flicker_rc=0$' "$RAW/meta.txt" && rm -f "$LOGS/flicker.log"
python3 "$ROOT/tools/qa/health_report.py" "$RAW" "$ROOT/docs/qa" $WRITE_BASELINE
CODE=$?
[ "$CODE" -gt 1 ] && CODE=2
say "done in $(( $(date +%s) - STARTED ))s: docs/qa/health-$DATE.md (exit $CODE)"
exit "$CODE"
