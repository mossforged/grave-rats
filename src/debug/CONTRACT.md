# debug

## Owns
- `fps_overlay.gd`: FPS / frame-time overlay. Autoload `DebugOverlay` (CanvasLayer 100). F3 toggles. Hidden in headless runs.
- `capture.gd`: windowed capture driver. Autoload `Capture`, idle unless the command line has `--capture-out=` (started by `tools/capture.sh`).
- Main scene: `scenes/pirates/pirate_deck.tscn` (in `project.godot`), so F5 runs the latest build.
- `tuning_panel.gd`: F1 tuning panel (dev only; the scene that wants it adds it). Sliders from `data/debug.json` "tuning" write into the loaded data live; Save writes changed files back to `data/`. Its Display section switches anti-aliasing live, saves the pick to `data/display.json` at once, and shows live frame time. A deck with `pick_ship` gets a ship picker (F1 > Shift). Save refuses on any ship but the first: the loaded data then holds that ship's overrides. Its Effects section is `src/vfx/vfx_gallery.gd`: pick a recipe, P spawns it at the cursor, O stands a wall of each surface and fires on them. Vsync is off while the panel is open, so that number is the cost and not the display's refresh.
- `display_aa.gd`: the anti-aliasing modes in `data/display.json` (T016). `DebugOverlay` applies the saved one at start; env `DISPLAY_AA=<id>` overrides that for a run without saving. Godot 4.7 offers FXAA and SMAA as screen-space passes; MSAA and those are set on the root viewport.
- `t023_stand.gd`: script of `scenes/dev/t023_stand.tscn` (dev only): T023's stands on the survey; env `T023_SHIP`, `T023_AT` for frame times. `tools/t023_sheet.py`, `tools/t023_bench.py`. **If CoreAudio hangs Godot at start, captures need `GODOT=` a wrapper that adds `--audio-driver Dummy`** (2026-10-31).
- `t021_stand.gd`: script of `scenes/dev/t021_stand.tscn` (dev only): the overturned bed with and without its stripe, and the wall-top repeat on one seed with the camera held still. `tools/t021_sheet.py` makes the sheet and `wall_repeat.json`.
- `t019_stand.gd`: script of `scenes/dev/t019_stand.tscn` (dev only): T019's stands from the game camera; run with `KIT_CORRIDORS=off` for the "before". `tools/t019_bench.py` prices the dressing, `tools/t019_sheet.py` makes the sheet.
- `t016_stand.gd`: script of `scenes/dev/t016_stand.tscn` (dev only): T016's capture stands on the real shift deck. `tools/t016_aa_bench.py` prices the modes, `tools/t016_sheet.py` makes the sheets.
- `asset_viewer.gd`: script of `scenes/dev/asset_viewer.tscn`, the legacy asset viewer (dev only).

## Does not own
- Gameplay, input mapping, the real camera (T002).
- The legacy assets themselves (`assets/game/legacy/`, see `docs/handoffs/auto-T001.md`).

## Public API
- `tools/capture.sh <scene> <out-dir> [seconds]` (env `CAPTURE_SIZE=WxH`, `GODOT=`, `CAPTURE_ONLY=name,name` or `none` to pick shots): sizes the framebuffer to 1920×1080 pixels (HiDPI aware), vsync off, 2 s warmup, measures `seconds` (default 10), saves `<scene>.png` and `<scene>_overlay.png`, then one PNG per shot if the scene offers them, writes `frametime.json` (frame_ms avg/p95/p99/max, fps, frames, resolution, renderer, driver, adapter, MSAA, screen-space AA, Godot version) and quits. Godot args: `--capture-out= --capture-seconds= --capture-warmup= --capture-size=`.
- Scene capture hooks (optional, duck-typed on the current scene's root): `capture_shots() -> Array[Dictionary]` (each has `name`), `apply_shot(shot)` (may be a coroutine; it is awaited), `release_shot()`.
- `DisplayAA` (static): `modes()`, `starting_mode()`, `apply(viewport, id) -> bool`, `mode_of(viewport)`.
- `TuningPanel`: `gallery`, `toggle()`, `set_value(file, path, value)`, `pick_aa(id) -> bool`, `show_frame_time(avg_ms, worst_ms)`, `save() -> PackedStringArray` (files written), static `resolve(file, dotted_path)`, `sliders`, `dirty`, `save_dir`, `aa_picker`, `frame_label`. Save writes `JSON.stringify` output, so an untouched `data/camera.json` gains one cosmetic change the first time (`default_preset` 0 to 0.0).
- Frame time is wall-clock per frame with vsync off. The Metal driver returns 0 for viewport GPU timers, so there is no separate GPU number.

## Signals
None.

## Data keys
- `data/debug.json`: `fps_overlay` (bool, overlay on at start), `fps_overlay_refresh_s` (float), `tuning` [{`section`} or {`label`, `file`, `path` (dotted), `min`, `max`, `step`}].
- `data/display.json`: `aa_mode` (the saved pick), `aa_modes` [{`id`, `label`, `msaa` 2x|4x, `screen_space` off|smaa|fxaa}], `section`, `readout`, `readout_s`.
- `data/viewer.json` (asset viewer only): `camera` {fov, position, target, near, far}; `flashlight` {local_position, pitch_deg, color, energy, range, angle_deg, attenuation, angle_attenuation, shadows}; `practical_cool` / `practical_amber` {position, color, energy, range, attenuation, shadows}; `environment` {background_color, ambient_color, ambient_energy, tonemap ("agx"|"filmic"), exposure, glow_*, ssao_*, fog_*}; `roll_pause_s`; `shots` [{name, focus (node name), offset, fov, time (s into every clip)}].
