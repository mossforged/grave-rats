# A006 - Stage 3 targets: paint-overs of the real game, kit sheets at game dimensions (art)

**Read:** `AGENTS.md`, `docs/handoffs/game-brief.md`, `docs/decisions.md` (2026-10-30 lines), `docs/handoffs/auto-A002.md`, `docs/screens/A002/sheet.png`, `docs/screens/A005/sheet.png`, `docs/concepts/C001-dead-circuit-key-art/gameplay-panel.jpg`, and the grey-box captures `docs/screens/T006/camera_default.png`, `in_cover_readout.png`, `door_mid_bash.png`, `stalker_deck.png`. **Needs:** nothing.
**Autonomy:** human-gated (John approves the slice's look before anyone models it).

Stage 2 passed: the grey box plays well. Stage 3 turns the medbay, corridor and cargo into concept-quality art. Before anyone models a piece, we need two things:
- **Paint-overs of the real game's frames**, so the target matches our actual camera, scale and layout, not an imagined one;
- **Kit sheets drawn to the game's real dimensions**, so modelled pieces snap onto the deck.

John approved A002 and A005: the A002 environment sheets (with 08b signage and 09b lighting), the A005 orange hauler and crew family, the logo, the rat patch and the door title art.

## Game dimensions (from `data/deck.json`; read it to confirm)
- **Wall:** 2.6 m tall, in segments of 2 m or less.
- **Floor grid:** 0.5 m.
- **Door width and room sizes:** read them from `data/deck.json`. Note that John picked a room scale of 0.85; T007 may already have applied it.
- **Low cover:** about 0.9 m. **Tall cover:** 1.2 m and up.
- **Operator:** about 1.8 m at character scale 1.15.

## Do
Save each as `assets/source/A006-slice/A006-NN.png` with `A006-NN.prompt.md` beside it.

1. **Paint-overs (A006-01 … 04).** Each starts from one grey-box capture and keeps its exact camera, layout, positions and proportions. Only the surfaces, lighting, props and atmosphere become concept quality, using A002's kit and lighting and A005's hauler.
   - **01:** from `camera_default.png`, the medbay: clinical cool light, the overturned bed, the flashlight cone in dust.
   - **02:** from `in_cover_readout.png`, crouched in cover.
   - **03:** from `door_mid_bash.png`, a door being battered from the other side: dents and light leaking.
   - **04:** from `stalker_deck.png`, the junction toward the cargo hold, in sodium amber.
   Use image-to-image or a reference edit if the tool allows it. If it can't hold the layout, say so, and overlay the grey-box edges on the result so John can see how far it drifted.
2. **Kit sheets at game dimensions (A006-05 … 07).** Flat orthographic views with dimension lines in metres, on the game's 0.5 m grid, redrawn from the A002 picks:
   - **05:** wall modules: corridor and cargo bays, medbay panels, a corner, a wall top/cap seen from the steep camera, and the cut-away fade state;
   - **06:** doors: the sliding bulkhead (closed, open), locked, dented mid-bash, broken flat, at the deck's door width;
   - **07:** the cover props at their real heights: the bed (upright and overturned), console, low crate, tall crate stack, ammo crate, plus the silhouettes and colours that separate low from tall cover.
3. **Material and trim board (A006-08):** the surface families the slice needs (painted hull plate, grimy deck plate, grate, clinical panel, hazard trim, rubber, glass, emissive strips), as swatches with notes on roughness, wear and where each is used. This guides the textures.
4. **Contact sheet** `docs/screens/A006/sheet.png`, labelled, with each paint-over next to the grey-box frame it came from.

## Acceptance
- Eight images with prompts, plus the sheet.
- `docs/handoffs/auto-A006.md`:
  - a line per image;
  - how faithfully each paint-over kept the layout (with any drift shown);
  - which kit sheets are clean enough to model from;
  - anything refused.
- **Human (John):** approves the slice target and says which pieces he wants to model himself.

Out of scope: 3D, textures, HUD (the ring question is open), new threats.
