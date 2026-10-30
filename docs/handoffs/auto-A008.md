# A008 — Hauler A-pose for rigging

Completed 2026-10-30 using the built-in image_gen tool. Four selected full-figure input images and their exact prompts are saved. No image requests were refused. No human decision is blocking this packet.

## Deliverables

All four delivery PNGs are opaque RGB, 1254 × 1254 pixels:

- `assets/source/meshy/input/hauler-apose-front.png`
- `assets/source/meshy/input/hauler-apose-side.png` — selected revision **A008-sideb**, deliberately near-side rather than a strict profile.
- `assets/source/meshy/input/hauler-apose-back.png`
- `assets/source/meshy/input/hauler-apose-34.png`

Each has the matching `.prompt.md` beside it, with exact prompt, reference order and tool recorded. Use these four files together; the old relaxed-pose hauler images remain untouched.

Review sheet: `docs/screens/A008/sheet.png`, 1680 × 1850 pixels, labeled 2 × 2 layout with each input displayed at 780 × 780. The packet specifies no sheet dimensions. Labels are confined to the review sheet; input images contain no added labels or guide lines.

## View consistency

The views match the same recognizable hauler: chipped orange helmet and shoulder armor, opaque black visor, dirty ivory pressure suit, dark harness, ivory chest pouch, compact ivory/orange backpack, close neck hose, fitted utility belt, asymmetric knee/shin/thigh equipment and orange/black gloves and boots. Front A-pose was generated first and supplied as the pose/design reference for all other views. Original front/side/back images and A005-01b were inspected before generation.

Large equipment placement, colors and silhouette are consistent. These are generated views rather than exact projections of a shared mesh: scratches, fabric folds, small fasteners and pouch details vary. The revised side stance is slightly wider to expose both legs. The side camera is oblique (prompted approximately 50° from front); it shows backpack depth and helmet profile while avoiding the limb overlap inherent in a strict side projection of a frontal A-pose. Do not treat it as an orthographic measurement drawing.

## Gap / pose inspection

| View | Arms and gloves | Legs |
| --- | --- | --- |
| Front | Clear background wedges under both arms; both gloves well outside hip and thigh equipment. | Open background channel below crotch through knees to boots. |
| Back | Clear underarm wedges and glove-to-hip separation on both sides. | Open channel between thighs, knees and boots. |
| Near-side, A008-sideb | Both gloves clear of the hip/pouch silhouette; visible background between forearms and torso, narrower on the far side. Shoulder roots remain naturally attached. | Corrected to expose a continuous background channel below crotch through mid-thighs, knees and boots; narrower than front/back. |
| Three-quarter | Both hands and forearms independently readable and clear of hip/thigh gear. | Visible background channel between legs down to boots. |

Arms extend approximately 45° out/down with nearly straight elbows; hands are open with fingers grouped and hold nothing. Legs are straight in a stable spread stance. Hose stays close to neck/shoulder. Belt tools and clips stay against the body rather than crossing the limb gaps. Each image contains one whole centered figure, light-grey studio background and soft lighting. The generated backgrounds retain slight studio tonal variation and subtle floor shadows.

## Revision provenance

The initial near-side attempt closed the projected thigh gap and was rejected during visual QA (not a tool refusal). It is archived as `assets/source/A008-hauler-apose/A008-side.png` with `A008-side.prompt.md`; **do not use this draft for Meshy**. A targeted edit opened the leg gap. The selected revision is retained as `assets/source/A008-hauler-apose/A008-sideb.png` with `A008-sideb.prompt.md`. The packet-required `hauler-apose-side.png` and its prompt are delivery copies of that revision, not an additional design or reused revision ID.

## Validation and scope

Inspected each generated image and the assembled contact sheet. Decoded the PNGs and checked dimensions, prompt presence and the selected side-copy identity. No Meshy reconstruction or rig was run, so deformation quality remains to be assessed on the resulting model.

No git commands were run. No game files, original hauler references, legacy assets or project tools were modified. Outputs are confined to the packet's image destinations, a new A008 source archive, its review folder and this handoff.
