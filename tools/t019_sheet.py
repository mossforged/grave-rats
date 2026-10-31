#!/usr/bin/env python3
"""T019: the before and after of each stand, side by side. usage: python3 tools/t019_sheet.py"""
from pathlib import Path
from PIL import Image, ImageDraw

DIR = Path(__file__).resolve().parents[1] / "docs/screens/T019"
STANDS = ["long_corridor_north", "long_corridor_south", "long_corridor_play", "side_corridor", "door_jambs_lintel",
          "door_side", "inner_corner", "grimmest", "grimmest_play"]
W, H = 960, 476
sheet = Image.new("RGB", (W * 2, H * len(STANDS)))
draw = ImageDraw.Draw(sheet)
for row, name in enumerate(STANDS):
    for col, tag in enumerate(["before", "after"]):
        im = Image.open(DIR / f"t019_{name}_{tag}.png").convert("RGB").resize((W, H))
        sheet.paste(im, (col * W, row * H))
        draw.text((col * W + 8, row * H + 6), f"{name} {tag}", fill=(255, 230, 120))
sheet.save(DIR / "sheet.png")
