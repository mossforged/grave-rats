# player

The weighty operator (T003). The rule: the intent responds the same step, the completion takes time (`docs/studies/2026-10-29-weight-without-lag.md`).

## Owns
- `operator_model.gd`: scene-free weight. Velocity and speed with ramps, capped turning, torso/hips split, crouch, leg blend and clip rate. Numbers from `data/player.json`.
- `operator.gd`: CharacterBody3D. Reads intent, steps the model, fires, moves, drives animation and floor drawings. Speed and direction are fixed **before** `move_and_slide` (the prototype measured after, so its walk never animated).
- `operator_anim.gd`, `spine_twist.gd`: AnimationTree over the legacy clips, and the torso lead as a spine twist (a SkeletonModifier3D, which also records the gun's pose for the muzzle).
- `operator_body.gd`: which body an operator wears, by data, and builds it: "Model" and "Anim" with the same face either way. `forced` overrides the data for tools and tests.
- `hauler_anim.gd`: the same face as `operator_anim.gd` over John's hauler: legs by direction, sprint, turn in place, crouch; upper body aim, low or reload; roll, hit and death over everything.
- `hauler_clips.gd`: builds one shared AnimationLibrary, one clip per state, from `data/hauler_anim.json`. `hauler_retarget.gd`: scene-free retarget, hip strip, forward kinematics, foot measures.
- `aim_visuals.gd`: floor cone, turn arc, ring under the aim point.
- `weight_deck.gd`: root of `scenes/player/weight_deck.tscn`: deck, targets, camera, the suit OS and noise ring (`src/hud`), panel, camera kick, capture shots. `_noise_senses()` says whose ears the ring shows. H toggles the key help.

## Does not own
- The gun's rules, FX, targets (`src/weapons`); camera behaviour (`src/camera`); deck (`src/study`); the panel (`src/debug`).

## Public API
- `OperatorModel.new(cfg)`: `step(delta, wish, to_yaw, wants_crouch, wants_sprint)`, `note_shot()`, `face_now(yaw)`, `reset_motion()`, `aim_yaw_for(from, point)`, `aim_error()`, `noise_kind()`, `torso_lead()`, `leg_blend()` (x right, y forward, relative to the torso), `leg_time_scale()`, `crouch_time_scale()`, `current_turn_rate_deg()`, `top_speed()`, `moving()`, `firing()`; fields `velocity`, `speed`, `torso_yaw`, `hips_yaw`, `aim_yaw`, `crouch_amount`, `sprinting`, `turned_deg`. Statics `wish_from_keys`, `yaw_to`, `yaw_dir`. Yaw 0 faces -Z.
- `operator.gd`: `aim_point`, `move_yaw_deg`, `input_enabled`, `scripted` {`keys`, `crouch`, `sprint`, `fire`} (used when input is off), `anim_speed`, `crouch_shown` (share of the crouch the body shows; a braced shot rises out of it), `model`, `rifle`, `anim`; `simulate(delta)`, `hold_control(seconds)` / `release_control()` / `control_held()` (no moving, turning or firing: a stagger, tipping a bed, death), `request_reload()`, `face_now(point)`, `gun_yaw()`, `aim_dir()`, `muzzle_position()`, `shot_reach(yaw)`, `set_character_scale(s)`, `body_radius()`.
- `anim`, either body: `update(...)`, `set_motion(sprinting, speed, hip_turn_deg_s)`, `set_recoil(share)`, `play_state(state, seconds := -1) -> bool` ("roll", "hit", "death"; the legacy body returns false), `clear_states()`, `over_state()`, `cycle_length()`, `foot_bones()`, `clip_length(name)`; fields `tree`, `skeleton`, `twist`. Operator: `play_hit(seconds)`; `hold_control(INF)` plays the death, `release_control()` gets up.
- `OperatorBody`: `kind(wanted)`, `weight_for(wanted, weight)`, `build(owner, wanted, anim_cfg, muzzle_bone) -> {visual, anim}`, `fit_scale`, `weapon_offset`, static `forced`.
- `HaulerClips`: `library(cfg, player, rest)`, `sources()` (state to source), `lifts()`, `forget()`. `HaulerRetarget`: `rest_of`, `retarget`, `strip_hip_travel`, `strip_hip_yaw`, `hip_travel`, `lift_hips`, `fk`, `fk_poses`, `lowest`, `foot_speed`.
- `OperatorModel` also: `firing_share()`, field `hip_turn_deg_s`.
- Scene keys: WASD, Shift sprint, C/Ctrl crouch, mouse aim, LMB fire, R reload, 1-5 camera, V cut-away, Backspace respawn and refill, F1 tuning, F3 frame time.
- Scene capture hooks: `capture_shots()`, `apply_shot(shot)` (a coroutine: runs real frames, then freezes `Engine.time_scale`), `release_shot()`.

## Behaviour worth knowing
- Turn rate: standing to crouched by crouch amount, and the slower of that and firing while a shot is recent.
- Hips stay planted until the torso runs out of lead, then get dragged; while moving they also catch up at `hip_settle_deg_s`.
- Sprinting needs Shift, a move held, no crouch key and fully upright, so crouch beats sprint.
- `L_Idle` and `L_Crouch_Idle` hold each thigh half a turn about its length from the walk clips and the rest pose, which made the blend into a crouch swing the feet around the body. `operator_anim.gd` rewrites those keys at load, same pose, the short way. It edits the shared clip resources once.
- The legacy `L_Strafe_L/R` clips are named backwards (planted feet sweep the wrong way); the blend tree swaps them. `tests/test_player.gd` guards it.

- **Hauler clips:** a state's source is a clip in the hauler's file, a file in `assets/game/hauler/`, or `legacy:<clip>`. New file: copy `hauler-<state>.fbx` or `.glb` into `assets/game/hauler/` (`crouch_walk` is `hauler-crouch-walk.fbx`), re-import, and it takes over the state with no data edit. Set a matching clip speed in data if it's a moving clip.
- **Retarget:** world-space rotation changes onto a rest straightened to match the source's, so rest poses and bone axes may differ. Retargeted clips are stood on the floor automatically: lowest ankle goes to the rest ankle. Meshy clips aren't; `hip_y_offset_m` on a state adjusts any clip.
- **Root motion:** hips x and z are pinned to the first key in every clip. `strip_yaw` also takes the turn out of turn clips, because the code turns the body.
- **Gun:** the legacy rifle's mesh sits on the right hand bone, with `rifle` in data. `SpineTwist.aim_lock` takes up the yaw and pitch the mixed clips leave in the barrel, so it aims with the torso on any clip mix. Reload, low and over-states release it.
- **Facing:** the hauler's file faces +Z, so the scene inside "Model" is turned 180 degrees and scaled to `height_m`. The character scale stays on "Model".

## Signals
None. (The rifle has its own.)

## Data keys (`data/player.json`)
`radius_m`, `height_m`, `aim_height_m`; `move` {`walk_speed_m_s`, `crouch_speed_m_s`, `sprint_speed_m_s`, `accel_s`, `decel_s`, `moving_threshold_m_s`}; `turn` {`standing_deg_s`, `firing_deg_s`, `crouched_deg_s`, `firing_hold_s`, `torso_lead_deg`, `hip_settle_deg_s`, `aim_deadzone_m`}; `crouch` {`down_s`, `stand_up_s`}; `anim` {`clip_speed_forward_m_s`, `clip_speed_back_m_s`, `clip_speed_strafe_m_s`, `clip_speed_crouch_m_s`, `max_time_scale`, `upper_xfade_s`, `reload_clip_s`, `spine1_twist_share`}; `aim_visuals` {`floor_y_m`, `cone_length_m`, `cone_segments`, `cone_edge_width_m`, `cone_fill_color`, `cone_edge_color`, `arc_radius_m`, `arc_width_m`, `arc_min_deg`, `arc_step_deg`, `arc_color`, `marker_radius_m`, `marker_width_m`, `marker_segments`, `marker_color`}.

`data/player.json` also has `body` ("hauler" or "legacy").

## Data keys (`data/hauler_anim.json`)
`file`, `clip_dir`, `height_m`, `skeleton_path`, `retarget_fps`; `bones` {`hips`, `spine_lower`, `spine_upper`, `hand_right`, `hand_left`, `feet`, `toes`}; `states` {state: {`source`, `loop`, optional `strip_yaw`, `hip_y_offset_m`, `stand_in`}}; `anim` (merged over the body's "anim": `clip_speed_forward_m_s`, `clip_speed_back_m_s`, `clip_speed_strafe_m_s`, `clip_speed_crouch_m_s`, `clip_speed_sprint_m_s`, `max_time_scale`, `reload_clip_s`); `aim` {`walk_blend_at`, `sprint_blend_s`, `turn_blend_s`, `lock_blend_s`, `recoil_kick_deg`, `turn_start_deg_s`, `turn_max_speed_m_s`, `turn_left_clip_deg_s`, `turn_right_clip_deg_s`, `hit_fade_in_s`, `hit_fade_out_s`, `roll_fade_in_s`, `roll_fade_out_s`}; `rifle` {`hand_offset_m`, `hand_euler_deg`, `scale`}; `upper_bones`; `legacy_map`.

Tests: `tests/test_player.gd`, `tests/test_hauler.gd`. Foot slide: `tools/t003_footslide.gd [-- --body=legacy]`. Rifle fit: `tools/t009_rifle_fit.gd`. What a clip file holds: `tools/t009_inspect.gd`. State sheet: `scenes/dev/t009_sheet.tscn`.
