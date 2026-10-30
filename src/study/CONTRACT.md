# study

T002 camera and scale study. Grey-box only; meant to be thrown away or folded into a real level module later.

## Owns
- `deck_layout.gd`: scene-free deck generator. `data/deck.json` → space rects, doorways (+ frame posts), wall pieces, props, and a walkability check (grid BFS for a disc of given radius).
- `deck_builder.gd`: layout → nodes (floors, wall pivots in the camera's cut-away group, hazard door frames, real-size props, box collision on walls/frames/props).
- `stand_in.gd`: CharacterBody3D with the legacy operator; WASD (screen-relative), faces `aim_point`, `L_Run_F`/`L_Idle`. No shooting.
- `scale_deck.gd`: root of `scenes/study/scale_deck.tscn`; plain lighting, HUD, live keys, capture shots.
- `tools/t002_sheet.py`: comparison sheets from the captures.

## Does not own
- Camera behaviour (`src/camera`), data loading (`src/core`), capture driver (`src/debug`), legacy assets.

## Public API
- `DeckLayout.new(deck: Dictionary, room_scale := -1)`: `spaces`, `space_order`, `doors`, `walls` (Rect2), `props`, `bounds`; `space_rect(name)`, `point_in(name, [fx, fz])`, `space_at(p)`, `blockers()`, `is_free(p, radius)`, `path_cells(from, to, radius, cell) -> int` (-1 = no path), `free_grid(radius, cell)`.
- `DeckBuilder.build(layout) -> Node3D` named "Deck".
- Scene: `set_room_scale(s)`, `set_character_scale(s)`, `respawn()`, `capture_shots()`, `apply_shot(shot)`, `release_shot()`.
- Keys: 1–5 camera preset, 6/7/8 room scale 0.85/1.0/1.15, 9/0 character scale 1.0/1.15, C cut-away mode, R respawn, WASD, mouse aim, F3 frame time.

## Layout rules
Rects are world XZ metres (x east, z south). Space sizes scale with `room_scale` and snap to `grid_m`; walls, doors, props and the character don't scale. A space with an `anchor` sits on the given side of another space, one wall thickness away (or touching when `open`), shifted by `offset_m` × room scale + `offset_walls` × thickness. Wall = inside some space's wall band, outside every interior, doorway and frame post; merged into boxes, split to ≤ `wall_segment_m`.

## Signals
None.

## Data keys (`data/deck.json`)
`grid_m`, `floor_tile_m`, `wall_height_m`, `wall_thickness_m`, `wall_segment_m`, `door_width_m`, `door_frame_m`, `room_scale`, `room_scale_options`, `character_scale`, `character_scale_options`; `spaces` [{`name`, `kind` (room|corridor), `size_m` [x, z], `anchor` {`to`, `side`, `offset_m`, `offset_walls`, `open`}}]; `doors` [{`space`, `side`, `at` (0–1 along that side)}]; `props` [{`type`, `space`, `at` [fx, fz] centre, `size_m` [x, y, z]}]; `spawn` {`space`, `at`, `aim_deg` (0 = north/screen-up)}; `path_check` {`from`, `to`, `cell_m`, `margin_m`}; `stand_in` {`speed_m_s`, `turn_deg_s`, `radius_m`, `height_m`, `aim_height_m`}; `lighting` {...}; `colors` {...}.

Tests: `tests/test_deck.gd`.
