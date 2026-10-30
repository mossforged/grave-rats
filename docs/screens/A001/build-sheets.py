"""Rebuild deterministic labelled review sheets; no source art is altered."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parents[3]
SRC = ROOT / 'assets/source/A001-crew-threat'
OUT = Path(__file__).resolve().parent
FONT = '/System/Library/Fonts/Supplemental/Arial.ttf'
TITLE = ImageFont.truetype(FONT, 42)
LABEL = ImageFont.truetype(FONT, 27)
SMALL = ImageFont.truetype(FONT, 21)
NAMES = ['Orange hauler', 'Yellow cutter', 'Teal heavy rig', 'Red medic-scrounger',
         'Cobalt drone tech', 'Violet shipbreaker', 'Overhead / neutral deck',
         'Overhead / ship lighting', 'Rogue ship AI', 'Security robots',
         'Acid stalker / medbay', 'Suit-wearing horror', 'Rival pirate crew',
         'Wildcard / scrap predator', 'Medbay-corridor-cargo key art']

def canvas(size, title, subtitle):
    im = Image.new('RGB', size, '#11171c')
    d = ImageDraw.Draw(im)
    d.text((30, 22), title, font=TITLE, fill='#f1eee6')
    d.text((30, 78), subtitle, font=SMALL, fill='#aebbc5')
    return im

def panel(out, num, box, small=False):
    x,y,w,h = box
    d = ImageDraw.Draw(out)
    font = SMALL if small else LABEL
    d.text((x+14,y+8), f'A001-{num:02}  {NAMES[num-1]}', font=font, fill='#f1eee6')
    with Image.open(SRC / f'A001-{num:02}.png') as src:
        img = ImageOps.contain(src.convert('RGB'), (w-24,h-56), Image.Resampling.LANCZOS)
        out.paste(img, (x+(w-img.width)//2, y+48+(h-56-img.height)//2))

crew = canvas((1800,1880), 'GRAVE RATS / A001 / CREW', '01-06: front three-quarter concepts   |   07-08: all six from overhead   |   Exploration, pending John')
for n in range(1,7):
    panel(crew,n,(((n-1)%3)*600,120+((n-1)//3)*550,600,550))
for n in (7,8):
    panel(crew,n,((n-7)*900,1230,900,620))
crew.save(OUT/'crew.png')

threats = canvas((1800,3000), 'GRAVE RATS / A001 / THREATS + KEY ART', '09-14: six threat directions   |   15: crew in the reference room layout   |   Exploration, pending John')
for n in range(9,15):
    panel(threats,n,(((n-9)%2)*900,120+((n-9)//2)*620,900,620))
panel(threats,15,(0,1990,1800,980))
threats.save(OUT/'threats.png')

summary = canvas((2100,1260), 'GRAVE RATS / A001 / ALL DIRECTIONS', '15 ImageGen concepts / labels are asset IDs / see crew.png and threats.png for larger review')
for n in range(1,16):
    panel(summary,n,(((n-1)%5)*420,120+((n-1)//5)*380,420,380),small=True)
summary.save(OUT/'sheet.png')
print('Wrote crew.png (1800x1880), threats.png (1800x3000), sheet.png (2100x1260)')
