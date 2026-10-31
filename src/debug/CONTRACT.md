# debug

## Owns
- `fps_overlay.gd`: FPS / frame-time overlay. Autoload `DebugOverlay` (CanvasLayer 100). F3 toggles. Hidden in headless runs.
- `capture.gd`: windowed capture driver. Autoload `Capture`, idle unless the command line has `--capture-out=` (started by `tools/capture.sh`).
- Main scene: `scenes/pirates/pirate_deck.tscn` (in `project.godot`), so F5 runs the latest build.
- `tuning_panel.gd`: F1 tuning panel (dev only; the scene that wants it adds it). Sliders from `data/debug.json` "tuning" write into the loaded data live; Save writes changed files back to `data/`.
- `asset_viewer.gd`: script of `scenes/dev/asset_viewer.tscn`, the legacy asset viewer (dev only).

## Does not own
- Gameplay, input mapping, the real camera (T002).
- The legacy assets themselves (`assets/game/legacy/`, see `docs/handoffs/auto-T001.md`).

## Public API
- `tools/capture.sh <scene> <out-dir> [seconds]` (env `CAPTURE_SIZE=WxH`, `GODOT=`, `CAPTURE_ONLY=name,name` or `none` to pick shots): sizes the framebuffer to 1920×1080 pixels (HiDPI aware), vsync off, 2 s warmup, measures `seconds` (default 10), saves `<scene>.png` and `<scene>_overlay.png`, then one PNG per shot if the scene offers them, writes `frametime.json` (frame_ms avg/p95/p99/max, fps, frames, resolution, renderer, driver, adapter, MSAA, Godot version) and quits. Godot args: `--capture-out= --capture-seconds= --capture-warmup= --capture-size=`.
- Scene capture hooks (optional, duck-typed on the current scene's root): `capture_shots() -> Array[Dictionary]` (each has `name`), `apply_shot(shot)` (may be a coroutine; it is awaited), `release_shot()`.
- `TuningPanel`: `toggle()`, `set_value(file, path, value)`, `save() -> PackedStringArray` (files written), static `resolve(file, dotted_path)`, `sliders`, `dirty`, `save_dir`. Save writes `JSON.stringify` output, so an untouched `data/camera.json` gains one cosmetic change the first time (`default_preset` 0 to 0.0).
- Frame time is wall-clock per frame with vsync off. The Metal driver returns 0 for viewport GPU timers, so there is no separate GPU number.

## Signals
None.

## Data keys
- `data/debug.json`: `fps_overlay` (bool, overlay on at start), `fps_overlay_refresh_s` (float), `tuning` [{`section`} or {`label`, `file`, `path` (dotted), `min`, `max`, `step`}].
- `data/viewer.json` (asset viewer only): `camera` {fov, position, target, near, far}; `flashlight` {local_position, pitch_deg, color, energy, range, angle_deg, attenuation, angle_attenuation, shadows}; `practical_cool` / `practical_amber` {position, color, energy, range, attenuation, shadows}; `environment` {background_color, ambient_color, ambient_energy, tonemap ("agx"|"filmic"), exposure, glow_*, ssao_*, fog_*}; `roll_pause_s`; `shots` [{name, focus (node name), offset, fov, time (s into every clip)}].
