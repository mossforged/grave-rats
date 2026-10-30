# T003 handoff: the weighty operator and the gun

Branch `auto/t003-mac`. Play it: `godot --path . scenes/player/weight_deck.tscn`.
Keys: WASD, Shift sprint, C/Ctrl crouch, mouse aim, LMB fire, R reload, 1-5 camera, V cut-away (C is crouch here), Backspace respawn and refill, F1 tuning, F3 frame time.

## What changed
- `src/player/`: scene-free weight model, operator body, animation hookup with spine twist, floor cone / arc / ring, minimal HUD, the scene root.
- `src/weapons/`: scene-free cone and rifle rules, hitscan, flash / tracer / impact, target dummies.
- `src/debug/`: `tuning_panel.gd` (F1). `capture.gd` now awaits `apply_shot`, so a scene can run real frames to reach a moment. T002's scene still captures (15 files).
- `data/player.json`, `data/weapons.json` are new; `data/debug.json` gains `tuning`. Contracts are written or updated.
- `tools/`: `t003_blackbox.py`, `t003_footslide.gd`, `t003_strip.py`.
- `src/camera` and `src/study` are untouched. The camera kick goes through `Camera3D.h_offset/v_offset`.

## Checks run
**Headless: 71 passed, 0 failed, 0 load errors** (32 before T003). Import prints no errors.
- 180° turn takes `180/rate` within a frame, for standing, firing and crouched.
- Cone closes wide to tight over `settle_s`, half closed at half time; moving never goes under the minimum, from the first step.
- Reload: fire is refused and doesn't cancel it, it takes its full time; sprint cancels it and loses the magazine.
- Speed before the move: pushing a wall still reads walk speed with the body stopped.
- Numbers from data: edited config changes behaviour; a scan rejects tunable literals in 9 gameplay scripts (HUD, panel, `weight_deck.gd` and `operator_anim.gd` are not scanned; `weight_deck.gd` has literals only in its capture and demo code).
- I broke the code on purpose to prove two tests bite: measuring speed after the move fails the walk test, and un-swapping the strafe clips fails the strafe test. Both restored.

**Frame time** (`docs/screens/T003/frametime.json`): **2.08 ms avg, 2.50 ms p95, 3.13 ms p99, 19.2 ms max**, 4812 frames, 1920×954 (this display's limit), M2 Pro, Metal, MSAA 4x, vsync off. The measuring window walks, turns and fires, so it counts the gun.

**Black boxes:** `postfx_no_flash.png` vs `postfx_flash.png` under the asset viewer's glow, SSAO and volumetric fog: no solid dark block, 23161 pixels much brighter. The detector does fail on a 60 px black square painted into the frame. The 9436 "much darker" pixels are thin edges from the camera kick and the dummy flinching. Also looked at the frames: clean.

## Screenshots (`docs/screens/T003/`)
`turn_arc_midturn`, `cone_wide`, `cone_settled`, `shot_tracer`, `reload_mid`, `walk_strip` (the 6 frames, cropped; `walk_1`..`6` are the full ones), plus `crouched`, `sprint_low_ready`, `torso_lead`, `target_flinch`, `tuning_panel`, `postfx_*`.

## Foot sliding: how bad
Measured by `tools/t003_footslide.gd`, planted foot speed over the ground at the start numbers:

| Move | Body | Foot slides | Share of body speed |
| --- | --- | --- | --- |
| walk forward | 3.40 m/s | 2.66 m/s | 78% |
| walk back | 3.40 m/s | 3.25 m/s | 95% |
| strafe right / left | 3.40 m/s | 4.65 / 4.69 m/s | 137% / 138% |
| crouch forward | 1.50 m/s | 2.23 m/s | 149% |
| sprint forward | 5.40 m/s | 4.02 m/s | 75% |

Take these as rough: "planted" means the foot is in the lowest 3 cm of its swing, which catches some of the lift and plant. In the strip the legs clearly animate. At this camera I'd expect the slide to be noticeable on strafes and the crouch and acceptable forward, but I can only judge stills. Turning in place also slides: the legs have no turn clip, so dragged hips just rotate.

## Found in the legacy assets
- **`L_Strafe_L` and `L_Strafe_R` are named backwards.** In `L_Strafe_L` the planted feet sweep toward model-left, which is what stepping right looks like. Strafe slide was 233% before swapping them in the blend tree. The asset itself is unchanged.
- `L_Crouch_Walk` barely steps (feet range about 0.23 m, native speed about 0.7 m/s), so it plays capped at 1.6× at the 1.5 m/s crouch speed.

## Decisions made without you (easy to change)
- **Leg blend is relative to the torso, as the packet says,** but the legs hang off the hips. While the torso leads, the legs are off by that angle until the hips catch up (`hip_settle_deg_s`).
- **Cone model:** walking at full speed holds it at wide, slower movement scales down to the moving minimum, stopping closes it. Turning opens it per degree turned (`turn_open_per_deg`), so small tracking still settles and a hard turn opens it.
- **Recoil gets a recovery delay** (0.12 s) and a same-side chance, both new levers. At the study's 12°/s recovery, recoil would otherwise never build at this fire rate.
- **Reload:** the dropped magazine's rounds go back to the reserve; only the new magazine is at risk. No auto-reload on empty.
- **Start numbers not in the study:** walk 3.4 m/s (matches the run clip; T002's stand-in was 4.2), crouch 1.5, sprint 5.4, reload 2.0 s, fire interval 0.11 s.
- **Small addition:** the cone stops at walls, because without it it drew through them and out over the void. It is one ray per segment, per step.

## Needs John's eye
1. *"Does it feel heavy without feeling laggy?"* **Nobody has played this.** Everything above is scripted input: real keyboard and mouse handling, including a click during a reload and dragging sliders, has not been exercised.
2. **The F1 Save button has not been clicked against the real `data/`.** Tests run the save code against a temp folder. After your first Save, check `git diff data/`.
3. **Cursor vs cone** (open question in STATUS): the cone is on the floor, the cursor aims at gun height, so the cursor sits about 0.8 m screen-up of the cone's line. A ring marks the floor point under the aim. I kept the height aim so shots go where the cursor is on a dummy.
4. Is the tight cone (1.5°) readable? It is close to a line in `cone_settled`.
5. Is the `reload_mid` pose readable at game distance? It's clear in a zoomed crop; the HUD bar carries it otherwise.

## Study levers without a slider
Not built, so nothing to tune: footwork sound, melee commitment, shotgun recoil, player stagger (out of scope here). Targets flinch on every hit with no stagger threshold. The camera follow slider is included and saves to `data/camera.json`, a third file beyond the two the packet names.
