#!/usr/bin/env python3
"""T012 sheet: docs/screens/T012/sheet.png, the packet's frames in order. Run after the captures:
python3 tools/t012_sheet.py
"""
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/screens/T012"
FONT = "/System/Library/Fonts/Supplemental/Arial.ttf"
SHOTS = [("carry_small", "Carrying small"), ("carry_medium", "Carrying medium"), ("carry_heavy", "Carrying heavy"),
         ("salvage_in_the_dark", "Rims with the light off"), ("hold_deposit", "Hold deposit"), ("tier1_announcement", "Tier 1"),
         ("tier2_lights_before", "Tier 2: before"), ("tier2_lights_flicker", "Tier 2: flicker"), ("tier2_lights_failed", "Tier 2: failed"),
         ("prize_alarm_1_grab", "Prize alarm 1"), ("prize_alarm_2_pulse", "Prize alarm 2"), ("prize_alarm_3_converge", "Prize alarm 3"),
         ("oxygen_zero", "Oxygen at zero"), ("leaving", "Leaving"), ("left", "Left")]
CELL, H, GAP, TOP = 640, 360, 8, 26

rows = (len(SHOTS) + 2) // 3
sheet = Image.new("RGB", (CELL * 3 + GAP * 4, rows * (H + TOP + GAP) + 50), "#10181e")
d = ImageDraw.Draw(sheet)
ft = json.loads((OUT / "frametime.json").read_text())
d.text((GAP, 10), "T012 frame time, three stalkers: %.2f ms avg / %.2f ms p95, %s" % (ft["frame_ms_avg"], ft["frame_ms_p95"], ft["resolution"]),
       font=ImageFont.truetype(FONT, 22), fill="#e5b852")
small = ImageFont.truetype(FONT, 18)
for i, (name, label) in enumerate(SHOTS):
    x = GAP + (i % 3) * (CELL + GAP)
    y = 50 + (i // 3) * (H + TOP + GAP)
    d.text((x, y + 2), label, font=small, fill="#e4e6e3")
    sheet.paste(Image.open(OUT / (name + ".png")).convert("RGB").resize((CELL, H), Image.Resampling.LANCZOS), (x, y + TOP))
sheet.save(OUT / "sheet.png")
