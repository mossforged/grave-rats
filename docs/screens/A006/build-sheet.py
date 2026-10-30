from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageChops
import json
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'docs/screens/A006'
SRC=ROOT/'assets/source/A006-slice'
FONT='/System/Library/Fonts/Supplemental/Arial.ttf'
def font(n): return ImageFont.truetype(FONT,n)
BG='#10181e'; FG='#e4e6e3'; MUT='#9faeb8'; GOLD='#e5b852'
frames=['camera_default.png','in_cover_readout.png','door_mid_bash.png','stalker_deck.png']
subjects=['Medbay / cool white + dust','Crouched behind tipped bed','Mid-bash door / seam light','Junction toward cargo / amber']
preferred=['01b','02b','03c','04b','05b','06c','07b','08']
# Overlay is an explicitly requested diagnostic, not a new paint-over.
for i,frame in enumerate(frames,1):
    ref=Image.open(ROOT/'docs/screens/T006'/frame).convert('RGB')
    id=preferred[i-1]
    art=Image.open(SRC/f'A006-{id}.png').convert('RGB')
    edges=ref.filter(ImageFilter.FIND_EDGES).convert('L').point(lambda p: 215 if p>10 else 0)
    mask=Image.new('L',ref.size);mask.paste(edges.crop((4,80,ref.width-4,900)),(4,80))
    mask=mask.filter(ImageFilter.MaxFilter(3)).resize(art.size,Image.Resampling.LANCZOS)
    overlay=Image.composite(Image.new('RGB',art.size,'#28e3ed'),art,mask)
    overlay.save(OUT/f'A006-{id}-overlay.png')
    (OUT/f'A006-{id}-overlay.prompt.md').write_text(f'Deterministic diagnostic for A006-{id}: original T006/{frame} FIND_EDGES luminance >10, HUD bands masked (y80:900), MaxFilter(3), normalized full-frame resize to paint-over dimensions, cyan edges alpha 215/255. No registration or warp. Built by build-sheet.py. User explicitly requested grey-box edge overlays when layout drifts.\n')
W=3072; margin=28; gap=22; cell=(W-2*margin-2*gap)//3
rh=660; kit_h=1100; H=170+4*rh+2*kit_h+90
sheet=Image.new('RGB',(W,H),BG); d=ImageDraw.Draw(sheet)
d.text((28,22),'GRAVE RATS / A006 / SLICE TARGET REVIEW',font=font(42),fill=FG)
d.text((28,78),'Eight selected targets | b/c = preferred correction | human look approval pending',font=font(25),fill=MUT)
for j,title in enumerate(['T006 / ORIGINAL GREY BOX','A006 / PREFERRED PAINT-OVER','SOURCE EDGES / CYAN OVER PAINT-OVER']):
    d.text((margin+j*(cell+gap),124),title,font=font(24),fill=GOLD)
def pastefit(path,box):
    im=Image.open(path).convert('RGB');im.thumbnail((box[2]-box[0],box[3]-box[1]),Image.Resampling.LANCZOS)
    sheet.paste(im,(box[0]+(box[2]-box[0]-im.width)//2,box[1]))
for row,(frame,subject) in enumerate(zip(frames,subjects)):
    y=170+row*rh; id=preferred[row]
    paths=[ROOT/'docs/screens/T006'/frame,SRC/f'A006-{id}.png',OUT/f'A006-{id}-overlay.png']
    labels=[frame,f'A006-{id} / {subject}','Full-frame normalization; no alignment warp']
    for col,(p,label) in enumerate(zip(paths,labels)):
        x=margin+col*(cell+gap)
        d.text((x,y),label,font=font(23),fill=FG)
        pastefit(p,(x,y+40,x+cell,y+604))
    d.text((margin,y+615),'Approximate geometry retained. See handoff for local drift; brightened dark regions are art direction, not visibility rules.',font=font(23),fill=MUT)
kit_labels=['A006-05b / Wall modules + corner + cap + fade','A006-06c / Door states + storage envelope','A006-07b / Props + cover height language','A006-08 / Material families + trim']
kw=(W-2*margin-gap)//2
for n,id in enumerate(preferred[4:]):
    x=margin+(n%2)*(kw+gap);y=170+4*rh+(n//2)*kit_h
    d.text((x,y),kit_labels[n],font=font(27),fill=GOLD)
    pastefit(SRC/f'A006-{id}.png',(x,y+48,x+kw,y+kit_h-28))
d.text((margin,H-65),'Dimensions in handoff control blockout. Kit drawings are concept references; no 3D, texture maps or game imports supplied.',font=font(25),fill=MUT)
sheet.save(OUT/'sheet.png')
(OUT/'sheet.prompt.md').write_text('Deterministic review layout, built by build-sheet.py. Four rows of original T006 frame / preferred A006 paint-over / diagnostic cyan grey-box edges. Two rows of selected kit and material boards. Labels and caveats are authored, not generated. No crop or registration warp.\n')
print(json.dumps({'sheet_size':sheet.size,'preferred':preferred,'overlays':4}))
