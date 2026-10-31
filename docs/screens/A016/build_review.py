from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import json,textwrap
ROOT=Path(__file__).resolve().parents[3]
SRC=ROOT/'assets/source/A016-arsenal'
OUT=Path(__file__).resolve().parent
D=json.loads((SRC/'manifest.json').read_text())
BG='#10191f'; PANEL='#202c33'; FG='#e5e7df'; MUT='#a8bac0'; GOLD='#e7ad49'
font_path='/System/Library/Fonts/Supplemental/Arial.ttf'
def f(s): return ImageFont.truetype(font_path,s)
def txt(draw,xy,text,size=20,fill=FG):draw.text(xy,text,font=f(size),fill=fill)
def wrap(draw,x,y,s,width=85,size=18,fill=MUT):
 for line in textwrap.wrap(s,width):txt(draw,(x,y),line,size,fill);y+=size+5
 return y
# Crop the camera study out of the generated card, then make an explicit 96px-high proxy.
def thumb(item):
 p=SRC/(item['id']+'.png')
 if not p.exists():return None
 im=Image.open(p).convert('RGB');w,h=im.size
 bounds={'A016-02':(.65,.19,.99,.90),'A016-18':(.635,.16,.99,.89)}.get(item['id'],(.65,.19,.99,.91))
 return im.crop(tuple(int(v*(w if j%2==0 else h)) for j,v in enumerate(bounds)))
# Contact sheet: every ID has a tile; refused IDs remain labeled empty slots, never stand-in artwork.
sheet=Image.new('RGB',(2100,2200),BG);d=ImageDraw.Draw(sheet)
txt(d,(36,24),'GRAVE RATS / A016 / ARSENAL REVIEW',42)
txt(d,(36,80),'18 proposals / amber star = first-arsenal recommendation / John selects before modelling',24,MUT)
txt(d,(36,118),'Refused images are explicitly skipped. Matrix: assets/source/A016-arsenal/A016-00.png',22,MUT)
for idx,it in enumerate(D['items']):
 x=30+(idx%3)*690;y=176+(idx//3)*332
 d.rectangle((x,y,x+672,y+314),fill=PANEL)
 label=it['id']+' / '+it['name']+(' *' if it['top_six'] else '')
 txt(d,(x+12,y+9),label,24,GOLD if it['top_six'] else FG)
 p=SRC/(it['id']+'.png')
 if p.exists():
  im=Image.open(p).convert('RGB');im.thumbnail((648,224));sheet.paste(im,(x+12,y+47))
 else:
  txt(d,(x+18,y+112),'IMAGE REFUSED / SKIPPED',25,MUT)
  txt(d,(x+18,y+150),'Design note and original prompt preserved.',18,MUT)
 txt(d,(x+12,y+284),it['hold'].upper()+' / '+it['role'],17,MUT)
sheet.save(OUT/'sheet.png')
(OUT/'sheet.prompt.md').write_text('Deterministic review assembly of A016 generated cards with Pillow; no new weapon imagery. Three columns by six rows, IDs and hold classes, amber recommendations; missing/refused images explicitly labeled. See build_review.py.\n')
# Detailed matrix with all requested dimensions and native-size thumbnails.
mat=Image.new('RGB',(2400,4000),BG);dr=ImageDraw.Draw(mat)
txt(dr,(30,22),'A016-00 / ARSENAL MATRIX',42)
txt(dr,(30,80),'* Top six / 96px-high camera crops + exact 2x previews; profiles at 53 px/m / scale proxy',24,GOLD)
txt(dr,(30,116),'Camera studies are concept art, not engine captures. A015 counters are proposed task ideas, not approved mechanics.',22,MUT)
for idx,it in enumerate(D['items']):
 y=172+idx*207
 dr.rectangle((24,y,2376,y+198),fill=PANEL)
 t=thumb(it)
 if t:
  t.thumbnail((96,96));mat.paste(t,(40,y+22));big=t.resize((t.width*2,t.height*2),Image.Resampling.NEAREST);mat.paste(big,(150,y+3))
  # Isolated side-profile shape at the same numeric metres-to-pixels convention.
  source=Image.open(SRC/(it['id']+'.png')).convert('RGB');sw,sh=source.size
  box={'A016-02':(.092,.33,.628,.75),'A016-18':(.139,.364,.607,.613)}.get(it['id'],(.10,.30,.63,.76))
  profile=source.crop(tuple(int(v*(sw if j%2==0 else sh)) for j,v in enumerate(box)))
  pw=max(1,round(it['length_m']*96/1.8));ph=max(1,round(profile.height*pw/profile.width))
  profile=profile.resize((pw,ph),Image.Resampling.LANCZOS);mat.paste(profile,(40,y+139))
  txt(dr,(40,y+172),'PROFILE / 53 px per m',12,MUT)
 else:
  txt(dr,(40,y+56),'SKIPPED',20,MUT);txt(dr,(40,y+86),'REFUSED',20,MUT)
 x=365
 txt(dr,(x,y+8),it['id']+' / '+it['name']+(' *' if it['top_six'] else ''),26,GOLD if it['top_six'] else FG)
 txt(dr,(x,y+44),f"{it['hold'].upper()} | {it['length_m']:.2f} m | {it['role']} | {it['range']} | {it['rate']} | {it['weight']}",21)
 wrap(dr,x,y+77,'Answers: '+it['counters']+'  //  Ammo: '+it['ammo'],width=155,size=20)
 wrap(dr,x,y+111,'Feel: '+it['signature']+'  //  Hook: '+it['hook'],width=160,size=19)
 wrap(dr,x,y+151,'Animation: '+it['animation'],width=160,size=18)
mat.save(SRC/'A016-00.png')
(SRC/'A016-00.prompt.md').write_text('Matrix assembled deterministically with Pillow from manifest.json and camera-panel crops of accepted A016 images. Native 96px-high crops and exact nearest-neighbour 2x previews; no synthetic replacement silhouettes for refused images. Labels, roles, ranges, rates, weights, ammo, counters, gun-feel and satire notes come from manifest. Build: docs/screens/A016/build_review.py. Scale is a review proxy inherited from A005, not a measured engine view.\n')
# Searchable full text matrix.
md=['# A016 arsenal matrix','',D['A015'],'','All dimensions, ranges, rates and mass classes are concept proposals, not tuned game data. * = recommended first six.','', '| ID | Weapon | Hold | Role | Range | Rate | Weight feel | Answers |','|---|---|---|---|---|---|---|---|']
for it in D['items']:
 md.append('| '+' | '.join([it['id']+(' *' if it['top_six'] else ''),it['name'],it['hold'],it['role'],it['range'],it['rate'],it['weight'],it['counters']])+' |')
md+=['','## One-line briefs','']
for it in D['items']:
 md+=['- **'+it['id']+' '+it['name']+':** '+it['role']+'; '+it['rate']+'; ammo: '+it['ammo']+'; flash/sound/impact: '+it['signature']+'; hook: '+it['hook']+'.']
(SRC/'A016-00.md').write_text('\n'.join(md)+'\n')
print('Wrote contact sheet, matrix PNG and searchable matrix.')
