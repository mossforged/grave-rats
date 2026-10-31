from PIL import Image, ImageDraw, ImageFont
from pathlib import Path
import math, json
ROOT=Path(__file__).resolve().parents[3]
OUT=Path(__file__).resolve().parent
REVIEW=ROOT/'docs/screens/A012'
BG='#12191c'; INK='#171b1c'; PAPER='#eee9d9'; MUTED='#a5b0b0'; LINE='#b3b1a6'; YELLOW='#f5cc24'; RED='#aa302d'
F='/System/Library/Fonts/Supplemental/'
fonts={'body':'Arial.ttf','bold':'Arial Bold.ttf','title':'DIN Condensed Bold.ttf','mono':'Andale Mono.ttf'}
transcripts={}; fields={}; bounds=[]
def font(n,k='body'): return ImageFont.truetype(F+fonts[k],n)
def txt(d,x,y,s,n=26,c=INK,k='body',right=False):
    if right: x-=d.textlength(s,font=font(n,k))
    d.text((x,y),s,font=font(n,k),fill=c)
def rect(d,b,c,outline=None): d.rectangle(b,fill=c,outline=outline,width=2)
def rule(d,y,x=84,x2=1220): d.line((x,y,x2,y),fill=LINE,width=1)
def panel(d,b,c=PAPER):
    x,y,r,bottom=b; t=16
    d.polygon([(x+t,y),(r-t,y),(r,y+t),(r,bottom-t),(r-t,bottom),(x+t,bottom),(x,bottom-t),(x,y+t)],fill=c)
def stripe(d,y):
    rect(d,(56,y,1864,y+10),YELLOW)
    for x in range(56,1864,42): d.polygon([(x,y),(x+15,y),(x+5,y+10),(x-10,y+10)],fill=INK)
def base(title,ref):
    im=Image.new('RGB',(1920,1080),BG);d=ImageDraw.Draw(im)
    # Typeset company name, no speculative replacement logo.
    txt(d,56,30,'REMNANT',46,PAPER,'title'); txt(d,238,38,'ASSET RECOVERY',23,PAPER,'bold')
    txt(d,56,83,'EVERYTHING HAS A SECOND OWNER.',17,MUTED,'mono')
    txt(d,1864,42,ref,20,PAPER,'mono',True);stripe(d,116)
    txt(d,56,152,title,72,PAPER,'title')
    txt(d,56,1033,'INDEPENDENT RECOVERY CONTRACTOR / REMNANT ACCOUNTS',17,MUTED,'mono')
    return im,d
def button(d,b,label,primary=True):
    panel(d,b,YELLOW if primary else BG)
    if not primary:d.rectangle(b,outline=MUTED,width=2)
    x,y,r,bt=b;txt(d,(x+r)/2-d.textlength(label,font=font(35,'title'))/2,y+20,label,35,INK if primary else PAPER,'title')
def write(im,id,copy,fs,prompt):
    im.save(OUT/(id+'.png'));transcripts[id]=copy;fields[id]=fs
    (OUT/(id+'.prompt.md')).write_text('# '+id+' — deterministic rendering brief\n\n'+prompt+'\n\nRenderer: `python3 assets/source/A012-screens/build.py` (Pillow; no image generation). Exact copy and field mapping are in `docs/handoffs/auto-A012.md`. This is a new flat UI built from shapes and typeset text, following A010; no existing image is edited.\n')

