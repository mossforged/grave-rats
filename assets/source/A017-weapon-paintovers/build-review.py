"""Rebuild A017 review sheet from preserved inputs, images and generation records."""
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
FONT = '/System/Library/Fonts/Supplemental/Arial.ttf'
BOLD = '/System/Library/Fonts/Supplemental/Arial Bold.ttf'
def font(n, bold=False):
    return ImageFont.truetype(BOLD if bold else FONT, n)
def fit(canvas, path, box):
    im = Image.open(path).convert('RGB')
    thumb = ImageOps.contain(im, (box[2]-box[0], box[3]-box[1]), Image.Resampling.LANCZOS)
    canvas.paste(thumb, (box[0]+(box[2]-box[0]-thumb.width)//2, box[1]+(box[3]-box[1]-thumb.height)//2))

rows = json.loads((OUT/'generation-results.json').read_text())
sheet = Image.new('RGB', (2000, 180+7*500), '#e4dfd5')
d = ImageDraw.Draw(sheet)
d.text((40,25), 'GRAVE RATS / A017 / MODEL PAINTOVERS', font=font(43,True), fill='#252b2e')
d.text((40,85), 'LEFT: lead blockout   |   RIGHT: generated sheet or explicit refusal   |   Look selection pending John', font=font(26), fill='#42484a')
d.text((40,126), 'Lengths follow the lead model sheet. Camera insets are concept studies, not engine captures.', font=font(24), fill='#42484a')
for i,row in enumerate(rows):
    y=180+i*500
    d.rectangle((20,y,1980,y+482),fill='#f4f0e9')
    d.text((40,y+10), row['id']+' / '+row['name'].upper()+' / '+row['length_m']+' m',font=font(29,True),fill='#242b2d')
    fit(sheet, ROOT/row['input'], (40,y+65,880,y+457))
    d.line((905,y+65,905,y+457),fill='#b7ada0',width=2)
    image_path = OUT/(row['id']+'.png')
    if row['status']=='generated' and image_path.exists():
        fit(sheet,image_path,(930,y+60,1960,y+462))
    else:
        d.text((965,y+150),'REFUSED — SKIPPED',font=font(34,True),fill='#8a4d37')
        d.text((965,y+210),'moderation_blocked / violence',font=font(26),fill='#5b514b')
        d.text((965,y+255),'No substitute artwork. No rewording or retry.',font=font(25),fill='#5b514b')
        d.text((965,y+300),'Exact tool error: generation-results.json / handoff',font=font(23),fill='#5b514b')
dest=ROOT/'docs/screens/A017/sheet.png'
sheet.save(dest)
print(dest, sheet.size)
