# A006 — slice targets and measured kit sheets

Completed art packet 2026-10-30. **Human look gate pending; stop before modelling.** John must approve the slice target and choose which pieces he wants to model himself. No picks have been marked approved by this run.

## Deliverables

- Sources and exact submitted prompts: `assets/source/A006-slice/` — eight base images, seven letter-b corrections and two letter-c corrections, **17 PNG / prompt pairs**. Eight preferred targets listed below; earlier passes retained for provenance, not alternate modelling instructions.
- Review: [sheet.png](../screens/A006/sheet.png), 3072 × 5100. Each paint-over sits beside its actual T006 capture and a cyan source-edge diagnostic. Kit boards below use preferred revisions.
- Four full-size edge diagnostics in `docs/screens/A006/A006-01b-overlay.png`, `A006-02b-overlay.png`, `A006-03c-overlay.png`, `A006-04b-overlay.png` with method/prompt notes. Normalized whole-frame scale only, no alignment warp. Cyan also includes source floor grid and flashlight/debug outlines; these are comparison aids, not proposed art geometry. HUD top/bottom bands are masked.
- [A006-kit-dimensions.png](../screens/A006/A006-kit-dimensions.png), 2200 × 2000: authored orthographic bounds at **140 px/m**, uniform 0.5 m grid. Use this and the numerical specification below for blockout; generated drawings are approximate and should not be pixel-traced for measurements.
- Rebuild: `python3 docs/screens/A006/build-sheet.py` and `python3 docs/screens/A006/build-dimensions.py`. These read source art and write only A006 review artifacts.
- Built-in `image_gen.imagegen` used for every art image; no API/CLI fallback. Pillow used only for explicitly requested diagnostic overlays, review layout and the authored measurement diagram.

## Preferred eight targets

| Image | Review / layout faithfulness / modelling readiness |
| --- | --- |
| **A006-01b** | Medbay from `camera_default.png`: clinical cool light, dusty leftward beam, orange hauler, tipped solid bed on right. Main room footprint, operator anchor, bed anchor, central locker and corridor remain close in normalized comparison. Local drift: bed now more detailed/wider at ends, character pose/silhouette changes, floor seams retessellated and wall dressing adds depth. Dark areas are revealed by practicals rather than matching the source sight mask. **Look target, not exact geometry.** |
| **A006-02b** | From `in_cover_readout.png`: visibly crouched operator left of the tipped bed, door on right. Main anchors and aim direction retained; corrected vertical bed underside/wheels. Local drift: shield reaches farther upward, character outline/weapon shifts, added wall fixtures, broader room illumination and warm flashlight/door cast. Read cool medbay fixture vs warm threshold; use 01b for the main cool-white palette. **Cover composition target, not collision proof.** |
| **A006-03c** | From `door_mid_bash.png`: same nearly edge-on closed door, operator and tipped bed left of it. Dented leaf bulges toward player with narrow warm seam leaks; cool medbay practicals, amber beyond door. Frame and operator anchors close; exaggerated dent silhouette is intentional state deformation, bed width and floor seam details drift. More ambient visibility than source. **Preferred mid-bash look.** |
| **A006-04b** | From `stalker_deck.png`: doorway/junction toward cargo in sodium amber, clinical spill left, upward flashlight. Operator, adjacent bed, top console, upper wall and doorway remain close to source anchors. Corrected existing olive capsule/limb stalker placeholder retained as a placeholder, not a new threat design; its green debug light is removed. Bed endpoints, wall depths, deck seams and lit extent vary. **Environment/lighting target only.** |
| **A006-05b** | Corridor plain, pipe/vent, cargo reinforced and clinical wall elevations; corner plan, cap plan, steep cap inset and full-height ghosted fade state. Corrected corner legs to 2.0 m and axes to Y-up. **Clean enough for wall blockout and surface design after approval**, using literal bounds from the measurement supplement. Tiny bevels, joints and corner interlock still modeller detail; ghost fade is illustrative, not an opacity setting. |
| **A006-06c** | Closed/open/locked/dented/broken states, detached broken leaf top plan, jambs, section and left-storage schematic. **Clean enough for door frame/leaf blockout and damage direction after approval**, subject to proposed construction dimensions below. The small top-row-plan OPEN thumbnail still leaves a short illustrated remnant: ignore it for motion; the bottom mechanism and authored supplement control. Blue generated travel arrow is not pixel-scaled. Open aperture drawings contain illustrative corridor depth, not extra door geometry. |
| **A006-07b** | Upright/tipped same bed, console, low crate, tall stack, ammo, single tall crate and small junction cube. Corrected upright bed to NO COVER, bed height to 0.75 m, human reference to 1.8 m, header to A006. **Clean enough for prop bounds and silhouette blockout after approval.** Row-wide SIDE/END labels describe beds; for console/crates read front/side respectively. Dimensions override raised mattress/rail details; reconcile bed as one rigid physical object. Tall vertical ribs/ivory strips and low horizontal accents support silhouette; they do not change mechanics. |
| **A006-08** | Eight surface families, roughness ranges, wear/use notes and trim light colours. **Clean enough for material direction after approval.** Values are starting ranges to tune under actual game light; not seamless textures or production maps. Glass is decorative and must not silently change cover/sight classification. |

