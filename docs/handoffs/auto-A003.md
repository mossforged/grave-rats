# A003 — HUD and company screens

Completed 2026-10-30. Review concepts only; human gate pending. John must pick a HUD direction and approve the company screens' tone before implementation. No implementation work performed.

## Deliverables

Six full-frame 1920×1080 PNGs in `assets/source/A003-ui/`, each with its exact generation prompt in the matching `.prompt.md`. Labelled review sheet: `docs/screens/A003/sheet.png` (2000×1910, six 960×540 previews). The adjacent `build-sheet.py` rebuilds the sheet.

- **A003-01 — Minimal diegetic:** sparse corner suit/O2 and ammo/salvage, four crew rows, small schematic, doorway interaction and a short operator arc. All seven required HUD elements present; no garbled UI copy detected.
- **A003-02 — Suit OS:** scratched visor perimeter, faint RENTAL UNIT 04 watermark, oxygen BILLED PER MINUTE, corner instrument widgets. All required HUD elements present; no garbled UI copy detected. The company header and visor occupy more visual space than the other directions.
- **A003-03 — Watch strip:** one bottom status strip with four crew cards, suit, oxygen, salvage and ammunition; schematic upper right, interaction at doorway. All required HUD elements present; no garbled UI copy detected.
- **A003-04 — Contract briefing:** MERIDIAN DUE, probably abandoned, 8,600 CR estimate, three legible liability clauses and a much larger yellow ACCEPT than DECLINE. Required copy is legible and correctly spelled; no garbling detected. Additional generated vessel specifications are illustrative, not established lore.
- **A003-05 — Shift payslip:** recovered 2,480 CR; deductions 640 + 920 + 380 + 280 + 250 = 2,470 CR; net pay 10 CR. All requested fee categories present. Required copy and arithmetic checked; no garbling detected. Small decorative metadata includes the unexplained abbreviation CUS; do not treat that label as approved UI vocabulary.
- **A003-06 — Death bill:** posthumous processing 180 CR, unreturned equipment 1,640 CR, biohazard cleanup (you) 420 CR; total and outstanding balance 2,240 CR. Required copy and arithmetic checked; no garbling detected. Additional account metadata and slogans are exploratory.

**HUD pick: A003-03.** A single predictable status strip groups all survival and crew information while keeping the room view clear of perimeter instruments and visor wear.

## Production notes and limits

- Generated using the built-in `image_gen` tool, one distinct prompt per asset. No refusals, skipped images or generation failures.
- Read the brief, style and asset contracts, tone bible, STATUS and A003 packet; visually inspected the A002 sheet, A002-08b signage and C001 gameplay panel before generation.
- Generated rasters were 1672×941, normalized with Lanczos resampling to the required 1920×1080 delivery size (near-identical aspect ratio). They are concept mockups, not native-resolution runtime UI exports. No text repainting was used.
- A002's condensed typography, yellow/black accents and broken-ring recovery symbol informed the concepts. The generator interpreted the mark as three cubes rather than reproducing A002-08b's stacked cargo silhouette exactly; use the existing A002 mark as the production authority. These are not replacement logo proposals.
- The three gameplay backdrops vary slightly; review the HUD organization, not apparent changes in level geometry, camera scale or lighting. The schematic is illustrative and does not reveal enemies. This packet does not settle the open T002 camera/scale gate.
- No fonts or font files bundled, and generated letterforms are not an identified font. Font selection/licensing remains outside this packet.
- All mandatory interface copy visually checked at delivery size. Small decorative text and generated slogans remain concept copy; the saved prompt text is the transcription source for the requested fields.
- Only the new `assets/source/A003-ui/`, `docs/screens/A003/` and this handoff were written. No git commands run; no changes to legacy art or game/code folders.

## Human gate — stop here

John: choose A003-01, A003-02 or A003-03 for the HUD and approve or revise the tone of A003-04 through A003-06. Recommendation is 03 plus the three company-screen layouts. No choice or tone approval has been assumed. The code lane should wait for that selection.
