# camera

## Owns
- `camera_rig.gd`: follow camera (Node3D holding a `Camera3D`). Perspective or orthographic presets, exponential follow with look-ahead toward the aim, wall cut-away.
- `camera_math.gd`: scene-free math (preset → transform, projection to NDC, operator screen-height fraction, follow step, cut-away zone test). Static, preloaded by path.

## Does not own
- What it follows or how the target aims (the owner sets `target` and `aim_dir`).
- The walls themselves; it only scales / fades nodes that join its group.
- Input mapping: the owner calls `set_preset` / `cycle_cutaway_mode` (the study binds keys 1–5 and C).

## Public API (`camera_rig.gd`)
- `target: Node3D`, `aim_dir: Vector3` (horizontal; zero = no look-ahead), `camera: Camera3D`, `presets: Array`, `preset_index`, `cutaway: Dictionary`, `cutaway_mode: String`.
- `set_preset(i)`, `preset() -> Dictionary`, `set_cutaway_mode(mode)`, `cycle_cutaway_mode()`, `desired_focus() -> Vector3`, `snap()` (jump to the framing and settle the cut-away now).
- Yaw 0 = camera south of the target looking north (screen-up = world −Z). Godot keeps the vertical FOV / ortho size fixed (KEEP_HEIGHT), so wider windows see more to the sides.

### Cut-away contract
Any `Node3D` in group `camera_cutaway` with its origin on the floor, meta `cutaway_rect` (Rect2, world XZ footprint) and `cutaway_height` (m). Each frame the rig tests the footprint against a zone running `depth_m` from `behind_m` behind the target toward the camera, `half_width_m` each side. **drop** scales the node in Y down to `low_height_m`; **fade** (default since T007, John's pick) sets `transparency` on its `GeometryInstance3D` children; **off**. Collision is untouched (keep it outside the pivot).

## Signals
- `preset_changed(index: int, preset: Dictionary)`
- `cutaway_mode_changed(mode: String)`

## Data keys (`data/camera.json`)
- `default_preset` (index; 5, John's pick between old presets 1 and 2, in every deck. The first five presets stay on keys 1-5; only `stalker_deck` has a key for the sixth, 6), `near_m`, `far_m`.
- `follow` {`smoothing_hz` (exponential rate; 0 = locked), `look_ahead_m`, `focus_height_m`}.
- `presets` [{`name`, `projection` ("perspective"|"orthographic"), `pitch_deg` (below horizontal), `yaw_deg`, `fov_deg` (vertical), `distance_m`, `ortho_size_m` (vertical extent)}].
- `cutaway` {`mode`, `modes`, `low_height_m`, `fade_transparency`, `half_width_m`, `depth_m`, `behind_m`, `speed_per_s`}.

Tests: `tests/test_camera.gd` (target in view at every preset with look-ahead and running lag, cross-check against Godot's `Camera3D` frustum, concept-preset operator size, follow is frame-rate independent, cut-away zone).