im,d=base('RECOVERY AGREEMENT','CONTRACT / RAR-041')
panel(d,(56,244,1236,896));panel(d,(1260,244,1864,896),INK)
txt(d,84,269,'VESSEL',19,INK,'bold');txt(d,84,300,'MERIDIAN DUE',57,INK,'title');txt(d,1208,318,'probably abandoned',28,INK,'bold',True)
rule(d,373);txt(d,84,394,'ESTIMATED SALVAGE VALUE',20,INK,'bold');txt(d,1208,387,'8,600 CR',45,INK,'title',True)
rule(d,453);txt(d,84,475,'KNOWN HAZARDS / AS FOUND SO FAR',21,INK,'bold')
for y,s in [(518,'01   Corrosive organism sighted / medbay'),(560,'02   Armed rival crew reported / cargo'),(602,'03   Remaining compartments / unverified')]:txt(d,84,y,s,27)
rule(d,655)
for y,s in [(680,'Contractor assumes liability for anything that is not abandoned.'),(723,'Recovery estimates exclude recovery costs.'),(766,'Recovery does not include rescue.'),(809,'Acceptance confirms the clauses shown above.')]:txt(d,84,y,s,25)
txt(d,1292,274,'ASSIGNED CREW',27,YELLOW,'title')
for i,(name,role) in enumerate([('ROOK','Recovery'),('VALE','Systems'),('MOSS','Medical'),('PIKE','Cargo')]):
 y=329+i*100;txt(d,1292,y,f'0{i+1}',25,YELLOW,'mono');txt(d,1362,y-6,name,39,PAPER,'title');txt(d,1362,y+38,role,23,MUTED)
txt(d,1292,767,'ENTRY CONFIRMS ACCEPTANCE.',20,PAPER,'bold');txt(d,1292,814,'Liability begins at the airlock.',22,MUTED)
button(d,(56,924,1236,1008),'ACCEPT  >');button(d,(1260,924,1564,1008),'DECLINE',False)
write(im,'A012-01',['RECOVERY AGREEMENT','CONTRACT / RAR-041','VESSEL / MERIDIAN DUE / probably abandoned','ESTIMATED SALVAGE VALUE / 8,600 CR','KNOWN HAZARDS / AS FOUND SO FAR','01 Corrosive organism sighted / medbay','02 Armed rival crew reported / cargo','03 Remaining compartments / unverified','Contractor assumes liability for anything that is not abandoned.','Recovery estimates exclude recovery costs.','Recovery does not include rescue.','Acceptance confirms the clauses shown above.','ASSIGNED CREW','01 ROOK / Recovery','02 VALE / Systems','03 MOSS / Medical','04 PIKE / Cargo','ENTRY CONFIRMS ACCEPTANCE.','Liability begins at the airlock.','ACCEPT > / DECLINE'],['contract.id','contract.vessel_name','contract.status','contract.estimated_value_cr','contract.known_hazards[].description','contract.known_hazards[].location','contract.crew[].name','contract.crew[].role'], '1920 × 1080 opaque flat UI. A010 ivory, near-black and safety yellow; clipped panels, strong condensed headers, precise readable legal copy. Left: vessel, probably abandoned, estimate, known hazards and four liability clauses. Right: four crew slots. ACCEPT 1180 × 84 px, DECLINE 304 × 84 px. Fixture values are illustrative, not claims about the current game.')

im,d=base('SHIFT SETTLEMENT','SHIFT / RAR-041 / ROOK')
panel(d,(56,244,1236,1008));panel(d,(1260,244,1864,1008),INK)
txt(d,84,269,'CREDITS RECOVERED',28,INK,'title');txt(d,1208,275,'AMOUNT / CR',18,INK,'mono',True)
credits=[('Relay assembly','1 × 1,600','+1,600'),('Copper busbar','4 × 160','+640'),('Sealed medical pack','2 × 120','+240')]
for i,(label,unit,amt) in enumerate(credits):
 y=321+i*49;txt(d,84,y,label,26);txt(d,850,y,unit,22,INK,'mono',True);txt(d,1208,y,amt,27,INK,'bold',True)
rule(d,470);txt(d,84,485,'GROSS RECOVERED',24,INK,'bold');txt(d,1208,485,'2,480',27,INK,'bold',True)
txt(d,84,547,'DEDUCTIONS',28,INK,'title')
deduct=[('Suit rental','1 shift × 640','-640'),('Ammunition / company-store prices','46 rounds × 20','-920'),('Oxygen / billed per minute','19 min × 20','-380'),('Airlock cycling','5 cycles × 50','-250'),('Morale','1 shift × 280','-280')]
for i,(label,unit,amt) in enumerate(deduct):
 y=595+i*55;txt(d,84,y,label,25);txt(d,997,y,unit,21,INK,'mono',True);txt(d,1208,y,amt,27,INK,'bold',True)
