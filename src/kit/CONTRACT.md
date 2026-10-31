# kit

The slice kit (T010, polished in T011): every wall, door part, floor, box prop, fixture and sign on the deck, generated in the engine to A006's dimensions, with its materials and the deck's lighting.

## Owns
- `kit_mesh.gd`: scene-free mesh builder. Chamfered boxes, cylinders, a file's triangles (`add_triangles`), one surface per material, UVs in metres, grime as vertex colours (low and in corners). Faces of a material with `edge_band_m`, at least `dims.trim_face_min_m` both ways, are cut into nine so their rim lands on the texture's worn rim at any size (T011); four mirrorings stand in for the UV variants.
- `floor_wear.gd`: scene-free. `paint(layout, cfg, floors) -> Image` (R foot traffic door to door and thresholds, G damp round drains, grates and data patches), `rect_for`, `sample`.
- `kit_floor.gdshader`: the deck plates: PBR plus that map, in world XZ. `KitMaterials.floor_material(wear, rect)`.
- `kit_pieces.gd`: the pieces, cached by what makes them different. `wall`, `wall_cap`, `corner_post`, `door_jamb`, `door_header`, `door_leaf` (blend shapes `dent_front`, `dent_back`), `door_seam`, `prop`, `prop_yaw(layout, p)`, `slot_file`, `slot_mesh`, `slot_box`, `floor_space`, `threshold`, `fixture`; `space_layer(layout, space)`.
- `dressing.gd`: the room dressing from `data/deck.json` "dressing" (T016). `Dressing.placed(layout)` -> pieces {`type`, `space`, `wall`, `mesh`, `position`, `yaw`, `rect`}; `Dressing.build(layout)` -> the node `DeckBuilder` adds.
- `kit_materials.gd`: `material(key)`, `make(spec, shared)`, `decal(image)`, `floor_material(wear, rect)`, `cfg()`, `uv_metres(key)`, `edge_band(key)`. Reads `data/kit.json`.
- `deck_lighting.gd`: the environment (dark ambient, AgX, glow, SSAO), the fog volume, the strip fixtures and their lights, one reflection probe per room. `setup(layout, env, deck)`; fields `lights`, `probes`, `fog_volume`, `cfg`.
- `tools/t010_textures.py`: generates `assets/game/kit/tex/`. `tools/t011_decals.py`: cuts `assets/game/kit/decals/` from A010's sheets and removes any no longer in the data. Re-run them, then `godot --headless --path . --import`, after changing `textures` or `decals`.

## Does not own
- Where anything goes: `src/study/deck_layout.gd` still decides, and `src/study/deck_builder.gd` places pieces there. Door behaviour: `src/doors`. What you know: `src/sight`, whose mask sits on top of all this.

