#!/usr/bin/env python3
"""T023: cuts the A013 room graphics out of the art lane's atlases, with alpha, using T011's cutter.
Values: data/kit.json "room_decals" (its boxes are T023's: A013's manifest names the atlases but holds no
crops). Reads the atlases, never writes to them. Writes assets/game/decals/<name>.png with .import settings.

Run: python3 tools/t023_decals.py, then godot --headless --path . --import
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from t010_textures import write_import  # noqa: E402
from t011_decals import cut, sheet_grey  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
CFG = json.loads((ROOT / "data/kit.json").read_text())["room_decals"]
OUT = ROOT / "assets/game/decals"


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    sheets = {}
    for i, (name, item) in enumerate(CFG["items"].items()):
        key = item["sheet"]
        if key not in sheets:
            s = np.asarray(Image.open(ROOT / CFG["sheets"][key]).convert("RGB"), np.float32) / 255.0
            sheets[key] = (s, sheet_grey(s))
        spec = {"wear": CFG["wear"], **item}
        out = cut(*sheets[key], spec, 100 + i)
        Image.fromarray((out * 255 + 0.5).astype(np.uint8), "RGBA").save(OUT / f"{name}.png", optimize=True)
        write_import(OUT / f"{name}.png", normal_map=False)
    print(len(CFG["items"]), "decals in", OUT)


if __name__ == "__main__":
    main()
