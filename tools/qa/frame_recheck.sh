#!/bin/bash
# Q002: frame-time windows alone, for when the code lane spoiled a health check's. Unlike health_check.sh it watches
# during each window, not only before it, and a window the code lane's Godot touched doesn't count.
#   tools/qa/frame_recheck.sh <commit> <out-dir> <deadline, as HH:MM today>
# Writes <out-dir>/windows.tsv (scene, window, clean or dirty, resolution, scale, frames, avg, p95, p99, load before,
# load after) and <out-dir>/<scene>_<n>/frametime.json. Stops at two clean windows per scene, or at the deadline.
# Env: QA_SECONDS (default 30), QA_LOAD_MAX (load average to start a window under, default 6).
# The window is dirty if guard.sh said busy at any time during it.
set -u
export PATH="$HOME/.local/grave-rats-bin:$PATH:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
COMMIT="$1"; OUT="$2"; DEADLINE="$(date -j -f '%H:%M' "$3" +%s)"
SECONDS_WINDOW="${QA_SECONDS:-30}"; LOAD_MAX="${QA_LOAD_MAX:-6}"
GODOT="${GODOT:-$(command -v godot || echo /Applications/Godot.app/Contents/MacOS/Godot)}"; export GODOT
WANT=2
SCENES="scenes/pirates/pirate_deck.tscn scenes/enemies/stalker_deck.tscn scenes/shift/shift_deck.tscn"
WORK="$(mktemp -d /tmp/grave-rats-recheck.XXXXXX)"; trap 'rm -rf "$WORK"' EXIT
mkdir -p "$OUT"; OUT="$(cd "$OUT" && pwd)"; : > "$OUT/windows.tsv"

say() { echo "[$(date +%H:%M:%S)] $*"; }
load1() { sysctl -n vm.loadavg | tr -d '{}' | awk '{print $1}'; }
loadavg() { sysctl -n vm.loadavg | tr -d '{}' | awk '{print $1, $2, $3}'; }
# Q003: any other Godot on this Mac, or an agent in the code lane's clone, not only a code-lane Godot. See guard.sh.
code_lane_busy() { "$ROOT/tools/qa/guard.sh" "$WORK" >/dev/null; }
# Holds until the Mac has gone quiet; non-zero at the deadline.
wait_quiet() {
  while code_lane_busy || [ "$(echo "$(load1) >= $LOAD_MAX" | bc -l)" = 1 ]; do
    [ "$(date +%s)" -ge "$DEADLINE" ] && return 1
    sleep 10
  done
  [ "$(date +%s)" -lt "$DEADLINE" ]
}
capture() { CAPTURE_ONLY=none CAPTURE_SIZE=1920x1080 "$WORK/clone/tools/capture.sh" "$1" "$2" "$3" >"$2.log" 2>&1; }

# The origin, not this checkout: main may have moved on past what's fetched into local branches.
git clone -q --filter=blob:none "$(git -C "$ROOT" remote get-url origin)" "$WORK/clone" && git -C "$WORK/clone" checkout -q "$COMMIT" || exit 2
"$GODOT" --headless --path "$WORK/clone" --import >/dev/null 2>&1
printf '[display]\n\nwindow/size/borderless=true\n' > "$WORK/clone/override.cfg"
for S in $SCENES; do wait_quiet || break; say "warming $S"; capture "$S" "$WORK/warm" 5; done

ROUND=0
while :; do
  ROUND=$((ROUND + 1)); LEFT=0
  for S in $SCENES; do
    NAME="$(basename "$S" .tscn)"
    [ "$(awk -F'\t' -v n="$NAME" '$1 == n && $3 == "clean"' "$OUT/windows.tsv" | wc -l | tr -d ' ')" -ge "$WANT" ] && continue
    LEFT=1
    wait_quiet || { say "deadline reached"; exit 0; }
    BEFORE="$(loadavg)"; DIR="$OUT/${NAME}_$ROUND"; FLAG="$WORK/dirty"; rm -f "$FLAG"
    ( while :; do code_lane_busy && touch "$FLAG"; sleep 2; done ) </dev/null >/dev/null 2>&1 &
    GUARD=$!
    say "$NAME window $ROUND, load $BEFORE"
    capture "$S" "$DIR" "$SECONDS_WINDOW"
    kill "$GUARD" 2>/dev/null; wait "$GUARD" 2>/dev/null
    STATE=clean; [ -f "$FLAG" ] && STATE=dirty
    python3 - "$DIR/frametime.json" "$NAME" "$ROUND" "$STATE" "$BEFORE" "$(loadavg)" >> "$OUT/windows.tsv" <<'EOF'
import json, sys
path, name, n, state, before, after = sys.argv[1:]
try:
    d = json.load(open(path))
except (OSError, ValueError):
    print(f"{name}\t{n}\tmissing\t\t\t\t\t\t\t{before}\t{after}")
else:
    print("\t".join(str(x) for x in (name, n, state, d["resolution"], d["screen_scale"], d["frames"],
          round(d["frame_ms_avg"], 3), d["frame_ms_p95"], d["frame_ms_p99"], before, after)))
EOF
    say "  $STATE: $(tail -1 "$OUT/windows.tsv" | cut -f4-9 | tr '\t' ' ')"
  done
  [ "$LEFT" = 0 ] && { say "two clean windows per scene"; exit 0; }
done
