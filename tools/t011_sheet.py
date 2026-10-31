#!/usr/bin/env python3
"""T011 comparison sheet: docs/screens/T011/sheet.png, in T010's format. Each paint-over beside the T010 and
T011 frames from the same stand and camera, then T011 in play; the decals in each room; side and front
doors in five states; a hit from out of sight; the faded walls under the mask; the frame-time table.

Run after the captures, with docs/screens/T011/frame_times.json written (see the handoff):
python3 tools/t011_sheet.py
"""
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/screens/T011"
OLD = ROOT / "docs/screens/T010"
SRC = ROOT / "assets/source/A006-slice"
FONT = "/System/Library/Fonts/Supplemental/Arial.ttf"
BG, FG, MUT, GOLD = "#10181e", "#e4e6e3", "#9faeb8", "#e5b852"
FRAMES = [("01b", "Medbay / cool white + dust"), ("02b", "Crouched behind tipped bed"),
          ("03c", "Mid-bash door / seam light"), ("04b", "Junction toward cargo / amber")]
STATES = ["closed", "open", "locked", "bashed", "broken"]
DOOR_CROP = (420, 120, 1500, 727)


def font(n):
    return ImageFont.truetype(FONT, n)


def fit(sheet, path, box, crop=None):
    im = Image.open(path).convert("RGB")
    if crop:
        im = im.crop(crop)
    im.thumbnail((box[2] - box[0], box[3] - box[1]), Image.Resampling.LANCZOS)
    sheet.paste(im, (box[0] + (box[2] - box[0] - im.width) // 2, box[1]))


def row(sheet, d, y, x0, cell, gap, h, items):
    for i, (label, path) in enumerate(items):
        x = x0 + i * (cell + gap)
        d.text((x, y), label, font=font(22), fill=FG)
        fit(sheet, path, (x, y + 32, x + cell, y + 32 + h))
    return y + 32 + h + 14


def main():
    W, margin, gap = 4096, 28, 18
    cell = (W - 2 * margin - 3 * gap) // 4
    h = cell * 9 // 16
    door_cell = (W - 2 * margin - 4 * gap) // 5
    door_h = door_cell * 9 // 16
    times = json.loads((OUT / "frame_times.json").read_text())
    H = 170 + 4 * (h + 56) + 3 * (h + 90) + 2 * (door_h + 90) + 120 + 42 * (len(times) + 4)
    sheet = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(sheet)
    d.text((margin, 22), "GRAVE RATS / T011 / SLICE POLISH AGAINST THE A006 PAINT-OVERS", font=font(44), fill=FG)
    d.text((margin, 80), "Same stands and camera as T010. Bed, console, lockers, stalker: still boxes until the Meshy files land (out of scope).", font=font(26), fill=MUT)
    for j, title in enumerate(["A006 PAINT-OVER", "T010, MASK OFF", "T011, MASK OFF", "T011, IN PLAY (THE MASK DECIDES)"]):
        d.text((margin + j * (cell + gap), 124), title, font=font(24), fill=GOLD)
    y = 170
    for fid, subject in FRAMES:
        paths = [SRC / f"A006-{fid}.png", OLD / f"t010_{fid}_off.png", OUT / f"t011_{fid}_off.png", OUT / f"t011_{fid}_play.png"]
        for col, p in enumerate(paths):
            x = margin + col * (cell + gap)
            if col == 0:
                d.text((x, y), f"A006-{fid} / {subject}", font=font(23), fill=FG)
            fit(sheet, p, (x, y + 36, x + cell, y + h + 36))
        y += h + 56
    d.text((margin, y), "A010 decals in each room (mask off)", font=font(25), fill=GOLD)
    y = row(sheet, d, y + 36, margin, cell, gap, h, [(n, OUT / f"t011_rooms_{n}.png") for n in ["medbay", "junction", "cargo", "corridor"]])
    for view, label in [("side", "A side door, the medbay's: the state reads from the floor strips"), ("front", "A door facing the camera")]:
        d.text((margin, y), f"Door states / {label}", font=font(25), fill=GOLD)
        y += 36
        for i, st in enumerate(STATES):
            x = margin + i * (door_cell + gap)
            d.text((x, y), st, font=font(22), fill=FG)
            fit(sheet, OUT / f"t011_door_{st}_{view}.png", (x, y + 32, x + door_cell, y + 32 + door_h), crop=DOOR_CROP)
        y += 32 + door_h + 14
    d.text((margin, y), "Fairness and the mask", font=font(25), fill=GOLD)
    y = row(sheet, d, y + 36, margin, cell, gap, h, [
        ("A hit from out of sight: the flash lights the shooter, the arc points", OUT / "t011_hit_out_of_sight.png"),
        ("Faded walls under the mask (T010: they stayed lit)", OUT / "t011_faded_walls_under_mask.png"),
        ("The ambush panel's tell, remembered, outside the cone", OUT / "t011_ambush_tell.png"),
        ("Cut-away fade, mask off", OUT / "t011_cutaway_fade.png")])
    d.text((margin, y), "Frame time, 1920x1080 on this Mac, ms (average / p95 / p99). Target, pirate deck: under 7.5 average, under 9.5 p95.", font=font(25), fill=GOLD)
    y += 40
    for name, avg, p95, p99 in times:
        if name.startswith("---"):
            d.text((margin, y), name[4:], font=font(24), fill=MUT)
            y += 34
            continue
        d.text((margin, y), name, font=font(24), fill=FG)
        d.text((margin + 900, y), f"{avg:5.2f} / {p95:5.2f} / {p99:5.2f}", font=font(24), fill=FG)
        y += 34
    sheet = sheet.crop((0, 0, W, min(H, y + 30)))
    sheet.save(OUT / "sheet.png", optimize=True)
    print("sheet", sheet.size)


if __name__ == "__main__":
    main()