## Rules
- All numbers in `data/kit.json`. A piece of any length keeps its trim sizes; only its panels change, so closing pieces aren't stretched bays. Nothing pokes out of a piece's bounds.
- Collision, occluders and cover classes never come from a mesh. `tests/fixtures/t009_deck_snapshot.json` holds them to T009 (`tools/t010_snapshot.gd` wrote it on T009's builder).
- **Layers.** A space's floor, walls and props sit on that space's render layer (`space_layer`); its lights touch only that layer and layer 1 (people, doors, beds). So a lamp can't shine through a wall, without paying for a shadow. A wall shared by two rooms is on both, and each light only reaches the face turned to it.
- **Signs are alpha scissor, never alpha blend.** Transparents draw after the sight mask, so a blended sign would show through the dark.
- **Probes reflect in floors only.** Floors alone are on `floor_wear.layer_index`, which is each probe's `reflection_mask`; a probe sees only its room's layer, so never people, doors or the sight mask. Keep that index clear of the space layers.
- **Wear isn't in the deck tile.** A tile can't know where feet go: no polish or stains there, only in the map.
- **Glass is opaque** for the same reason: smoked, glossy, never a real see-through. It changes no cover or sight class (A006-08).
- **Slots.** `data/kit.json` "slots" names each type's file in `assets/game/props/` (T013: console, cabinet, locker_bank; T016: bed, gurney, surgical_lamp, iv_stand, trolley, med_station). A slot with several files is keyed by width in metres: the one matching the prop's long side, else the widest that fits. A file that won't fit the footprint (`slot_fit.tolerance_m`) or won't load gives the box. `KitPieces.prop` is the one place to swap them. `TipBed` and `SalvageField` take their meshes from here too.
- **Dressing is looks only.** No collision, cover class, sight occluder or nav blocker, and it isn't in `layout.props`, so a bot, a stalker or a round goes straight through it. Keep it off doors, a low prop's long sides, a bed's landing on either side, spawns, patrol points, salvage and the bots' routes (`tests/test_dressing.gd`). Entries for a room the deck doesn't have are skipped. A wall piece's back goes on the room's face of the wall, wherever the file's origin is; put it on a north wall, since the cut-away fades walls on the camera's side and a piece wouldn't fade with them. The gurney collides, so it is a normal `props` entry with `cover: low`, not dressing.
- **Slot files are rebuilt, not shown as imported.** `slot_mesh` reads positions and normals and sends them through `KitMesh.add_triangles`: each surface wears the kit material its file slot is named after (the file's colours are never used), with box-projected UVs at that material's `uv_m`, tangents and height grime. The files carry no UVs. Their faces aren't cut into nine as walls are; the prop's centre sits on the tile's centre instead, which keeps the worn rim off faces shorter than the tile.
- **Files front +Z, origin on the floor.** `prop` returns them in that frame; `prop_yaw` turns them so the file's long side lies along the prop's. A file wide in X fronts across the prop; a file long in Z (bed, gurney) fronts along it, foot first. The front goes toward the room's centre, unless a disc of `slot_fit.front_clear_m` there is blocked and the other side is open.

## Signals
None.

## Data keys (`data/kit.json`)
`dims` (A006 door and trim sizes; wall height and depth come from `data/deck.json`), `grime`, `uv_variants`, `bay_variants`, `wall_families` {`by_space`, `outside`, `corridor_pipe_every`, `corridor_pipe_min_m`, one entry per family}, `door_look`, `crate`, `slots`, `slot_mat`, `wall_mounts` {type: `mount_y_m`}, `slot_fit` {`tolerance_m`, `front_clear_m`}, `floors` {plates, seams, rivets, `hazard`, `threshold`, grates, `spaces` {name: `grates` [{`at`, `size_m`}], `drains` [[fx, fz]]}, `default`}, `materials` {key: `texture` or `color`, `tint`, `roughness`, `metallic`, `specular`, `uv_m`, `emission`, `energy`}, `material_shared`, `textures`, `decals`, `floor_wear` {`layer_index`, `px_per_m`, `margin_m`, path, threshold, drain, grate and patch reach and strength, `look`, `spaces` {name: `hub`, `routes`, `damp` [[fx, fz, reach]]}}, `signage` {`layer_step_m`, `walls` [{`image`, `space`, `wall`, `at`, `y_m`, `width_m`, `layer`, `tilt_deg`}], `floors` [{`image`, `space`, `at`, `width_m`, `turn_deg`}]}, `lighting` {`environment` (also `glow_levels`, `ssao_blur`), `sheen` {`mode` probe|ssr|off, `probe`, `ssr`}, `fog`, `fixtures` {sizes, `looks`, `shadow_mode`, `spaces` {name: [{`look`, `wall`, `at`, `vertical`, `shadow`}]}}}. `materials` entries may add `edge_band_m`, `normal_scale`.

## Env (frame-time pricing)
`KIT_FOG`, `KIT_PRACTICALS`, `KIT_SSAO`, `KIT_GLOW` = `off`; `KIT_SHEEN` = `probe`, `ssr` or `off`.

Tests: `tests/test_kit.gd`, `tests/test_slice_polish.gd`, `tests/test_dressing.gd`. `tests/test_kit.gd` holds the deck to the T009 snapshot apart from the gurney, T016's one deliberate addition; the fixture is unedited.
