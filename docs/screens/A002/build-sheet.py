from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageOps
ROOT=Path(__file__).resolve().parents[3]
SOURCE=ROOT/'assets/source/A002-slice-env'
OUT=ROOT/'docs/screens/A002'
font_path='/System/Library/Fonts/Supplemental/Arial.ttf'
def font(size): return ImageFont.truetype(font_path,size)
items=[('01','Corridor + cargo walls'),('02','Medbay walls'),('03','Doors + thresholds'),('04','Deck tile family'),('05','Medbay props'),('06','Cargo props'),('07','Cover height study'),('08b','Clean signage / preferred revision'),('09b','Lighting / preferred revision')]
sheet=Image.new('RGB',(3072,2360),'#11181d')
d=ImageDraw.Draw(sheet)
d.text((30,22),'GRAVE RATS / A002 / SLICE ENVIRONMENT CONCEPTS',font=font(48),fill='#f0eee6')
d.text((32,84),'9 selected sheets | b = preferred revision | proportions provisional pending T002 | John picks before stage 3',font=font(25),fill='#acbbc4')
for n,(suffix,title) in enumerate(items):
 x=24+(n%3)*1024;y=145+(n//3)*730
 d.text((x,y),f'A002-{suffix}  {title}',font=font(28),fill='#f0eee6')
 with Image.open(SOURCE/f'A002-{suffix}.png') as im:
  im=ImageOps.contain(im.convert('RGB'),(992,662),Image.Resampling.LANCZOS)
  sheet.paste(im,(x+(992-im.width)//2,y+46+(662-im.height)//2))
sheet.save(OUT/'sheet.png')
# Verify every persisted image and its exact submitted prompt; no game files needed.
images=sorted(SOURCE.glob('*.png'))
assert len(images)==11, len(images)
for p in images:
 assert p.with_suffix('.prompt.md').is_file(),p
 with Image.open(p) as im:
  im.verify()
 with Image.open(p) as im: print(f'{p.name}: {im.width}x{im.height} {im.mode}; prompt present')
print('sheet.png: 3072x2360; nine labelled selected sheets')
