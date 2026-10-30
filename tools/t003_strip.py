#!/usr/bin/env python3
"""T003 walking strip: crops walk_1..6.png around the operator and lays them side by side.

usage: python3 tools/t003_strip.py <capture-dir>   (needs Pillow; writes walk_strip.png there)
"""
import sys
from pathlib import Path

from PIL import Image

HALF_W, HALF_H, ZOOM = 90, 110, 2


def main(folder):
    d = Path(folder)
    frames = [Image.open(d / f"walk_{i}.png").convert("RGB") for i in range(1, 7)]
    w, h = HALF_W * 2 * ZOOM, HALF_H * 2 * ZOOM
    strip = Image.new("RGB", (w * 6, h))
    for i, im in enumerate(frames):
        cx, cy = im.width // 2, im.height // 2 + 30
        crop = im.crop((cx - HALF_W, cy - HALF_H, cx + HALF_W, cy + HALF_H))
        strip.paste(crop.resize((w, h), Image.LANCZOS), (i * w, 0))
    strip.save(d / "walk_strip.png")


if __name__ == "__main__":
    main(sys.argv[1])
