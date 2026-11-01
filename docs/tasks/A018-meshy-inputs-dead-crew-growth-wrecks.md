# A018 - Meshy input images: dead crew, infestation, wrecked machines (art)

**Read:**
- `AGENTS.md`;
- `docs/tasks/A007-meshy-input-images.md` (the input rules that worked);
- `assets/source/meshy/input/` (existing inputs: the hauler A-pose, the rival, the drone, the loader);
- `docs/screens/A014/sheet.png` (the survey vessel: "containment outlived the crew");
- `docs/screens/A015/sheet.png` (A015-17 Mother Culture, for the growth's look);
- `docs/screens/props/meshy_batch1_preview.jpg` (the drone and loader as built).

**Needs:** nothing.
**Autonomy:** auto-ok (input images; John approves the Meshy spend and judges the 3D results).

The lead will turn these into 3D models through the Meshy API, after John OKs the credits. Each model needs clean views of **one object**.

## Rules (as A007)
- One object, whole and centred, on a flat light-grey background, with soft even studio light.
- No text, labels, dimension lines or scenery.
- **Four views of the same object in the same pose:** front, side, three-quarter and back. These are static models, so the pose *is* the model, and all four views must match it exactly. Make the three-quarter view first, then edit only the camera for the others.
- Save to `assets/source/meshy/input/` as `<name>-front.png`, `-side.png`, `-34.png` and `-back.png`, each with a `.prompt.md`.
- **If an image is refused, record the refusal and move on. Don't reword and retry it.**

## Do
1. **Dead crew (static, non-graphic).** Use the hauler-style salvage suit, recoloured to a faded generic crew grey-blue: this ship's dead crew, not ours. Dark opaque visor, no face, no wounds, no blood. It reads as an empty, still suit. Four poses:
   - `crew_dead_sitting`: slumped sitting against a wall, legs out, head bowed, arms limp;
   - `crew_dead_prone`: face-down on the floor, one arm reaching forward;
   - `crew_dead_bunk`: half out of a bunk, as one object with a simple bunk frame;
   - `crew_cryo_occupant`: a suited figure upright with arms crossed, to sit inside the cryo pod.
2. **Infestation for the survey vessel** (organic, the A015-17 Mother Culture look: translucent, veined, sickly green-yellow):
   - `growth_wall_patch`: a flat-backed growth spreading over a wall panel, about 1.5 × 1.2 m, a few cm to 25 cm proud;
   - `growth_egg_cluster`: a cluster of five to eight leathery pods on a fleshy base, about 0.8 m across;
   - `specimen_floating`: a small curled alien specimen to float inside a tank (pale, embryo-like, not gory);
   - `specimen_dissected`: a dead quadruped specimen lying on its side for the autopsy table, closed, no exposed innards, with a sheet partly over it.
3. **Wrecked machines** (from the built models' look in `meshy_batch1_preview.jpg`; one object each, settled on the ground):
   - `drone_wreck`: the CUSTODIAN patrol drone flipped on its side, one wheel off, panels caved, lens cracked and dark;
   - `loader_wreck`: the loader slumped forward, one claw arm torn off and lying beside it as part of the same object, lamps dark;
   - `security_bot_gutted`: an older security robot (A015-06 Term Enforcer style) sitting broken against a wall, chest panel open showing simple dark machinery.
4. **Contact sheet** at `docs/screens/A018/sheet.png`: every object in four views, labelled.

## Acceptance
- The images and prompts, plus the sheet.
- `docs/handoffs/auto-A018.md`:
  - a line per object: generated or refused (with the refusal text), and whether the four views truly match;
  - suggested target sizes in metres for each, for the lead's Meshy settings.
