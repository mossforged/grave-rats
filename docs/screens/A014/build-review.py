from PIL import Image,ImageDraw,ImageFont,ImageOps
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'assets/source/A014-derelict-2'
FONT='/System/Library/Fonts/Supplemental/Arial.ttf'
def font(n): return ImageFont.truetype(FONT,n)
rooms=[('BRIDGE',10.5,0,11.5,6,'#463036','red'),('BIO LAB',10.5,6.5,11.5,9.5,'#243e3b','cyan-green'),('MESS',10.5,16.5,11.5,5.5,'#443c2b','amber'),('QUARTERS',10.5,22.5,11.5,5.5,'#343d48','cool white'),('WEST SPINE',6.5,0,3.5,28,'#29343c','cool white'),('EAST SPINE',22.5,0,3.5,28,'#29343c','amber'),('ENGINEERING',26.5,10,10,10,'#253b43','cyan'),('AIRLOCK / HOLD',0,22,6,6,'#314438','white')]
doors=[('D1',6,24,0.5,2),('D2',10,3,0.5,2),('D3',22,3,0.5,2),('D4',10,10,0.5,2),('D5',22,10,0.5,2),('D6',10,18,0.5,2),('D7',22,18,0.5,2),('D8',10,24,0.5,2),('D9',22,24,0.5,2),('D10',26,14,0.5,2)]
# Footprints in finished world metres; all boundaries lie on the 0.5m grid.
props=[('L',12,1,2,1),('L',17,1,2,1),('T',20.5,.5,1,2),('T',11,7,1.5,2),('T',14,7,1.5,2),('T',17,7,1.5,2),('T',20.5,13,1,2),('L',13,14,3,1),('L',12,17,3,1),('L',17,20,3,1),('T',20.5,20,1,1.5),('T',11,26,3,1.5),('T',16,26,3,1.5),('L',20,23,1.5,1),('T',29,10.5,6,2),('L',29,18,3,1),('T',34.5,16,1.5,3),('L',.5,22.5,2,1),('T',.5,26,2,1.5)]
salvage=[('S',13,2.5),('BB',17,2.5),('S',19,14.5),('M',13,13),('S',16,20.5),('M',19,17.5),('S',14,23.5),('M',19,27),('H',33,17),('M',33,13.5)]
spawns=[('V',9,7),('C',9,21),('V',25,8),('C',25,23),('V',35.5,11),('V',21,8)]
lights=[(12,.5,'red'),(19,.5,'red'),(12,8,'cyan'),(15,8,'cyan'),(18,8,'cyan'),(14,17,'orange'),(19,21.5,'orange'),(13,27.5,'white'),(19,27.5,'white'),(7,5,'white'),(7,15,'white'),(7,26,'white'),(25.5,5,'orange'),(25.5,18,'orange'),(25.5,26,'orange'),(29,11,'cyan'),(35,19,'cyan'),(1,24,'white')]
data={'units':'finished world metres, x east / y south, origin bridge-side northwest bounding box','grid_m':.5,'rooms':[dict(name=n,x=x,y=y,width=w,depth=h,light=c) for n,x,y,w,h,_,c in rooms],'doors':[dict(id=n,x=x,y=y,width=w,depth=h,aperture_m=2) for n,x,y,w,h in doors],'cover':[dict(kind=k,x=x,y=y,width=w,depth=h) for k,x,y,w,h in props],'salvage':[dict(kind=k,x=x,y=y) for k,x,y in salvage],'spawn_candidates':[dict(kind=k,x=x,y=y) for k,x,y in spawns],'lights':[dict(x=x,y=y,color=c) for x,y,c in lights],'scale_policy':'finished grid dimensions; room input size = target / 0.85 if importer applies room_scale; never scale target twice','custodian':{'cutter':[25,13],'drone_patrol':[[24,12],[24,19],[18,19],[8,19],[8,11],[18,11],[24,11]]}}
(OUT/'A014-02.layout.json').write_text(json.dumps(data,indent=2)+'\n')
im=Image.new('RGB',(2400,2020),'#101820');d=ImageDraw.Draw(im)
def txt(x,y,s,n=25,c='#dce5e9'):d.text((x,y),s,font=font(n),fill=c)
S=45;OX=85;OY=230
def pt(x,y):return OX+x*S,OY+y*S
def box(x,y,w,h,fill,outline=None,width=1):d.rectangle((*pt(x,y),*pt(x+w,y+h)),fill=fill,outline=outline,width=width)
txt(65,38,'GRAVE RATS / A014-02 / BIOLOGICAL SURVEY VESSEL',44)
txt(65,100,'Approval concept | 8 spaces | finished world metres | 0.5 m grid | north / bow at top',27)
txt(65,145,'Authoritative geometry: this plan + A014-02.layout.json. Mood images illustrate materials and light.',24,'#a6bac7')
# Draw 0.5m bulkheads around floor extents.
for n,x,y,w,h,col,lc in rooms:box(x-.5,y-.5,w+1,h+1,'#77818a');box(x,y,w,h,col)
for n,x,y,w,h,col,lc in rooms:
 for i in range(int(w*2)+1):
  xx=x+i*.5;d.line((*pt(xx,y),*pt(xx,y+h)),fill='#45505a',width=1)
 for i in range(int(h*2)+1):
  yy=y+i*.5;d.line((*pt(x,yy),*pt(x+w,yy)),fill='#45505a',width=1)
