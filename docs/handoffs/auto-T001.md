# auto-T001: Godot skeleton and legacy asset import

Branch `auto/t001-mac`. Godot 4.7.2 stable, Forward+ on Metal, Apple M2 Pro.

## What changed
- **Project** `project.godot`: "Grave Rats", Forward+, window 1920×1080 resizable, main scene = the asset viewer, autoloads `Data`, `DebugOverlay`, `Capture`. Anisotropic filtering 8×.
- **MSAA 3D 4×.** Why: the steep camera makes rifles, rails and wall trim thin, near-horizontal edges that crawl at 2×. Cost was inside the noise on this Mac: 10 s runs gave 2× = 3.9 / 7.9 / 7.0 ms avg, 4× = 7.0 / 8.1 ms avg (the machine had load avg ~6.6 from other work, so these runs vary a lot). Easy to drop to 2× later if a scene gets tight.
- **`src/core/data.gd`** (autoload `Data`): `load_data(name)` / `value(name, key, fallback)`; missing file, bad JSON or missing key → `push_error`, `null`/fallback, `last_error` set. `data/debug.json` seeds the overlay toggle.
- **`src/debug/`**: `fps_overlay.gd` (F3, on by default from `data/debug.json`), `capture.gd` (capture driver), `asset_viewer.gd`. Contracts written for `src/core` and `src/debug`.
- **Tests** `tests/run_tests.gd`: finds `tests/test_*.gd`, runs every `test_*` method, prints `TESTS: n passed, m failed, k load errors`, exits 1 on any fail or load error. It also hooks a `Logger`, so a runtime script error inside a test (null call etc.) fails that test instead of passing silently. Test files extend `res://tests/test_case.gd` by path (no `class_name`, so they work before the global class cache exists).
- **`tools/capture.sh <scene> <out-dir> [seconds]`**: windowed run on the GPU; see `src/debug/CONTRACT.md`. Forces a true 1920×1080 framebuffer, vsync off, 2 s warmup, then frame times, PNGs and `frametime.json`. Scenes can offer named "shots" (frozen poses with a close camera); the viewer uses this for the run/roll/walk close-ups, so the poses are deterministic instead of lucky timing. Has a watchdog (seconds + 120 s).
- **Viewer** `scenes/dev/asset_viewer.tscn`: 4×3 floor (two grate tiles), back wall (tall, screen, pipes, light), left wall (vent, tall, low), three tall posts, med bed, two crates, canister. Operator 1 runs `L_Run_F` legs + `U_Aim` upper body (an `AnimationTree` Blend2 filtered to the spine-up bones, the same split as the old `characters.js`), with the flashlight `SpotLight3D` (shadows) on its chest. Operator 2 loops `F_Roll` with a 0.8 s pause. The robot walks `L_Walk_F`. Cool and amber `OmniLight3D` practicals (both shadowed), glow, SSAO, light volumetric fog, AgX tonemap, temporary perspective camera at about 54° down. Every light, camera and environment number is in `data/viewer.json`.

