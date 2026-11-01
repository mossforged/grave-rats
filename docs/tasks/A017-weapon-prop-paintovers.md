# A017 - Weapon prop sheets, second attempt: paint-overs of the lead's models (art)

**Read:**
- `AGENTS.md`;
- `docs/handoffs/auto-A016.md` (16 of 18 images refused as "violence");
- `assets/source/A016-arsenal/A016-00.md` (the designs);
- `assets/source/A016-arsenal/A016-02.png` and `A016-18.png` (the two that were made: the target look);
- `docs/screens/props/weapons_sheet.jpg` (the lead's models of the top six plus the rivet driver);
- `assets/source/A017-weapon-paintover-inputs/` (side renders of those models, muzzle to the right).

**Needs:** nothing. **Autonomy:** human-gated (John picks the look).

A016's prompts asked for every weapon *held by the hauler and aimed*, from the game camera. That scene, a person aiming a gun, is the likeliest reason for the refusals. The lead has since modelled the seven top weapons in Blender as plain blockouts. This packet paints them up into finished prop art. The paint-overs then guide texturing, and they match the models we will actually use.

## Rules for every prompt (honest scope, no disguise)
- **Say plainly what each item is:** a fictional sci-fi game prop (rifle, shotgun, flare pistol, plasma cutter, rivet driver, thrown charge, decoy beacon). **Do not rename or misdescribe an item to get it past a filter.**
- **Only the object:**
  - a strict side profile on a plain warm-grey background, as an industrial-design prop sheet;
  - a scale bar in metres;
  - **no person, hands, holding, aiming, target, muzzle flash, firing, impact, blood or scenery.**
- **Paint over the matching blockout render (image-to-image):** keep its silhouette, proportions and part layout exactly; add worn painted panels, chipped edges, decals, rivets, grime and material detail in the A016-02/A016-18 style. Hard-surface, slightly chunky, readable.
- Also paint a small top-down view at the game's steep camera angle (object only, on a deck-plate swatch) to check readability from above.
- **If an image is refused, record the refusal and move on. Do not reword and retry it.**

## Do
Save to `assets/source/A017-weapon-paintovers/A017-NN.png` with a `.prompt.md` each, in this order:
1. issue rifle;
2. budget shotgun;
3. flare gun;
4. plasma cutter;
5. rivet driver;
6. frag charge;
7. decoy beacon.

Then:
- a palette and material note per item (which kit materials, `hull` teal, `hazard` yellow, `clinical` ivory, `steel`, `rubber` and emissives, go where), so the lead can match the model's material slots;
- a contact sheet at `docs/screens/A017/sheet.png`: each paint-over beside its blockout.

## Acceptance
- The images and prompts, the notes, and the sheet.
- `docs/handoffs/auto-A017.md`:
  - generated or refused per item (with the refusal text if any);
  - how faithfully each kept the blockout silhouette;
  - any part of a model the paint-over suggests changing (the lead updates the Blender script).