# Reserved travel bands, unobstructed 2m across rooms and down spines.
for x,y,w,h in [(7.5,1,2,26),(23,1,2,26),(10,3,12.5,2),(10,10,12.5,2),(10,18,12.5,2),(10,24,12.5,2),(26,14,8,2),(3,24,3.5,2)]:
 box(x,y,w,h,'#37535c')
for k,x,y,w,h in props:
 box(x,y,w,h,'#c9a060' if k=='L' else '#8c7c9a','#101820',3)
 d.text(pt(x+.1,y+.05),k,font=font(23),fill='#0b1017')
for n,x,y,w,h in doors:
 box(x,y,w,h,'#64d9e1')
 # ID on wall beside opening, no swing arcs for sliding doors.
 d.text(pt(x-.2,y-.6),n,font=font(18),fill='#e5ffff')
for k,x,y in salvage:
 px,py=pt(x,y);d.ellipse((px-15,py-15,px+15,py+15),fill='#edcf68',outline='#111820',width=2)
 d.text((px-10,py-12),k,font=font(16),fill='#111820')
for k,x,y in spawns:
 px,py=pt(x,y);d.rectangle((px-15,py-15,px+15,py+15),fill='#ea8b85');d.text((px-9,py-13),k,font=font(20),fill='#101820')
for x,y,c in lights:
 px,py=pt(x,y);d.ellipse((px-5,py-5,px+5,py+5),fill=c,outline='#ffffff')
# Room names offset from cover and primary routes.
for label,x,y in [('BRIDGE',13,5.25),('BIO LAB',13,12),('MESS',14,21),('QUARTERS',13,22.6),('ENGINEERING',28,16.2),('AIRLOCK',.4,27.5)]:
 txt(*pt(x,y),label,25)
# Patrol shown as discrete chevrons rather than blocking geometry.
for x,y in [(24,12),(24,17),(19,19),(8,17),(8,11),(18,11)]:
 px,py=pt(x,y);d.line((px-9,py-7,px,py,px-9,py+7),fill='#d39cf0',width=4)
px,py=pt(25,13);d.polygon([(px,py-15),(px-15,py+15),(px+15,py+15)],fill='#f07b65');txt(px+15,py-12,'CUT',16)
d.line((*pt(25,13),*pt(25,17)),fill='#f07b65',width=4)
# Legend sidebar
xx=1800;yy=240
def line(s,c='#dce5e9',n=25):
 global yy
 txt(xx,yy,s,n,c);yy+=42
line('PLAN KEY', '#e9c973',32)
for s in ['Cyan slots = sliding doors','D1-D10: 2.0 m aperture','L = low cover, 0.8-1.1 m','T = tall cover, >=1.2 m','Yellow circles = salvage','S small / M medium / H heavy','BB = heavy black box','V vent / C spawn closet','Dots = practical lights','Blue bands = reserved routes','Purple > = drone patrol','Coral CUT = cutter + sightline'] :line(s)
yy+=25;line('ROOM LIGHT / CLEAR SIZE','#e9c973',27)
for n,x,y,w,h,col,lc in rooms:
 line(n, '#ffffff',23);line(f'{w:g} x {h:g} m / {lc}', '#a8bec8',22)
