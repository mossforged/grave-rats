# A007 — Meshy input images

2026-10-30. Delivered 12 isolated PNG inputs for stalker, upright bed and med console, plus adjacent prompts and `docs/screens/A007/sheet.png`. Built-in image_gen used throughout. Rifle was refused and skipped as instructed; the four-model minimum therefore has this explicit refusal exception. No human decision is needed to use the three delivered models.

## Files and review

All input paths below are relative to `assets/source/meshy/input/`. Each PNG has its own matching `.prompt.md`. All are 1536 × 1024 px except bed-side, which is 1774 × 887 px. No generated input was cropped, stretched or composited. IDs are assigned in this handoff because the packet specifies model filenames rather than numbered sub-assets.

| ID | Image | Visual review and view matching |
| --- | --- | --- |
| A007-01 | `stalker-34.png` | Primary input. Whole creature, four neutral supporting legs, closed mouth, paired pale throat sacs, long ridged tail; no spray. Follows A001-11. |
| A007-02 | `stalker-front.png` | Matches master silhouette, sacs and major carapace; small plate/claw detail varies. Head-on elevation. |
| A007-03 | `stalker-side.png` | Matches long skull, bent limbs, dorsal ridge and tail; feet and small plate details vary. Full left profile. Far limbs naturally occlude. |
| A007-04 | `stalker-back.png` | Matches major body and limb arrangement; rear carapace inferred, not an exact geometric turnaround. Tail remains within frame. |
| A007-05 | `bed-34.png` | Primary input. Upright black padded treatment bed, ivory frame and plated deck underside, scissor support, low caster base. Based on A002-05 and A006-07b. |
| A007-06 | `bed-front.png` | Foot-end view. Major bed parts and colours match; foot-panel fittings vary. Some downward view remains, so this is not a strict zero-elevation orthographic render. |
| A007-07 | `bed-side.png` | Full long-side elevation; raised head left, foot right. Plated deck and low base read clearly. Lift spacing and rail details vary slightly from master. |
| A007-08 | `bed-back.png` | Head-end view. Main frame, cushion and caster design match; unseen rear fittings inferred. Scissor mechanism appears more spread in this view. |
| A007-09 | `console-34.png` | Primary input. Broad A006 console with dark screen, keyboard, service hatch, vent, worn ivory panels and black plinth. Target size 1.4 W × 1.1 H × 0.6 D m. |
| A007-10 | `console-front.png` | Closest match to master: screen, keyboard, hatch and lower panels retained. Minor fastener and wear differences. |
| A007-11 | `console-side.png` | Shallow right profile with control ledge projecting forward; major depth/silhouette consistent. Hidden service panels inferred. |
| A007-12 | `console-back.png` | Broad stepped rear silhouette mirrors front correctly; rear maintenance panels and vent inferred. Materials match; no screen visible. |
| A007-13 | `rifle-34.png` — NOT PRODUCED | Image tool refused request, safety category violence. Exact attempted prompt saved as `rifle-34.prompt.md`. |
| A007-14 | `rifle-side.png` — SKIPPED | Dependent view skipped after rifle refusal; no retry or substitute. |

## Consistency and use

Each model's three-quarter image is the preferred single-image Meshy input. Additional views preserve the broad design but are generated interpretations, not renders of a shared 3D mesh. Stalker micro-anatomy and bed lift hardware drift enough that their views should be treated as supporting references rather than guaranteed matching multi-view geometry. Console front and three-quarter are the strongest pair; its unseen rear is a conservative invention.

All delivered images show one whole centred object on a plain light-grey studio backdrop, with soft lighting and contact shading, no text, people or loose props. The bed is upright throughout. Its horizontal mattress deck has a continuous plated underside; a direct underside view was not requested or delivered, so enforce that plate if Meshy leaves holes. Rendered proportions guide construction; final metric scale must be applied to the generated mesh. Bed target: 0.9 W × 0.75 H × 2.0 L m.

## Refusal

Rifle generation returned HTTP 400 `moderation_blocked`, input category `violence`, request ID `47b20d42-2bca-4667-975e-8c46881a608e`. No image was produced. Followed the unattended-run instruction to note, skip and continue. No retry was attempted.

## Validation

Opened the approved source images, inspected the three-quarter masters and visually reviewed all 12 deliverables together in the labeled contact sheet. Verified every PNG decodes and every delivered PNG has its prompt companion. Existing hauler inputs were preserved. No git commands were run; no game-code or game-import folders were modified.
