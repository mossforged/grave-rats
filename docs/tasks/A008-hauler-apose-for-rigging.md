# A008 - Hauler in a clean A-pose, for rigging (art)

**Read:** `AGENTS.md`, `assets/source/meshy/input/hauler-front.png`, `hauler-side.png`, `hauler-back.png`, `assets/source/A005-dev/A005-01b.png`. **Needs:** nothing.
**Autonomy:** auto-ok (an input image; John judges the 3D result).

John's Meshy hauler rigged badly: when the limbs move, big stretched sheets of texture tear between the hands and the thighs, and between the arm and the legs. The source pose is the cause. The arms hang close to the body, and the gloves sit right against the thigh pouches, so Meshy builds one fused skin there, and the auto-rig can't tell hand from hip.

## Do
Redraw the same hauler, with the same suit, colours and gear, in a **rigging pose**. Save to `assets/source/meshy/input/` as `hauler-apose-front.png`, `-side.png`, `-back.png` and `-34.png`, each with a `.prompt.md`.
- Arms out at about 45° from the body, elbows nearly straight; **a clear gap of background between each arm and the torso, and between the gloves and the hips, pouches and thighs**.
- Hands open, fingers together, palms down; nothing held.
- Legs straight, feet shoulder-width apart, **a clear gap between the legs** down to the boots.
- Belt pouches and tools stay tight to the body, with nothing dangling into the arm or leg gaps. Keep the helmet hose tight to the shoulder.
- The same studio rules as A007: one whole figure, centred; a flat light-grey background; soft even light; no text or lines.
- A contact sheet `docs/screens/A008/sheet.png`.

## Acceptance
- Four images with prompts, plus the sheet.
- `docs/handoffs/auto-A008.md`: whether the views match, and whether the gaps are clean in every view.
