from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parents[3]
manifest = json.loads((ROOT / 'assets/source/meshy/input/A018/manifest.json').read_text())
OUT = Path(__file__).resolve().parent
font_path = '/System/Library/Fonts/Supplemental/Arial.ttf'
font = ImageFont.truetype(font_path, 24)
small = ImageFont.truetype(font_path, 19)
title = ImageFont.truetype(font_path, 36)
W, CELL, ROW, TOP = 2048, 488, 430, 150
sheet = Image.new('RGB', (W, TOP + ROW * 11 + 50), '#101920')
d = ImageDraw.Draw(sheet)
d.text((24, 20), 'GRAVE RATS / A018 / MESHY INPUT REVIEW', font=title, fill='#edf1f3')
d.text((24, 70), '11 objects / 44 generated views / no refusals / consistency limits: see auto-A018.md', font=font, fill='#e8bc52')
d.text((24, 106), 'Columns name requested camera; some attempts remain oblique or repeat a flank. Drafts, not approved Meshy inputs.', font=small, fill='#ccd6db')
notes = [
    'Pose broadly holds; surface and pack details vary.',
    '02b: grey-blue corrected. Helmet raised; flank/back details vary.',
    'Side/back revised. Figure hangs over end, not long edge; frame details vary.',
    'Crossed-arm pose holds; pack and small hardware vary.',
    'Side/back revised: shallow profile and metal rear now shown; contour varies.',
    'Pod arrangement/count not provably consistent; no true orthographic set.',
    'Front/side repeat flank; back is opposite flank. Missing end-on coverage.',
    'FAIL: front changes pose/anatomy; other views remain oblique.',
    '09b: tipped pose fixed. Cameras still oblique; rear invents details.',
    'FAIL: too upright; side appears to reattach arm. Front/back keep break.',
    'Seated pose holds; lean, hand positions and chest-panel details vary.',
]
count = 0
for i, obj in enumerate(manifest['objects']):
    y = TOP + i * ROW
    d.text((24, y), obj['id'] + ' / ' + obj['name'], font=font, fill='#e8bc52')
    d.text((24, y + 31), notes[i], font=small, fill='#e0e6e9')
    for j, view in enumerate(obj['views']):
        p = ROOT / manifest['root'] / (obj['name'] + '-' + view + '.png')
        prompt = p.with_suffix('.prompt.md')
        assert p.is_file() and prompt.is_file(), str(p)
        with Image.open(p) as im:
            im.verify()
        with Image.open(p) as im:
            thumb = ImageOps.contain(im.convert('RGB'), (CELL, 325), Image.Resampling.LANCZOS)
        x = 24 + j * 504
        sheet.paste(thumb, (x + (CELL - thumb.width)//2, y + 65 + (325-thumb.height)//2))
        d.text((x, y+394), obj['id'] + ' / ' + view, font=small, fill='#edf1f3')
        count += 1
sheet.save(OUT / 'sheet.png')
ImageOps.contain(sheet, (1280, 3100), Image.Resampling.LANCZOS).save(OUT / 'sheet-preview.jpg', quality=90)
print(f'Validated {count} PNGs and prompts. Sheet: {sheet.width} x {sheet.height}')
