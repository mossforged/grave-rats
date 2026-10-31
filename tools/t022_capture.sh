#!/bin/bash
# T022: the game-camera stills and sheet, and a recording of walking a circle while aiming at its centre.
#   tools/t022_capture.sh <out-dir>   (the sheet script reads docs/screens/T022)
set -euo pipefail
OUT="${1:-docs/screens/T022}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-$(command -v godot || echo /Applications/Godot.app/Contents/MacOS/Godot)}"
mkdir -p "$OUT"; OUT="$(cd "$OUT" && pwd)"
"$ROOT/tools/capture.sh" scenes/dev/t022_stand.tscn "$OUT" 2
python3 "$ROOT/tools/t022_sheet.py"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
T022_MOVIE=1 "$GODOT" --path "$ROOT" --write-movie "$TMP/circle.avi" --fixed-fps 30 --resolution 1280x720 res://scenes/dev/t022_stand.tscn >"$TMP/log" 2>&1 || { tail -20 "$TMP/log"; exit 1; }
ffmpeg -y -loglevel error -i "$TMP/circle.avi" -c:v libx264 -crf 24 -preset medium -pix_fmt yuv420p -an "$OUT/circle_aiming.mp4"
