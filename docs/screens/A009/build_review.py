"""Compose requested review sheets; no generated character content is repainted."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'docs/screens/A009'
ART = ROOT / 'assets/source/A009-rivals'
MESH = ROOT / 'assets/source/meshy/input'
BG = '#10181e'
INK = '#e8edf0'
MUTED = '#a4b3bf'
ACCENT = '#81bccd'

def font(size, bold=False):
    return ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial' + (' Bold' if bold else '') + '.ttf', size)

def text(im, xy, value, size=24, color=INK, bold=False):
    ImageDraw.Draw(im).text(xy, value, font=font(size, bold), fill=color)

def fit(im, path, box):
    src = Image.open(path).convert('RGB')
    src.thumbnail((box[2]-box[0], box[3]-box[1]), Image.Resampling.LANCZOS)
    im.paste(src, (box[0]+(box[2]-box[0]-src.width)//2, box[1]+(box[3]-box[1]-src.height)//2))

for suffix in ('03', '03b'):
    im = Image.new('RGB', (1840, 960), BG)
    text(im, (32, 24), f'A009-{suffix} / PRIOR CLAIM / GAME CAMERA READ', 34, bold=True)
    text(im, (32, 76), 'Leader / heavy / scout / tech / orange hauler. Empty-handed concept comparison.', 24, MUTED)
    text(im, (32, 122), 'GAME-SIZE PROXY / leader approximately 96 px tall', 23, ACCENT, True)
    text(im, (32, 334), 'EXACT 4x / nearest-neighbour enlargement of the SAME downsampled pixels', 24, ACCENT, True)
    src = Image.open(OUT / f'A009-{suffix}-render.png').convert('RGB')
    # One common resize for the entire row preserves relative character scale.
    crop = src.crop((25, 195, 1745, 740) if suffix == '03b' else (25, 80, 1745, 810))
    small = crop.resize((393, 125) if suffix == '03b' else (291, 123), Image.Resampling.LANCZOS)
    im.paste(small, (48, 178))
    large = small.resize((small.width * 4, small.height * 4), Image.Resampling.NEAREST)
    im.paste(large, (48, 386))
    text(im, (32, 912), '96 px is the A005 review proxy, not a measured engine capture. Camera angle is illustrative.', 22, MUTED)
    im.save(ART / f'A009-{suffix}.png')

sheet = Image.new('RGB', (2048, 2480), BG)
text(sheet, (32, 24), 'GRAVE RATS / A009 / RIVAL CREW REVIEW', 42, bold=True)
text(sheet, (32, 80), 'PRIOR CLAIM - better funded, worse people. Proposed look; John approval pending.', 26, MUTED)
text(sheet, (32, 132), 'A009-01 / Outfit identity + sponsor + three taglines', 25, ACCENT, True)
text(sheet, (1050, 132), 'A009-02 / Four matching crew roles / front', 25, ACCENT, True)
fit(sheet, ART/'A009-01.png', (32, 174, 1008, 825))
fit(sheet, ART/'A009-02.png', (1040, 174, 2016, 825))
text(sheet, (32, 854), 'A009-03b / Preferred steep-camera revision / 1x + exact 4x shown at native sheet size', 26, ACCENT, True)
sheet.paste(Image.open(ART/'A009-03b.png'), (104, 900))
text(sheet, (32, 1884), 'A009 / Squad leader Meshy inputs / A008 open-hand A-pose / light-grey A007 studio', 27, ACCENT, True)
for i, (view, label) in enumerate([('front', 'FRONT / authority'), ('side', 'SIDE / near-side at ~60 degrees'), ('back', 'BACK / pack construction'), ('34', '3/4 / form cross-check')]):
    x = 32 + i * 504
    text(sheet, (x, 1940), label, 22, INK, True)
    fit(sheet, MESH/f'rival-apose-{view}.png', (x, 1982, x+472, 2454))
sheet.save(OUT/'sheet.png')
print('Built A009-03.png, A009-03b.png and sheet.png')
