#!/bin/bash
# T017: records tools/t017_sound_sequence.gd with Movie Maker (picture and sound, nothing out of the
# speakers), once through the limiter and once without, and measures both.
#   tools/t017_sound_capture.sh <out-dir>
# Leaves in out-dir: sequence.mp4, sequence.wav (the limited mix) and levels.json. Needs ffmpeg and numpy.
set -euo pipefail
OUT="${1:?usage: $0 <out-dir>}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-$(command -v godot || echo /Applications/Godot.app/Contents/MacOS/Godot)}"
mkdir -p "$OUT"; OUT="$(cd "$OUT" && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
record() {
	T017_SEGMENTS="$TMP/segments.json" T017_NO_LIMITER="$1" timeout 900 "$GODOT" --path "$ROOT" --write-movie "$TMP/$2.avi" \
		--fixed-fps 30 --resolution 1280x720 res://scenes/dev/t017_sound_sequence.tscn >"$TMP/$2.log" 2>&1 \
		|| { tail -20 "$TMP/$2.log"; exit 1; }
	ffmpeg -y -loglevel error -i "$TMP/$2.avi" -vn -c:a pcm_s16le "$TMP/$2.wav"
}
record 0 limited
record 1 open
ffmpeg -y -loglevel error -i "$TMP/limited.avi" -c:v libx264 -crf 26 -preset medium -pix_fmt yuv420p -c:a aac -b:a 128k "$OUT/sequence.mp4"
cp "$TMP/limited.wav" "$OUT/sequence.wav"
python3 -I "$ROOT/tools/t017_levels.py" "$TMP/limited.wav" "$TMP/open.wav" "$TMP/segments.json" "$OUT/levels.json"
