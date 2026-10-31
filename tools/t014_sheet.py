#!/usr/bin/env python3
"""T014 sheet: docs/screens/T014/sheet.png, the packet's frames in order. Run after the captures:
python3 tools/t014_sheet.py
"""
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/screens/T014"
FONT = "/System/Library/Fonts/Supplemental/Arial.ttf"
SHOTS = [("t014_briefing", "Briefing (second shift, hazards from the first)"), ("t014_decline_confirm", "Decline, the confirm line"),
         ("t014_payslip_good", "Payslip, good shift"), ("t014_payslip_bad", "Payslip, bad shift (balance due)"),
         ("t014_payslip_long", "Payslip, full ship (scrolls)"), ("t014_death_bill", "Death bill"),
         ("t014_termination", "Termination notice"), ("t014_quota_hud", "Quota on the HUD (top right)")]
CELL, H, GAP, TOP = 800, 450, 8, 26

rows = (len(SHOTS) + 1) // 2
sheet = Image.new("RGB", (CELL * 2 + GAP * 3, rows * (H + TOP + GAP) + 50), "#10181e")
d = ImageDraw.Draw(sheet)
ft = json.loads((OUT / "frametime.json").read_text())
d.text((GAP, 10), "T014 frame time, three stalkers, quota plate on: %.2f ms avg / %.2f ms p95, %s" % (ft["frame_ms_avg"], ft["frame_ms_p95"], ft["resolution"]),
       font=ImageFont.truetype(FONT, 22), fill="#e5b852")
small = ImageFont.truetype(FONT, 18)
for i, (name, label) in enumerate(SHOTS):
    x = GAP + (i % 2) * (CELL + GAP)
    y = 50 + (i // 2) * (H + TOP + GAP)
    d.text((x, y), label, font=small, fill="#d8d6cc")
    sheet.paste(Image.open(OUT / (name + ".png")).convert("RGB").resize((CELL, H), Image.LANCZOS), (x, y + TOP))
sheet.save(OUT / "sheet.png")
