# A018 — Meshy input images: generation delivered; exact-view acceptance blocked

2026-10-31. Built-in imagegen used. No git commands, Meshy API calls, credit spend, game imports, or edits outside the art/report lanes.

## Deliverables and acceptance

- 44 current PNGs: `assets/source/meshy/input/<name>-{front,side,34,back}.png`, each with a sibling `.prompt.md` recording the actual prompt and reference.
- Labelled review sheet: `docs/screens/A018/sheet.png` (2048 × 4930); smaller `sheet-preview.jpg`; reproducible layout script `build_sheet.py` beside it. Columns denote the requested camera, not a guarantee that generation achieved it.
- ID/name/size manifest: `assets/source/meshy/input/A018/manifest.json`.
- Ten superseded draft PNGs and their original prompts are retained in `assets/source/meshy/input/A018/`. These are NOT current Meshy candidates. The orange prone drafts were quality rejects, not policy refusals.
- All 44 current PNGs decoded successfully and all 44 prompts exist. Every generated view was visually inspected; the contact sheet was rendered and inspected. No game tests apply to these input images.

**Not a full acceptance pass:** generated images do not guarantee one frozen 3D object across camera edits. None of these sets can be certified as an exact four-view geometric match. Sitting crew and cryo occupant are the strongest approximate sets. Do not batch-submit all four views of the failing sets as though they were consistent.

**John decision required; stopping:** choose whether to proceed with selected three-quarter images as single-view Meshy drafts (separate credit approval still required), or commission a fixed-geometry modelling/render pass to obtain genuinely matching views. Recommendation: use fixed geometry for the wrecks and covered specimen; their limb/detached-part identity is important. No Meshy spend has been initiated.

## Per-object results and target sizes

Sizes below are suggested finished world-space bounding boxes in **width × height × depth, metres**, including the static pose, bunk and detached parts. They are not camera-space pixel dimensions. Meshy settings exposing only one size should use the largest dimension, followed by axis verification. Standing crew source scale is about 1.9 m suited height; crew anatomy should remain consistent when posing.

| ID / filename stem | Result | Do the four views truly match? | Suggested W × H × D (m) |
|---|---|---|---|
| A018-01 / `crew_dead_sitting` | Generated 4/4; no refusal | Approximate pose match, **not exact**. Legs out, bowed helmet, limp arms and grey-blue suit hold. Pack hardware, wear, proportions and camera elevation vary. | 0.95 × 1.15 × 1.65 |
| A018-02b / `crew_dead_prone` | Generated 4/4; no refusal. Original orange 34/front drafts archived; b uses sitting suit as colour reference. | **Not exact**. Reaching left arm and belly-down pose hold broadly; helmet is raised rather than fully face-down. Pack and limb spacing differ. | 0.85 × 0.55 × 2.25 |
| A018-03 (side/back b) / `crew_dead_bunk` | Generated 4/4; no refusal. Side/back camera corrections saved. | **No**. Body hangs over the head end rather than the requested long edge. Corrected side is head-end camera; front is long-side camera, back opposite long side but still oblique. Frame rails, hose count and body placement vary. Treat the 34 as a composite concept only. | 1.00 × 1.25 × 2.15 |
| A018-04 / `crew_cryo_occupant` | Generated 4/4; no refusal | Strong approximate pose match, **not exact**. Upright crossed arms and feet together hold; pack panel and small hardware change. No pod included. | 0.80 × 1.90 × 0.65 |
| A018-05 (side/back b) / `growth_wall_patch` | Generated 4/4; no refusal. Repeated-front side/back attempts archived and corrected. | **Not exact**. Corrected side is shallow edge-on; corrected back shows metal backplane. Front/34 maintain large left lobe and right panel; rear contour and roots vary. Use maximum proud depth 0.25 m, not a freestanding bulky mass. | 1.50 × 1.20 × 0.25 |
| A018-06 / `growth_egg_cluster` | Generated 4/4; no refusal | **No**. Front shows six pods, but other angles show five visible pods with uncertain occlusion and changed arrangement/root base. Not a provable six-pod turntable. Material direction is consistent. | 0.80 × 0.65 × 0.75 |
| A018-07 / `specimen_floating` | Generated 4/4; no refusal | **No**. Compact curled alien and pale veined surface hold, but front/side/34 mostly repeat a flank; back shows the opposite flank rather than true posterior. Missing end-on coverage; limb details vary. No tank/stand. | 0.35 × 0.55 × 0.30 |
| A018-08 / `specimen_dissected` | Generated 4/4; no refusal | **No; major failure**. Front edit rolls/reposes the animal and invents bilateral tail-like forms. Side/back remain oblique and change head/limbs/sheet. Body stays closed and non-graphic. 34 is the only pose authority; it also reads more armoured than leathery. | 0.65 × 0.45 × 1.25 |
| A018-09b / `drone_wreck` | Generated 4/4; no refusal. Original insufficiently tipped set archived; entire current set revised from tipped 34. | **No**. Revised pose stays tipped, lens/spotlight dark, three attached wheels plus one loose wheel broadly hold. Front and side remain oblique and similar; rear invents a large louvre layout. Damage, axle positions and detached wheel relationship vary. | 1.25 × 1.00 × 1.50 |
| A018-10 / `loader_wreck` | Generated 4/4; no refusal | **No; major failure**. Torso insufficiently slumped. Front/34/back show detached right arm beside track, but side appears to restore attachment and changes arm pose. Lamps dark; ivory/teal tracked design holds. | 2.20 × 1.60 × 2.10 |
| A018-11 / `security_bot_gutted` | Generated 4/4; no refusal | Approximate seated pose, **not exact**. Open chest holds where visible. Front straightens the torso, side changes feet/hand positions, rear changes lean and panel geometry. No wall or weapon. | 1.15 × 1.15 × 1.70 |

## Refusals and technical notes

No image was refused. There is therefore no refusal text to report, and no refused request was reworded or retried. The first call failed before generation because a reference path was relative; supplying its absolute path resolved the tool argument error. Later revisions addressed visible quality/camera failures, not refusals.

Read AGENTS.md, STATUS, game brief, style contract, asset contract, A007 and A018. Inspected A014/A015 review sheets, built-model batch preview, and existing hauler/rival/drone/loader inputs. Assets use no real brands, celebrity likenesses or other games' characters. Generic grey-blue crew suits contain no visible face, wounds or blood.

Prompts retain their per-view IDs: b labels identify camera/colour revisions, while unsuffixed packet-style filenames remain the requested intake names. Do not use archived first-pass files to fill missing angles. Backgrounds are opaque light-grey studio renders with soft contact shadows; no baked labels or dimensions. Their lighting has some gradient, so strict flat-background cleanup would be a further pass.

Stop condition reached at review: John must choose the next route before Meshy spend or treating these drafts as approved reconstruction inputs.
