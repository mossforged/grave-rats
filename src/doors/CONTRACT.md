# doors

Sliding bulkhead doors (T004), which stalkers break (T006).

## Owns
- `door_state.gd`: scene-free rules: closed, opening, open, closing, locked, broken, the panel's progress, and how far it's been bashed. Numbers from `data/doors.json`.
- `door.gd`: one door. A006's leaf (2.0 × 2.2 × 0.12 m, `src/kit`), its collision and sight rect all follow the panel, so a half-open door leaves a real half-size gap. Collision and sight keep T006's 0.2 m thick, full-height panel; only what you see is thinner. Lamp on the frame post, the same state light on the header top.
- `door_system.gd`: places the deck's doors, steps them, answers E, shows one prompt over the door in reach.

## Does not own
- The opening and frame posts (`src/study/deck_layout.gd`), the E key (the scene calls `interact`), what sight does with a door (`src/sight`).

## Rules
- Fully open is the only state that doesn't block; anything short of it still has a panel in the doorway.
- A door won't start closing on someone in the doorway ("blocked"), and a closing door backs off if someone steps in.
- A locked door answers "locked" and never moves. `unlock()` exists; nothing in the game calls it yet.
- Bashing only adds up on a shut, unlocked door, and stays if the basher leaves. At `bash.break_s` it's `BROKEN`: for good, stops nothing, hides nothing, leaf flat on the floor on the far side; E answers "broken". Only `reset` brings it back. Who bashes and when is `src/enemies`: only a stalker already hunting you, never one that just heard a noise (T008).
- **Dents (T010).** `bash_progress` drives the leaf's blend shape directly, bulging away from the blows, plus a warm lit seam and its light. No separate mid-bash mesh.
- A fully open panel is hidden: it lies inside the wall, where it fought the door post's surfaces.
- Only doors facing the camera (`along_x`) join the cut-away. Side doors stay tall, so a shut one reads as shut beside a dropped wall.

## Public API
- `DoorState.new(cfg, start)`: `interact(doorway_clear) -> "opening"|"closing"|"locked"|"blocked"|"broken"`, `step(delta, doorway_clear)`, `bash(delta) -> broke`, `blocks()`, `is_locked()`, `is_broken()`, `unlock()`, `prompt_key()`; fields `state`, `progress`, `bash_progress`; enum `State`.
- `Door`: `setup(door, spec, cfg, wall_height)`, `tick(delta, actors)`, `interact(actors)`, `reset(start)`, `bash(delta, from)`, `bang()`, `front_point(from, radius)`, `within_reach(p, radius)`, `doorway_clear(actors)`, `blocks_sight()`, `sight_rect()`; fields `door_state`, `opening`, `along_x`, `slide`, `space`, `side`. It's in group `sight_occluder`.
- `DoorSystem`: `setup(layout)`, `tick(delta)`, `door_in_reach(p)`, `interact(p) -> answer or ""`, `show_prompt(p)`; fields `doors` (same order as `data/deck.json` "doors"), `cfg`, `actors` [{`position`: Vector2, `radius`}].

## Signals
`Door.state_changed(door)`, `DoorSystem.door_used(door, answer)`.

## Data keys
- `data/doors.json`: `open_s`, `close_s`, `reach_m`, `panel_thickness_m`, `panel_top_gap_m`, `open_tolerance`, `lamp_size_m` [along, up, across], `lamp_height_m`, `lamp_energy`, `label_height_m`, `label_pixel_size`, `label_font_size`, `bash` {`break_s`, `bang_interval_s`, `reach_m`, `shake_m`, `shake_s`, `shake_hz`, `broken_lean_deg`}, `colors` {`panel`, `panel_dented`, `panel_broken`, `panel_locked` (all tints on the leaf's paint), `lamp_closed`, `lamp_open`, `lamp_locked`, `lamp_broken`, `label`, `label_locked`}, `words` {`open`, `close`, `locked`, `broken`}.
- `data/kit.json`: `dims` (leaf, aperture, header) and `door_look` (dent shape, seam, leak light, state strip).
- `data/deck.json` "doors" entries gain `state` ("closed"|"open"|"locked") and `slide` (±1, which way along the wall the panel goes; pick the side with solid wall).

Tests: `tests/test_doors.gd`.
