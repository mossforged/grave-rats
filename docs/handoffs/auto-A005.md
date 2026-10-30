# A005 — hauler, crew, suit OS, title and logo development

2026-10-30. Delivered for John's approval using built-in image_gen; no API/CLI fallback. No git commands run. Changes are confined to the new assets/source/A005-dev folder, docs/screens/A005 and this report. No game implementation or imports.

Review: [contact sheet](../screens/A005/sheet.png), 2400 x 3280. Images and exact prompts: [A005-dev](../../assets/source/A005-dev/). Rebuild layouts with `python3 docs/screens/A005/build-sheet.py` (Pillow; Mac system Arial fonts).

## Image-by-image

| Packet image | Result and review notes |
| --- | --- |
| A005-01 | 1536 x 1024 front/back/left-side turnaround, aligned floor and 1.80 m height line. Original side retained a slight oblique angle. Prefer **A005-01b**, same size, with a more strictly side-on profile. Both versions and prompts retained. |
| A005-02 | 1536 x 1024 three-quarter plus HELMET, LIFE SUPPORT, TOOL BELT and RIFLE GRIP insets. Suit identity and component forms read well. **Garbled content:** the last inset and full-body hand show the original industrial cutter, despite the RIFLE GRIP label. A005-02b correction was refused; no 02b image exists. Do not model a firearm from this inset. |
| A005-03 | 1200 x 720 camera review layout, preserved 1254 x 1254 generated master. Initial view was too shallow. Prefer **A005-03b**, visibly steeper overhead, approximating the requested 60-degree pitch. Both layouts show a 96 px projected-figure proxy and an exact nearest-neighbour 4x enlargement to 384 px; 03b sample rectangles are 94 x 96 and 376 x 384. Orange crown and shoulders, pale rectangular pack and rifle silhouette remain distinct at the small size. Tiny belt fittings merge. |
| A005-04 | 1536 x 1024 same-floor front lineup: orange hauler, small wiry teal, tall heavy ochre, average blue. Coherent shared suit family with different silhouettes. Nominal labels are 1.80 / 1.60 / 2.00 / 1.75 m; generated horizontal height guides and measured figure heights do not agree exactly. Use these as target model heights, not traceable dimensioned drawings. |
| A005-05 | 1672 x 941 suit OS normal HUD over dark ship view. Employer, crew rows, minimap and status docks follow A003-02. Segmented floor ring follows A003-01 and is intended as ammo feedback. Oxygen BILLED PER MINUTE and RENTAL UNIT 04 preserved. Proposed AMMO text on the ring was omitted by the generator; numeric ammo remains in the dock. |
| A005-06 | 1672 x 941 tense HUD: SUIT 19%, AMMO 03 / 72, ACID ALARM, shield + IN COVER, warning ring and acid stalker at doorway. Original lacked explicit LOW AMMO wording; prefer **A005-06b**, same dimensions, adding the amber warning. Rental watermark, billed oxygen and layout preserved. Ring conveys suit danger plus three ammo ticks in this state. |
| A005-07 | 1672 x 941 wide title art, approximately 16:9 to pixel rounding. Exactly two crew: orange hauler actively cutting the airlock seam; teal crew mate stepping up behind with rifle low. Amber doorway, cold blue wrecks, tethers and dark upper-left logo space retained. No baked title. |
| A005-08 | 1600 x 1400 labelled logo sheet: hull stencil primary, cracked-visor variant and rat crew patch, each large and at exactly 64 px tall. Original remained too distressed. Prefer **A005-08b**, cleaner revision, with 308 x 64 primary, 121 x 64 visor and 68 x 64 emblem samples. Both wordmarks remain legible; rat ears, muzzle and helmet read at 64 px while stitching softens. Generated 1419 x 1109 masters preserved as -render.png with matching prompts. Opaque raster review art, not vector/transparent production exports. |

## Refusal

**A005-02b:** correcting the cutter into a rifle and glove grip was refused at input moderation: `moderation_blocked`, category `violence`. Request ID: `09224f1b-b7a1-4fee-b9a8-ceaaf62ca5e5`. Skipped without retry, as instructed. Exact rejected prompt saved. All eight base packet images were generated; this refused revision has no PNG.

## Are 01–03 clean enough to model from?

**Yes for a suit blockout/material and silhouette study using 01b + 02 + 03b; no for an unambiguous final production model.** 01b supplies front/back/profile and human height. 02 supplies helmet, belt and pack construction. 03b checks orange/helmet/pack separation from above. Broad forms and seams are legible under neutral illumination.

Pack hose ports, small pouch locations and strap fittings vary between views. Resolve minor fittings against 01b. The rifle inset is wrong and its correction was refused; 03b supplies a rifle silhouette only. A separate approved firearm/grip reference is needed before final detailing. The 96 px sample is a review proxy, not an actual game capture: camera/character scale remains unapproved in STATUS.md. No measured render proves an exact 60-degree camera.

## Validation and human gate

Eight base PNGs, four successful lettered revisions (01b, 03b, 06b, 08b), matching prompts, generated masters and the labelled sheet are present. All PNGs decode successfully. Visually inspected every generated output and final layout. Layout resizing preserves aspect ratio; the 4x panel uses the small sample's pixels, and each logo sample is exactly 64 px tall. Essential HUD text reads correctly. No code tests apply to this art-only packet.

**John must now approve:** the hauler for modelling with these limits, the crew-variety direction, the suit OS/ring layout and the two-person title composition. Suggested review set: **01b, 02, 03b, 04, 05, 06b, 07, 08b**. Work stops at this human gate; no approval is inferred and nothing is copied into the game.
