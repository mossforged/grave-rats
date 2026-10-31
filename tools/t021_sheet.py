#!/usr/bin/env python3
"""T021's sheet: docs/screens/T021/sheet.png, and the wall-top numbers: docs/screens/T021/wall_repeat.json.
Run after tools/capture.sh scenes/dev/t021_stand.tscn docs/screens/T021 2. Band: the medbay's north wall top."""
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw

OUT = Path("docs/screens/T021")
BAND = (700, 318, 1650, 345)
BED = (760, 380, 1000, 590)


def grey(name):
    return np.asarray(Image.open(OUT / f"{name}.png").convert("L"), float)


def band_diff(a, b):
    x0, y0, x1, y1 = BAND
    d = np.abs(grey(a) - grey(b))[y0:y1, x0:x1]
    return {"mean": round(float(d.mean()), 3), "max": float(d.max())}


numbers = {
    "pinned_camera_same_seed": band_diff("t021_wall_repeat_a", "t021_wall_repeat_b"),
    "camera_moved_1_mm": band_diff("t021_wall_repeat_a", "t021_wall_nudged"),
}
(OUT / "wall_repeat.json").write_text(json.dumps(numbers, indent=2) + "\n")
print(numbers)

panels = [("t021_bed_room_before", "Bed, no mask, before"), ("t021_bed_room_after", "Bed, no mask, after"),
          ("t021_bed_before", "Bed, play view, light on, before"), ("t021_bed_after", "Bed, play view, light on, after"),
          ("t021_bed_dark_before", "Bed, play view, light off, before"), ("t021_bed_dark_after", "Bed, play view, light off, after")]
W, H = 480, 420
sheet = Image.new("RGB", (W * 2 + 10, (H + 24) * 3 + 300), "#101214")
d = ImageDraw.Draw(sheet)
for i, (name, label) in enumerate(panels):
    x, y = (i % 2) * (W + 10), (i // 2) * (H + 24)
    d.text((x + 4, y + 6), label, fill="#d8e2e6")
    sheet.paste(Image.open(OUT / f"{name}.png").convert("RGB").crop(BED).resize((W, H)), (x, y + 24))
y = (H + 24) * 3
for i, name in enumerate(["t021_wall_repeat_a", "t021_wall_repeat_b", "t021_wall_nudged"]):
    x0, y0, x1, y1 = BAND
    crop = Image.open(OUT / f"{name}.png").convert("RGB").crop((x0, y0 - 14, x1, y1 + 14)).resize((W * 2 + 10, 80))
    d.text((4, y + 6 + i * 100), name, fill="#d8e2e6")
    sheet.paste(crop, (0, y + 20 + i * 100))
sheet.save(OUT / "sheet.png")
