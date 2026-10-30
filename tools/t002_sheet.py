#!/usr/bin/env python3
"""T002 comparison sheets from tools/capture.sh output (needs Pillow).

usage: python3 tools/t002_sheet.py <capture-dir> <concept.jpg> <out-dir>

Godot keeps the vertical FOV fixed, so a centre crop of a capture is exactly what a window of that
aspect would show. Captures are cropped to 16:9 (the game's target) and, for the side-by-side, to
the concept panel's own aspect so the composition compares like for like.
"""
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

BG = (12, 14, 18)
FG = (235, 235, 235)


def font(size):
    try:
        return ImageFont.load_default(size=size)
    except TypeError:
        return ImageFont.load_default()


def crop_aspect(im, aspect):
    w, h = im.size
    if w / h > aspect:
        nw = round(h * aspect)
        x = (w - nw) // 2
        return im.crop((x, 0, x + nw, h))
    nh = round(w / aspect)
    y = (h - nh) // 2
    return im.crop((0, y, w, y + nh))


def fit_w(im, width):
    return im.resize((width, round(im.height * width / im.width)), Image.LANCZOS)


def label(draw, xy, text, size=28):
    draw.text(xy, text, fill=FG, font=font(size), stroke_width=3, stroke_fill=(0, 0, 0))


def sheet(cells, cols, cell_w, aspect, title, out):
    rows = (len(cells) + cols - 1) // cols
    cell_h = round(cell_w / aspect)
    pad, head = 16, 64
    img = Image.new("RGB", (cols * cell_w + (cols + 1) * pad, head + rows * (cell_h + pad) + pad), BG)
    d = ImageDraw.Draw(img)
    label(d, (pad, 16), title, 34)
    for i, (path, text) in enumerate(cells):
        im = fit_w(crop_aspect(Image.open(path).convert("RGB"), aspect), cell_w)
        x = pad + (i % cols) * (cell_w + pad)
        y = head + (i // cols) * (cell_h + pad)
        img.paste(im, (x, y))
        label(d, (x + 12, y + 10), text)
    img.save(out)
    print("sheet:", out, img.size)


def main():
    cap, concept, out = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3])
    out.mkdir(parents=True, exist_ok=True)
    cam = json.loads(Path("data/camera.json").read_text())
    presets = sorted(cap.glob("preset_*.png"))
    names = [f"{i + 1}  {p['name']}" for i, p in enumerate(cam["presets"])]
    sheet(list(zip(presets, names)), 3, 760, 16 / 9, "T002 camera presets (default scale, 16:9 crop)",
          out / "sheet_presets.png")
    scales = sorted(cap.glob("concept_room_*.png"))
    scales = [s for s in scales if s.stem.count("_") == 2] + [s for s in scales if s.stem.count("_") > 2]
    sheet([(s, s.stem.replace("concept_", "concept preset, ").replace("_", " ")) for s in scales], 3, 760, 16 / 9,
          "T002 concept preset: room scale 0.85 / 1.0 / 1.15, character 1.15, fade, medbay, cargo",
          out / "sheet_scales.png")
    panel = Image.open(concept).convert("RGB")
    aspect = panel.width / panel.height
    width = 1536
    a = fit_w(panel, width)
    rows = [(a, "CONCEPT gameplay-panel.jpg")]
    for p, n in [(presets[0], names[0]), (presets[2], names[2])]:
        rows.append((fit_w(crop_aspect(Image.open(p).convert("RGB"), aspect), width),
                     f"T002 preset {n} (cropped to the panel's {aspect:.2f}:1)"))
    pad = 16
    h = sum(r[0].height + pad for r in rows) + pad
    img = Image.new("RGB", (width + 2 * pad, h), BG)
    d = ImageDraw.Draw(img)
    y = pad
    for im, text in rows:
        img.paste(im, (pad, y))
        label(d, (pad + 12, y + 10), text)
        y += im.height + pad
    img.save(out / "sheet_concept_side_by_side.png")
    print("sheet:", out / "sheet_concept_side_by_side.png", img.size)


if __name__ == "__main__":
    main()
