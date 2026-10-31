"""Assemble review documents; source atlases remain unmodified."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import json

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / 'assets/source/A013-room-graphics'
OUT = Path(__file__).resolve().parent
FONT = '/System/Library/Fonts/Helvetica.ttc'
def font(size):
    return ImageFont.truetype(FONT, size)

names = ['Engineering', 'Bio lab', 'Bridge', 'Crew quarters', 'Mess', 'Remnant overlays / revised']
ids = ['A013-01', 'A013-02', 'A013-03', 'A013-04', 'A013-05', 'A013-06b']
bg, ink, yellow = '#10191c', '#f1ecdc', '#f0c637'
sheet = Image.new('RGB', (3200, 3500), bg)
d = ImageDraw.Draw(sheet)
d.text((40, 26), 'GRAVE RATS / A013 / FIVE ROOMS + RECOVERY OVERLAYS', font=font(44), fill=ink)
d.text((40, 88), 'SOURCE DECAL ATLASES / JOHN: COPY + LOOK APPROVAL PENDING', font=font(28), fill=yellow)
for i, (asset, name) in enumerate(zip(ids, names)):
    x, y = 40 + (i % 2) * 1584, 160 + (i // 2) * 1100
    d.text((x, y), f'{asset} / {name}', font=font(30), fill=yellow)
    im = Image.open(SOURCE / f'{asset}.png').convert('RGB')
    assert im.size == (1536, 1024), (asset, im.size)
    sheet.paste(im, (x, y + 48))
d.text((40, 3470), 'Opaque plain-gray source sheets: cut individual graphics before import. Readability previews: readability.png', font=font(22), fill=ink)
sheet.save(OUT / 'sheet.png')

# Crops are review-only and do not create additional source-asset IDs.
examples = [
    ('A013-01', 'Room plate', (1100, 712, 1510, 982), .5),
    ('A013-01', 'Radiation poster', (1075, 47, 1515, 695), .5),
    ('A013-02', 'Biohazard notice', (38, 378, 1500, 674), .5),
    ('A013-02', 'Expired certificate', (35, 680, 863, 999), .5),
    ('A013-03', 'Captain poster', (580, 24, 1115, 596), .5),
    ('A013-03', 'Navigation table / floor', (20, 610, 1517, 990), .87),
    ('A013-04', 'Quiet-hours sign', (721, 587, 1209, 977), .5),
    ('A013-04', 'Bunk name tag', (1072, 105, 1520, 534), .5),
    ('A013-05', 'Nutrition poster', (589, 91, 1055, 678), .5),
    ('A013-05', 'Menu and prices', (20, 91, 578, 677), .5),
    ('A013-06b', 'Priority sticker', (789, 29, 1513, 263), .5),
    ('A013-06b', 'Biological exclusion tape', (28, 547, 1511, 724), .5),
]
review = Image.new('RGB', (1800, 3000), bg)
r = ImageDraw.Draw(review)
r.text((32, 25), 'A013 / DECAL READABILITY STRESS PREVIEW', font=font(36), fill=ink)
r.text((32, 77), 'Each crop: 256 px wide front-on, then 60-degree pitch approximation.', font=font(24), fill=yellow)
r.text((32, 112), 'Wall height x 0.50; floor height x 0.87. Graphic proxy only; game lighting and distance untested.', font=font(22), fill=ink)
for i, (asset, label, box, scale) in enumerate(examples):
    x, y = 32 + (i % 2) * 890, 174 + (i // 2) * 460
    r.text((x, y), f'{asset} / {label}', font=font(24), fill=yellow)
    im = Image.open(SOURCE / f'{asset}.png').crop(box).convert('RGB')
    h = round(im.height * 256 / im.width)
    front = im.resize((256, h), Image.Resampling.LANCZOS)
    compressed = front.resize((256, round(h * scale)), Image.Resampling.LANCZOS)
    r.text((x, y + 35), 'Front-on / 256 px', font=font(19), fill=ink)
    r.text((x + 290, y + 35), 'Foreshortened / 256 px', font=font(19), fill=ink)
    review.paste(front, (x, y + 65))
    review.paste(compressed, (x + 290, y + 65))
review.save(OUT / 'readability.png')
(OUT / 'readability-crops.json').write_text(json.dumps(examples, indent=2) + '\n')
print('Wrote sheet.png and readability.png')
