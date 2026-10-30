# player

The weighty operator (T003). The rule: the intent responds the same step, the completion takes time (`docs/studies/2026-10-29-weight-without-lag.md`).

## Owns
- `operator_model.gd`: scene-free weight. Velocity and speed with ramps, capped turning, torso/hips split, crouch, leg blend and clip rate. Numbers from `data/player.json`.
- `operator.gd`: CharacterBody3D. Reads intent, steps the model, fires, moves, drives animation and floor drawings. Speed and direction are fixed **before** `move_and_slide` (the prototype measured after, so its walk never animated).
- `operator_anim.gd`, `spine_twist.gd`: AnimationTree over the legacy clips, and the torso lead as a spine twist (a SkeletonModifier3D, which also records the gun's pose for the muzzle).
- `aim_visuals.gd`: floor cone, turn arc, ring under the aim point.
- `player_hud.gd`: magazine / reserve, reload bar, stance word, key help.
- `weight_deck.gd`: root of `scenes/player/weight_deck.tscn`: deck, targets, camera, HUD, panel, camera kick, capture shots.

## Does not own
- The gun's rules, FX, targets (`src/weapons`); camera behaviour (`src/camera`); deck (`src/study`); the panel (`src/debug`).

## Public API
- `OperatorModel.new(cfg)`: `step(delta, wish, to_yaw, wants_crouch, wants_sprint)`, `note_shot()`, `face_now(yaw)`, `reset_motion()`, `aim_yaw_for(from, point)`, `aim_error()`, `torso_lead()`, `leg_blend()` (x right, y forward, relative to the torso), `leg_time_scale()`, `crouch_time_scale()`, `current_turn_rate_deg()`, `top_speed()`, `moving()`, `firing()`; fields `velocity`, `speed`, `torso_yaw`, `hips_yaw`, `aim_yaw`, `crouch_amount`, `sprinting`, `turned_deg`. Statics `wish_from_keys`, `yaw_to`, `yaw_dir`. Yaw 0 faces -Z.
- `operator.gd`: `aim_point`, `move_yaw_deg`, `input_enabled`, `scripted` {`keys`, `crouch`, `sprint`, `fire`} (used when input is off), `anim_speed`, `crouch_shown` (share of the crouch the body shows; a braced shot rises out of it), `model`, `rifle`, `anim`; `simulate(delta)`, `hold_control(seconds)` / `release_control()` / `control_held()` (no moving, turning or firing: a stagger, tipping a bed, death), `request_reload()`, `face_now(point)`, `gun_yaw()`, `aim_dir()`, `muzzle_position()`, `shot_reach(yaw)`, `set_character_scale(s)`.
- Scene keys: WASD, Shift sprint, C/Ctrl crouch, mouse aim, LMB fire, R reload, 1-5 camera, V cut-away, Backspace respawn and refill, F1 tuning, F3 frame time.
- Scene capture hooks: `capture_shots()`, `apply_shot(shot)` (a coroutine: runs real frames, then freezes `Engine.time_scale`), `release_shot()`.

## Behaviour worth knowing
- Turn rate: standing to crouched by crouch amount, and the slower of that and firing while a shot is recent.
- Hips stay planted until the torso runs out of lead, then get dragged; while moving they also catch up at `hip_settle_deg_s`.
- Sprinting needs Shift, a move held, no crouch key and fully upright, so crouch beats sprint.
- `L_Idle` and `L_Crouch_Idle` hold each thigh half a turn about its length from the walk clips and the rest pose, which made the blend into a crouch swing the feet around the body. `operator_anim.gd` rewrites those keys at load, same pose, the short way. It edits the shared clip resources once.
- The legacy `L_Strafe_L/R` clips are named backwards (planted feet sweep the wrong way); the blend tree swaps them. `tests/test_player.gd` guards it.

## Signals
None. (The rifle has its own.)

## Data keys (`data/player.json`)
`radius_m`, `height_m`, `aim_height_m`; `move` {`walk_speed_m_s`, `crouch_speed_m_s`, `sprint_speed_m_s`, `accel_s`, `decel_s`, `moving_threshold_m_s`}; `turn` {`standing_deg_s`, `firing_deg_s`, `crouched_deg_s`, `firing_hold_s`, `torso_lead_deg`, `hip_settle_deg_s`, `aim_deadzone_m`}; `crouch` {`down_s`, `stand_up_s`}; `anim` {`clip_speed_forward_m_s`, `clip_speed_back_m_s`, `clip_speed_strafe_m_s`, `clip_speed_crouch_m_s`, `max_time_scale`, `upper_xfade_s`, `reload_clip_s`, `spine1_twist_share`}; `aim_visuals` {`floor_y_m`, `cone_length_m`, `cone_segments`, `cone_edge_width_m`, `cone_fill_color`, `cone_edge_color`, `arc_radius_m`, `arc_width_m`, `arc_min_deg`, `arc_step_deg`, `arc_color`, `marker_radius_m`, `marker_width_m`, `marker_segments`, `marker_color`}.

Tests: `tests/test_player.gd`. Foot slide: `tools/t003_footslide.gd`.
