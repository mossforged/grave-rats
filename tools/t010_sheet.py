#!/usr/bin/env python3
"""T010 comparison sheet: docs/screens/T010/sheet.png, like A006's. Each paint-over beside the same
camera in the game: mask off (the art alone), everything known (the rooms the paint-overs show),
and in play. Then the door states, the cut-away and the frame times.

Run after the captures: python3 tools/t010_sheet.py
"""
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/screens/T010"
SRC = ROOT / "assets/source/A006-slice"
FONT = "/System/Library/Fonts/Supplemental/Arial.ttf"
BG, FG, MUT, GOLD = "#10181e", "#e4e6e3", "#9faeb8", "#e5b852"
FRAMES = [("01b", "Medbay / cool white + dust"), ("02b", "Crouched behind tipped bed"),
          ("03c", "Mid-bash door / seam light"), ("04b", "Junction toward cargo / amber")]
STATES = ["closed", "open", "locked", "bashed", "broken"]


def font(n):
    return ImageFont.truetype(FONT, n)


def fit(sheet, path, box, crop=None):
    im = Image.open(path).convert("RGB")
    if crop:
        im = im.crop(crop)
    im.thumbnail((box[2] - box[0], box[3] - box[1]), Image.Resampling.LANCZOS)
    sheet.paste(im, (box[0] + (box[2] - box[0] - im.width) // 2, box[1]))


def main():
    W, margin, gap = 4096, 28, 18
    cols = 4
    cell = (W - 2 * margin - (cols - 1) * gap) // cols
    rh = cell * 9 // 16 + 56
    door_cell = (W - 2 * margin - 4 * gap) // 5
    door_h = door_cell * 9 // 16 + 44
    table = []
    for f in sorted(OUT.glob("frametime_*.json")):
        d = json.loads(f.read_text())
        table.append((f.stem.replace("frametime_", ""), d["frame_ms_avg"], d["frame_ms_p95"], d["frame_ms_p99"]))
    H = 170 + 4 * rh + 2 * door_h + 50 + (cell * 9 // 16 + 70) + 60 + 40 * (len(table) + 2)
    sheet = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(sheet)
    d.text((margin, 22), "GRAVE RATS / T010 / SLICE KIT AGAINST THE A006 PAINT-OVERS", font=font(44), fill=FG)
    d.text((margin, 80), "Same stands and camera as the T006 frames A006 painted over. Bed, console, lockers, stalker: boxes until the Meshy files land.", font=font(26), fill=MUT)
    for j, title in enumerate(["A006 PAINT-OVER", "T010, MASK OFF (ART ALONE)", "T010, ALL KNOWN (REMEMBERED)", "T010, IN PLAY (THE MASK DECIDES)"]):
        d.text((margin + j * (cell + gap), 124), title, font=font(24), fill=GOLD)
    y = 170
    for fid, subject in FRAMES:
        paths = [SRC / f"A006-{fid}.png", OUT / f"t010_{fid}_off.png", OUT / f"t010_{fid}_known.png", OUT / f"t010_{fid}_play.png"]
        for col, p in enumerate(paths):
            x = margin + col * (cell + gap)
            if col == 0:
                d.text((x, y), f"A006-{fid} / {subject}", font=font(23), fill=FG)
            fit(sheet, p, (x, y + 36, x + cell, y + rh - 8))
        y += rh
    for view, label in [("front", "A door facing the camera"), ("side", "A side door, the medbay's")]:
        d.text((margin, y), f"Door states / {label}", font=font(25), fill=GOLD)
        y += 36
        for i, st in enumerate(STATES):
            x = margin + i * (door_cell + gap)
            fit(sheet, OUT / f"t010_door_{st}_{view}.png", (x, y + 32, x + door_cell, y + door_h), crop=(420, 120, 1500, 727))
            d.text((x, y), st, font=font(22), fill=FG)
        y += door_h + 10
    d.text((margin, y), "Cut-away: full-height kit walls, fade on and off / rooms, mask off", font=font(25), fill=GOLD)
    y += 40
    for i, name in enumerate(["t010_cutaway_fade", "t010_cutaway_off", "t010_rooms_cargo", "t010_rooms_corridor"]):
        fit(sheet, OUT / f"{name}.png", (margin + i * (cell + gap), y, margin + i * (cell + gap) + cell, y + cell * 9 // 16))
    y += cell * 9 // 16 + 20
    d.text((margin, y), "Frame time, 1920x1080 on this Mac, ms (average / p95 / p99). Budget: 8.3 average.", font=font(25), fill=GOLD)
    y += 40
    for name, avg, p95, p99 in table:
        d.text((margin, y), f"{name:<28}", font=font(24), fill=FG)
        d.text((margin + 560, y), f"{avg:5.2f} / {p95:5.2f} / {p99:5.2f}", font=font(24), fill=FG)
        y += 34
    sheet.save(OUT / "sheet.png", optimize=True)
    print("sheet", sheet.size)


if __name__ == "__main__":
    main()
