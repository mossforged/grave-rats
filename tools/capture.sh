#!/bin/bash
# Windowed capture on the real GPU: tools/capture.sh <scene> <out-dir> [seconds]
#   scene    res:// path or project-relative path, e.g. scenes/dev/asset_viewer.tscn
#   out-dir  where PNGs and frametime.json go (created if missing)
#   seconds  frame-time measuring window after a 2 s warmup (default 10)
# Extra env: CAPTURE_SIZE=1920x1080 (framebuffer pixels), GODOT=/path/to/godot.
# The work is done by src/debug/capture.gd (autoload `Capture`).
set -euo pipefail
if [ $# -lt 2 ]; then echo "usage: $0 <scene> <out-dir> [seconds]" >&2; exit 2; fi
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCENE="$1"; case "$SCENE" in res://*) ;; *) SCENE="res://${SCENE#./}";; esac
mkdir -p "$2"; OUT="$(cd "$2" && pwd)"
SECS="${3:-10}"
SIZE="${CAPTURE_SIZE:-1920x1080}"
GODOT="${GODOT:-$(command -v godot || echo /Applications/Godot.app/Contents/MacOS/Godot)}"
LIMIT=$(( ${SECS%.*} + 120 ))
"$GODOT" --path "$ROOT" "$SCENE" -- --capture-out="$OUT" --capture-seconds="$SECS" --capture-size="$SIZE" &
PID=$!
# watchdog: kills Godot if it hangs; its output is detached so callers' pipes close on time
( sleep "$LIMIT"; kill "$PID" 2>/dev/null ) </dev/null >/dev/null 2>&1 &
WATCH=$!
set +e
wait "$PID"; CODE=$?
pkill -P "$WATCH" sleep 2>/dev/null; kill "$WATCH" 2>/dev/null
[ "$CODE" -eq 143 ] && echo "capture: killed after ${LIMIT}s (hung?)" >&2
[ -f "$OUT/frametime.json" ] || { echo "capture: no frametime.json written" >&2; exit 1; }
exit "$CODE"
