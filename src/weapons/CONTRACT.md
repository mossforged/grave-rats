# weapons

The rifle and the things it shoots (T003).

## Owns
- `aim_cone.gd`: scene-free aim-settle cone. `spread_deg` is the full angle.
- `rifle_state.gd`: scene-free magazine, reserve, fire interval, recoil, camera kick, reload commitment.
- `rifle.gd`: Node3D; hitscan inside the cone, signals, holds the two above.
- `rifle_fx.gd`: muzzle flash from the sheet (a side cone and a front star, random frame, roll and size, on screen `flash_frames` frames), muzzle light, tracer. All unshaded additive, so nothing can draw a black box.
- `shot_timeline.gd`: one gun's shot apart from the rules (T020): the layers of sound, smoke, haze, casing, wisps after a long burst, the magazine, the round landing. Calls `src/audio` and `src/vfx`. The pirates hold one too.
- `target_dummy.gd`: grey-box target. Takes hits, flinches, falls, resets.

## Sounds (T017)
The layers in `ShotTimeline` (`gun` in `data/audio.json`), dry fire and its tail on an empty magazine, mag out, then `reload_stages`, through `src/audio`. The charging handle (`only_empty`) only plays when the magazine ran dry. A cancelled reload stops there.

## Does not own
- Input, facing, where the gun points (the owner passes those in; see `src/player`). Camera movement: the owner reads `camera_kick_m`.

## Public API
- `AimCone.new(cfg)`: `step(delta, speed_fraction, moving, sprinting, turned_deg)`, `target_deg(...)`, `spread_deg`.
- `RifleState.new(cfg)`: `step(delta, sprinting) -> "finished"|"cancelled"|""`, `try_fire(sprinting) -> FIRED|BLOCKED_*`, `start_reload(sprinting) -> bool`, `cancel_reload()`, `refill()`, `reloading()`, `reload_progress()`, `shot_yaw(center, spread_deg)`; fields `mag`, `reserve`, `reload_left`, `reload_total`, `recoil_deg`, `camera_kick_m`, `arm_kick` (1 as a round goes off, falling to 0), `rng`.
- `rifle.gd`: `state`, `cone`, `fx`, `trigger_held`, `exclude`, `shot_tracer` (optional Callable `(origin, dir, length) -> {} or {position, collider}` replacing the flat physics ray; `src/cover/shot_tracer.gd` is the 3D one, and scenes without it are unchanged); `tick(delta, sprinting, origin, center_yaw, muzzle) -> bool` (once per physics step), `request_reload(sprinting) -> bool`, `play_round(origin, yaw, muzzle)` (the gallery: no trigger, no rules), `timeline`.
- `ShotTimeline.new()`: `shot(muzzle, dir, rounds_left, space, local)`, `land(target, point, normal, dir, damage)`, `dry(at)`, `drop_magazine(muzzle, dir)`, `step(delta, muzzle, dir)`; fields `gun_id`, `burst`.
- Anything a shot hits may have `take_hit({point, direction, damage, origin})`, `hit_surface() -> String` and `plays_own_hit()` (`src/vfx`).

## Reload rules
Starting drops the magazine: its rounds go back to the reserve and the new magazine leaves the reserve, so the gun holds 0. It takes the full `reload_s`. Fire is refused and changes nothing. Sprinting cancels and the new magazine is lost. It can't start while sprinting, on a full magazine or with nothing left.

## Signals (`rifle.gd`)
`fired(from, to, direction, hit)`, `blocked(reason)`, `reload_started`, `reload_finished`, `reload_cancelled`. Target: `hit_taken(damage)`, `went_down`, `was_reset`.

## Data keys (`data/weapons.json`)
- `rifle` {`damage`, `magazine`, `reserve`, `fire_interval_s`, `range_m`, `reload_s`, `muzzle_bone`, `muzzle_bone_offset`; `cone` {`wide_deg`, `tight_deg`, `settle_s`, `moving_min_deg`, `sprint_deg`, `open_deg_s`, `turn_open_per_deg`}; `recoil` {`kick_deg`, `recover_deg_s`, `recover_delay_s`, `max_deg`, `same_side_chance`}; `camera_kick` {`kick_m`, `recover_s`}; `arm_kick` {`recover_s`}}.
- `fx` {`flash_life_s` (the light), `flash_sheet`, `flash_cols`, `flash_rows`, `flash_star_frames`, `flash_cone_frames`, `flash_cone_length_m`, `flash_cone_width_m`, `flash_star_size_m`, `flash_scale_jitter`, `flash_frames`, `flash_warm_depth_m`, `flash_color`, `flash_energy`, `flash_light_energy`, `flash_light_range_m`, `tracer_life_s`, `tracer_width_m`, `tracer_color`, `tracer_energy`, `pool_size`}.
- `targets` {`health`, `flinch_deg`, `flinch_s`, `down_deg`, `down_s`, `reset_s`, `hit_flash_s`, `radius_m`, `height_m`, `head_radius_m`, `color`, `hit_color`, `down_color`, `placements` [{`space`, `at`}]}.

Tests: `tests/test_weapons.gd`. Black-box check on captures: `tools/t003_blackbox.py`.
