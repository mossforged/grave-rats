#!/bin/bash
# T020: the shots and frame-time windows on both decks, then a recording of a full mag dump (Movie Maker: picture
# and sound, nothing out of the speakers) with its peak and RMS.
#   tools/t020_capture.sh <out-dir>
# Leaves in out-dir: t020_*.png and frametime_t020_stand_shift.json, pirate/ the same, mag_dump.mp4, mag_dump_levels.txt.
set -euo pipefail
OUT="${1:?usage: $0 <out-dir>}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-$(command -v godot || echo /Applications/Godot.app/Contents/MacOS/Godot)}"
mkdir -p "$OUT/pirate"; OUT="$(cd "$OUT" && pwd)"
"$ROOT/tools/capture.sh" scenes/dev/t020_stand_shift.tscn "$OUT" 2
"$ROOT/tools/capture.sh" scenes/dev/t020_stand_pirate.tscn "$OUT/pirate" 2
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
T020_MOVIE=1 "$GODOT" --path "$ROOT" --write-movie "$TMP/dump.avi" --fixed-fps 30 --resolution 1280x720 res://scenes/dev/t020_stand_shift.tscn >"$TMP/log" 2>&1 || { tail -20 "$TMP/log"; exit 1; }
ffmpeg -y -loglevel error -i "$TMP/dump.avi" -c:v libx264 -crf 24 -preset medium -pix_fmt yuv420p -c:a aac -b:a 160k "$OUT/mag_dump.mp4"
ffmpeg -hide_banner -i "$TMP/dump.avi" -af volumedetect -vn -f null - 2>&1 | grep -E "mean_volume|max_volume" > "$OUT/mag_dump_levels.txt"
