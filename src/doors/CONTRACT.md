# doors

Sliding bulkhead doors (T004).

## Owns
- `door_state.gd`: scene-free rules: closed, opening, open, closing, locked, and the panel's progress. Numbers from `data/doors.json`.
- `door.gd`: one door. Panel mesh, collision and sight rect all follow the panel, so a half-open door leaves a real half-size gap. Lamp on the frame post.
- `door_system.gd`: places the deck's doors, steps them, answers E, shows one prompt over the door in reach.

## Does not own
- The opening and frame posts (`src/study/deck_layout.gd`), the E key (the scene calls `interact`), what sight does with a door (`src/sight`).

## Rules
- Fully open is the only state that doesn't block; anything short of it still has a panel in the doorway.
- A door won't start closing on someone in the doorway ("blocked"), and a closing door backs off if someone steps in.
- A locked door answers "locked" and never moves. `unlock()` exists; nothing in the game calls it yet.
- Only doors facing the camera (`along_x`) join the cut-away. Side doors stay tall, so a shut one reads as shut beside a dropped wall.

## Public API
- `DoorState.new(cfg, start)`: `interact(doorway_clear) -> "opening"|"closing"|"locked"|"blocked"`, `step(delta, doorway_clear)`, `blocks()`, `is_locked()`, `unlock()`, `prompt_key()`; fields `state`, `progress`; enum `State`.
- `Door`: `setup(door, spec, cfg, wall_height)`, `tick(delta, actors)`, `interact(actors)`, `doorway_clear(actors)`, `blocks_sight()`, `sight_rect()`; fields `door_state`, `opening`, `along_x`, `slide`, `space`, `side`. It's in group `sight_occluder`.
- `DoorSystem`: `setup(layout)`, `tick(delta)`, `door_in_reach(p)`, `interact(p) -> answer or ""`, `show_prompt(p)`; fields `doors` (same order as `data/deck.json` "doors"), `cfg`, `actors` [{`position`: Vector2, `radius`}].

## Signals
`Door.state_changed(door)`, `DoorSystem.door_used(door, answer)`.

## Data keys
- `data/doors.json`: `open_s`, `close_s`, `reach_m`, `panel_thickness_m`, `panel_top_gap_m`, `panel_roughness`, `open_tolerance`, `lamp_size_m` [along, up, across], `lamp_height_m`, `lamp_energy`, `label_height_m`, `label_pixel_size`, `label_font_size`, `colors` {`panel`, `panel_locked`, `lamp_closed`, `lamp_open`, `lamp_locked`, `label`, `label_locked`}, `words` {`open`, `close`, `locked`}.
- `data/deck.json` "doors" entries gain `state` ("closed"|"open"|"locked") and `slide` (±1, which way along the wall the panel goes; pick the side with solid wall).

Tests: `tests/test_doors.gd`.
