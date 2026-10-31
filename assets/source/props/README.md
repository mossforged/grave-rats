# Scripted hard-surface props (lead, Blender by script)

Built by `tools/blender/props.py` (run `python3 tools/blender/props.py assets/source/props`; needs `pip install bpy`). Previews in `docs/screens/props/`.

| File | Deck prop | Size w × h × d (m) | Tris |
| --- | --- | --- | --- |
| `console_1600.glb` | `console` 0.6 × 1.1 × 1.6 (pirate deck) | 1.60 × 1.10 × 0.59 | 752 |
| `console_1400.glb` | `console` 1.4 × 1.1 × 0.6 (medbay) | 1.40 × 1.10 × 0.59 | 752 |
| `console_1200.glb` | `console` 0.6 × 1.1 × 1.2 (side-facing, so 1.2 wide) | 1.20 × 1.10 × 0.59 | 752 |
| `console_1000.glb` | `console` 0.6 × 1.1 × 1.0 (side-facing) | 1.00 × 1.10 × 0.59 | 752 |
| `cabinet.glb` | `cabinet` 0.6 × 1.9 × 0.5 | 0.60 × 1.90 × 0.49 | 564 |
| `locker_bank.glb` | `locker_bank` 0.6 × 2.0 × 2.4 (2.4 long) | 2.40 × 2.00 × 0.60 | 4180 |

- Origin at the centre of the base; front faces +Z (glTF); width along X. A deck prop whose size is narrower in X than in Z is the same model turned 90°, front toward the room.
- **Material slots are `data/kit.json` material keys:** `clinical`, `steel`, `hull`, `hazard`, `rubber`, `glass`, `emit_blue`, `emit_red`. The colours in the file are previews only; the game should bind its kit materials by slot name, so props get the same textures, wear and grime as the walls.
- Nothing pokes out of the deck footprint; collision, occluders and cover still come from the deck data, never the mesh.

- The locker bank is a freestanding island: doors on both long faces, and a light (`clinical`) top cap with a vent grille and a hazard stencil plate, so it reads from the steep camera (T013 found the first version a dark slab).

## Set 1 and 2 (`tools/blender/props_set_medbay_salvage.py`)
Medbay: `bed`, `surgical_lamp`, `iv_stand`, `gurney`, `trolley`, `med_station` (wall). Salvage: `salvage_<kind>.glb` for all nine kinds in `data/salvage.json`. Roles and sizes in `catalogue.json`; previews `docs/screens/props/medbay_*.jpg`, `salvage_*.jpg`.

## Set 3–4 and room sets
`tools/blender/props_set_cargo_engineering.py`: cargo (pallet, barrel, gas_rack, shelving_rack, strapped_stack, cargo_lift) and corridor/engineering wall props (junction_box, fuse_panel, wall_terminal, pipe_valve, emergency_locker, cable_spool, vent_cover).
`tools/blender/props_set_rooms.py`: engineering (reactor_core, power_cell_rack, control_desk, toolbox_cart), bio lab (specimen_tank, lab_bench, centrifuge, sample_freezer), bridge (captain_chair, helm_console, nav_table, wall_screen_bank), crew quarters (bunk_bed, footlocker, desk_chair), mess (mess_table, food_dispenser, galley_counter). Previews: `docs/screens/props/` (`rooms_sheet.jpg`). These rooms don't exist in the deck yet; they're ready for when level layouts add them.

## Expansion: hallway set and second room batch (`tools/blender/props_set_expansion.py`)
- **Hallway** (wall depth, for T019): `wall_rib`, `wall_panel_recessed`, `wall_panel_breached`, `pipe_run_low`, `pipe_run_high`, `conduit_tray`, `air_duct`, `wall_light_strip`, `emergency_lamp`, `door_jamb`, `door_lintel`, `corner_pillar`, `handrail`, `floor_grate`, `kick_plate`, `wall_sign_arrow`, `maintenance_hatch`, `fire_hose_reel`, `debris_pile`, `hanging_cables`.
- **Medbay:** `cryo_pod`, `scrub_sink`, `privacy_screen`, `defib_cart`, `biohazard_bin`, `body_bag`.
- **Cargo:** `crate_pile_tipped`, `container_section`, `pallet_jack`, `tarp_pile`, `cargo_net_wall`, `manifest_terminal`.
- **Engineering:** `coolant_pump`, `transformer`, `catwalk_section`, `workbench`.
- **Bio lab:** `incubator_shelf`, `chem_cabinet`, `autopsy_table`, `containment_cell`.
- **Bridge:** `crew_station`, `holo_projector`, `comms_rack`, `viewport_frame`.
- **Crew quarters:** `wardrobe_locker`, `sleeping_pod`, `shower_stall`, `personal_shelf`.
- **Mess:** `drinks_cooler`, `tray_trolley`, `round_table`, `waste_bin`.
- New mount kind **`wall_high`**: the origin is on the floor under the prop and the mounting height is baked in, against walls of 2.6 m (`data/deck.json`). Plain `wall` props still sit at a height the game picks.
- `props.py`'s `Builder.box`/`cyl` take an optional `rot=(rx, ry, rz)` in degrees, used for debris, ajar doors and knocked-over stools.
- Previews: `docs/screens/props/hall_*.jpg` and `<room>_b_*.jpg`.

## Weapons (`tools/blender/props_weapons.py`)
A016's designs, modelled by script because the art tool refused the images: `weapon_issue_rifle`, `weapon_budget_shotgun`, `weapon_flare_gun`, `weapon_plasma_cutter`, `weapon_rivet_driver`, `weapon_frag_charge`, `weapon_decoy_beacon`. About 4,300 triangles for all seven.
- **Held convention:** origin at the right-hand grip, forward +Z, up +Y (glTF). `catalogue.json` gives each weapon's `hold` (long gun, sidearm or thrown, matching the Mixamo holds) and `muzzle_m`, the muzzle point from the origin.
- Kit material slots as the other props. Sheet: `docs/screens/props/weapons_sheet.jpg`.
