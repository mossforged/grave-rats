# auto-T002: camera and scale study (grey box)

Branch `auto/t002-mac`. Godot 4.7.2, Forward+ on Metal, M2 Pro. Run it: open `scenes/study/scale_deck.tscn` and press F6, or `godot --path . scenes/study/scale_deck.tscn`.

## What changed
- **`src/camera/`** (new): `camera_rig.gd` follows a target with exponential smoothing (`smoothing_hz` 5) and 1.6 m look-ahead toward the aim. Perspective or orthographic, with pitch, yaw, FOV, distance and ortho size all in `data/camera.json`. Five presets plus the wall cut-away. `camera_math.gd` holds the math, scene-free, so it is tested headless.
- **`src/study/`** (new, see "deviation" below): `deck_layout.gd` generates the deck from `data/deck.json`. `deck_builder.gd` turns it into boxes with collision. `stand_in.gd` is the legacy operator with WASD and mouse aim. `scale_deck.gd` runs the scene: HUD, keys and capture shots.
- **`scenes/study/scale_deck.tscn`**: medbay 14×10 m, junction corridor 6 m wide and 26 m long, cargo hold 14×12 m, side corridor 3.5 m wide. The cargo hold has two doors (one from the junction, one from the side corridor), so there is a loop. Walls are 2.6 m tall (about 1.4 character heights) and 0.5 m thick. Doors are 2.0 m with hazard-yellow frames. Props at real size: two beds 0.9×2.0 m, consoles, cabinets, 1.2 m and 0.8 m crates, a yellow ammo crate. The floor has 1 m tile lines so you can count metres. Lighting is plain: one sun plus ambient.
- **Data-driven scale.** Room and corridor sizes, wall height, thickness and segment length, door width, grid, room and character scale (with their key options), props, spawn and stand-in speed all live in `data/deck.json`. A number edit changes the deck, and a test edits numbers to prove it. Rooms scale and snap to the 0.5 m grid. Walls, doors, props and the operator keep their real size.
- **Keys** (also shown on the HUD): **1–5** camera preset; **6/7/8** room scale 0.85/1.0/1.15; **9/0** character scale 1.0/1.15; **C** cut-away mode (drop/fade/off); **R** respawn; **WASD** move (screen-relative); **mouse** aim; **F3** frame time. The HUD also shows a live "operator = x% of view height".
- `tools/t002_sheet.py` builds the comparison sheets (needs Pillow).

## Presets (`data/camera.json`)
| key | name | projection | pitch | fov / size | distance | operator % of view height* |
|---|---|---|---|---|---|---|
| 1 | concept match | persp | 56° | 35° | 23 m | 6.6 % (7.7 % at character ×1.15) |
| 2 | steeper / closer | persp | 68° | 35° | 16 m | 5.5 % |
| 3 | flatter / wider | persp | 48° | 40° | 30 m | 5.5 % |
| 4 | prototype ortho | ortho | 52° | 17 m tall | 40 m | 6.5 % (computed: 1.8 m × cos 52° / 17 m) |
| 5 | wildcard: long lens | persp | 58° | 18° | 44 m | 6.7 % |

\*Measured for a 1.8 m operator (the HUD number). The model with its helmet is 1.96 m.

- **Wildcard, long lens:** a narrow FOV from far away. Walls still show their inner faces a little, but lines stay nearly parallel, close to orthographic. It looks calmer and less fish-eyed than 35°.
- **Prototype ortho is an estimate.** I read the pitch and zoom off `dead-circuit-pass05-compare-junction.jpg` and did not read the prototype code.

## Wall cut-away: picked **drop**
Walls are split into pieces of 2 m or less. Any piece inside a zone that runs 7 m from the player toward the camera, 4 m to each side, sinks to 0.45 m. Fade (key C) is also built and is in `concept_room_100_fade.png`.

Why drop:
- It matches the concept, where near walls are drawn as low cut edges.
- The floor plan stays readable, because you still see where every wall and doorway is.
- It avoids the ghostly see-through walls and the transparency sorting that fade brings.

Collision never changes in either mode.

## Checks run
- **Headless tests:** `godot --headless --path . -s tests/run_tests.gd` gives `TESTS: 32 passed, 0 failed, 0 load errors`. That is 12 old tests plus 20 new: 8 in `test_camera.gd` and 12 in `test_deck.gd`.
  - **Deck:** room and corridor sizes come from `deck.json` at each room scale. Editing `size_m` or `wall_thickness_m` changes the deck. Corridors are 6 m and 3.5 m. Walls are no longer than the segment length, no thinner than the wall thickness, don't overlap each other and stay out of rooms. Door frames are separate pieces, so there's no z-fighting.
  - **Doors and path:** every doorway is 2.0 m. The test needs more than 2 × 0.46 m (the radius at character ×1.15) plus 0.3 m margin, i.e. more than 1.22 m. No wall or prop sits in a doorway. A grid search (0.1 m cells, radius 0.51 m) finds a walkable path from the medbay to cargo at all three room scales. A control test with 0.6 m doors finds no path, so the check can fail.
  - **Spawn, props, scene:** the spawn point is free and every prop sits inside its room at every scale. Beds stay 0.9×2.0 m and crates are 1.2 m and 0.8 m tall at room ×1.15. The builder makes one cut-away pivot per wall piece. The scene builds headless, switches preset, room scale and character scale, and frees the old deck. The stand-in collides with a wall.
  - **Camera:** the operator's feet and head (2.3 m) stay in the middle 85 % of the screen at every preset, at 16:9 and 16:10. That holds with 16 look-ahead directions, and after running 3 s at full speed in 8 directions with the aim pointing backwards (worst follow lag). Godot's own `Camera3D.is_position_in_frustum` agrees with my math at every preset. The concept preset gives the operator 6.5–9.5 % of view height. The follow is the same at 60 and 120 fps. The cut-away zone is tested, including a yawed camera.
