#!/usr/bin/env python3
"""T016 sheets, after the captures and tools/t016_aa_bench.py: docs/screens/T016/sheet.png (the packet's
frames) and aa_sheet.png (the four modes cropped on a wall top and a light strip, with frame times).
python3 tools/t016_sheet.py
"""
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/screens/T016"
FONT = "/System/Library/Fonts/Supplemental/Arial.ttf"
SHOTS = [("t016_medbay_room", "Medbay dressed, no mask"), ("t016_medbay_01b_off", "The A006-01b stand, no mask"),
         ("t016_medbay_01b_play", "The A006-01b stand, in play"), ("t016_salvage_small", "Small"),
         ("t016_salvage_medium", "Medium"), ("t016_salvage_heavy", "Heavy and the black box"),
         ("t016_salvage_dark", "Heavy, light off: rings carry it"), ("t016_carry_medium", "Carrying medium"),
         ("t016_carry_heavy", "Carrying heavy"), ("t016_bed_tipping", "Bed tipping (falls west, shoved from the east)"),
         ("t016_bed_tipped_your_side", "Tipped, from your side"), ("t016_bed_tipped_shield_side", "The room's overturned bed, from its shield side"),
         ("t016_bed_plate_closeup", "Not a game view: low camera and lamp on the plated face"), ("t016_panel_display", "F1, Display")]
CELL, H, GAP, TOP = 800, 397, 8, 26
small = ImageFont.truetype(FONT, 18)

rows = (len(SHOTS) + 1) // 2
sheet = Image.new("RGB", (CELL * 2 + GAP * 3, rows * (H + TOP + GAP) + GAP), "#10181e")
d = ImageDraw.Draw(sheet)
for i, (name, label) in enumerate(SHOTS):
    x = GAP + (i % 2) * (CELL + GAP)
    y = GAP + (i // 2) * (H + TOP + GAP)
    d.text((x, y + 2), label, font=small, fill="#d8e2e6")
    sheet.paste(Image.open(OUT / (name + ".png")).convert("RGB").resize((CELL, H), Image.LANCZOS), (x, y + TOP))
sheet.save(OUT / "sheet.png")

MODES = [("msaa2", "MSAA 2x"), ("msaa4", "MSAA 4x"), ("msaa2_smaa", "MSAA 2x + SMAA"), ("msaa2_fxaa", "MSAA 2x + FXAA")]
CROP = (880, 310, 1200, 430)
ZOOM = 3
times = json.loads((OUT / "frame_times.json").read_text())["summary"]
w, h = (CROP[2] - CROP[0]) * ZOOM, (CROP[3] - CROP[1]) * ZOOM
aa = Image.new("RGB", (w * 2 + GAP * 3, (h + TOP * 2 + GAP) * 3 + GAP), "#10181e")
d = ImageDraw.Draw(aa)
for i, (mode, label) in enumerate(MODES):
    x = GAP + (i % 2) * (w + GAP)
    y = GAP + (i // 2) * (h + TOP * 2 + GAP)
    d.text((x, y + 2), label, font=small, fill="#d8e2e6")
    line = "   ".join("%s %.2f / %.2f" % (deck.replace("_deck", ""), times[deck][mode]["avg"], times[deck][mode]["p95"]) for deck in times)
    d.text((x, y + TOP), line + " ms", font=small, fill="#a6e7c4")
    crop = Image.open(OUT / ("t016_aa_%s.png" % mode)).convert("RGB").crop(CROP)
    aa.paste(crop.resize((w, h), Image.NEAREST), (x, y + TOP * 2))
x, y = GAP, GAP + 2 * (h + TOP * 2 + GAP)
d.text((x, y + 2), "MSAA 2x again, same run: judge the wall top against this", font=small, fill="#d8e2e6")
crop = Image.open(OUT / "t016_aa_msaa2_again.png").convert("RGB").crop(CROP)
aa.paste(crop.resize((w, h), Image.NEAREST), (x, y + TOP * 2))
aa.save(OUT / "aa_sheet.png")
