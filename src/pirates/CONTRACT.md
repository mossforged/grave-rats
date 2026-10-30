# pirates

The rival crew (T007): an enemy that shoots back, by your rules, in a squad of 3. "Better funded, worse people."

## Owns
- `pirate_brain.gd`: scene-free states. Only ever asks `OperatorModel` to move and turn, and `RifleState` and `AimCone` to fire.
- `squad_tactics.gd`: scene-free roles: one suppresses, one flanks, the rest support.
- `cover_spots.gd`: scene-free slots around cover, the best one against a threat, flank spots, fire spots.
- `hit_tally.gd`: scene-free: rounds landing close together add up to a big hit.
- `player_target.gd`: the player as a `ShotTracer` body.
- `pirate.gd`, `pirate_recolour.gd`, `pirate_light.gd`: one pirate in the world: the legacy operator with its materials swapped by name, its rifle FX, its flashlight (the player's beam: `src/sight/beam_fan.gd`, `beam.gdshader`).
- `pirate_squad.gd`: what the squad shares: where it thinks you are, roles and spots, senses, the shot trace, doors, barks.
- `pirate_deck.gd`: root of `scenes/pirates/pirate_deck.tscn`, the project's main scene. Extends `src/sight/sight_deck.gd`; wires cover, lock-to-cover, suit, squad and run log. Plays on a copy of the deck (`data/pirates.json` "deck").

## Does not own
- Cover and shot rules, lock-to-cover (`src/cover`); weight (`src/player`); the gun's rules and FX (`src/weapons`); the suit (`src/health`); sight (`src/sight`). `StalkerNav` and `StalkerBrain.perceives` are reused from `src/enemies`, unchanged.

## States
`LOOT` → `MOVE` on an order → `DOWN` on arrival. `DOWN` → `RISE` when it's worth coming up → `BURST` once braced, settled and on target → `LOWER` → `DOWN`, or `RELOAD` when low → `DOWN`. A stagger freezes moving, turning and firing in any state. Any → `LOOT` on standing down. Any → `DEAD`.

## Rules
- **Weight:** same model, cone and rifle state as the player, with numbers in the same shape. They start equal to yours, except damage: a pirate round does 8, yours 18. It has no aim assist: it only fires inside the real cone, turning at the real cap.
- **Senses:** `StalkerBrain.perceives`: cone, range, walls, shut doors, tall cover, low cover on the line from its torso to yours. Also hearing, and your light landing on one. One sees, all know. Its aim lags where you are by `reaction_s`.
- **Roles:** nearest suppresses, furthest unhurt flanks, the rest support. A reloading suppressor hands over if someone can take it; a hurt one doesn't flank; alone, it holds.
- **Suppressor:** fires at where you were last known for `suppress_memory_s`, seen or not. **Support and flanker:** come up only with an open line on your body.
- **Flanker:** goes when the suppressor opens fire, or after `flank_wait_s`, to a spot with an open line on a crouched body at least `flank_min_deg` off the suppressor's angle, on a walk that stays `flank_keep_off_m` away from you. Nothing found: `fire_spot`.
- **Cover:** slots that hide from you and can fire: over low cover, or from a peek point beside tall. Torso height comes from `CoverField.torso_height`, so down is protected and braced is exposed, exactly as for you.
- **Rounds:** `ShotTracer`, the same 3D trace as yours. They pass through friends; it holds fire with a friend on the line.
- **Hurt:** at `fall_back_below` of its suit it falls back once to further cover and gives up flanking.
- **Stagger:** at least a quarter of the suit within `big_hit.window_s`, for them and, in this deck, for you.
- **Doors:** they open shut, unlocked doors on their way. Locked ones hold.
- **Barks:** text labels, and they show even when the one shouting can't be seen. A voice carries.
- **Beam:** additive sheet, drawn only where the player has sight, so it can't shine out of a room you can't see. Its spot lights the floor for real, so a remembered room shows it dimly.

## Public API
- `PirateBrain.new(cfg, loot_points, yaw)`: `step(delta, senses) -> events`, `order(role, spot)`, `stand_down()`, `take_hit(amount) -> dealt`, `alive()`, `exposed()`, `hurt()`, `wants_fall_back()`, `dug_in()`, `gun_yaw()`, `state_name()`; fields `state`, `role`, `spot`, `goal`, `brace`, `model`, `gun`, `cone`, `suit`, `rng`, `fell_back`. Senses: `pos`, `next_point`, `aim`, `can_engage`, `sees`. Events `EV_SHOT`, `EV_RELOAD`, `EV_HURT`.
- `SquadTactics.assign(members, player, was) -> {id: Role}`; enum `Role` {`NONE`, `SUPPRESS`, `FLANK`, `SUPPORT`}.
- `CoverSpots.new(...)`: `best_cover(threat, crouched_m, from, taken, away := false)`, `flank_spot(threat, crouched_m, from, anchor, taken)`, `fire_spot(threat, from, taken)`, `hides(spot, threat, crouched_m)`, `open_line(p, target, height)`; a spot is {`hide`, `fire`, `kind`, `id`}.
- `HitTally.new(window, big)`: `add(amount) -> bool`, `step(delta)`, `clear()`.
- `PirateSquad`: `setup(...)`, `tick(delta)`, `reset()`, `alert(at)`, `noise(kind, at)`, `shot_at(from, to)`, `living()`, `with_role(role)`, `senses_for(p)`, `say(p, key)`, `hide_barks()`, `shooter_lines()`, `set_mask(texture, bounds)`; fields `pirates`, `nav`, `spots`, `tracer`, `player_body`, `target`, `alerted`, `last_known`, `contact_age`, `light_on`.
- `Pirate`: `simulate(delta, squad)`, `reset()`, `take_hit`, `shot_disc`, `shot_origin()`, `muzzle_position()`, `floor_position()`; fields `brain`, `light`, `fx`, `label`, `path`, `loot`.
- `pirate_deck.gd`: `simulate_world(delta)`, `body_height()`, `in_cover_now()`, plus `weight_deck`'s and `sight_deck`'s; fields `cover`, `tracer`, `driver`, `suit`, `squad`, `run_log`. Keys: E door, Space lock, RMB aim over, 6 default camera, Backspace resets everything.

## Signals
`PirateSquad.barked(pirate, key, line)`; `Pirate.was_shot(pirate, damage, from)`.

## Data keys (`data/pirates.json`)
`radius_m`, `height_m`, `aim_height_m`, `hit_radius_m`, `health`; `stagger` {`threshold_fraction`, `control_loss_s`, `cone_deg`}; `big_hit` {`window_s`}; `weight` (`move`, `turn`, `crouch`, `anim`, as `data/player.json`); `rifle` (as `data/weapons.json` "rifle"); `senses` {`sight_range_m`, `sight_half_angle_deg`, `close_sense_m`, `gunfire_m`, `sprint_m`, `walk_m`, `crouch_m`, `sprint_emit_s`, `shot_line_m`, `reaction_s`, `stand_down_s`}; `fight` {`burst_min`, `burst_max`, `suppress_gap_s`, `support_gap_s`, `flank_gap_s`, `first_gap_s`, `gap_jitter`, `rise_s`, `lower_s`, `exposed_at`, `brace_crouch_shown`, `fire_within_deg`, `fire_spread_deg`, `peek_hold_s`, `reload_below`, `suppress_memory_s`, `friend_clear_m`, `arrive_m`, `fire_point_m`, `sprint_over_m`, `retask_s`, `reflank_s`, `flank_wait_s`, `fall_back_below`, `door_open_m`}; `spots` {`gap_m`, `step_m`, `peek_margin_m`, `claim_m`, `min_range_m`, `max_range_m`, `prefer_range_m`, `range_cost_per_m`, `travel_cost_per_m`, `away_score_per_m`, `low_score`, `path_tries`, `flank_radii_m`, `flank_samples`, `flank_min_deg`, `flank_score_per_rad`, `flank_max_rad`, `flank_travel_cost_per_m`, `flank_cover_score`, `flank_keep_off_m`}; `nav`, `stalk` (for `StalkerNav`); `loot` {`walk_share`, `pause_s`, `sweep_deg`, `sweep_hz`, `arrive_m`}; `squad` [{`name`, `space`, `at`, `yaw_deg`, `loot`}]; `flashlight` {`start_on`, `color`, `energy`, `range_m`, `half_angle_deg`, `attenuation`, `angle_attenuation`, `pitch_deg`, `shadows`, `shadow_blur`, `beam_strength`, `beam_fade_power`, `beam_edge_power`, `beam_rays`, `beam_reach_rate_m_s`, `beam_snap_m`, `beam_floor_m`, `beam_hz`}; `body` {`materials` {name: {`color`, `drop_texture`, `roughness`, optional `emission`}}, `hit_lean_deg`, `hit_lean_recover_deg_s`, `dead_tilt_deg`, `dead_tilt_deg_s`}; `barks` {`life_s`, `height_m`, `pixel_size`, `font_size`, `outline_px`, `color`, `cooldown_s`, `lines` {key: [lines]}}; `sound` {`mix_rate`, `unit_size_m`, `shot` {...}}; `deck` {`keep_spaces`, `doors`, `spawn`, `props`}; `help` {`text`}.

Tests: `tests/test_pirates.gd`. Bots: `tools/t007_bots.gd`.