rule(d,882);txt(d,84,904,'TOTAL DEDUCTIONS',24,INK,'bold');txt(d,1208,901,'-2,470',31,INK,'bold',True)
txt(d,84,963,'Time aboard 18:24 / Oxygen rounded up to whole minutes.',23)
txt(d,1292,279,'CONTRACTOR / ROOK',24,PAPER,'title');txt(d,1292,335,'RETURN FILED',22,YELLOW,'mono')
txt(d,1292,443,'NET PAY',52,PAPER,'title');txt(d,1292,507,'10 CR',122,YELLOW,'title')
txt(d,1292,692,'2,480 earned.',26,PAPER);txt(d,1292,735,'2,470 recovered by Remnant.',26,PAPER)
txt(d,1292,813,'Thank you for choosing',25,MUTED);txt(d,1292,851,'independent recovery.',25,MUTED)
button(d,(1292,904,1832,984),'ACKNOWLEDGE  >')
write(im,'A012-02',['SHIFT SETTLEMENT','SHIFT / RAR-041 / ROOK','CREDITS RECOVERED / AMOUNT / CR']+[f'{a} / {b} / {c}' for a,b,c in credits]+['GROSS RECOVERED / 2,480','DEDUCTIONS']+[f'{a} / {b} / {c}' for a,b,c in deduct]+['TOTAL DEDUCTIONS / -2,470','Time aboard 18:24 / Oxygen rounded up to whole minutes.','CONTRACTOR / ROOK','RETURN FILED','NET PAY / 10 CR','2,480 earned.','2,470 recovered by Remnant.','Thank you for choosing independent recovery.','ACKNOWLEDGE >'],['contract.id','contract.contractor_name','salvage[].label','salvage[].quantity','salvage[].unit_value_cr','credits[].amount_cr','gross_cr','deductions[].label','deductions[].quantity','deductions[].unit','deductions[].rate_cr','deductions[].amount_cr','deductions_total_cr','time_alive_s','settlement.status','net_cr'], '1920 × 1080 flat typeset settlement. Itemised credits then deductions, right-aligned numeric columns, large yellow net pay in right sidebar. Five real quantity/rate examples; all math exact. Oxygen uses ceil(time_alive_s/60). Persistent clear footer and acknowledge action. Match A010 clipped shapes, ivory ledger, black sidebar, no texture or scene backdrop.')

im,d=base('ACCOUNT CONTINUES.','INVOICE / RAR-041-D / ROOK')
panel(d,(56,244,644,1008),INK);panel(d,(668,244,1864,1008))
txt(d,88,277,'RECOVERY STATUS',27,PAPER,'title');panel(d,(88,330,612,402),YELLOW);txt(d,108,347,'NOT RETURNED',41,INK,'title')
txt(d,88,445,'CAUSE OF DEATH / AS RECORDED',23,PAPER,'title')
for y,label,value in [(500,'KILLER','Stalker 01'),(598,'METHOD','spit'),(696,'LOCATION','Not recorded')]:txt(d,88,y,label,18,MUTED,'mono');txt(d,88,y+31,value,38,PAPER,'title')
txt(d,88,814,'TIME ALIVE',19,MUTED,'mono');txt(d,88,848,'18:24',44,PAPER,'title');txt(d,88,936,'No location supplied by run log.',22,MUTED)
txt(d,700,274,'POSTHUMOUS INVOICE',34,INK,'title');txt(d,1832,284,'AMOUNT / CR',19,INK,'mono',True)
deathrows=[('Posthumous processing','180'),('Unreturned equipment','1,640'),('Biohazard cleanup (you)','420')]
for i,(label,amt) in enumerate(deathrows):
 y=347+i*73;txt(d,700,y,label,30);txt(d,1832,y,amt,32,INK,'bold',True);rule(d,y+56,700,1832)
