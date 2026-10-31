"""Assemble generated plates into labeled review artifacts; no generated art is repainted."""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / 'assets/source/A015-bestiary'
OUT = ROOT / 'docs/screens/A015'
ROWS = json.loads((SOURCE / 'manifest.json').read_text())
TOP = {'A015-02', 'A015-04', 'A015-07', 'A015-08', 'A015-15'}
BG, FG, MUTED, GOLD = '#10191f', '#e6ecee', '#a9bec8', '#edc466'
def font(n, bold=False):
    return ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial'+(' Bold' if bold else '')+'.ttf', n)
def label(draw, xy, text, size=24, color=FG, bold=False):
    draw.text(xy, text, font=font(size,bold), fill=color)
def fitpaste(canvas, img, box):
    im=ImageOps.contain(img, (box[2]-box[0],box[3]-box[1]), Image.Resampling.LANCZOS)
    canvas.paste(im,(box[0]+(box[2]-box[0]-im.width)//2,box[1]+(box[3]-box[1]-im.height)//2))
def camera(row):
    im=Image.open(SOURCE/(row['id']+'.png')).convert('RGB')
    # All generated plates put the in-room game-camera panel at upper right.
    return im.crop((int(im.width*.58),0,im.width,int(im.height*.56)))

# Full-plate contact sheet, 3 columns; labels are deterministic and authoritative.
sheet=Image.new('RGB',(2220,3510),BG); d=ImageDraw.Draw(sheet)
label(d,(28,22),'GRAVE RATS / A015 / THREAT BESTIARY',44,bold=True)
label(d,(28,78),'18 concepts | GOLD = five recommended builds | John selects before implementation',26,GOLD)
label(d,(28,115),'Hero + in-room oblique view + tell strip per plate. Concept images; camera and scale are illustrative.',23,MUTED)
for i,r in enumerate(ROWS):
    x=24+(i%3)*732; y=172+(i//3)*548
    c=GOLD if r['id'] in TOP else FG
    label(d,(x,y),r['id']+' / '+r['name'],25,c,True)
    fitpaste(sheet,Image.open(SOURCE/(r['id']+'.png')),(x,y+42,x+708,y+514))
    label(d,(x,y+518),r['category'].upper()+' | '+r['build'],19,MUTED)
label(d,(28,3470),'A015-00 matrix gives role / light / tell / counterplay / build / ship. Human approval gate remains open.',22,GOLD)
sheet.save(OUT/'sheet.png')

# A015-00: each threat gets its camera thumbnail plus six explicit, unwrapped lines.
matrix=Image.new('RGB',(2200,4490),BG); d=ImageDraw.Draw(matrix)
label(d,(30,20),'A015-00 / THREAT MATRIX',44,bold=True)
label(d,(30,77),'GOLD / TOP FIVE = recommendation only. Every row is a candidate; no roster or build approval implied.',25,GOLD)
label(d,(30,118),'Camera thumbnails are cropped concept scenes, not engine captures or measured gameplay-size tests.',23,MUTED)
for i,r in enumerate(ROWS):
    y=175+i*236; c=GOLD if r['id'] in TOP else FG
    d.rectangle((24,y,2176,y+225),fill='#1b2932' if i%2==0 else '#142129',outline=c if r['id'] in TOP else '#344550',width=2)
    fitpaste(matrix,camera(r),(34,y+8,340,y+216))
    label(d,(362,y+8),r['id']+' / '+r['name']+(' / TOP FIVE' if r['id'] in TOP else ''),28,c,True)
    for j,(key,title) in enumerate([('role','ROLE'),('light','LIGHT'),('tell','TELL'),('counter','COUNTER'),('build','BUILD'),('ship','SHIP')]):
        text=title+': '+r[key]
        assert d.textbbox((0,0),text,font=font(24))[2] < 1780, text
        label(d,(362,y+49+j*27),text,24,FG if j!=4 else MUTED)
label(d,(30,4440),'Build routes are proposals. See auto-A015.md for reuse, new systems and visual limitations.',24,GOLD)
matrix.save(SOURCE/'A015-00.png')

headers=['ID / threat','Role','Light relationship','Tell','Counterplay','Build route','Ship','New work']
md=['# A015-00 / Threat matrix','','Gold TOP FIVE entries are recommendations awaiting John. Image matrix: A015-00.png.','', '| '+' | '.join(headers)+' |','| '+' | '.join(['---']*len(headers))+' |']
for r in ROWS:
    md.append('| '+' | '.join([r['id']+' '+r['name']+(' **TOP FIVE**' if r['id'] in TOP else ''),r['role'],r['light'],r['tell'],r['counter'],r['build'],r['ship'],r['systems']])+' |')
(SOURCE/'A015-00.md').write_text('\n'.join(md)+'\n')
(SOURCE/'A015-00.prompt.md').write_text('# A015-00 / assembly specification\n\nDeterministic Pillow assembly; no image-generation call. Use manifest.json and the upper-right camera panels of A015-01 through A015-18. Place one camera thumbnail per row, followed by six lines: role, light relationship, tell, counterplay, build route and ship. Mark 02, 04, 07, 08 and 15 TOP FIVE in gold. Full text companion: A015-00.md. Rebuild with docs/screens/A015/build-review.py.\n')
(OUT/'sheet.prompt.md').write_text('# A015 / contact sheet assembly specification\n\nDeterministic Pillow assembly of the 18 unmodified concept plates, three columns by six rows, 708 x 472 pixel plate previews. Label each ID and name, category and build route. Highlight five recommendations in gold. Canvas 2220 x 3510. Rebuild with build-review.py. The packet specifies no fixed review dimensions.\n')

checks=[]
for r in ROWS:
    p=SOURCE/(r['id']+'.png')
    with Image.open(p) as im:
        im.verify()
    with Image.open(p) as im:
        checks.append({'id':r['id'],'size':list(im.size),'prompt_present':(SOURCE/(r['id']+'.prompt.md')).is_file()})
(OUT/'validation.json').write_text(json.dumps({'threats':checks,'count':len(checks),'top_five':sorted(TOP),'matrix_size':list(matrix.size),'contact_size':list(sheet.size),'refusals':0,'review':'Concept visual review; no engine scale or behavior validation claimed.'},indent=2)+'\n')
print(json.dumps({'threats':len(checks),'matrix':matrix.size,'contact':sheet.size,'all_prompts':all(c['prompt_present'] for c in checks)}))