## Import approach (legacy pass-05 → `assets/game/legacy/`)
- **Copies**, not in-place import: the three glbs and 42 textures are copied into `assets/game/legacy/`. Reason: importing in place writes `.import` files into `assets/source/`, which the code lane must not edit and the runner never commits.
- **Textures**: VRAM compressed with mipmaps; `*_normal.jpg` flagged as normal maps (OpenGL convention, Godot's native one, so no Y flip).
- **Materials**: `tools/godot/build_legacy_materials.gd` wrote `assets/game/legacy/materials/*.tres` from the `materials.js` list: 14 `ORMMaterial3D` (albedo + normal + ORM), the glow set (`light_*`, `screen_cyan`), `visor` (clearcoat) and `glass` (alpha 0.55). The glb `.import` files bind them **by slot name** through external-material import settings, so the editor, the viewer and any future scene get the same materials with no runtime code. As in `characters.js`, the character status lights use dimmer copies: operator `light_cyan/amber` → `char_cyan/char_amber` (energy 0.9); robot `light_red` → `robot_eye_red` (5.0).
- **Operator**: imports with one `AnimationPlayer` holding all 13 clips. Clips are also saved to `assets/game/legacy/anim/*.res` by the import settings; `L_*`/`U_*` loop, `F_*` play once.
- **Robot**: `assets/game/legacy/robot.tscn` = `robot.glb` + an `AnimationPlayer` using `anim/legacy_clips.tres` (the operator's clips; same 22 bones, same names, checked by a test).
- **Kit**: **one scene per piece**, `assets/game/legacy/kit/<piece>.tscn` (32 of them), each a `Node3D` + `MeshInstance3D` whose mesh the kit import saves to `kit/meshes/<piece>.res`. Chose scenes over a `MeshLibrary` because pieces will want collision, lights and scripts later, and scenes are what level building in T002 will place by hand.
- To redo after a source change: copy the files again, `godot --headless --path . --import`, then `godot --headless --path . -s tools/godot/build_legacy_scenes.gd` (rebuilds the clip library, kit scenes and robot scene). `build_legacy_materials.gd` only needs re-running to reset the materials.

## Checks run
- **Headless tests:** `godot --headless --path . -s tests/run_tests.gd` → `TESTS: 12 passed, 0 failed, 0 load errors`, exit 0. Covers: data loader (good, missing, bad JSON, missing key, every `data/*.json` parses, autoload present); legacy assets (operator has all 13 clips and loop modes, operator and robot share 22 identically named bones, robot's thigh moves while playing `L_Walk_F`, every mesh surface in operator/robot/kit uses a material from `materials/`, suit has albedo+normal+ORM, kit piece scenes load); viewer builds headless (flashlight shadows and range from data, flashlight points where the operator faces, glow/SSAO/fog on, layered tree active, shots work).
- **Load-error check:** deleted the closing `]` of the `CLIPS` array in `tests/test_legacy_assets.gd` → `LOAD ERROR res://tests/test_legacy_assets.gd`, `TESTS: 6 passed, 0 failed, 1 load errors`, exit 1. Restored → 11/11 at the time (12 after adding the viewer test).
- **Runtime-error check:** a throwaway test calling a method on `null` was reported as `FAIL` with the script error, exit 1. Removed.
- **Imports:** `godot --headless --path . --import` reports no errors or warnings, also on a **fresh clone** of the branch (then 12/12 tests pass there too).
- **Frame time** (`docs/screens/T001/frametime.json`, 30 s, 1920×1080 framebuffer, MSAA 4×, vsync off, Metal, M2 Pro): **7.68 ms avg (130 fps), p95 14.49 ms, p99 20.13 ms, max 98.9 ms**, 3907 frames. The p95 at about 2× the average and the 99 ms spike are probably other work on the Mac (load average 6.6 during the run), not the scene; a quiet-machine run would settle that.

## Screenshots (`docs/screens/T001/`, all 1920×1080)
- `asset_viewer.png`: the viewer; `asset_viewer_overlay.png`: same with the FPS overlay.
- `operator_run_a/b/c.png`: running operator at 0.00 / 0.17 / 0.33 s into the clip (legs at different stride points, upper body aiming).
- `roll_tuck.png`: second operator 0.30 s into `F_Roll`, tucked.
- `robot_walk_a/b.png`: robot at 0.27 / 0.80 s into `L_Walk_F`.
- `frametime.json`.

## What looked wrong or needs a look
- **Nothing broken in materials or normals that I could see**: paints, hazard stripes, floor plates, grates, wall panels and med fabric all read right, emissives glow, no inside-out or black surfaces. I did not do a dedicated normal-map direction check (e.g. a raking light on one wall).
- The robot stands close to the large crate in the viewer (my layout); its gun nearly touches the crate.
- At `robot_walk_b` (0.80 s) the legs are near the passing pose, so the stride shows better in `_a`.
- The fog is deliberately faint (density 0.012); you can just see it in the flashlight cone.
- The scene is dark overall (by design for the flashlight look); the right half of the room sits outside both practicals.
- Asset contract note: the legacy characters do face −Z as `asset-contract.md` says. (I briefly thought otherwise: `.tscn` `Transform3D` values are row-major, which my first scene writer got wrong.)

## Needs a human decision
- **`assets/source/` and Godot.** Godot scans the whole project, so every import also writes `.import` files next to the sources in `assets/source/`. I didn't touch that folder; I gitignored `assets/source/**/*.import` so they never get committed. The clean fix is a one-line empty file `assets/source/.gdignore` (Godot then skips the folder), but that's a file inside the art lane's folder, so it's John's or the lead's call. I added `docs/.gdignore` myself so the reference JPGs in `docs/` aren't imported.
- MSAA 4× vs 2×: kept 4×; see above.

## Parked (one line each, also in STATUS)
- A quiet-machine frame-time baseline for the viewer (no other lanes running).
