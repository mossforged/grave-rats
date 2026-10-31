# T023 - Build the second derelict: the biological survey vessel (code)

**Modules:**
- `src/study/` (deck builder, a deck chosen by file);
- `src/kit/` (dressing, corridor dressing, decals);
- `src/shift/` (which ship a shift runs on);
- `src/enemies/` and `src/custodian/` (positions from data only);
- `data/` (a new deck file, A013 decals in `data/kit.json`).

**Read:**
- `CLAUDE.md`;
- **`docs/handoffs/auto-A014.md`** and **`assets/source/A014-derelict-2/A014-02.layout.json`** (the authoritative geometry), plus `A014-02.png` and `docs/screens/A014/sheet.png`;
- `assets/source/A013-room-graphics/manifest.json` and `docs/screens/A013/` (the decals and their crops);
- `assets/source/props/catalogue.json` (room sets: engineering, biolab, bridge, quarters, mess, plus their `_b` batches);
- the contracts of the modules above;
- `docs/handoffs/auto-T019.md` (corridor dressing rules) and `auto-T020.md` (effects lists).

**Needs:** T022 merged.
**Autonomy:** auto-ok for the build; human-gated on look and play (John).

John approved A014's pitch B, the biological survey vessel ("containment outlived the crew"), and A013's graphics ("the signs are great"). Build it as a second ship beside the current one. The mining tug (pitch C) is a likely third ship later; don't build it.

## Do
1. **Decks by file.**
   - The builder loads a deck from a named data file.
   - The current ship stays `data/deck.json`; the new one is `data/deck_survey.json`.
   - Nothing about the current ship changes. Its tests and bot numbers stay identical.
2. **Geometry from A014-02.layout.json:**
   - the eight spaces, ten doors, cover, salvage spots by class, the black box on the bridge, vent and closet spawn candidates, the lights and their colours;
   - CUSTODIAN's cutter and drone patrol.
   - The plan's dimensions are final world metres. Follow its `scale_policy` (divide by 0.85 if the builder applies `room_scale`; never scale twice), and say which you did.
3. **Dress every room** from the catalogue sets: bridge, bio lab (the specimen tanks along the wall, as the plan has three), mess, quarters, engineering, and the airlock/hold.
   - Every cover prop in the plan uses a catalogue prop of the right `role` and size.
   - Clutter stays off routes, using the same tests as T016.
   - The story beat: a meal trolley (`tray_trolley`) stopped at the bio lab's seal.
4. **Corridors:** the two spines get T019's corridor dressing by the same rules (ribs, one high run, low pipes, jambs, lintels, fixtures, one grim spot), through the same generator.
5. **A013 decals:**
   - cut the graphics from the atlases using the manifest's crops into `assets/game/decals/`;
   - place room plates on every room, plus each room's posters and notices;
   - add Remnant overlays (ASSESSED, salvage priority) on a few props;
   - the reactor-core and captain's-chair inventory tags go on those props.
   - Big pieces must read from the camera; small print is texture.
6. **Effects (T020 recipes):**
   - the bio lab tanks glow and an acid/slime pool is placed (visual only, no damage);
   - a sparking console on the bridge;
   - steam in engineering;
   - dust motes everywhere.
7. **Choosing the ship:**
   - `data/shift.json` gets `ships` (deck files) and `ship_pick` (`"first"` default, `"rotate"`, `"random_seeded"`);
   - F1 → Shift gets a ship picker for testing;
   - a command-line flag `--ship survey` for John.
   - The default stays the current ship until John has played both.
8. **Bots:** run the T012 and T015 bots on the new deck, 12 seeds. Report survival, banked credits, deaths by cause and route times against the current ship. This is for information; don't tune.

## Acceptance
- **Headless:**
  - all tests pass, and the current ship's tests are unchanged;
  - the survey deck loads, and every door, salvage spot, spawn candidate and cover prop matches the layout file within half a grid cell;
  - routes are at least 1.5 m clear;
  - the black-box route from the airlock exists both ways round the loop;
  - no clutter on bot routes;
  - every A013 decal loads.
- **Windowed** (`docs/screens/T023/`), from the game camera:
  - each room;
  - both spines;
  - the bio lab with the trolley;
  - the bridge with the black box;
  - engineering's dead end.

  Then a sheet comparing them with A014-03/04/05.
- **Frame time:** the survey deck against the current ship.
- **Human (John):** does it feel like a different ship, and is the black-box run tense?
