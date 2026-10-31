#!/usr/bin/env python3
"""T023's sheet: docs/screens/T023/sheet.png. The concept frames A014-03/04/05 beside the built rooms, then every
other stand. Run after tools/capture.sh scenes/dev/t023_stand.tscn docs/screens/T023 2."""
from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path("docs/screens/T023")
SRC = Path("assets/source/A014-derelict-2")
W, H = 800, 445
PAIRS = [("A014-03", "t023_bridge_black_box", "Bridge"), ("A014-04", "t023_bio_lab", "Bio lab"), ("A014-05", "t023_east_spine_north", "Corridor")]
REST = ["bridge", "bridge_black_box_play", "bio_lab_tanks_play", "bio_lab_seal_trolley", "bio_lab_seal_play", "mess", "quarters", "airlock_hold",
        "engineering_dead_end", "engineering_door_play", "west_spine_north", "west_spine_south", "west_spine_play", "east_spine_south", "east_spine_grim", "east_spine_play"]


def fit(path):
    im = Image.open(path).convert("RGB")
    s = max(W / im.width, H / im.height)
    im = im.resize((round(im.width * s), round(im.height * s)))
    x, y = (im.width - W) // 2, (im.height - H) // 2
    return im.crop((x, y, x + W, y + H))


rows = len(PAIRS) + (len(REST) + 1) // 2
sheet = Image.new("RGB", (W * 2 + 10, (H + 24) * rows), "#101214")
d = ImageDraw.Draw(sheet)
for i, (a, b, label) in enumerate(PAIRS):
    y = i * (H + 24)
    d.text((4, y + 6), f"{label}: concept {a} (mood frame, not a registered overlay)", fill="#d8e2e6")
    d.text((W + 14, y + 6), f"{label}: built, game camera, no mask", fill="#d8e2e6")
    sheet.paste(fit(SRC / f"{a}.png"), (0, y + 24))
    sheet.paste(fit(OUT / f"{b}.png"), (W + 10, y + 24))
for i, name in enumerate(REST):
    x, y = (i % 2) * (W + 10), (len(PAIRS) + i // 2) * (H + 24)
    d.text((x + 4, y + 6), name.replace("_", " "), fill="#d8e2e6")
    sheet.paste(fit(OUT / f"t023_{name}.png"), (x, y + 24))
sheet.save(OUT / "sheet.png")
print(sheet.size)