txt(d,700,601,'OUTSTANDING BALANCE',31,INK,'title');panel(d,(700,651,1832,769),YELLOW);txt(d,728,670,'2,240 CR',82,INK,'title')
txt(d,700,806,'PASSED TO NEXT OF KIN',24,RED,'bold');txt(d,700,849,'Nominated contact / VALE',28)
txt(d,700,903,'Liability survives the contractor.',27);txt(d,700,948,'Recovery does not include rescue.',25)
write(im,'A012-03',['ACCOUNT CONTINUES.','INVOICE / RAR-041-D / ROOK','RECOVERY STATUS / NOT RETURNED','CAUSE OF DEATH / AS RECORDED','KILLER / Stalker 01','METHOD / spit','LOCATION / Not recorded','TIME ALIVE / 18:24','No location supplied by run log.','POSTHUMOUS INVOICE / AMOUNT / CR']+[f'{a} / {b}' for a,b in deathrows]+['OUTSTANDING BALANCE / 2,240 CR','PASSED TO NEXT OF KIN','Nominated contact / VALE','Liability survives the contractor.','Recovery does not include rescue.'],['invoice.id','contract.contractor_name','settlement.status','killer','killed_by.how','death.location','time_alive_s','death_bill.lines[].label','death_bill.lines[].amount_cr','outstanding_cr','contract.next_of_kin'], '1920 × 1080 clean flat posthumous invoice. Left black evidence column with recorded killer/method/location and time. No invented location: literal Not recorded. Right ivory invoice, three itemised charges, large yellow balance, restrained red next-of-kin routing heading. No monster art or jokes at the victim’s expense. Match A010 graphic hierarchy.')
# Alternatives, not cumulative penalties. C = current run log; P = proposed event/metadata.
deductions=[
('Suit rental','time_alive_s > 0; 1 × rates.suit_shift_cr','C','One shift. No ownership implied.'),
('Ammunition / company-store prices','shots_fired × rates.round_cr','C','Every discharge is a purchase.'),
('Oxygen / billed per minute','ceil(time_alive_s / 60) × rates.oxygen_min_cr','C','Partial minutes remain breathable.'),
('Airlock cycling','airlock_cycles × rates.cycle_cr','P','Return journeys are separate journeys.'),
('Morale','time_alive_s > 0; 1 × rates.morale_shift_cr','C','Participation confirms satisfaction.'),
('Missed-round disposal','max(0, shots_fired - shots_hit) × rate','C','Unrecovered rounds remain sold.'),
('Impact reconciliation','shots_hit × rate','C','Successful delivery confirmed.'),
('Obstruction damage assessment','your_shots_blocked × rate','C','Cover is company-adjacent property.'),
('Ballistic shelter service','shots_blocked_for_you × rate','C','Protection has been itemised.'),
('Corrosive interception','times_protected × rate','C','Exposure avoided. Service supplied.'),
('Cover occupancy','ceil(time_locked_s / 60) × rate','C','Shelter is billed while occupied.'),
('Open-position incident review','hits_in_open × rate','C','The review does not reverse the incident.'),
('Covered-position incident review','hits_in_cover × rate','C','Cover does not imply coverage.'),
('Corrosive contact treatment','damage_by_source.spit × rate','C','Contact has been established.'),
('Floor-residue decontamination','damage_by_source.puddle × rate','C','Residue transfers with the contractor.'),
('Impact seal inspection','damage_by_source.lunge × rate','C','Suit integrity requires verification.'),
('Ballistic seal inspection','damage_by_source.rifle × rate','C','Third-party damage. First-party invoice.'),
('Early closure administration','ended == quit; 1 × rate','C','Departure does not cancel the account.'),
('Replacement-shift administration','ended == respawn; 1 × rate','C','A new start is a separate service.'),
('Salvage handling','sum(salvage[].quantity) × rates.handling_cr','P','Recovery includes a handling charge.'),
]
causes=[
('Corrosive discharge','method == spit','Contact recorded. Liability retained.'),
('Residual corrosive exposure','method == puddle','Exposure continued after delivery.'),
('Close-contact impact','method == lunge','Personal space is not insured.'),
('Ballistic injury','method == rifle','Third-party fire. Contractor account.'),
('Unclassified fatal incident','method missing or unrecognised','Classification pending. Processing complete.'),
('Stalker involvement','killed_by.stalker exists','Organism liability could not be established.'),
('Rival-contractor involvement','killed_by.pirate exists','Competing claim acknowledged.'),
('Multiple exposure classes','count(damage_by_source > 0) >= 2','Separate incidents. One account.'),
('Cover-related injury history','hits_in_cover > 0','Cover was present. Coverage was not.'),
('Open-position injury history','hits_in_open > 0','Exposure review added to file.'),
('Corrosive residue on file','damage_by_source.puddle > 0','Decontamination remains chargeable.'),
('Close-contact damage on file','damage_by_source.lunge > 0','Seal inspection remains chargeable.'),
('Ballistic damage on file','damage_by_source.rifle > 0','Inspection excludes projectile recovery.'),
('Shelter service on file','shots_blocked_for_you + times_protected > 0','Prior protection does not void this invoice.'),
('Cause unavailable','killed_by == null','Evidence unavailable. Balance available.'),
]
# Field spec uses readable diagram versions of all three screen hierarchies.
im=Image.new('RGB',(1920,1080),BG);d=ImageDraw.Draw(im)
txt(d,40,22,'A012-04 / BUILD FIELD SPEC',43,PAPER,'title')
txt(d,1880,34,'C  CURRENT LOG   P  PROPOSED INPUT   D  DERIVED',18,YELLOW,'mono',True)
txt(d,40,76,'Boxed areas replace changing content. Ordered ledger rows repeat; full paths, rules and copy are in auto-A012.md.',21,MUTED)
cols=[
('01 / RECOVERY AGREEMENT',[
('P {contract.id}',),('P {contract.vessel_name}  {contract.status}',),('P {contract.estimated_value_cr}',),('P {contract.known_hazards[].description}',),('P {contract.known_hazards[].location}',),('P {contract.crew[].name}  {..role}',),('Fixed: liability clauses',),('ACCEPT  >                     DECLINE',)]),
('02 / SHIFT SETTLEMENT',[
('P {contract.id}  {contract.contractor_name}',),('P {salvage[].label} {..quantity} {..unit_value_cr}',),('D {credits[].amount_cr}  {gross_cr}',),('D {deductions[].label} {..quantity} {..unit}',),('D {deductions[].rate_cr} {..amount_cr}',),('C {time_alive_s}  D {deductions_total_cr}',),('P {settlement.status}  D {net_cr}',),('ACKNOWLEDGE  >',)]),
('03 / ACCOUNT CONTINUES.',[
('P {invoice.id}  {contract.contractor_name}',),('P {settlement.status}  C {time_alive_s}',),('D {killer}  C {killed_by.how}',),('P {death.location} / absent: Not recorded',),('D {death_bill.lines[].label}',),('D {death_bill.lines[].amount_cr}',),('D {outstanding_cr}  P {contract.next_of_kin}',),('Fixed: liability and rescue clauses',)])]
for i,(title,rows) in enumerate(cols):
 x=40+630*i;panel(d,(x,117,x+610,456));txt(d,x+16,128,title,30,INK,'title')
 for j,(s,) in enumerate(rows):
  y=174+j*33;rect(d,(x+14,y,x+596,y+28),None if False else PAPER,INK);txt(d,x+22,y+4,s,17,INK,'mono')
