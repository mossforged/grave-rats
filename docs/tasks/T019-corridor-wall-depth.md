# T019 - Corridors get depth: wall dressing from the hallway prop set (code)

**Modules:** `src/kit/` (dressing, slots), `data/deck*.json` (a `dressing` list per corridor). **Read:** `CLAUDE.md`, `assets/source/props/README.md` and `catalogue.json` (set `hallway`), `docs/screens/props/hall_*.jpg`, the `src/kit/` contract, `docs/handoffs/auto-T016.md` (the dressing list T016 made). **Needs:** T016 merged (the dressing list and kit-materials-by-slot).
**Autonomy:** auto-ok for the wiring; John judges the look.

John: "make sure that the environments seem as realistic as possible. I think that'll be part of the horror... a lot of good props just for the hallways, like maybe things to make the walls a little bit more 3D." The lead modelled a 20-piece hallway set in Blender by script. Corridors are flat walls today; this task makes them read as a ship's structure. **Visual only: no new collision, cover or gameplay.**

## Do
1. **Import** the hallway glbs into `assets/game/props/` (copies; never edit `assets/source/`). Bind kit materials by slot name as T013/T016.
2. **Two mount kinds** (in `catalogue.json`):
   - `wall`: back against the wall, its own base at `mount_y_m` from data;
   - `wall_high`: the origin is on the floor and the height is baked in (pipes, ducts, cable tray, lintels, hanging cables, viewport). Place at y = 0.
3. **Dress every corridor on both decks** with a rhythm, not a scatter:
   - a `wall_rib` every 2.4 to 3 m on both walls, staggered;
   - one high run per corridor (`pipe_run_high`, `conduit_tray` or `air_duct`) on one wall, with sections butted end to end;
   - `pipe_run_low` or `kick_plate` along the foot of the other wall;
   - `door_jamb` pairs and a `door_lintel` (scaled on X to the aperture) on every door;
   - `corner_pillar` at inner corners;
   - light fixtures (`wall_light_strip`, `emergency_lamp`) where the deck's lights already are, so a fixture explains each light;
   - sprinkle singles: hatch, hose reel, sign, handrail, a `floor_grate` every so often, and one `wall_panel_breached`, `hanging_cables` and `debris_pile` per deck where the story is grimmest.

   All numbers (spacing, which runs where) live in data.
4. **The rule that keeps the game fair:** nothing may intrude more than `dressing_max_intrusion_m` (start at 0.3) from the wall face below 2.0 m, so routes, cover lines and doorways are untouched. The two exceptions:
   - `corner_pillar` is 0.4 m square, allowed only where the corner is not a route;
   - `debris_pile` and the breached panel's plate are clutter with no collision. Keep them off bot routes.
5. **Wall-top readability:** from the steep camera, the high runs sit over the wall tops. If they hide the wall tops that show players where the walls are (camera readability, T002), lower them or drop that run. Report what you chose.
6. Make `hanging_cables`'s blue spark tip flicker using an existing light (no new light system; reuse the T008 flicker if it fits). If it doesn't fit, park it.

## Acceptance
- **Headless:**
  - all tests pass;
  - every hallway slot loads its file;
  - no dressing piece intrudes past the limit below 2.0 m;
  - none overlaps a doorway, a cover line or a T012 bot route;
  - bot route times are unchanged.
- **Windowed** (`docs/screens/T019/`), each from the game camera:
  - the long corridor, before and after;
  - a door with jambs and lintel;
  - an inner corner;
  - the grimmest spot.
- **Frame time:** before and after on both decks.
