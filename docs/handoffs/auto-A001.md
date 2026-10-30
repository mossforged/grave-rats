# A001 — Crew and threat exploration

Status: complete — 15 source images, 15 adjacent prompt files, and labelled review sheets delivered. John's direction-pick gate remains open. No art is approved for game import.

All source concepts and exact generation prompts: `assets/source/A001-crew-threat/A001-NN.png` and `A001-NN.prompt.md`. Generated with built-in ImageGen, one call per asset. Crew camera studies and key art use `docs/screens/A001/crew-reference.png` for identity and the project's C001 concept sheet for camera/mood. The crew-reference board is a deterministic labelled montage of 01–06.

## Image ideas

- **A001-01 — Orange hauler:** broad rounded work suit, low wide pack, tow hook and powered salvage tool; rental-property stamp makes the worker's economic position visible.
- **A001-02 — Yellow cutter:** lean silhouette, welding helmet, twin cylinders and long cutting lance; “PAY PER CUT” turns basic work equipment into a fee joke.
- **A001-03 — Teal heavy rig:** oversized tall rectangular life-support pack and load frame; “AIR ON CREDIT” makes survival another financed expense.
- **A001-04 — Red medic-scrounger:** dirty off-white suit with red crown, medical hip boxes and a battered trauma bag; “CARE / METERED” sells care by the unit.
- **A001-05 — Cobalt drone tech:** two inspection drones on a fork pack and a handheld terminal make a distinct upper silhouette; “SUPPORT / EXTRA” carries the satire.
- **A001-06 — Violet shipbreaker:** flattened helmet, work apron, salvage basket and gripping tool; “DEPOSIT LOST” suggests gear held together long after its warranty.
- **A001-07 — Neutral overhead study:** all six designs spaced on a plain deck to compare helmet accents and pack footprints from above.
- **A001-08 — Ship-lighting overhead study:** all six in connected medbay/cargo corridors, testing the same identities under cool-white and amber practicals.
- **A001-09 — Rogue ship AI:** synchronized sensors, drones, turret and closing doors turn ship infrastructure into the enemy and constrain escape routes.
- **A001-10 — Security robots:** heavy industrial restraining machines and inspection lights threaten a cargo lane; “SAFETY FIRST” reads as institutional menace.
- **A001-11 — Acid stalker:** a low plated alien threatens a cool-white medbay while orange and red workers crouch behind an overturned examination table.
- **A001-12 — Suit-wearing horror:** a slack empty-visored suit with wrong joints and subtle tendrils occupies a threshold; the surrounding empty suits make recognition uncertain.
- **A001-13 — Rival pirates:** matched cream/graphite gear, gold accents and immaculate packs contrast with our crew's repairs; “PRIOR CLAIM” and “RECOVERY FEE” frame theft as business.
- **A001-14 — Wildcard scrap predator:** a crane-legged crusher assembles itself from ship scrap, oxygen cylinders and cable, making salvage hunger physically threatening.
- **A001-15 — Key art variant:** the orange hauler, yellow cutter, red medic and teal rig inhabit the reference's medbay–corridor–cargo arrangement with engineering cyan below.

## Recommendations and review notes

**Top crew pick: A001-01, orange hauler.** Its broad outline, bright helmet crown and heavy salvage gear communicate a grubby worker quickly, including from overhead.

**Top threat pick: A001-11, acid stalker.** The medbay doorway, acid hazard and overturned table directly express deliberate combat built around cover and position.

A001-09 is the strongest complementary systemic direction: much of its menace could come from ship machinery and lighting rather than a new articulated character.

Orange and yellow carry best through the mixed lighting in 08. Teal relies on its tall pack as well as color; violet loses separation under amber lighting. Preserve overhead color blocks if these advance. Front views share canvas size and broadly comparable framing, but generated poses and pack heights are not calibrated model scale. Camera studies are concept approximations of the 55–65 degree target, not measurements from the future T002 rig. They depict six candidates for comparison, not a proposed six-player mode.

Generated suit stencils are decorative: some digits/letterforms drift (notably the wildcard), and asset filenames are the authoritative IDs. Small text and surface noise should be simplified for gameplay. Threats 10 and 13 use somewhat closer dramatic framing than the gameplay reference. These remain direction concepts, not final sheets, turnarounds, rigs, textures or production-ready geometry.

## Review artifacts and validation

- `docs/screens/A001/crew.png`: labelled 01–08, 1800×1880.
- `docs/screens/A001/threats.png`: labelled 09–15, 1800×3000.
- `docs/screens/A001/sheet.png`: labelled overview of all 15, 2100×1260.
- `docs/screens/A001/build-sheets.py`: deterministic Pillow montage recipe; contains no image generation or changes to source art.
- `docs/screens/A001/crew-reference.png` and `threats-review.png`: supporting inspection montages.

Refused or skipped images: none.

Validation: opened and visually inspected all concepts through full-image views and inspection montages, inspected the final crew/threat/overview sheets, verified all 15 PNG files decode, and confirmed the exact 01–15 filename set with 15 adjacent nonempty prompt files. Source dimensions: 01–06 are 1254×1254; 07–14 are 1536×1024; 15 is 1774×887. No packet-specific pixel sizes were specified; review dimensions above were chosen to keep labels readable. Generation remained at original output resolution without source resampling.

## Human gate — stop here

John must pick crew looks and threat directions to develop. The recommendations above do not select on his behalf. Stop after this exploration; no final character development, 3D work or game import is authorized by this packet. No git commands were run; changes are confined to the packet's new source folder, review folder and this handoff.
