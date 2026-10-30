from PIL import Image, ImageDraw, ImageFont
from pathlib import Path
O=Path(__file__).resolve().parent
F='/System/Library/Fonts/Supplemental/Arial.ttf'
def ft(n):return ImageFont.truetype(F,n)
im=Image.new('RGB',(2200,2000),'#10181e');d=ImageDraw.Draw(im)
white='#e6e7e4';mut='#a6b6c0';gold='#e3b650';cyan='#49d6dd'
S=140 # pixels per metre in ALL measured diagrams

def text(x,y,t,n=24,c=white):d.text((x,y),t,font=ft(n),fill=c)
def grid(x,y,w,h):
    for px in range(x,x+w+1,70):d.line((px,y,px,y+h),fill='#29353d')
    for py in range(y,y+h+1,70):d.line((x,py,x+w,py),fill='#29353d')
def rect(x,y,w,h,c='#53616a'):
    d.rectangle((x,y-h*S,x+w*S,y),fill=c,outline=white,width=3)
def dimh(x,y,w,label):
    x2=x+w*S;d.line((x,y,x2,y),fill=cyan,width=2)
    for v in [x,x2]:d.line((v,y-7,v,y+7),fill=cyan,width=2)
    text(x+6,y+9,label,22,cyan)
def dimv(x,y,h,label):
    d.line((x,y-h*S,x,y),fill=cyan,width=2)
    for v in [y-h*S,y]:d.line((x-7,v,x+7,v),fill=cyan,width=2)
    text(x+10,y-h*S/2,label,22,cyan)
text(32,22,'A006-05 / 06 / 07 — MEASURED BLOCKOUT BOUNDS',40)
text(32,78,'Authored orthographic supplement | uniform 140 px/m | grid 0.5 m | Y up | dimensions override generated drawings',24,c=mut)
# Wall and corner
text(32,130,'A006-05 / wall elevation + corner plan',29,c=gold)
grid(32,185,850,425)
rect(55,575,2,2.6);dimh(55,600,2,'2.0 m');dimv(355,575,2.6,'2.6 m')
text(55,650,'All wall families: 2.0 W x 2.6 H x 0.5 D m',24)
text(55,685,'Pivot: floor centre. Short closing pieces <= 2.0 m.',22,c=mut)
# L is exact 2 m external lengths, 0.5 thick
x=570;y=575
# use top-plan with vertical depth down-screen
pts=[(x,y),(x+280,y),(x+280,y-70),(x+70,y-70),(x+70,y-280),(x,y-280)]
d.polygon(pts,fill='#53616a',outline=white,width=3)
dimh(x,y+25,2,'2.0 m outer');dimv(x-20,y,2,'2.0 m')
text(570,240,'TOP PLAN',23,c=mut);text(570,650,'0.5 m thickness / 2.0 m outer legs',22)
# Door
text(1110,130,'A006-06 / closed door + open travel plan',29,c=gold)
grid(1110,185,1050,425)
x=1420;y=575
rect(x,y,2.4,2.6);d.rectangle((x+.2*S,y-2.2*S,x+2.2*S,y),fill='#b9b8ac',outline=gold,width=3)
dimh(x,y+25,2.4,'2.4 m outer');dimh(x+.2*S,y-2.2*S-20,2,'2.0 m CLEAR')
text(1110,650,'Jambs 0.2 m each; wall depth 0.5 m [deck]',23)
text(1110,685,'Aperture H 2.2; header 0.4; leaf D 0.12 m [proposed]',22,c=mut)
# travel plan accurate storage -2..0, aperture 0..2
x=1440;y=790
text(1110,735,'OPEN / one rigid leaf slides left',23,c=gold)
d.rectangle((x-2*S,y,x,y+.12*S),fill='#b9b8ac',outline=white,width=2)
d.rectangle((x,y-20,x+2*S,y+.5*S),outline=gold,width=2)
dimh(x-2*S,y+100,2,'LEFT STORAGE / 2.0 m');dimh(x,y+100,2,'CLEAR APERTURE / 2.0 m')
text(1110,950,'Storage lies outside aperture; no leaf remains in opening.',23,c=mut)
# Props one common baseline and front/side long profile
text(32,1015,'A006-07 / measured elevations — bounding shapes only; use concept boards for detail',29,c=gold)
base=1490;grid(32,1095,2128,420)
props=[('Bed upright',.9,.75,2,'NO COVER'),('Bed tipped',.75,.9,2,'LOW'),('Console',1.4,1.1,.6,'LOW / data'),('Low crate',1.2,.8,1.2,'LOW'),('Tall stack',1.2,2.1,1.2,'TALL'),('Ammo',1,.6,.6,'NONE')]
for n,(name,w,h,dep,cover) in enumerate(props):
    x=55+n*350
    # bed shown long side to compare upright and tipped 2m length
    shown=dep if n<2 else w
    rect(x,base,shown,h,'#79796e' if n<2 else '#53616a')
    dimh(x,base+25,shown,f'{shown:g} m');dimv(x-15,base,h,f'{h:g} m')
    text(x,1090,name,25,c=gold)
    text(x,1570,f'W {w:g} / H {h:g} / D {dep:g} m',21)
    text(x,1610,cover,23,c=gold)
text(32,1675,'Bed elevations above: LONG SIDE. Others: FRONT. Y height; X width; Z depth. Object sizes can be off-grid.',25,c=mut)
text(32,1735,'Other deck bounds: single tall crate 1.2 x 1.2 x 1.2 m; junction low cube 0.8 m; ammo is not cover.',25)
text(32,1785,'Scale state: deck.json rooms 1.0 / character 1.0. John target rooms 0.85 / character 1.15 pending T007.',25)
text(32,1835,'Human reference: 1.80 m base; 2.07 m nominal scaled target. Props above retain the deck size_m values.',25)
text(32,1900,'No new collision rules. Tipped bed orientation is a modelling proposal; final collision fit belongs to code lane.',24,c=mut)
im.save(O/'A006-kit-dimensions.png')
(O/'A006-kit-dimensions.prompt.md').write_text('Authored technical diagram, no generative prompt. build-dimensions.py draws literal deck bounds at uniform 140 pixels/metre on 0.5 m grid. Door aperture height, leaf thickness and storage construction explicitly proposed. Tipped bed uses rigid 90-degree long-axis rotation of .9 x .75 x2 m bound. No art images edited.\n')
print(im.size)
