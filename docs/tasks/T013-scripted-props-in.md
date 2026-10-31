# T013 - Scripted props into the deck slots (code)

**Modules:** `src/kit/` (`KitPieces.prop`, the slots). **Read:** `CLAUDE.md`, `src/kit/CONTRACT.md`, `assets/source/props/README.md`, `docs/screens/props/`. **Needs:** T012 merged.
**Autonomy:** auto-ok for the wiring; John sees the result with T012/T014.

The lead built the console (three widths), the medbay cabinet and the locker bank in Blender by script (`tools/blender/props.py`), at the deck's exact sizes, with material slots named after the kit materials. Put them in the `console`, `cabinet` and `locker_bank` slots in place of boxes.

## Do
1. Import copies into `assets/game/props/` (never edit `assets/source/`).
2. **Slots:** `data/kit.json` `slots` maps each type to its file. A console picks the variant whose width matches the deck prop's long side (1.4, 1.2 or 1.0), turned so its front faces the room's centre, or the nearest open floor.
3. **Bind kit materials by slot name** (`clinical`, `steel`, `hull`, `hazard`, `rubber`, `glass`, `emit_*`), so the props get the kit's textures, edge wear and grime (vertex grime as on kit pieces, if it applies). Scale `uv_m` so the texture density matches the walls.
4. The `bed` slot stays a box (John's Meshy bed is coming).
5. Collision, occluders and cover classes are unchanged: the T009 snapshot test must pass.

## Acceptance
- **Headless:**
  - all tests pass;
  - each slot loads its file;
  - the console variant matches its deck width;
  - every material slot binds to a kit material (none left on file colours);
  - the snapshot is unchanged.
- **Windowed** (`docs/screens/T013/`): the medbay and junction with the props, from the default camera and the T011 sheet stands; frame time for both decks.
