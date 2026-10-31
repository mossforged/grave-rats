from PIL import Image, ImageDraw, ImageFont, ImageOps
from pathlib import Path
root=Path(__file__).resolve().parents[3]
src=root/'assets/source/A011-rogue-ai'
font='/System/Library/Fonts/Supplemental/Arial.ttf'
bold='/System/Library/Fonts/Supplemental/Arial Bold.ttf'
im=Image.new('RGB',(2400,3410),'#10191e'); d=ImageDraw.Draw(im)
def text(x,y,s,size=28,color='#e5e6df',heavy=False):
 d.text((x,y),s,font=ImageFont.truetype(bold if heavy else font,size),fill=color)
def panel(id,label,x,y,w,h):
 text(x,y,f'A011-{id} / {label}',28,'#a6e7c4',True)
 pic=Image.open(src/f'A011-{id}.png').convert('RGB')
 pic=ImageOps.contain(pic,(w,h-45))
 im.paste(pic,(x+(w-pic.width)//2,y+43+(h-45-pic.height)//2))
text(35,22,'GRAVE RATS / A011 / CUSTODIAN',46,heavy=True)
text(35,82,'Identity + three industrial bodies | JOHN: IDENTITY AND BUILD ORDER PENDING',28,'#a6e7c4')
panel('01','Identity + corporate voice',35,140,1150,815)
panel('02','Cutter / patrol / loader',1215,140,1150,815)
panel('03','Game-camera concept / tells revealed',35,980,1500,1045)
text(1570,1000,'RECOMMENDED FIRST BUILD',28,'#a6e7c4',True)
for i,s in enumerate(['Cutter + patrol drone.','Cover answers the cutter.','Spotlight announces the patrol.','Loader follows after turn /','charge timing is tested.','','MINT = ship AI identity','Ring / bars / twin lamps','give distinct visual tells.','','3/4 images are Meshy masters.','Other views are supporting','design interpretations.','','Concept art, not an in-engine','capture or calibrated scale.']):
 text(1570,1050+i*42,s,28)
# Eight input views, two rows of four at review scale.
for row,items in enumerate([[('04','Drone 3/4'),('05','Drone front'),('06b','Drone side / revised'),('07','Drone back')],[('08','Loader 3/4'),('09','Loader front'),('10b','Loader side / revised'),('11','Loader back')]]):
 for col,(id,label) in enumerate(items):
  panel(id,label,35+col*590,2045+row*450,560,430)
text(35,2965,'INITIAL SIDE ATTEMPTS / retained for provenance; use lettered revisions above',28,'#9eabb0')
panel('06','Initial drone oblique',35,3010,560,370)
panel('10','Initial loader oblique',625,3010,560,370)
im.save(root/'docs/screens/A011/sheet.png')
