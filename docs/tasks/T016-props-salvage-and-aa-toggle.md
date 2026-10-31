# T016 - Bed, medbay dressing and salvage models in; a live anti-aliasing toggle (code)

**Modules:** `src/kit/` (slots, dressing), `src/salvage/` (pickup meshes), `src/cover/` only for the bed's tipped mesh, `src/debug/` (F1 toggle). **Read:** `CLAUDE.md`, `assets/source/props/README.md` and `catalogue.json`, `docs/screens/props/` (medbay_*.jpg, salvage_*.jpg), the `src/kit/`, `src/salvage/` and `src/cover/` contracts, `docs/handoffs/auto-T013.md` (how slots work now). **Needs:** T015 merged.
**Autonomy:** auto-ok for the wiring; John judges the look and picks the AA setting by eye.

The lead modelled a medbay set and all nine salvage pickups in Blender by script, with kit material slot names, like T013's props.

## Do
1. **Bed:** the `bed` slot gets `bed.glb`. Tipping (T005) rotates the same mesh, so its plated underside faces away from the player as the shield. Collision, cover and the tip timing are unchanged.
2. **Medbay dressing:** a new `dressing` list in deck data places clutter and wall props by room. `surgical_lamp`, `iv_stand` and `trolley` are clutter (small or no collision, no cover class, never in a doorway or a cover line). `gurney` is low cover (add it to the cover data). `med_station` is a wall prop at `mount_y_m`. Dress the medbay so it reads like A006-01b (lamp over a bed, IV by a bed, trolley by the cabinet, station on a wall), without blocking any route the T012 bots use.
3. **Salvage meshes:** each `kind` in `data/salvage.json` maps to its `salvage_<kind>.glb`. The class rim and colour code stay (the fairness rule). Carried items use the mesh too.
4. **Kit materials by slot name**, as T013 (including `brass`, now used by fuse caps, busbars and engine flanges).
5. **Anti-aliasing toggle (F1 → Display):**
   - modes MSAA 2×, MSAA 4×, MSAA 2× + SMAA, and MSAA 2× + FXAA (use what this Godot version offers; say which);
   - live frame time shown beside it;
   - the choice saves to `data/`, so John can pick by eye while playing.
   Report each mode's cost on both decks and `shift_deck`.

## Acceptance
- **Headless:**
  - all tests pass;
  - every salvage kind and every slot loads its file;
  - dressing never overlaps a doorway, a cover prop's line or a bot route (test against the T012 bot paths);
  - the bed's tipped orientation puts the plated face toward the shield side;
  - the AA modes switch and save.
- **Windowed** (`docs/screens/T016/`): the medbay dressed (the A006-01b stand), salvage in each class from the game camera, a tipped bed, the four AA modes cropped on a wall top and a light strip, and frame time per mode.
