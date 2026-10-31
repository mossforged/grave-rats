# enemies

The stalker, its spit, the bulkhead ambush, and the scene that closes the grey-box core loop (T005). Made dangerous in T006: dashes, dodges, breaks doors.

## Owns
- `stalker_brain.gd`: scene-free states, senses, turning, timing.
- `stalker_nav.gd`: scene-free paths (`AStarGrid2D` over `DeckLayout.free_grid`, with shut doors, beds and the panel as named blockers) and the choice of where a stalk goes next.
- `spit_arc.gd`: scene-free glob: lobbed at short range, nearly flat at long range.
- `ambush_trigger.gd`: scene-free rule of the burst.
- `stalker.gd`, `stalker_body.gd`: one CharacterBody3D and its grey-box body.
- `spit_system.gd`: globs and puddles in the world, in opaque materials so the sight mask hides them.
- `stalker_pack.gd`: the stalkers and what they share: builds senses, carries noise, turns events into spits and hits.
- `bulkhead.gd`: the sealed panel: wall-coloured, stops bodies and sight, bursts into debris. A hairline beacon along its foot is the tell (T011, `ambush.tell`), a look and not a rule.
- `placeholder_sound.gd`: a generated bang. Only `src/pirates` still uses it; everything else plays through `src/audio`.
- `spawn_picker.gd`: scene-free. Where a new stalker may come in: not in any viewer's sight, not within `spawning.min_player_m` of a player, not a point already used (T012).
- `stalker_deck.gd`: root of `scenes/enemies/stalker_deck.tscn`. Extends `src/sight/sight_deck.gd`; wires cover, suit, pack, ambush, run log. Dresses a copy of the deck: adds the closet and breach, moves the spawn south of the panel, removes dummies, makes the `tippable` props TipBeds.

## Does not own
- Cover rules (`src/cover`), the suit and puddle rules (`src/health`), sight (`src/sight`; `Visibility.blocked` answers "walls, shut doors, tall cover" for it), doors (`src/doors`).

## States
`DORMANT` (the closet) → `STALK` on `wake`, rushing. `PROWL` → `INVESTIGATE` on a noise → back after `linger_s`. Prowl or investigate → `STALK` on seeing you, being shot at, or your light landing on it. `STALK` → `SPIT` or `LUNGE` in range → `RECOVER` → `STALK` (backing off for `back_off_s`). Prowl, investigate or stalk → `DODGE` on a threat, cooldown allowing → `STALK`. `STALK` → `BASH` when a breakable shut door is all that's between it and `last_known` → `STALK` when the door stops being in the way. `INVESTIGATE` never goes to `BASH`. Memory running out in `STALK` → `INVESTIGATE` the last known place. Your death → `PROWL`.

## Rules
- **Sight:** forward cone, stopped by walls, shut doors and tall cover, and by low cover on the 3D line to your torso: crouching behind a bed hides you. Within `close_sense_m` it feels you past low cover (not through walls).
- **Doors:** it never opens them. If it's hunting you (it saw you, or was stalking you) and you're behind a shut door with no way round, it walks up and bangs until the door breaks, `data/doors.json` `bash.break_s` of bashing. **A noise never starts this (T008):** a stalker that wasn't hunting walks up to the door, lingers `investigate.linger_s` facing it, and goes back to prowling. A round stopped by the door doesn't count as passing it.
- **Hearing:** `<kind>_m` for `gunfire`, `sprint`, `walk`, `crouch`, emitted every `sprint_emit_s` while moving. With no open way to the noise, it carries `through_door_factor` of that. `StalkerBrain.hearing_radius` is the one rule; the HUD's ring reads the same `senses`. Two on one door are no faster. Locked doors hold: a stalker won't try them. Doors won't close on it.
- **Moving:** in stalk it goes in dashes (`dash`) between short pauses, skittering side to side, facing where it's going; paused, it faces you. It walks only when prowling or investigating.
- **Dodge:** a hit, a round passing within `shot_line_m`, or the light first landing on it. Sideways to you, to somewhere hidden if it can. Not out of a wind-up or charge. A threat during recovery waits for the recovery to end, so that window stays yours. Hits land normally during a dodge.
- **Ambush rush:** on `wake` it goes straight at you with no pauses for up to `rush_s`, lunging as soon as it's in reach with the floor clear, whether or not it's facing you.
- **Stalk:** a planner picks points on rings around you and beside cover, scored for being hidden from you, off the direct line and on its chosen side; far away it must also get closer by walking, and close up it circles. It replans on arriving and after an attack, when further from you scores instead of nearer and it may change sides.
- **Lunge** only with nothing at knee height on the line (`ground_clear`). With a box between you it spits, which at short range arcs over.
- **Fast turn on a lunge only.** Everything else turns at capped rates, and it walks where it faces.
- **Firing from hiding** refreshes where it thinks you are.
- **Ambush:** after you pass the panel by `past_m` with it at least `behind_deg` off your aim, within `max_range_m`. Bang and kick at once; the stalker moves `emerge_delay_s` later.

