# A002 — Slice environment concepts

Completed 2026-10-30. Art packet complete; awaiting John's direction picks before stage 3 modelling. No git commands run. No game files or legacy sources touched.

## Deliverables

- Source: `assets/source/A002-slice-env/` — nine requested base sheets plus two non-destructive lettered revisions (11 PNGs total), each with its exact submitted `<ID>.prompt.md`.
- Review: `docs/screens/A002/sheet.png` — 3072 × 2360, three by three, asset IDs and subjects labelled; uses 08b and 09b as preferred revisions. Source images are all 1536 × 1024 RGB PNGs.
- Rebuild/validation: `python3 docs/screens/A002/build-sheet.py`. This only reads the A002 sources and writes the A002 contact sheet.
- Generated using the built-in imagegen tool. All outputs visually reviewed; PNG decoding, counts and prompt pairing checked. No refusals, skipped subjects, or tool failures.

## Per-image review

| ID | Contents and recommendation |
| --- | --- |
| A002-01 | Corridor/cargo: plain, pipe, vent, strip light, screen and corner pilaster; front and three-quarter views, 1.8 m silhouette. **Clean enough for modelling direction after pick.** Strong common caps, docking seams and plinths. |
| A002-02 | Medbay: clinical panel, supply niche, medical-cross plaque and strip light; front and three-quarter views, 1.8 m silhouette. **Clean enough for modelling direction after pick.** Shared graphite frame with pale inserts. |
| A002-03 | Sliding bulkhead closed/half/open, locked override, breached leaf and closed/open hatch. **Clean enough for blockout and surface direction after pick.** Pocket travel, jamb clearance and actual aperture dimensions still require mechanical resolution; pictured corridor beyond is illustrative. |
| A002-04 | Top-down deck plate, grate, hazard edge, drain, cable tray, wet/acid damage. **Clean enough for floor-family modelling direction after pick.** Not seamless textures or a production atlas. |
| A002-05 | Bed upright and overturned in side/overhead views, surgical lamp, cabinet, IV, gurney, console and supplies. **Clean enough for prop silhouettes after pick.** Upright lifting mechanism and overturned solid underside are simplified differently; reconcile as one physical bed, using the broad underside as the intended shield. Overhead angle is approximate. |
| A002-06 | Small/medium/large and stacked crates, yellow ammo crate, pallet, rack, canister, parked empty loader, lift. **Crates, pallet, canister and platform clean enough for modelling direction after pick.** Loader is silhouette/assembly direction only; joints and harness need a later breakdown. Lift caption has a minor generated typo; intended name is CARGO LIFT PLATFORM. |
| A002-07 | Eight small prop/mannequin comparisons split into low/tall groups, with elevation insets. **Readability study, not a collision or visibility specification.** Height values are generated proposals, not approved dimensions. Low ammo box (~0.5 m) provides only partial crouched protection; do not assume full shielding from its label. Solid cabinet and solid-backed rack are sight-blocking variants, unlike the glass cabinet in 05 and open rack in 06. Bed/crate details vary; use 05/06 for build forms and 07 for silhouette classes. |
| A002-08 | Original signage includes all room plates, deadpan warnings, four hazard pictograms, floor labels and invented Remnant Asset Recovery identity. **Superseded by 08b:** unwanted physical sign wear, screws and backing plates make this unsuitable as the clean master. Retained with prompt for provenance. |
| A002-08b | **Preferred signage sheet.** Cleaner flat graphics, isolated floor stencil marks, legible room/warning copy, hazard icons and original recovery logo/motto. Clean enough for graphic direction and tracing into later production decals. Some subtle generated tonal variation remains; this opaque raster sheet needs separation/alpha and flat-colour reconstruction before production use. No textures or decal atlas delivered in this concept packet. |
| A002-09 | Four matching corridor light states: cool white, amber, red, flashlight. **Superseded by 09b:** a lit screen survived in the flashlight-only panel. Retained with prompt. |
| A002-09b | **Preferred lighting board.** Same bay layout and camera across four states; flashlight panel fixtures/screens are dark. Strong cool-medbay/amber-cargo separation, sparse red emergency state and dusty narrow beam. Clean enough as lighting reference; tiny generated geometry/view variations mean this is an approximate concept comparison, not four controlled renders. |

## Recommended direction

Recommend 01 + 02 as the common structural kit; 03 + 04 for doors and deck vocabulary; 05 + 06 for prop families, subject to the caveats above. Use 08b for signage and 09b for lighting. Treat 07 as the visual height-language study; cover and sight need validation with the final camera and crouching operator in the code lane.

All dimensions and camera-angle annotations are provisional. The 1.8 m silhouettes establish human reference only; module widths, wall heights, door clearances, pivots and grid must follow T002. These are modelling briefs, not orthographic CAD, 3D assets or import-ready textures.

## Human gate — stop here

John must pick the environment, signage and lighting directions stage 3 builds. Suggested review starts with the nine-cell contact sheet, then the full-resolution sources. No direction has been marked approved, and no modelling/import work was started. Crew and threats remain outside this packet and await A001 picks.