txt(85,1550,'ROUTE LOGIC',30,'#e9c973')
for j,s in enumerate(['Airlock -> west spine -> bridge black box. Return via east spine and mess or quarters.',
'Loops: west -> bridge -> east -> mess -> west; lab and quarters give extra cross-links.',
'Engineering has only D10: heavy engine salvage rewards the dead end. Cutter faces south on east spine.',
'Drone loops through lab + mess; tall cover and sliding doors interrupt sight. Spawns must remain out of sight.',
'Reserve 2.0 m blue bands; 3.5 m spines allow wall dressing <=0.5 m deep. No floor cables across routes.',
'0.5 m walls / 2.6 m high; door frames 0.2 m. Worst 2.0 - 2(0.2) = 1.6 m clear at frame.',
'Overall hull envelope 37.5 x 29 m including outer walls. BB lies ~37 m along marked orthogonal route from hold.',
'Room scale 0.85: dimensions shown are FINAL. Precompensate room sizes by /0.85 when importing.']):txt(85,1605+j*43,s,24)
im.save(OUT/'A014-02.png')
(OUT/'A014-02.prompt.md').write_text('Use case: infographic-diagram. Deterministic scaled floor plan, rendered by docs/screens/A014/build-review.py with Pillow. Source specification: A014-02.layout.json. Draw eight finished-world-metre spaces on a 0.5m grid; mark 2m sliding doors, 0.5m walls (height 2.6m), low/tall cover, all salvage classes, black box, out-of-sight vent/closet candidates, practical light colors, cutter and drone route. Reserve 2m travel bands, minimum 1.6m at frames. All final dimensions compensate importer room_scale=0.85. Labels and legend are authoritative; mood renders are illustrative. No image generation used for engineering geometry.\n')
print('Plan saved:',im.size)
# Review board uses the original images without changing their content.
board=Image.new('RGB',(3000,3900),'#101820');bd=ImageDraw.Draw(board)
def bt(x,y,s,n=30,c='#dce5e9'):bd.text((x,y),s,font=font(n),fill=c)
def panel(id,x,y,w,h):
 source=Image.open(OUT/f'A014-{id}.png').convert('RGB');thumb=ImageOps.contain(source,(w,h));board.paste(thumb,(x+(w-thumb.width)//2,y+(h-thumb.height)//2))
bt(60,35,'GRAVE RATS / A014 / SECOND DERELICT',48)
bt(60,100,'Concept approval gate | recommended: biological survey vessel | 2026-10-31',30,'#e9c973')
panel('01',60,160,2880,1200)
for x,title,lines in [(65,'A014-01 / A: CREW TRANSPORT',['Slow death on a long voyage.','BB: life-support failure record.','Story: set meals, empty bunks.']), (1050,'B: BIOLOGICAL SURVEY / PICK',['Containment outlived the crew.','BB: quarantine orders + lab telemetry.','Story: meal trolley stopped at lab seal.']), (2030,'C: MINING TUG',['Engineering swallowed the ship.','BB: tow overload / accident record.','Story: bunks beside stripped machinery.'])]:
 bt(x,1380,title,30,'#e9c973')
 for i,s in enumerate(lines):bt(x,1430+i*42,s,28)
bt(60,1620,'A014-02 / SCALED PLAN + TACTICAL MARKUP',34,'#e9c973')
panel('02',40,1690,1710,1440)
for id,y,title,note in [('03',1640,'BRIDGE / EMERGENCY RED','White flashlight anchors the player; recorder at helm.'),('04',2340,'BIO LAB / LUMINOUS TANKS','Tank, bench, centrifuge, fridge and folding-screen kit.'),('05',3040,'CORRIDOR / FAILED INFRASTRUCTURE','Ribs, pipe runs, breach and hanging cable bundle.')]:
 bt(1810,y,f'A014-{id} / {title}',30,'#e9c973');panel(id,1790,y+55,1150,570);bt(1810,y+640,note,23)
for i,s in enumerate(['RECOMMENDATION','Research purpose connects all five new room types.', 'Eight spaces; looped spines; engineering salvage dead end.', 'Bridge black box is distant from the extraction hold.', 'Floor plan controls dimensions; mood frames control finish.', '', 'APPROVAL REQUIRED BEFORE CODE BUILDS', 'John: ship pitch, route plan, mood and scale policy.', 'Read docs/handoffs/auto-A014.md for checks and limits.']):bt(75,3180+i*55,s,31 if i in (0,6) else 28,'#e9c973' if i in (0,6) else '#dce5e9')
bt(60,3820,'Concepts only / original unbranded designs / imagegen mood art + deterministic scaled plan / no game imports',26,'#9eb5c3')
board.save(ROOT/'docs/screens/A014/sheet.png')
(ROOT/'docs/screens/A014/sheet.prompt.md').write_text('Deterministic contact sheet: assemble A014-01 through A014-05 at native aspect ratio on 3000x3900 dark board. Label three pitch thumbnails, recommendation, scaled plan, bridge red, bio lab cyan-green, dressed corridor. Include black-box rationale and room-story captions. Render with build-review.py and Pillow; no generated artwork altered.\n')
print('Review sheet saved:',board.size)
