# T011 - Slice polish: closing the gap to the paint-overs (code)

**Modules:** `src/kit/`, `src/sight/` (aim cone, mask over faded walls), the deck lighting, `tools/t010_textures.py`, `src/doors/` (side-door readout only). **Read:** `CLAUDE.md`, `docs/handoffs/auto-T010.md` (its "Known problems" are this packet), `docs/screens/T010/sheet.png`, `docs/screens/A006/sheet.png`, `docs/handoffs/auto-A010.md` and `assets/source/A010-graphics/` (decals John approved), `docs/studies/2026-10-30-comparable-games.md` (the presentation section). **Needs:** T010 merged.
**Autonomy:** human-gated (stage 3: *"Does it match or beat the concept?"*).

T010 got the slice's structure, palette and lighting right. Against the paint-overs it still reads cleaner and flatter. Close that gap, and fix the known problems, without spending more frame time.

## Do
1. **Decals from A010** (John approved the copy and look): Vesper Reach Freight posters (the dead owner, faded), Remnant overlays (fresh stickers and tape over them), room plates and arrows, floor stencils, the medbay set. Cut them out of the sheets with alpha (a script in `tools/`), place them from data per room, and replace the A002-08b signs.
2. **Surface quality:**
   - **wear:** chips concentrated on edges and corners, not spotted across panels;
   - **floors:** no splat-like polished patches; wear follows foot paths and door thresholds;
   - **wet sheen:** a subtle sheen on floors where the paint-overs have it (screen-space reflection, or one cheap reflection probe per room; measure both and pick);
   - **more depth:** stronger normal detail on panels and grates.
   Compare against A006 in the same sheet format as T010.
3. **Known problems from T010:**
   - **aim cone:** it draws over the art bright and unmasked. Mask it by sight and tone it down;
   - **faded walls in unknown space:** they must be darkened by the mask too;
   - **side doors:** their state must read from the game camera (the closed/locked/open lamp visible from above, or a floor light strip at the threshold);
   - the flaky `test_hauler::test_a_turn_in_place_plays_only_when_the_hips_are_dragged`: make it deterministic.
4. **Fairness (from the study):**
   - everything the player needs (doors, salvage once it exists, the ambush panel's tell) keeps a readable emissive or rim outside the cone;
   - nothing that hurts you stays invisible: a pirate muzzle flash lights the shooter for a moment, and hits from out of sight show a directional indicator.
5. **Frame time:** win back headroom, **pirate deck under 7.5 ms average and p95 under 9.5 ms** (T010: 7.81 / 9.95). Levers: fewer shadowed practicals, light culling per room, SSAO quality, fog resolution. Report each cost.

## Acceptance
- **Headless:**
  - all tests pass, three full runs in a row (no flakes);
  - decals are placed from data;
  - the aim cone and faded walls are masked;
  - the side-door state indicator follows the door state;
  - a muzzle-flash reveal and a damage-direction indicator exist and come from data.
- **Windowed** (`docs/screens/T011/`):
  - the T010 sheet's four paint-over frames redone, as A006 | T010 | T011;
  - the decals in each room;
  - side doors in five states;
  - a hit from out of sight;
  - frame time with the cost breakdown.
- **Human (John):** does it match or beat the concept?

Out of scope: the Meshy props (still boxes until John's files land), new rooms, rule changes.
