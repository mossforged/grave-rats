#!/usr/bin/env python3
"""T015 sheet: docs/screens/T015/sheet.png, the packet's frames in order. Run after the captures:
python3 tools/t015_sheet.py
"""
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/screens/T015"
FONT = "/System/Library/Fonts/Supplemental/Arial.ttf"
SHOTS = [("t015_lens_dormant", "Dormant: lens dim"), ("t015_lens_awake", "Awake: lens bright"),
         ("t015_cutter_sweep", "Cutter sweeping"), ("t015_cutter_warmup", "Cutter on you: line and ring filling"),
         ("t015_cutter_beam", "The burn"), ("t015_cutter_stopped_by_tall", "Line stopped by tall cover"),
         ("t015_cutter_over_low", "Low cover: the line goes over, the ring fills"), ("t015_drone_patrol", "Drone patrol: spotlight"),
         ("t015_drone_bars_1", "Drone calling: bar 1"), ("t015_drone_bars_2", "Bar 2"),
         ("t015_drone_bars_3", "Bar 3"), ("t015_drone_call_complete", "Call complete: a cutter comes online"),
         ("t015_death_bill", "Death bill from the cutter"), ("t015_payslip", "Payslip with the CUSTODIAN line")]
CELL, H, GAP, TOP = 800, 450, 8, 26

rows = (len(SHOTS) + 1) // 2
sheet = Image.new("RGB", (CELL * 2 + GAP * 3, rows * (H + TOP + GAP) + 50), "#10181e")
d = ImageDraw.Draw(sheet)
ft = json.loads((OUT / "frametime.json").read_text())
d.text((GAP, 10), "T015 frame time, CUSTODIAN awake, three stalkers: %.2f ms avg / %.2f ms p95, %s" % (ft["frame_ms_avg"], ft["frame_ms_p95"], ft["resolution"]),
       font=ImageFont.truetype(FONT, 22), fill="#a6e7c4")
small = ImageFont.truetype(FONT, 18)
for i, (name, label) in enumerate(SHOTS):
    x = GAP + (i % 2) * (CELL + GAP)
    y = 50 + (i // 2) * (H + TOP + GAP)
    d.text((x, y), label, font=small, fill="#d8d6cc")
    sheet.paste(Image.open(OUT / (name + ".png")).convert("RGB").resize((CELL, H), Image.LANCZOS), (x, y + TOP))
sheet.save(OUT / "sheet.png")
