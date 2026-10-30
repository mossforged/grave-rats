# enemies

The stalker, its spit, the bulkhead ambush, and the scene that closes the grey-box core loop (T005).

## Owns
- `stalker_brain.gd`: scene-free states, senses, turning, timing.
- `stalker_nav.gd`: scene-free paths (`AStarGrid2D` over `DeckLayout.free_grid`, with shut doors, beds and the panel as named blockers) and the choice of where a stalk goes next.
- `spit_arc.gd`: scene-free glob: lobbed at short range, nearly flat at long range.
- `ambush_trigger.gd`: scene-free rule of the burst.
- `stalker.gd`, `stalker_body.gd`: one CharacterBody3D and its grey-box body.
- `spit_system.gd`: globs and puddles in the world, in opaque materials so the sight mask hides them.
- `stalker_pack.gd`: the stalkers and what they share: builds senses, carries noise, turns events into spits and hits.
- `bulkhead.gd`: the sealed panel: wall-coloured, stops bodies and sight, bursts into debris.
- `placeholder_sound.gd`: generated bangs and spits, until real sound.
- `stalker_deck.gd`: root of `scenes/enemies/stalker_deck.tscn`. Extends `src/sight/sight_deck.gd`; wires cover, suit, pack, ambush, run log. Dresses a copy of the deck: adds the closet and breach, moves the spawn south of the panel, removes dummies, makes the `tippable` props TipBeds.

## Does not own
- Cover rules (`src/cover`), the suit and puddle rules (`src/health`), sight (`src/sight`; `Visibility.blocked` answers "walls, shut doors, tall cover" for it), doors (`src/doors`).

## States
`DORMANT` (the closet) → `STALK` on `wake`. `PROWL` → `INVESTIGATE` on a noise → back after `linger_s`. Prowl or investigate → `STALK` on seeing you or being shot. `STALK` → `SPIT` or `LUNGE` in range → `RECOVER` → `STALK`. Memory running out in `STALK` → `INVESTIGATE` the last known place. Your death → `PROWL`.

## Rules
- **Sight:** forward cone, stopped by walls, shut doors and tall cover, and by low cover on the 3D line to your torso: crouching behind a bed hides you. Within `close_sense_m` it feels you past low cover (not through walls).
- **Doors:** it can't open them. A shut door stops it and its paths, and a noise behind one brings it up to the door. Doors won't close on it.
- **Stalk:** a planner picks points on rings around you and beside cover, scored for being hidden from you, off the direct line and on its chosen side; far away it must also get closer by walking, and close up it circles.
- **Lunge** only with nothing at knee height on the line (`ground_clear`). With a box between you it spits, which at short range arcs over.
- **Fast turn on a lunge only.** Everything else turns at capped rates, and it walks where it faces.
- **Firing from hiding** refreshes where it thinks you are.
- **Ambush:** after you pass the panel by `past_m` with it at least `behind_deg` off your aim, within `max_range_m`. Bang and kick at once; the stalker moves `emerge_delay_s` later.

## Public API
- `StalkerBrain.new(cfg, patrol, dormant, yaw)`: `step(delta, senses) -> events`, `hear(kind, at, from) -> bool`, `take_hit(damage, from) -> dealt`, `wake(player)`, `force_hunt`, `force_spit`, `force_lunge`, `alive()`, `hunting()`, `vulnerable()`, `state_name()`; static `perceives(...)`; fields `state`, `yaw`, `goal`, `velocity`, `last_known`, `knows`, `windup`, `charging`, `health`. Events `EV_SPIT`, `EV_LUNGE_START`, `EV_LUNGE_HIT`.
- `StalkerNav.new(cfg, layout)`: `set_blocker(id, rect)` (empty Rect2 clears), `path(from, to)`, `is_free(p)`, `stalk_point(from, player, side, hidden)`.
- `SpitArc.new(cfg, from, to)`: `step(delta, cover, plan_blocked, body) -> FLYING|COVER|WALL|HIT|LANDED`, `point_at(s)`; static `blocked_by_cover(cfg, cover, from, to)`, `apex_for(cfg, d)`.
- `AmbushTrigger.new(cfg, panel)`: `check(player, aim_dir) -> bool` (true once), `would_fire`, `reset()`, `fired`.
- `StalkerPack`: `setup(layout, cover, blocked, dps)`, `tick(delta)`, `reset()`, `noise(kind, at)`, `shooter_lines()`, `play_sound(key, at)`; fields `stalkers`, `nav`, `spits`, `target` {`pos`, `height`, `alive`}.
- `Stalker`: `setup`, `reset`, `simulate(delta, pack)`, `place_hunting(from, at)`, `take_hit`, `shot_disc`, `mouth`, `floor_position`; fields `brain`, `label`.
- `Bulkhead`: `setup(breach, cfg, height)`, `blow()`, `reset()`, `tick(delta)`, `blocks_sight()`, `sight_rect()`, `panel_center()`, `debris_count()`, `sealed`.
- `stalker_deck.gd`: `simulate_world(delta)`, `interact()`, `fire_ambush()`, `body_height()`, `bed_in_reach(p)`, plus `weight_deck`'s and `sight_deck`'s. Keys: E tips a bed in reach, otherwise works a door; Backspace resets everything, starts a new life and writes the old one's log.

