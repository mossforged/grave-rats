#!/usr/bin/env python3
"""T008: twinkle numbers from the frames tools/t008_flicker.gd saved.
Moved: pixels that changed by more than THRESH between neighbouring frames.
Twinkle: moved one way and straight back within two frames, what a flicker does and a slow
sweep doesn't. usage: t008_flicker_diff.py <dir> [<dir> ...]"""
import glob, os, sys
import numpy as np
from PIL import Image

THRESH = 6  # out of 255, on luma

def luma(path):
    a = np.asarray(Image.open(path).convert("L"), dtype=np.int16)
    return a

for root in sys.argv[1:]:
    for tag in sorted(os.listdir(root)):
        files = sorted(glob.glob(os.path.join(root, tag, "*.png")))
        if len(files) < 3:
            continue
        frames = [luma(f) for f in files]
        moved, twinkle = [], []
        worst_box = None
        for a, b, c in zip(frames, frames[1:], frames[2:]):
            d1 = b.astype(int) - a
            d2 = c.astype(int) - b
            moved.append((np.abs(d1) > THRESH).mean() * 100)
            flip = (np.abs(d1) > THRESH) & (np.abs(d2) > THRESH) & (np.sign(d1) != np.sign(d2))
            twinkle.append(flip.mean() * 100)
        print(f"{os.path.basename(root)}/{tag}: moved {np.mean(moved):.3f}% (max {np.max(moved):.3f}%), "
              f"twinkle {np.mean(twinkle):.4f}% (max {np.max(twinkle):.4f}%) of the screen")
