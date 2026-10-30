# T001 - Godot skeleton and legacy asset import (code)

**Modules:** new: `src/core/`, `src/debug/`. **Read:** `CLAUDE.md`, `docs/handoffs/asset-contract.md`. **Needs:** nothing.
**Autonomy:** auto-ok (the lead reviews screenshots and numbers; nothing for John to judge yet).

Grave Rats starts here. This sets up the Godot 4.7 project every later task builds on, and proves the old prototype's assets survive the move: the skinned operator with its clips, the robot, and the environment kit with real PBR materials, all rendering on the Mac's GPU at a known frame time.

## Do
1. **Project.** `project.godot` for Godot 4.7, Forward+ renderer, project name "Grave Rats".
   - Window 1920×1080, resizable; MSAA 2× or 4× (record which and why).
   - Folder layout per `CLAUDE.md`.
   - `.gitignore` already ignores `.godot/`.
   - Commit the `.import` files Godot generates; don't commit the `.godot/` cache.
2. **Data loading.** `src/core/data.gd`: a small autoload that loads `data/*.json` by name and fails loudly (a test catches it) on a missing file or bad JSON. Seed `data/debug.json` with the FPS-overlay toggle.
3. **Headless test runner.** `tests/run_tests.gd`:
   - Discovers `tests/test_*.gd`.
   - Counts passes and fails.
   - Exits non-zero on any fail **or on any test file that fails to load or parse**.
   - Prints a final `TESTS: <n> passed, <m> failed, <k> load errors` line.
   - Add tests for the data loader (good file, missing file, bad JSON) and a test that the legacy glTFs load and expose the expected clip names.
4. **Legacy asset import.** Import from `assets/source/legacy-pass05/` into `assets/game/legacy/`, as copies or via import settings (your call; record it in the handoff):
   - **Materials.** Build Godot materials from the texture sets in `tex/`: albedo, normal, and ORM (Godot's `ORMMaterial3D` takes AO/roughness/metalness packed like ours). Bind them to the glTF material slots by name (`suit_fabric`, `paint_orange`, `wall_panel`…), the way the old `materials.js` did (see `docs/reference/dead-circuit-web/src/materials.js` for the name list and the emissive and visor settings).
   - **Operator.** One `AnimationPlayer` (or `AnimationTree` placeholder) that can play every clip.
   - **Robot.** Plays the operator's clips (same skeleton and bone names).
   - **Kit.** Each kit piece usable as its own scene, or as a `MeshLibrary` (your call; say which).
5. **Viewer scene** `scenes/dev/asset_viewer.tscn`:
   - A lit room built from a few kit pieces (wall_tall, post_tall, floor tiles, a crate, a med bed).
   - The operator looping `L_Run_F` + `U_Aim`, a second operator on `F_Roll`, the robot on `L_Walk_F`.
   - A flashlight `SpotLight3D` with shadows, two `OmniLight3D` practicals (one cool, one amber), glow on, SSAO on, volumetric fog on (light, just to see it).
   - A temporary perspective camera at a steep angle.
   - **FPS and frame-time overlay** (`src/debug/`), toggled by F3 and on by default in dev.
6. **Capture tool.** `tools/capture.sh <scene> <out-dir> [seconds]` runs the scene windowed on the GPU, waits, saves PNGs of the viewport, and writes `frametime.json`: average and 95th-percentile frame time over the run, resolution and renderer. Later packets reuse it.

## Acceptance
- **Headless:** `godot --headless --path . -s tests/run_tests.gd` passes with the counts printed. Delete one test file's closing bracket locally and confirm the runner reports a load error and fails; then restore it.
- **Imports:** `godot --headless --path . --import` reports no import errors.
- **Windowed:** captures in `docs/screens/T001/`:
  - the viewer at 1920×1080;
  - the operator mid-run (legs visibly animating);
  - the roll mid-tuck;
  - the robot walking.
  Include `frametime.json` for a 30-second run of the viewer.
- **Handoff:** `docs/handoffs/auto-T001.md` with test counts, frame times, the import approach, anything that looked wrong (materials, normals, animation glitches), and screenshots listed.

Out of scope: gameplay, input, the real camera (T002), new art.