## Signals
`StalkerPack.player_hit(source, amount, stalker, in_cover)`, `player_protected(stalker)`; `SpitSystem.glob_ended(result, shooter, aimed_at)`; `Stalker.was_shot(stalker, damage, from)`; `Bulkhead.burst`.

## Data keys (`data/enemies.json`)
- `stalker`: `health`, `radius_m`, `height_m`, `torso_m`, `mouth_m`, `hit_radius_m`, `vulnerable_damage_mult`; `senses` {`sight_range_m`, `sight_half_angle_deg`, `close_sense_m`, `memory_s`, `gunfire_m`, `sprint_m`, `sprint_emit_s`}; `turn` {`prowl_deg_s`, `investigate_deg_s`, `stalk_deg_s`, `spit_deg_s`, `lunge_deg_s`}; `speed` {`prowl_m_s`, `investigate_m_s`, `stalk_m_s`}; `prowl` {`pause_s`, `arrive_m`}; `investigate` {`linger_s`, `timeout_s`, `arrive_m`}; `stalk` {`replan_s`, `arrive_m`, `ring_radii_m`, `ring_samples`, `spot_margin_m`, `spot_range_m`, `hidden_score`, `flank_score_per_rad`, `flank_max_rad`, `side_score`, `from_cost_per_m`, `close_score_per_m`, `path_tries`, `orbit_slack_m`, `orbit_within_m`}; `nav` {`cell_m`, `repath_s`, `lookahead_cells`, `search_rings`}; `spit` {`windup_s`, `recover_s`, `cooldown_s`, `first_delay_s`, `min_range_m`, `max_range_m`, `face_deg`, `damage`, `hit_radius_m`, `protect_radius_m`, `body_margin_m`, `speed_m_s`, `min_flight_s`, `apex_short_m`, `apex_long_m`, `short_range_m`, `long_range_m`, `arc_samples`, `glob_radius_m`, `glob_color`, `glob_energy`}; `puddle` {`life_s`, `radius_m`, `blocked_back_m`, `shrink_from`, `height_m`, `color`, `energy`, `max_count`}; `lunge` {`windup_s`, `range_m`, `charge_m`, `speed_m_s`, `damage`, `hit_reach_m`, `recover_s`, `cooldown_s`, `first_delay_s`, `probe_height_m`}; `flinch` {`s`, `speed_factor`, `pitch_deg`, `flash_s`}; `body` {colours, `glow_*`, `windup_lean_deg`, `charge_stretch`, `recover_squash`, `dead_tilt_deg`, `visual_rate_per_s`, `parts` [{`capsule` [r, h] or `box` [x, y, z], `at`, `rot`}]}.
- `pack` [{`name`, `space`, `at`, `yaw_deg`, `patrol` [[fx, fz]], `dormant`}].
- `ambush`: `closet` (a space spec), `breach`, `spawn`, `pass_dir`, `past_m`, `max_range_m`, `behind_deg`, `emerge_delay_s`, `camera_kick_m`, `camera_kick_recover_s`, `panel_color`, `panel_roughness`, `debris` {`count`, `size_min_m`, `size_max_m`, `speed_min_m_s`, `speed_max_m_s`, `spread_deg`, `lift_m_s`, `gravity_m_s2`, `bounce`, `friction`, `spin_deg_s`, `color`, `hot_color`, `hot_share`}.
- `sound`: `mix_rate`, `unit_size_m`, and `bang`, `spit`, `lunge` {`length_s`, `decay_per_s`, `low_hz`, `low_share`, `volume_db`}.
- `help` {`text`}.

Tests: `tests/test_enemies.gd`.
