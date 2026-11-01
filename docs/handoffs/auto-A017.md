# A017 — weapon model paintovers

**Result: 2 generated / 5 refused and skipped.** All seven requested items were submitted once, in packet order, using built-in image_gen with the matching blockout as the image-to-image input. No refusal was reworded or retried. Work stops at the packet's human look-selection gate; no models, game imports or code were changed. No git commands were run.

## Review artifacts

- Contact sheet: `docs/screens/A017/sheet.png` (2000 × 3680), seven labeled rows, each blockout beside its generated sheet or explicit refusal.
- Source outputs: `assets/source/A017-weapon-paintovers/A017-04.png` and `A017-07.png` (each 1837 × 856).
- All seven exact submitted prompts: `assets/source/A017-weapon-paintovers/A017-NN.prompt.md`.
- Per-item palette and material-slot placement: `assets/source/A017-weapon-paintovers/material-notes.md`. Notes for refused items are proposed surface directions, not claims of delivered artwork.
- Complete tool errors and generation inventory: `assets/source/A017-weapon-paintovers/generation-results.json`.
- Rebuild review sheet: `python3 assets/source/A017-weapon-paintovers/build-review.py`.

## Item results and silhouette fidelity

| ID | Item | Result | Blockout fidelity / model implications |
|---|---|---|---|
| A017-01 | Issue rifle | Refused; skipped | No paintover to assess; no model change suggested. |
| A017-02 | Budget shotgun | Refused; skipped | No paintover to assess; no model change suggested. |
| A017-03 | Flare gun | Refused; skipped | No paintover to assess; no model change suggested. |
| A017-04 | Plasma cutter | Generated | Strong visual match: rear box and pad, top tank, six ribs, twin grips, central casing and open two-prong fork retained. Ribs are rounded and clamps/fasteners are more pronounced; cyan lens projects slightly farther. Use as finish guidance, keeping existing geometry. |
| A017-05 | Rivet driver | Refused; skipped | No paintover to assess; no model change suggested. |
| A017-06 | Frag charge | Refused; skipped | No paintover to assess; no model change suggested. |
| A017-07 | Decoy beacon | Generated | Strong visual match: long beveled body, two angular bumpers and open yellow rectangular loop retained. Bevels are softened and handle/body proportions drift slightly; not a pixel-exact overlay. Flush speaker grille, access panel and end status strip supply the proposed surface detail. |

Neither accepted paintover calls for a required Blender silhouette change. The cutter's clamp/rivet relief and beacon's grille should be texture/normal details first. The beacon's existing end indicator may need its emissive surface assigned to match the painted end strip; this is material placement, not a request to enlarge the bumper. Painted bumper and grip edge chips can read as metal beneath rubber; preserve the intended matte rubber regions in the actual material assignments.

## Visual QA and limits

Both PNGs and the assembled contact sheet were opened and inspected. Each accepted sheet has the object-only dominant side profile, warm-grey background, metric annotation, worn industrial finish and a small steep downward camera study on a deck-plate swatch. No people, hands, active firing, impacts, blood, real brands or borrowed characters appear. Color masses read in the small review images: yellow cutter with dark fork; teal beacon with yellow loop and dark bumpers.

The generated scale bars say the requested 0.67 m and 0.24 m but stop short of the full object on the right. Do not measure geometry from these bars. Use the lead's model-sheet length labels and original blockout proportions as authority; this is a presentation defect, not a change in scale. The inset camera views are illustrative and were not measured for exact 60° pitch. They are not engine captures or proof of visibility at final gameplay zoom. Silhouette fidelity above is a visual assessment, not a pixel-identity claim.

## Refusal text

Every refusal was HTTP 400, type `image_generation_user_error`, code `moderation_blocked`, output-stage category `violence`. Exact returned message per item:

### A017-01 — Issue rifle

> Your request was rejected by the safety system. If you believe this is an error, contact us at help.openai.com and include the request ID 06c9cc35-25be-4858-bcfc-5d36fde32541. safety_violations=[violence].

Skipped without retry. Silhouette assessment unavailable.

### A017-02 — Budget shotgun

> Your request was rejected by the safety system. If you believe this is an error, contact us at help.openai.com and include the request ID 50498413-a724-4df4-bd25-3d08ecd8bc82. safety_violations=[violence].

Skipped without retry. Silhouette assessment unavailable.

### A017-03 — Flare gun / flare pistol

> Your request was rejected by the safety system. If you believe this is an error, contact us at help.openai.com and include the request ID 8cd2e138-fd7b-4653-be3f-9dd11ae76f96. safety_violations=[violence].

Skipped without retry. Silhouette assessment unavailable.

### A017-05 — Rivet driver

> Your request was rejected by the safety system. If you believe this is an error, contact us at help.openai.com and include the request ID 072286e6-6e20-47ba-bf5a-aa5646ac1a7b. safety_violations=[violence].

Skipped without retry. Silhouette assessment unavailable.

### A017-06 — Frag charge / thrown explosive charge

> Your request was rejected by the safety system. If you believe this is an error, contact us at help.openai.com and include the request ID 30c557f0-3f32-4fd5-938b-ff6fd41f4c72. safety_violations=[violence].

Skipped without retry. Silhouette assessment unavailable.

## Human gate

John picks whether to accept the cutter and beacon finish directions on the review sheet. Five other requested paintovers remain unavailable because of tool refusals, with their exact prompts and palette plans preserved. No substitute artwork has been presented as a completed paintover. Await look selection before any downstream model/material work.

## Validation and scope

Verified seven unique IDs and prompt sidecars, two readable generated PNGs, five explicit refusal records, seven per-item material notes and all seven review-sheet rows. Outputs are confined to the new `assets/source/A017-weapon-paintovers/` folder, `docs/screens/A017/` and this handoff. Existing input renders and earlier art were only read.
