#!/usr/bin/env python3
"""T020: copies the lead's VFX set from assets/source/ into assets/game/vfx/ and the two gun meshes into
assets/game/props/. Reads the source folder, never writes to it. Godot's Decal node takes one whole texture,
so each decal sheet is also cut into <sheet>_<frame>.png. Then: godot --headless --path . --import
"""
import json
import pathlib
import shutil

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[1]
SRC = ROOT / "assets" / "source" / "vfx"
OUT = ROOT / "assets" / "game" / "vfx"
PROPS = ["shell_casing.glb", "spent_magazine.glb"]


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = json.loads((SRC / "manifest.json").read_text())
    shutil.copy2(SRC / "manifest.json", OUT / "manifest.json")
    for name, m in manifest.items():
        shutil.copy2(SRC / m["file"], OUT / m["file"])
        if not name.startswith("decal_"):
            continue
        sheet = Image.open(SRC / m["file"]).convert("RGBA")
        cols = m["cols"]
        rows = m["frames"] // cols
        w, h = sheet.width // cols, sheet.height // rows
        for f in range(m["frames"]):
            x, y = (f % cols) * w, (f // cols) * h
            sheet.crop((x, y, x + w, y + h)).save(OUT / f"{name}_{f}.png")
    for p in PROPS:
        shutil.copy2(ROOT / "assets" / "source" / "props" / p, ROOT / "assets" / "game" / "props" / p)
    print(f"{len(manifest)} sheets, {len(PROPS)} meshes")


if __name__ == "__main__":
    main()