txt(d,40,478,'20 / DEDUCTION LINE LIBRARY',31,YELLOW,'title')
txt(d,1010,478,'15 / DEATH-BILL CAUSE & CONTEXT VARIANTS',31,YELLOW,'title')
# Two-column deduction library, predicate key is an exact log field or explicit P input.
shortkeys=['time_alive_s','shots_fired','time_alive_s','P airlock_cycles','time_alive_s','shots_fired - shots_hit','shots_hit','your_shots_blocked','shots_blocked_for_you','times_protected','time_locked_s','hits_in_open','hits_in_cover','damage_by_source.spit','damage_by_source.puddle','damage_by_source.lunge','damage_by_source.rifle','ended: quit','ended: respawn','P salvage[].quantity']
for i,(label,trigger,state,copy) in enumerate(deductions):
 x=40+(i//10)*480;y=527+(i%10)*49
 txt(d,x,y,f'{i+1:02}  {label}',20,PAPER,'bold');txt(d,x+34,y+25,shortkeys[i],16,MUTED,'mono')
for i,(label,pred,copy) in enumerate(causes):
 y=524+i*31;txt(d,1010,y,f'{i+1:02} {label}',20,PAPER,'bold')
 # concise predicates at right, full selection rules in handoff
 key=['how=spit','how=puddle','how=lunge','how=rifle','unknown how','stalker','pirate','2+ sources','hits_in_cover','hits_in_open','puddle > 0','lunge > 0','rifle > 0','protected > 0','killed_by=null'][i]
 txt(d,1880,y,key,17,MUTED,'mono',True)
txt(d,40,1032,'Fees are approval proposals. Cause variants 08–14 are contributing context, never inferred killing blows.',21,YELLOW)
write(im,'A012-04',['BUILD FIELD SPEC','C CURRENT LOG / P PROPOSED INPUT / D DERIVED','Boxed areas replace changing content. Ordered ledger rows repeat; full paths, rules and copy are in auto-A012.md.']+[title+' / '+' / '.join(r[0] for r in rows) for title,rows in cols]+['Fees are approval proposals. Cause variants 08–14 are contributing context, never inferred killing blows.'],[], '1920 × 1080 field specification. Three diagrammatic versions of the prior screens across the top; all variable slots boxed with literal brace placeholders and provenance C/P/D. Below, twenty deduction titles with telemetry keys in two columns, fifteen death-cause/context titles with predicate keys. 17–21 px spec text. Full exact rules and copy in handoff; not a player-facing screen.')
# Review sheet: complete originals at 50%, 2 × 2.
sheet=Image.new('RGB',(2024,1316),BG);sd=ImageDraw.Draw(sheet)
txt(sd,32,20,'GRAVE RATS / A012 / END-OF-SHIFT SCREENS',43,PAPER,'title')
txt(sd,32,76,'LAYOUT + COPY APPROVAL PENDING / 1920 × 1080 originals / illustrative rates and fixtures',23,YELLOW)
for i,title in enumerate(['01 / Contract briefing','02 / End-of-shift payslip','03 / Death bill','04 / Field spec + copy library']):
 x=32+(i%2)*992;y=132+(i//2)*588;txt(sd,x,y,title,28,PAPER,'title')
 sheet.paste(Image.open(OUT/f'A012-0{i+1}.png').resize((960,540),Image.Resampling.LANCZOS),(x,y+36))
sheet.save(REVIEW/'sheet.png')
(REVIEW/'sheet.prompt.md').write_text('Deterministic 2024 × 1316 review sheet. Four complete 1920 × 1080 originals at exactly 50%, labelled in a two-by-two grid. Built by assets/source/A012-screens/build.py. Review full-size originals for spec labels.\n')
# Handoff: canonical text and honest mapping, no gameplay changes.
h=['# A012 — End-of-shift screens','Status: complete for human review. John must approve layouts, rates and copy before a build task. No approval is claimed. Work stops at this packet gate.','## Deliverables']
for id,desc in [('A012-01','Contract briefing; 1180 px ACCEPT versus 304 px DECLINE, known hazards and four crew slots.'),('A012-02','Itemised payslip; 2,480 gross − 2,470 deductions = 10 CR net.'),('A012-03','Death bill; 180 + 1,640 + 420 = 2,240 CR to next of kin, cause evidence separate from accounting.'),('A012-04','Three boxed field diagrams, twenty deduction lines and fifteen death-bill cause/context variants.')]:h.append(f'- **{id}** — {desc} Source: `assets/source/A012-screens/{id}.png`; matching `.prompt.md`.')
h+=['Review: `docs/screens/A012/sheet.png` (2024 × 1316; all originals shown at 50%). All four originals are opaque RGB PNG, **1920 × 1080**. Editable deterministic source: `assets/source/A012-screens/build.py`. Run with Python 3 + Pillow on macOS; system fonts: DIN Condensed Bold, Arial/Arial Bold, Andale Mono. Fonts are referenced, not redistributed. All copy is typeset, not image-generated. No image tool was called, no refusal occurred, no garbled text.','## Graphic and build specification','A010 Remnant language: ivory #eee9d9, ink #171b1c, yellow #f5cc24, restrained red #aa302d, dark surround #12191c. Clipped 16 px corners, crisp dividers, condensed headings, plain body and monospaced evidence. No speculative new company logo. No combat artwork, grime, fake scan codes or baked scene background. A005 suit-OS informs terse evidence labels and administrative grouping.','Screen safe area: 56 px sides, header to y=126, title y=152, content begins y=244; footer y=1033. Body 23–30 px; primary headers 72 px. A012-04 is an engineering diagram: 17 px field labels, 20 px library entries. Scale UI as a layout rather than stretching a PNG. These are layout references, not shipped UI textures.','Repeated ledger rows: preserve description, quantity × rate and right-aligned CR columns. Variable lists scroll within their panel when longer than the example; keep gross/net, total due and actions pinned. Wrap labels to two lines and increase row height; never shrink player copy below 23 px. Empty hazards: “No hazards confirmed.” Empty salvage: “No recoveries recorded.” Crew supports 1–4 rows. Missing values render “Not recorded”; a real recorded zero stays 0. Negative net pay displays a minus sign and label “NET PAY / BALANCE DUE”; no silent clamping. No continue button is specified for the death screen; navigation belongs to a later build packet.','## Evidence boundary and proposed inputs','The packet requires data absent from the current CONTRACT.md. The layouts are buildable proposals, not a claim that these fields already exist. This does not block layout review. All fixture names, hazards, credits, rates and return status are illustrative. A012-02 is a successful-return fixture; A012-03 is a separate fatal fixture, not the same run. The current log has no successful extraction outcome, so `ended=quit` must never imply returned.','**C / existing:** `started_at`, `ended`, `time_alive_s`, `shots_fired`, `shots_hit`, `damage_by_source.{spit,puddle,lunge,rifle}`, `hits_in_cover`, `hits_in_open`, `times_protected`, `killed_by`, `time_locked_s`, `shots_blocked_for_you`, `your_shots_blocked`. `ended` is death/respawn/quit. It has no death location, oxygen usage, equipment inventory or monetary values.','**P / contract metadata proposed:** `contract.id`, `contract.vessel_name`, `contract.status`, `contract.estimated_value_cr`, `contract.known_hazards[].{description,location}`, `contract.crew[].{name,role}`, `contract.contractor_name`, `contract.next_of_kin`. Hazards must come from actual discovered intel; do not reveal unobserved threats. `contract.status` example is “probably abandoned”. Fixed liability clauses remain fixed for this design.','**P / event and settlement inputs proposed:** `salvage[].{label,quantity,unit_value_cr}`, `airlock_cycles` (completed cycles only), `death.location` (room at lethal hit), `equipment_unreturned_cr` (ledger valuation), `settlement.status` (authoritative returned/not-returned, not guessed from quit), `invoice.id` (account metadata). Without these, hide affected charge rows, label missing metadata “Not recorded”, and show totals as “Pending records” if monetary inputs are incomplete. Do not replace absent data with fabricated charges.','**D / presentation fields:** `killer = killed_by.stalker ?? killed_by.pirate ?? "Not recorded"`; `method = killed_by.how` verbatim, fallback “Not recorded”. The CONTRACT lists source keys, not guaranteed `how` vocabulary: a code task must explicitly map recorded values; unknown values display verbatim and use unclassified copy, never guess from damage totals. `started_at` may be displayed in future but is not a changing field on these layouts.','**D / accounting fields:** `credits[].amount_cr = quantity × unit_value_cr`; `gross_cr = sum(credits[].amount_cr)`; `deductions[].{label,quantity,unit,rate_cr,amount_cr}` from selected fee rule; `deductions_total_cr = sum(deductions[].amount_cr)`; `net_cr = gross_cr - deductions_total_cr`; `death_bill.lines[].{label,amount_cr}` from approved rules; `outstanding_cr = sum(death_bill.lines[].amount_cr)`. CR uses integer arithmetic. Format thousands with commas; totals omit a plus sign, credit rows show +, deduction rows show −. `time_alive_s` displays floor(seconds) as mm:ss, hours when needed. Oxygen billed quantity is ceil(time_alive_s/60), not HUD oxygen remaining.','**Proposed rates:** `rates.suit_shift_cr=640`, `rates.round_cr=20`, `rates.oxygen_min_cr=20`, `rates.cycle_cr=50`, `rates.morale_shift_cr=280`. Fatal fixture: `rates.posthumous_cr=180`, `equipment_unreturned_cr=1640`, `rates.cleanup_cr=420`; apply only when `ended=death` is supported by the death invoice flow. All other library rates are intentionally unset (`rate`) pending approval. No fees or debt are implemented. Amounts express potential choices: time, ammunition, routes, salvage and risk affect the settlement.','## Full player-facing copy']
shared=['REMNANT / ASSET RECOVERY','EVERYTHING HAS A SECOND OWNER.','INDEPENDENT RECOVERY CONTRACTOR / REMNANT ACCOUNTS']
h+=['Shared header/footer:\n```text\n'+'\n'.join(shared)+'\n```']
for id,copy in transcripts.items():
 h+=['### '+id,'```text\n'+'\n'.join(copy)+'\n```']
 if fields[id]:h+=['Changing fields (every other printed string is fixed):\n'+', '.join('`{'+s+'}`' for s in fields[id])+'.']
h+=['## Twenty deduction lines — full copy and triggers','C means existing telemetry can drive quantity/eligibility; prices are proposed. P means extra event data is required. Nonzero quantities only, unless a per-shift rule explicitly applies. These are a library, not twenty simultaneous charges. Select a coherent approved tariff; do not stack ammunition with miss/impact/obstruction charges or overlapping inspection fees by default. Morale is the packet’s required fixed per-shift fee, not a morale counter. No behavioural score is inferred.','| # | Line / supporting copy | Eligibility or quantity | Input |','|---|---|---|---|']
for i,(label,tr,state,copy) in enumerate(deductions):h.append(f'| {i+1:02} | **{label}** — {copy} | `{tr}` | {state} |')
h+=['## Fifteen death-bill causes and context variants — full copy','All require `ended=death`. Pick one primary cause (01–05), one killer descriptor (06–07, if known), and at most one context line (08–14). Variant 15 replaces primary cause when `killed_by` is null. 08–14 describe the recorded damage history or prior protection; they never assert the fatal blow or position at death. Each variant is exclusive within its group, uses fixed priority 01→15 within that group, and may be suppressed after repeated use by a future presentation layer. No fee amount is inferred from a cause label.','| # | Cause/context heading | Predicate | Exact supporting copy |','|---|---|---|---|']
for i,(label,pred,copy) in enumerate(causes):h.append(f'| {i+1:02} | {label} | `{pred}` | {copy} |')
h+=['Location remains “Not recorded” until a location event exists. A known killer with a missing/unknown method uses 05. A missing killer uses 15. Unknown killer types display the available evidence without assigning stalker/pirate. Absence of telemetry cannot establish suffocation, friendly fire, decompression, being abandoned by crew or any other unrecorded cause.','## Three favourite lines','1. **Cover does not imply coverage.**\n2. **Unrecovered rounds remain sold.**\n3. **Evidence unavailable. Balance available.**','## Verification and scope','All four PNGs decoded and dimensions checked; review sheet and originals visually inspected for clipping and hierarchy. Arithmetic fixtures checked (2,480 − 2,470 = 10; 180 + 1,640 + 420 = 2,240). No game code, scenes, data, tests or tools changed. No legacy source assets touched, no source asset IDs reused, and no git commands run. Only the new A012 source folder, A012 review folder and this handoff were written.','Pending human gate: approve layouts and copy (including proposed tariffs and telemetry additions) before a code build packet. No additional human decision was required to prepare this review.']
handoff='\n\n'.join(h)+'\n'
while '|\n\n|' in handoff: handoff=handoff.replace('|\n\n|','|\n|')
(ROOT/'docs/handoffs/auto-A012.md').write_text(handoff)
# Basic artifact and content integrity checks.
assert len(deductions)==20 and len(causes)==15
assert 1600+4*160+2*120==2480
assert 640+46*20+math.ceil(1104/60)*20+5*50+280==2470
assert 180+1640+420==2240
for i in range(1,5):
 with Image.open(OUT/f'A012-0{i}.png') as check: assert check.size==(1920,1080);check.verify()
print('Wrote four 1920x1080 screens, prompts, review sheet, handoff; accounting and image checks passed.')