All four paint-overs use actual captures as image-to-image targets, with A002/A005 sheets as style references. The tool preserved major composition but **did not lock exact geometry or visibility**. The overlays expose that limitation. No paint-over should replace deck geometry, define the sight mask, or serve as a camera calibration render. Glossy wet highlights are localized target detail; reduce them if they obscure pickups/enemies at gameplay zoom. No HUD work delivered; source prototype text/debug graphics removed from art only.

## Remaining images — provenance, not picks

| Image | Status |
| --- | --- |
| A006-01 | Superseded by 01b: tipped bed read as upright, medbay too warm. |
| A006-02 | Superseded by 02b: shield bed read as upright. |
| A006-03 | Superseded: upright-looking bed, insufficient door deformation, warm medbay. |
| A006-03b | Superseded by 03c: bed corrected, but door damage too subtle and medbay still amber. |
| A006-04 | Superseded by 04b: bed correction needed; existing stalker placeholder was incorrectly dressed as equipment. Do not build that interpretation. |
| A006-05 | Superseded by 05b: corner-plan leg erroneously labelled 2.6 m; axis labels not Y-up. |
| A006-06 | Superseded: storage/travel diagram intruded into clear opening. |
| A006-06b | Superseded by 06c: correct storage schematic introduced but detached broken-flat leaf disappeared. |
| A006-07 | Superseded by 07b: upright bed cover/height labels wrong and header carried A002. |

## Dimensions and scale source of truth

Read `data/deck.json` directly, read-only. At this checkout it still says **room_scale 1.0 / character_scale 1.0**; T007's defaults are not present in that file. Do not imply these T006 paint-overs already show John's tighter/bigger target. John's approved target is rooms ×0.85 and character ×1.15, with full-height fade cut-away. No game data was changed.

| Space | Current size_m (m) | Arithmetic ×0.85 target (m), pending code application |
| --- | --- | --- |
| Junction | 6 × 26 | 5.1 × 22.1 |
| Medbay | 14 × 10 | 11.9 × 8.5 |
| Cargo | 14 × 12 | 11.9 × 10.2 |
| Side corridor | 14 × 3.5 | 11.9 × 2.975 |

These non-grid extents require closing pieces; do not stretch standard 2 m bays or silently round rooms. Wall height **2.6 m**, depth **0.5 m**, max segment **2 m**. Placement grid **0.5 m**; deck floor tile **1 m**. Preserve full-height geometry in fade state. Floor pivot, metres, Godot Y-up; X width / Y height / Z depth.

Door width is **2.0 m** and frame value **0.2 m** in the file. Sheet interprets this as a 2.0 m clear aperture with 0.2 m jamb each side (2.4 m outer width). Leaf/aperture height is not provided by this data: **2.2 m aperture**, **0.4 m header**, **0.12 m leaf thickness** are explicitly proposed construction values, not extracted engine dimensions. One rigid leaf slides a proposed 2 m into a full-width storage bay outside the aperture; actual doors can mirror slide direction per deck entry. Broken leaf footprint under this proposal is 2.0 × 2.2 m. The code lane must check jamb/header, travel pocket and broken-leaf fit before finalising the model.

| Prop | Current W × H × D in metres | Cover class from deck |
| --- | --- | --- |
| Bed upright | 0.9 × 0.75 × 2.0 | none (one pre-tipped instance is low) |
| Bed tipped, rigid-rotation proposal | 0.75 × 0.9 × 2.0 | low; verify against existing tip collision |
| Main med console | 1.4 × 1.1 × 0.6 | low, despite approximate 0.9 m guideline |
| Other consoles | 0.6 × 1.1 × 1.2 med / 0.6 × 1.1 × 1.0 junction | low |
| Cargo low crate | 1.2 × 0.8 × 1.2 | low |
| Junction/side low cube | 0.8 × 0.8 × 0.8 | low |
| Single high crate | 1.2 × 1.2 × 1.2 | tall; cannot fire over it per T006 decision |
| Crate stack | 1.2 × 2.1 × 1.2 | tall |
| Ammo crate | 1.0 × 0.6 × 0.6 | none |

Nominal human 1.8 m, nominal ×1.15 height **2.07 m** shown dashed as target reference only. Prop numbers are the data's raw size_m values, not blanket scaled by 0.85. The sheet is not a proposal to change cover rules, shrink wall height, or resize imported props automatically.

Material board includes painted hull, dirty deck, grate, clinical enamel, hazard trim, rubber, glass and emissive strips. OpenGL normals; ORM R=AO, G=roughness, B=metalness. No maps or meshes were produced.

## Verification and stop

All source and review PNGs decoded and visually reviewed. Every source image has its exact submitted prompt and reference provenance beside it. Preferred selection: **01b, 02b, 03c, 04b, 05b, 06c, 07b, 08**. Source-edge diagnostics and measurement supplement inspected; contact sheet rebuilt after final selection. No image refusals, missing subjects or skipped requests. Corrections retained rather than reusing IDs.

No git commands run. Writes confined to new `assets/source/A006-slice/`, `docs/screens/A006/`, and this handoff. No game files, legacy art, 3D, texture maps or imports touched.

**John's decision now:** approve/revise the slice look, then name the pieces he wants to model personally. Recommended review order: comparison sheet → 03c/06c door states → 05b/07b + measured supplement → materials. This run stops at that human gate; modelling/imports remain for a later authorised packet.
