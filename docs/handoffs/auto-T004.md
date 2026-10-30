# T004 handoff: sight, flashlight and doors

Branch `auto/t004-mac`. Play it: `godot --path . scenes/sight/sight_deck.tscn`.
New keys: F flashlight, E door, F2 sight debug. Everything from `weight_deck` still works (WASD, Shift, C/Ctrl, mouse, LMB, R, 1-5, V, Backspace, F1, F3). Backspace also forgets the deck, as a new run.

## What changed
- `src/sight/` (new): scene-free line of sight and memory grid, the Godot adapter, `SightTarget`, the screen-space mask, flashlight with beam and motes, F2 view, and the scene root.
- `src/doors/` (new): scene-free door rules, the door, the door system with its E prompt.
- `data/sight.json`, `data/doors.json` are new. `data/debug.json` gains a "Sight" section in the F1 panel.
- `data/deck.json`: doors gain `state` and `slide`. **A fourth door was added** (locked, junction to cargo). **Two tall props were added** so rooms have something to hide behind: a locker bank mid-medbay and a crate stack in cargo. These also appear in `weight_deck` and T002's `scale_deck`, because they share the deck. The T002 and T003 captures were not retaken.
- No code changed in `src/player`, `src/camera`, `src/study` or `src/debug`. `sight_deck.gd` extends `weight_deck.gd`. `src/study/CONTRACT.md` notes the two new door keys.
- `tools/t004_sight_bench.gd`: CPU cost of a sight update.

**Cells, not rooms.** The three states live on a 0.25 m grid. A sight polygon cuts rooms in pieces, and the half you haven't seen is the corner you fear; a per-room state would light the whole room the moment you glimpsed it.

## Checks run
**Headless: 96 passed, 0 failed, 0 load errors** (71 before T004). `--import` exits 0 with no errors.

| Packet check | Test |
| --- | --- |
| wall blocks sight | `test_a_wall_blocks_sight` |
| closed door blocks, open doesn't | `test_a_closed_door_blocks_sight_and_an_open_one_does_not`, plus the scene test |
| low props don't block | `test_low_props_do_not_block_and_tall_props_do` |
| remembered persists after leaving | `test_grid_states_and_memory_persist_after_leaving`, `test_scene_memory_and_state_through_the_system` |
| `SightTarget` behind a wall is hidden | `test_a_sight_target_behind_a_wall_is_hidden` |
| off cone shorter than on | `test_the_light_off_cone_is_shorter_than_the_on_cone` |
| data-driven numbers | `test_numbers_come_from_data` (both modules), plus a literal scan of 8 scripts |

Also tested: closed doors stop a body and open ones let it through, door timing, locked, a door never shutting on someone, door placement, reach, and the F, E and F2 key handlers (fed key events directly).

I broke the code on purpose to prove the tests bite, then restored it:
- doors never block sight: 2 tests fail
- every prop is treated as tall: 1 fails
- walls removed from sight: 1 fails

The literal scan allows `4` (a rect's corners) and `0.0001` (geometry snapping). The mask scripts, the scene root and the shaders aren't scanned. The shaders hold default uniform values that are overwritten from data, plus the luma weights.

**Flashlight cost: about 0.35 ms, against the 2 ms limit.** Same scripted walk and light sweep through the open medbay door, 15 s per run, alternating:

| Run | Light on avg / p95 ms | Light off avg / p95 ms | Difference in avg |
| --- | --- | --- | --- |
| 1 | 3.44 / 4.75 | 2.97 / 3.31 | 0.47 |
| 2 | 3.29 / 3.74 | 2.97 / 3.32 | 0.32 |
| 3 | 3.80 / 5.79 | 3.55 / 6.71 | 0.25 |
| Mean | 3.51 | 3.16 | 0.35 |

- **Not quite 1080p.** All runs are 1920×954, this display's limit (open question in STATUS). 1080p has 13% more pixels. The worst on-versus-off pairing I can make from these numbers is 0.83 ms, so I don't expect the extra pixels to approach 2 ms, but that is a projection, not a measurement.
- **Not a quiet machine.** Load average was 4 to 7 during the runs, which shows in the p95 spread and is why run 3 is slow in both columns.
- M2 Pro, Metal, MSAA 4x, vsync off. Files: `docs/screens/T004/frametime_on*.json`, `frametime_off*.json`.

**Sight overall** adds about 0.8 ms on top of the flashlight question: 3.16 ms light off against 2.33 ms for `weight_deck` (`frametime_weight_deck.json`). That comparison is rough because the two scenes run different scripted demos; `weight_deck`'s also fires. CPU share: polygon 0.40 ms, grid fill 0.11 ms at its 20 Hz (2000 random spots on the real deck, `tools/t004_sight_bench.gd`).

## Screenshots (`docs/screens/T004/`)
- `enter_medbay_three_states`: medbay lit ahead, junction remembered behind, cargo and the rest of the medbay unknown.
- `flashlight_on`, `flashlight_off`: same spot.
- `door_closed`, `door_open`: same spot.
- `door_locked_prompt`, `target_hidden`, `target_seen`, `debug_f2`.
- `camera_ortho`: the mask also works on the orthographic preset.
- `postfx_glow_ssao_fog`: under the asset viewer's post effects, no black boxes by eye. I didn't run the T003 detector on it.

## Decisions made without you (easy to change)
- **Start numbers:** awareness 2.6 m; light cone 15 m at ±24°; no-light cone 7 m at ±36°; door 0.45 s; reach 2.2 m. All are in the data files, and most sight numbers have F1 sliders.
- **Darker lighting in this scene only** (`data/sight.json` "lighting"). `weight_deck` keeps its own.
- **What counts as tall:** 1.5 m and up blocks sight. The existing 1.2 m `crate_high` doesn't, so those crates are not corners yet. Crouching doesn't change sight.
- **The beam is a thin sheet, not a fog volume.** It is cut to the sight polygon, so it can't leak through a wall, and it is cheap.
- **Motes use CPU particles.** The GPU version made Godot report a leaked shader at exit.
- **The locked door can't be opened by anything yet.** Cargo is still reachable through its other door.
- **Side-facing doors skip the camera cut-away.** Otherwise a shut door dropped to knee height when you stood beside it and stopped looking like it blocked anything. Camera-facing doors still drop.

## Known limits
- **A few things draw over the mask and can tell you a little about dark areas:** the floor aim cone (it stops at walls you may not have seen), tracers, and the door prompt. Shots also hit dummies you can't see.
- **Hidden targets pop in** with no fade.
- **The remembered edge is slightly stepped** close up (no MSAA on that mask, because an uncleared multisampled target came back as garbage on Metal). The top of a tall prop can show a small notch at its edge.
- **The sight wedge is a little wider than the lit cone near the player** (up to about 0.3 m each side), because the wedge starts at the eye and the light at the muzzle.

## Needs John's eye
1. *"Do I feel the corners? Does walking into an unknown room feel uncertain?"* **Nobody has played this.** Everything above is scripted, and no real keyboard or mouse has driven it. Only stills were reviewed, so motion hasn't been judged: how the beam sweeps, how memory paints as you turn, the door slide, popping targets.
2. **Is a 2.6 m awareness circle too generous?** It's the first lever for dread. F1, section "Sight".
3. **How dark?** Remembered 0.30 and unknown 0.035 brightness are my read of the concept panel.
4. **Should 1.2 m crates block sight?** There's no stance rule yet, so this waits on the cover packet unless you want it sooner.
