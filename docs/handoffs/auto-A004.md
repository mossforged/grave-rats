# A004 — Logo and title art

2026-10-30. Packet complete; nine raster concepts and nine adjacent prompt files in `assets/source/A004-title/`. Generated with the built-in imagegen tool, then assembled into review layouts with Pillow. No refusals or generation failures. No git commands run. Work confined to the new A004 source folder, A004 review folder and this handoff.

## Review and recommendation

- Contact sheet: `docs/screens/A004/sheet.png` (2400 × 2420), all nine IDs labeled. Each wordmark has a separate actual 64-pixel-high sample on the sheet; inspect at 100% zoom.
- Dedicated native-size check: `docs/screens/A004/wordmarks-64px.png` (1000 × 750).
- **Pick: A004-01, hull stencil.** Reads quickly at 64 pixels, feels crew-owned rather than employer-issued, and can be redone easily if the working title changes. Its chipped stencil and rat-tail underline carry the game's identity without making the combat world cartoonish. Retain fewer paint chips for a later small-size/vector version.
- **Fallback: A004-03, hazard label.** Strongest compact contrast and a useful capsule treatment, but closer to the employer's industrial graphics than 01.
- Use A004-07 as the independent emblem candidate. Pair the chosen wordmark with A004-08 for a title-screen composition; A004-09 is separately composed for a tall capsule.

## Per-image notes

| ID | Direction / result | 64 px verdict |
| --- | --- | --- |
| A004-01 | Spray-painted cut stencil on hull plate; cream paint, amber damage, subtle tail underline. Recommended game wordmark. | Strong pass; words remain immediate, small distress becomes texture. |
| A004-02 | Welded scrap block letters, stacked; steel faces, seams, heat scars and sparse rivets. | Pass; words hold, weld/bolt detail merges. Visually heavier and more conventional than 01. |
| A004-03 | Battered ochre hazard label with tall black lettering and striped ends. | Strong pass; clearest label silhouette and contrast. More corporate-adjacent. |
| A004-04 | Bold stacked visor lettering in cracked glass and a scarred helmet bezel, restrained cyan ticks. | Pass for wording; glass/HUD detail mostly disappears, bezel takes too much thumbnail area. |
| A004-05 | Crude embroidered oval crew patch; helmeted rat beside stacked cream lettering. | Marginal pass for words; rat and stitching become muddy. Prefer larger patch use and 07 for the emblem. |
| A004-06 | Wildcard: chipped mortuary/salvage tag with an eyelet and oxygen-hose tail. | Pass; words hold and tag silhouette survives, hose detail softens. Best deadpan black-humour alternative. |
| A004-07 | Standalone round helmeted-rat embroidered emblem, no lettering; cream, ochre and orange on charcoal. | Not a wordmark. Bold rat/helmet silhouette is suitable for icon development; simplify embroidery and whiskers after selection. |
| A004-08 | Wide outer-hull boarding scene: teal rig, red medic, yellow cutter and orange hauler enter an amber airlock beneath drifting wrecks. Large dark upper-left logo space. | Not applicable. All four roles are visually distinct. |
| A004-09 | Dedicated portrait composition: orange hauler foreground, red medic, teal rig and yellow cutter at airlock; wreck graveyard above. Dark upper-left/top-center logo space. | Not applicable. Crew fills lower half and remains readable at capsule scale. |

## Files and reproduction

- `A004-01.png` through `A004-06.png`: 1536 × 1200 presentation boards. The entire generated 1536 × 1024 artwork remains intact above a dark footer. Each footer duplicates a crop of the complete mark, proportionally resampled to exactly 64 pixels high; these are measured raster samples, not generated size claims. Crop bounds and assembly notes are in each adjacent `.prompt.md`.
- `A004-07.png`: 1254 × 1254 square emblem source on dark fabric.
- `A004-08.png`: exact 16:9 at 1664 × 936. The tool returned 1672 × 941; a centered near-identical aspect fit normalized the export. This is a source-resolution concept, not a promised 4K production master.
- `A004-09.png`: exact 2:3 at 1024 × 1536.
- Title-art prompts identify all four A001 reference files in generation order: 01 orange hauler, 02 yellow cutter, 04 red medic, 03 teal rig. Colours, bulky suits, carried equipment and backpack silhouettes carry through. Both compositions keep lettering separate and contain no baked-in title.
- All six wordmarks spell **GRAVE RATS** correctly. Reviewed the contact sheet, true 64 px strip, title images and original wordmark previews. PNG integrity, counts and aspect ratios checked programmatically.

## Human gate / next step

John must choose the wordmark (recommend 01; fallback 03), whether to retain the rat emblem, and whether the title art direction should progress. These are review candidates, not approved branding. Per A004's “human-gated (John picks)” instruction, stop here after delivering the exploration. Final vector logo, font licensing, title-screen integration and game imports remain outside this packet. The source images and saved prompts keep the working title easy to revise.