## Sounds (T017)
Through `src/audio`. The hiss starts as the spit's wind-up starts, however it started. Awake and alive, a stalker clicks or chirps every `stalker_idle` gap; you can hear one through a wall, and that's how you know it's there. Hit, death, spit, lunge, bash at the door, the panel's burst, and a scuttle where a vent stalker comes in.

## Public API
- `StalkerBrain.new(cfg, patrol, dormant, yaw)`: `step(delta, senses) -> events`, `hear(kind, at, from, through_door) -> bool`, static `hearing_radius(cfg, kind, through_door)`, `take_hit(damage, from) -> dealt`, `notice_shot(from)`, `alert(at)` (told where you are: it hunts; dormant and dead ignore it), `wants_dodge()`, `backing_off()`, `wake(player, from)`, `force_hunt`, `force_spit`, `force_lunge`, `alive()`, `hunting()`, `vulnerable()`, `state_name()`; static `perceives(...)`; fields `state`, `yaw`, `goal`, `velocity`, `last_known`, `knows`, `windup`, `charging`, `dashing`, `rushing`, `bashing`, `plan_now`, `flip_side`, `rng`, `health`. Events `EV_SPIT`, `EV_LUNGE_START`, `EV_LUNGE_HIT`, `EV_BANG`.
- `StalkerNav.new(cfg, layout)`: `set_blocker(id, rect, breakable)` (empty Rect2 clears), `path(from, to)`, `is_free(p)`, `line_free(a, b)`, `door_on_way(from, to)`, `dodge_point(from, player, side, hidden)`, `stalk_point(from, player, side, hidden, backing_off)`.
- `SpitArc.new(cfg, from, to)`: `step(delta, cover, plan_blocked, body) -> FLYING|COVER|WALL|HIT|LANDED`, `point_at(s)`; static `blocked_by_cover(cfg, cover, from, to)`, `apex_for(cfg, d)`.
- `AmbushTrigger.new(cfg, panel)`: `check(player, aim_dir) -> bool` (true once), `would_fire`, `reset()`, `fired`.
- `SpawnPicker`: static `pick(points, viewers, players, used, min_player_m, rng) -> index or -1`, `allowed(...)`. `viewers` is one `(p) -> bool` per player.
- `StalkerPack`: `setup(layout, cover, blocked, dps)`, `tick(delta)`, `reset()` (extras leave; `stalkers` keeps its identity, the shot tracer holds it), `spawn_out_of_view(viewers, players, rng) -> stalker or null`, `spawn_points()`, `alert(at)`, `noise(kind, at)`, `shot_at(from, to)`, `door_towards(s)`, `next_dodge_point(s)`, `shooter_lines()`, `play_sound(key, at)`; fields `stalkers`, `nav`, `spits`, `light_on` (Callable, set by the scene), `target` {`pos`, `height`, `alive`}.
- `Stalker`: `setup`, `reset`, `simulate(delta, pack)`, `place_hunting(from, at)`, `take_hit`, `shot_disc`, `mouth`, `floor_position`; fields `brain`, `label`, `door`.
- `Bulkhead`: `setup(breach, cfg, height)`, `blow()`, `reset()`, `tick(delta)`, `blocks_sight()`, `sight_rect()`, `panel_center()`, `debris_count()`, `use_mask(bind)`, `tell_visible()`, `sealed`.
- `stalker_deck.gd`: `simulate_world(delta)`, `interact()`, `fire_ambush()`, `body_height()`, `in_cover_now()`, `bed_in_reach(p)`, plus `weight_deck`'s and `sight_deck`'s. Keys: E tips a bed in reach, otherwise works a door; 6 goes back to the default camera; Backspace resets everything, starts a new life and writes the old one's log.

