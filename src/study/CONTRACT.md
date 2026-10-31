# study

T002 camera and scale study; since T010 its builder places the real kit (`src/kit`). Meant to be folded into a real level module later.

## Owns
- `deck_layout.gd`: scene-free deck generator. `data/deck.json` → space rects, doorways (+ frame posts), wall pieces, props, and a walkability check (grid BFS for a disc of given radius).
- `deck_builder.gd`: layout → nodes. Kit pieces: floors, wall pivots in the camera's cut-away group, door jambs and headers, props, wall and floor signs. Props take their yaw from `KitPieces.prop_yaw`. Box collision on walls, frames and props, as in T009. Every mesh has meta `kit_piece`.
- `stand_in.gd`: CharacterBody3D with the legacy operator; WASD (screen-relative), faces `aim_point`, `L_Run_F`/`L_Idle`. No shooting.
- `scale_deck.gd`: root of `scenes/study/scale_deck.tscn`; plain lighting, HUD, live keys, capture shots.
- `tools/t002_sheet.py`: comparison sheets from the captures.

## Does not own
- Camera behaviour (`src/camera`), data loading (`src/core`), capture driver (`src/debug`), legacy assets.

## Public API
- `DeckLayout.new(deck: Dictionary, room_scale := -1)`: `spaces`, `space_order`, `doors`, `breaches`, `walls` (Rect2), `props`, `bounds`; `space_rect(name)`, `point_in(name, [fx, fz])`, `space_at(p)`, `blockers()`, `is_free(p, radius)`, `path_cells(from, to, radius, cell) -> int` (-1 = no path), `free_grid(radius, cell)`.
- `DeckBuilder.build(layout) -> Node3D` named "Deck", with children `Floors`, `Walls`, `DoorFrames`, `Props`, `FloorSigns`; `DeckBuilder.wall_at(walls, p)`.
- Scene: `set_room_scale(s)`, `set_character_scale(s)`, `respawn()`, `capture_shots()`, `apply_shot(shot)`, `release_shot()`.
- Keys: 1–5 camera preset, 6/7/8 room scale 0.85/1.0/1.15, 9/0 character scale 1.0/1.15, C cut-away mode, R respawn, WASD, mouse aim, F3 frame time.

## Decks by file (T023)
`data/deck.json` is the first ship. Another ship is a file like it (`data/deck_survey.json`), with `data_overrides` {file: keys} laid over the other data files while that ship is in use. `Data` does this (`src/core/CONTRACT.md`): everything goes on reading `Data.load_data("deck")`. `tools/t023_make_deck.py` writes the survey's file from A014's plan.

## Layout rules
Rects are world XZ metres (x east, z south). Space sizes scale with `room_scale` and snap to `grid_m`, except a space with `rect_m`, which is final world metres and never scaled (T023's scale policy: the plan's dimensions are built as they are, not divided by 0.85); walls, doors, props and the character don't scale. A space with an `anchor` sits on the given side of another space, one wall thickness away (or touching when `open`), shifted by `offset_m` × room scale + `offset_walls` × thickness. Wall = inside some space's wall band, outside every interior, doorway and frame post; merged into boxes, split to ≤ `wall_segment_m`.

## Rules
- A wall piece's family comes from the space on each face (`data/kit.json` `wall_families`); its end becomes a corner post where another wall meets it from the side.
- A door header is a child of the door's first jamb pivot, so it fades with the frame and the cut-away count stays two per door.

## Signals
None.

## Data keys (`data/deck.json`)
`grid_m`, `floor_tile_m`, `wall_height_m`, `wall_thickness_m`, `wall_segment_m`, `door_width_m`, `door_frame_m`, `room_scale`, `room_scale_options`, `character_scale`, `character_scale_options`; `spaces` [{`name`, `kind` (room|corridor), `size_m` [x, z], `anchor` {`to`, `side`, `offset_m`, `offset_walls`, `open`}} or {`name`, `kind`, `rect_m` [x, z, w, d]}]; `doors` [{`space`, `side`, `at` (0–1 along that side), `state`, `slide` (both read by `src/doors`; this module only cuts the opening)}]; `props` [{`type`, `space`, `at` [fx, fz] centre, `size_m` [x, y, z], `cover` (none|low|tall, read by `src/cover`), optional `tippable`, `overturned`, `tip_side` (read by `stalker_deck`; other scenes draw these beds as plain upright boxes), optional `wear` {slot: kit material} (a surface in another material), optional `plan_cover` (index into the plan's cover list; read by tests)}]; `dressing` [{`type`, `space`, `at` [fx, fz], optional `turn_deg`} or {`type`, `space`, `wall`, `at` (0-1 along it)}] (read by `src/kit/dressing.gd`; the builder only adds its node); `dressing_max_intrusion_m`, `corridor_dressing` {...} (read by `src/kit/corridor_dressing.gd`; the builder only passes it the wall and frame nodes); `spawn` {`space`, `at`, `aim_deg` (0 = north/screen-up)}; `effects` (read by `src/vfx`, through `weight_deck`; this module doesn't touch them); optional `breaches` [{`space`, `side`, `at`}]: wall openings with floor but no door or frame, for their owner to fill (`src/enemies/bulkhead.gd`); only `stalker_deck`'s copy of the deck has any; `path_check` {`from`, `to`, `cell_m`, `margin_m`}; `stand_in` {`speed_m_s`, `turn_deg_s`, `radius_m`, `height_m`, `aim_height_m`}; `lighting` {...}. The kit's look is in `data/kit.json` (`src/kit/CONTRACT.md`); `colors` here is no longer read by the builder.

Tests: `tests/test_deck.gd`.
