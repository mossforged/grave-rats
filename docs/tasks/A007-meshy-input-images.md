# A007 - Clean input images for Meshy image-to-3D (art)

**Read:** `AGENTS.md`, `docs/handoffs/meshy-shortlist.md`, and the source images it lists: A001-11 (stalker), A002-05 and A006-07b (bed, console), A001-01 and A005-02 (suit and gear). **Needs:** nothing.
**Autonomy:** auto-ok (input images; John judges the 3D results).

John will build a few models in Meshy (image-to-3D). Meshy needs **one object per image**, on a plain background, with nothing cropped or overlapping. Our sheets are scenes, multi-view boards or dimension drawings, so they don't work as inputs. The hauler is already done: `assets/source/meshy/input/hauler-{front,back,side}.png`, cropped from A005-01b.

## Do
For each model, make a **front three-quarter view** and, where you can keep the design identical, **front, side and back** orthographic views. Rules:
- one object, whole and centred;
- a flat light-grey background and soft even light, with no dramatic shadows, fog, glow or motion;
- no text, labels or dimension lines, and no people or other props.

Save to `assets/source/meshy/input/` as `<model>-34.png`, `<model>-front.png`, `<model>-side.png`, `<model>-back.png`, each with a `.prompt.md` beside it.
1. **stalker:** the acid stalker from A001-11, standing in a neutral four-legged pose, mouth closed, no acid spray.
2. **bed:** the medical bed from A002-05 and A006-07b, **upright**, with a solid, plated underside (that side becomes the shield when tipped).
3. **console:** the med console from A006-07b (1.4 × 1.1 × 0.6 m), screen dark.
4. **rifle:** a chunky industrial salvage carbine in the A001/A005 style (worn, taped, a flashlight under the barrel), side view plus three-quarter. No real-world brands or exact real-gun copies.
5. A contact sheet `docs/screens/A007/sheet.png`.

## Acceptance
- Up to 16 images, at least the three-quarter view for each model, with prompts and the sheet.
- `docs/handoffs/auto-A007.md`: a line per image, whether its views match each other, and anything refused.