## Signals
`StalkerPack.player_hit(source, amount, stalker, in_cover)`, `player_protected(stalker)`; `SpitSystem.glob_ended(result, shooter, aimed_at)`; `Stalker.was_shot(stalker, damage, from)`; `Bulkhead.burst`.

## Data keys (`data/enemies.json`)
- `stalker`: `health`, `radius_m`, `height_m`, `torso_m`, `mouth_m`, `hit_radius_m`, `vulnerable_damage_mult`; `senses` {`sight_range_m`, `sight_half_angle_deg`, `close_sense_m`, `memory_s`, `gunfire_m`, `sprint_m`, `walk_m`, `crouch_m`, `thud_m`, `through_door_factor`, `sprint_emit_s`}; `turn` {`prowl_deg_s`, `investigate_deg_s`, `stalk_deg_s`, `spit_deg_s`, `lunge_deg_s`}; `speed` {`prowl_m_s`, `investigate_m_s`}; `dash` {`speed_m_s`, `min_s`, `max_s`, `pause_min_s`, `pause_max_s`, `turn_deg_s`, `jink_deg`, `jink_hz`, `rush_s`}; `dodge` {`speed_m_s`, `max_s`, `reach_m`, `cooldown_s`, `shot_line_m`, `angles_deg`, `hidden_score`, `side_score`, `arrive_m`}; `prowl` {`pause_s`, `arrive_m`}; `investigate` {`linger_s`, `timeout_s`, `arrive_m`}; `stalk` {`replan_s`, `arrive_replan_s`, `arrive_m`, `min_hop_m`, `back_off_s`, `flip_side_chance`, `ring_radii_m`, `ring_samples`, `spot_margin_m`, `spot_range_m`, `hidden_score`, `flank_score_per_rad`, `flank_max_rad`, `side_score`, `from_cost_per_m`, `close_score_per_m`, `path_tries`, `orbit_slack_m`, `orbit_within_m`}; `nav` {`cell_m`, `repath_s`, `lookahead_cells`, `search_rings`}; `spit` {`windup_s`, `recover_s`, `cooldown_s`, `first_delay_s`, `min_range_m`, `max_range_m`, `face_deg`, `damage`, `hit_radius_m`, `protect_radius_m`, `body_margin_m`, `speed_m_s`, `min_flight_s`, `apex_short_m`, `apex_long_m`, `short_range_m`, `long_range_m`, `arc_samples`, `glob_radius_m`, `glob_color`, `glob_energy`}; `puddle` {`life_s`, `radius_m`, `blocked_back_m`, `shrink_from`, `height_m`, `color`, `energy`, `max_count`}; `lunge` {`windup_s`, `range_m`, `charge_m`, `speed_m_s`, `damage`, `hit_reach_m`, `recover_s`, `cooldown_s`, `first_delay_s`, `probe_height_m`}; `flinch` {`s`, `speed_factor`, `pitch_deg`, `flash_s`}; `body` {colours, `glow_*`, `windup_lean_deg`, `charge_stretch`, `dash_stretch`, `recover_squash`, `dead_tilt_deg`, `visual_rate_per_s`, `parts` [{`capsule` [r, h] or `box` [x, y, z], `at`, `rot`}]}.
- `pack` [{`name`, `space`, `at`, `yaw_deg`, `patrol` [[fx, fz]], `dormant`}].
- `ambush`: `closet` (a space spec), `breach`, `spawn`, `pass_dir`, `past_m`, `max_range_m`, `behind_deg`, `emerge_delay_s`, `camera_kick_m`, `camera_kick_recover_s`, `debris` {`count`, `size_min_m`, `size_max_m`, `speed_min_m_s`, `speed_max_m_s`, `spread_deg`, `lift_m_s`, `gravity_m_s2`, `bounce`, `friction`, `spin_deg_s`, `color`, `hot_color`, `hot_share`}.
- `help` {`text`}.
- `spawn_points` [{`name`, `kind` (vent|closet, a label for now: nothing's drawn), `space`, `at`, `patrol` [[fx, fz]]}]; `spawning` {`min_player_m`, `retry_s`}.

Tests: `tests/test_enemies.gd`. Bots: `tools/t006_bots.gd`.