- **Import:** `godot --headless --path . --import` gives 0 errors. There are 13 old warnings ("invalid UID … using text path instead") for the legacy `operator.glb` animation `.res` files. They come from the lead's local re-import (f982ce4), not from this task. I left them alone because the legacy assets aren't my module.
- **Frame time** (`docs/screens/T002/frametime.json`, concept preset, 10 s after a 2 s warmup, vsync off, MSAA 4×, sun shadows on): **2.81 ms avg (356 fps), p95 4.41 ms, p99 6.92 ms, max 29.1 ms**, 3557 frames, at **1920×954**.
  - **Not quite 1080p:** the display here is 1920×1080 at scale 1.0, so the title bar and menu bar keep the window at 954 px tall (T001 got the full 1080). `CAPTURE_SIZE=1600x900` was ignored too, and the window stayed 1920×954.
  - **Mac load:** load average was about 2 during the run.
  - **Standing still:** the stand-in stands still during the measurement. There's no auto-walk.

## Screenshots (`docs/screens/T002/`, 1920×954 each)
- **Every preset at default scale:** `preset_1_concept_match.png` … `preset_5_wildcard_long_lens.png`.
- **Concept preset at each room scale:** `concept_room_085.png`, `concept_room_100.png`, `concept_room_115.png`. Also `concept_room_100_char_115.png`, `concept_room_100_fade.png`, `concept_room_100_medbay.png` (inside the medbay, south wall dropped) and `concept_room_100_cargo.png`.
- **Sheets:**
  - `sheet_presets.png`: all five presets.
  - `sheet_scales.png`: room scales, bigger character, fade, inside rooms.
  - `sheet_concept_side_by_side.png`: `gameplay-panel.jpg` above preset 1 and preset 3, both cropped to the panel's 2.33:1.
- **How the crops work:** sheet cells are centre crops. Godot keeps the vertical view fixed, so a centre crop shows exactly what a window of that shape would.
- `scale_deck.png` / `scale_deck_overlay.png` show the default view, without and with the FPS overlay.

## What needs John's eye
**The question:** *which preset and scale feel like the concept, and do the medbay and junction feel tight enough?* He answers by playing.

**Main finding: the concept can't be matched on both counts at once with a real-size operator.**
- At a 55–65° pitch, a standing figure is foreshortened to about half its height (cos 60° = 0.5). The concept draws its crew nearly upright, as if seen from about 30–40°.
- So you can match the lead's "operator ≈ 8 % of view height" or the panel's composition (medbay, junction and a good part of cargo all in view), but not both.
  - **Preset 1** leans to operator size: 6.6 %, and 7.7 % with character ×1.15. You see about one and a half rooms.
  - **Preset 3** leans to composition: the side-by-side shows it frames like the panel, but the operator is 5.5 %.
- Levers to try live:
  - character ×1.15 (key 0);
  - room ×0.85 (key 6);
  - a lower pitch, which makes the operator look taller.
- One more measurement against the panel: its medbay is about 7 drawn operator heights wide. With a real 2 m bed that only works with the operator about 2.2 m tall or the room about 12 m wide. So **room ×0.85 with character ×1.15** may be the closest match. I couldn't judge feel, only measure.

**Other things to look at:**
- **Cut-away zone:** 4 m each side and 7 m deep. Walls south-east and south-west of you stay tall. If that blocks too much, widen `half_width_m`.
- **Wall height:** 2.6 m is tall enough to hide the floor behind north-facing walls at pitch 48° (preset 3).
- **Animation:** the run animation slides, as expected, and there's no upper-body aim layer.
- **Not checked:** I didn't play it by hand; the run was unattended. Mouse aim, WASD feel and the key switching are tested headless and visible in captures, but no human tried them.

## Deviation from the packet
- **New `src/study/` module.** The packet names `src/camera/` and `scenes/study/`. The deck generator, stand-in and scene script needed somewhere to live, and CLAUDE.md puts scripts in `src/<module>/`, so they're in `src/study/` with a CONTRACT. The cut-away talks to walls only through the camera group contract.
- **Two extra data files:** `data/camera.json` and `data/deck.json`. The deck file also holds stand-in speed and size, and the plain lighting.

## Needs a human decision
- Preset and scale (the gate question above).
- **Capture height:** `capture.sh` reaches only 1920×954 on this display. Either accept that, or let the capture tool use a borderless window (that's in `src/debug`, a separate task).

## Parked (also in STATUS)
- An auto-walk path during frame-time capture, so the number includes camera motion and the cut-away animating.
