# weapons

The rifle and the things it shoots (T003).

## Owns
- `aim_cone.gd`: scene-free aim-settle cone. `spread_deg` is the full angle.
- `rifle_state.gd`: scene-free magazine, reserve, fire interval, recoil, camera kick, reload commitment.
- `rifle.gd`: Node3D; hitscan inside the cone, signals, holds the two above.
- `rifle_fx.gd`: muzzle flash, tracer, impact. All unshaded additive, so nothing can draw a black box.
- `target_dummy.gd`: grey-box target. Takes hits, flinches, falls, resets.

## Does not own
- Input, facing, where the gun points (the owner passes those in; see `src/player`). Camera movement: the owner reads `camera_kick_m`.

## Public API
- `AimCone.new(cfg)`: `step(delta, speed_fraction, moving, sprinting, turned_deg)`, `target_deg(...)`, `spread_deg`.
- `RifleState.new(cfg)`: `step(delta, sprinting) -> "finished"|"cancelled"|""`, `try_fire(sprinting) -> FIRED|BLOCKED_*`, `start_reload(sprinting) -> bool`, `cancel_reload()`, `refill()`, `reloading()`, `reload_progress()`, `shot_yaw(center, spread_deg)`; fields `mag`, `reserve`, `reload_left`, `reload_total`, `recoil_deg`, `camera_kick_m`, `rng`.
- `rifle.gd`: `state`, `cone`, `fx`, `trigger_held`, `exclude`, `shot_tracer` (optional Callable `(origin, dir, length) -> {} or {position, collider}` replacing the flat physics ray; `src/cover/shot_tracer.gd` is the 3D one, and scenes without it are unchanged); `tick(delta, sprinting, origin, center_yaw, muzzle) -> bool` (once per physics step), `request_reload(sprinting) -> bool`.
- Anything a shot hits may have `take_hit({point, direction, damage, origin})`.

## Reload rules
Starting drops the magazine: its rounds go back to the reserve and the new magazine leaves the reserve, so the gun holds 0. It takes the full `reload_s`. Fire is refused and changes nothing. Sprinting cancels and the new magazine is lost. It can't start while sprinting, on a full magazine or with nothing left.

## Signals (`rifle.gd`)
`fired(from, to, direction, hit)`, `blocked(reason)`, `reload_started`, `reload_finished`, `reload_cancelled`. Target: `hit_taken(damage)`, `went_down`, `was_reset`.

## Data keys (`data/weapons.json`)
- `rifle` {`damage`, `magazine`, `reserve`, `fire_interval_s`, `range_m`, `reload_s`, `muzzle_bone`, `muzzle_bone_offset`; `cone` {`wide_deg`, `tight_deg`, `settle_s`, `moving_min_deg`, `sprint_deg`, `open_deg_s`, `turn_open_per_deg`}; `recoil` {`kick_deg`, `recover_deg_s`, `recover_delay_s`, `max_deg`, `same_side_chance`}; `camera_kick` {`kick_m`, `recover_s`}}.
- `fx` {`flash_life_s`, `flash_size_m`, `flash_color`, `flash_energy`, `flash_light_energy`, `flash_light_range_m`, `tracer_life_s`, `tracer_width_m`, `tracer_color`, `tracer_energy`, `impact_life_s`, `impact_size_m`, `impact_color`, `impact_energy`, `pool_size`}.
- `targets` {`health`, `flinch_deg`, `flinch_s`, `down_deg`, `down_s`, `reset_s`, `hit_flash_s`, `radius_m`, `height_m`, `head_radius_m`, `color`, `hit_color`, `down_color`, `placements` [{`space`, `at`}]}.

Tests: `tests/test_weapons.gd`. Black-box check on captures: `tools/t003_blackbox.py`.
