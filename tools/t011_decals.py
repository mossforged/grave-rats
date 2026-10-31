#!/usr/bin/env python3
"""T011: cuts the A010 company graphics out of the art lane's sheets, with alpha. Values: data/kit.json
"decals". Reads the sheets, never writes to them.

Each item names a sheet and a box. "outline" keeps everything inside a sign's frame: only sheet grey
touching the crop goes. "key" also drops grey inside it: stencils have bridges and open letters.
`fade` washes an item out (the dead owner's graphics); `wear` scuffs holes in it; `ink` repaints dark
ink that would vanish on a dark deck.

Writes assets/game/kit/decals/<name>.png with their .import settings and removes decals no longer
in the data. Then: godot --headless --path . --import

Run: python3 tools/t011_decals.py
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy.ndimage import binary_erosion, gaussian_filter, label

sys.path.insert(0, str(Path(__file__).resolve().parent))
from t010_textures import fbm, rgb, threshold_for, write_import  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
CFG = json.loads((ROOT / "data/kit.json").read_text())["decals"]
DEC = ROOT / "assets/game/kit/decals"


def sheet_grey(sheet):
    """The sheet's background, from its top and bottom rows."""
    return np.median(np.concatenate([sheet[:6].reshape(-1, 3), sheet[-6:].reshape(-1, 3)]), axis=0)


def cut(sheet, grey, item, seed):
    x0, y0, x1, y1 = item["box"]
    crop = sheet[y0:y1, x0:x1].copy()
    near = np.abs(crop - grey).max(axis=2) < CFG["key_tolerance"]
    if item["mode"] == "outline":
        lab, _ = label(near)
        edge = set(lab[0, :]) | set(lab[-1, :]) | set(lab[:, 0]) | set(lab[:, -1])
        edge.discard(0)
        near = np.isin(lab, list(edge))
    alpha = binary_erosion(~near, iterations=1).astype(np.float32)
    alpha = np.clip(gaussian_filter(alpha, CFG["edge_soft_px"]) * 2.0 - 0.5, 0, 1)
    wear = item.get("wear", CFG["wear"])
    if wear > 0:
        worn = fbm(0, 2.6, 3, 400 + seed, alpha.shape) * 0.72 + fbm(0, 1.9, 24, 500 + seed, alpha.shape) * 0.28
        alpha = alpha * (worn > threshold_for(worn, 1.0 - wear))
    if "ink" in item:
        dark = (crop.max(axis=2) < CFG["ink_dark"])[..., None]
        crop = crop * (~dark) + rgb(item["ink"])[None, None] * dark
    fade = item.get("fade", 0.0)
    if fade > 0:
        luma = (crop * [0.2126, 0.7152, 0.0722]).sum(axis=2, keepdims=True)
        washed = luma * (1 - CFG["fade_grey"]) + rgb(CFG["fade_wash"])[None, None] * CFG["fade_grey"]
        blotch = fbm(0, 2.6, 2, 600 + seed, alpha.shape)[..., None] * 0.5 + 0.5
        crop = crop * (1 - fade * blotch) + washed * fade * blotch
    return np.dstack([np.clip(crop, 0, 1), alpha])


def main():
    DEC.mkdir(parents=True, exist_ok=True)
    sheets = {}
    for i, (name, item) in enumerate(CFG["items"].items()):
        key = item["sheet"]
        if key not in sheets:
            s = np.asarray(Image.open(ROOT / CFG["sheets"][key]).convert("RGB"), np.float32) / 255.0
            sheets[key] = (s, sheet_grey(s))
        out = cut(*sheets[key], item, i)
        Image.fromarray((out * 255 + 0.5).astype(np.uint8), "RGBA").save(DEC / f"{name}.png", optimize=True)
        write_import(DEC / f"{name}.png", normal_map=False)
    for old in DEC.glob("*.png"):
        if old.stem not in CFG["items"]:
            old.unlink()
            Path(str(old) + ".import").unlink(missing_ok=True)
    print("decals:", sorted(p.stem for p in DEC.glob("*.png")))


if __name__ == "__main__":
    main()
