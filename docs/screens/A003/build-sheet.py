from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
font = '/System/Library/Fonts/Supplemental/Arial Narrow Bold.ttf'
title = ImageFont.truetype(font, 42)
label = ImageFont.truetype(font, 30)
small = ImageFont.truetype(font, 24)
sheet = Image.new('RGB', (2000, 1910), '#10171b')
d = ImageDraw.Draw(sheet)
d.text((24, 18), 'GRAVE RATS / A003 / HUD + COMPANY SCREENS', font=title, fill='#eeeae0')
d.text((24, 72), 'Six 1920 x 1080 concepts | John picks HUD + tone | recommendation: A003-03 Watch strip', font=small, fill='#adb9bd')
labels = ['A003-01 / Minimal diegetic', 'A003-02 / Suit OS', 'A003-03 / Watch strip - recommended', 'A003-04 / Contract briefing', 'A003-05 / Shift payslip', 'A003-06 / Death bill']
for i, text in enumerate(labels):
    x = 24 + (i % 2) * 988
    y = 124 + (i // 2) * 590
    d.text((x, y), text, font=label, fill='#dec05f' if i == 2 else '#eeeae0')
    im = Image.open(ROOT / 'assets/source/A003-ui' / f'A003-{i+1:02}.png').convert('RGB')
    assert im.size == (1920, 1080)
    sheet.paste(im.resize((960, 540), Image.Resampling.LANCZOS), (x, y + 38))
sheet.save(OUT / 'sheet.png')
