# custodian

Vesper Reach's maintenance AI, protecting company property from you (T015). Systemic and readable: each unit has one rule and one tell. Design: `docs/handoffs/auto-A011.md`. Grey box: boxes until the Meshy models come.

## Owns
- `cutter_brain.gd`: scene-free cutter. `DORMANT` > `SWEEP` > `AIM` (the ring fills once the line is on you) > `BURN` > `COOL` > `SWEEP`.
- `drone_brain.gd`: scene-free drone. `DORMANT` > `PATROL` > `CALL` > `PATROL`; `DEAD`.
- `custodian_voice.gd`: scene-free. When it speaks: each line's own rest and one shared rest. Urgent lines don't wait.
- `custodian_trace.gd`: the guns' 3D trace for a line: physics for walls and doors, then the cover field, as `src/cover/shot_tracer.gd` reads them. Non-static colliders are stepped through.
- `cutter_unit.gd`, `drone_unit.gd`: one unit in the world. `custodian_fx.gd` and the three `.gdshader`s: housings, lens, ring, line.
- `custodian.gd`: all the units and the voice, the terminals, waking, what a completed call brings.

## Does not own
- Damage, the suit, the log, the HUD, stalkers, the sight mask, the flash (`src/shift/shift_deck.gd` answers its signals and passes in what it needs). Copy for the paperwork (`data/paperwork.json`).

## Rules
- **Cutter rule:** it needs a clear line to you; tall cover breaks it. Low cover doesn't, by geometry: it fires from `mount_height_m` at a point no lower than `aim_floor_m`, both over everything low (`tests/test_custodian.gd` holds this against the props), so it works crouched too.
- **Cutter tell:** the line sweeps, swings on, and stays on while the ring fills on the mount and under you, for `warmup_s` once aligned. Break the line and it cancels that step, ring empty, and looks away for `cancel_hold_s`. The burn is checked on the step it fires. It doesn't follow you, and lands once.
- **Fairness:** aiming at you, its line and rings show anywhere, through the mask, and it flashes itself into your sight (`reveal`). Sweeping, its line reads only where you've seen. The line stops at what stops it, with a mark there.
- **Arc:** a cutter reaches `arc_half_deg` either side of `home_yaw_deg`, within `range_m`. Out of its arc is safe.
- **Drone rule:** break its spotlight's line before the call completes. Out of the cone, out of range or behind cover cancels it, back to nothing, and it can't re-acquire for `reacquire_s`. After a completed call it rests `call_cooldown_s`. It uses the same trace to your torso from `eye_height_m` (low), so unlike the cutter, crouching behind low cover can hide you from it.
- **Drone tell:** the cone, three roof bars filling in order, a chirp rising per bar (`data/audio.json` `drone_chirp`). While calling, the bars float on a plate over everything and the cone ignores the mask.
- **Completed call:** the nearest sleeping cutter within `call.wake_cutter_m` of the drone wakes. With none, the deck alerts the nearest stalker that's up. `on_wake` false keeps a cutter back for this.
- **Fragile:** `drone.health` is 3 rifle rounds. It stays as a dark wreck. It has no collider. It never does damage.
- **Waking:** once a shift, from tier 2 or the prize. The prize's line is said even if it's already up. Dormant lenses are dim, awake bright.
- **Voice:** only at state changes (waking, a warm-up or call starting, a hit, a completed call), on `cooldown_s` and `global_cooldown_s`.
- **Multiplayer:** players come in as a list by ID, and every event carries one. Solo for now.

## Sounds (T017)
Through `src/audio`. The cutter's hum runs exactly while it aims, its pitch rising with `warm_share()`; a broken line stops it. The burn comes with the beam, a chirp with each bar, a chime with each voice line that's actually said.

## Public API
- `Custodian`: `setup(cfg, layout, trace, visibility, bind, knows, mask_texture, bounds)`, `reset()`, `wake(reason) -> bool` (`reason`: key of `wake`), `tick(delta, players)`, `cutter_on(id)`, `drone_on(id)`; fields `cutters`, `drones`, `voice`, `awake`, `calls_done`, `calls_broken`. `players`: [{`id`, `pos`: Vector2, `body`: Vector3, `alive`}]. `trace`: (from, to) -> {`clear`, `point`}.
- `CutterUnit`: `tick`, `wake()`, `reset()`, `floor_position()`; fields `brain`, `label`, `line_mesh`, `beam_mesh`, `mount_ring`, `target_ring`, `lens`, `stop_mark`, `line_end`, `line_stopped`.
- `DroneUnit`: as above, plus `shot_disc()`, `take_hit(hit)` (rifle body contract), `set_mask(texture, bounds)`; fields `spot`, `fan`, `beam`, `bars`, `tell_bars`.
- `CutterBrain.new(cfg, at, home_yaw_deg, arc_half_deg)`: `step(delta, players, trace) -> events`, `wake()`, `reset()`, `awake()`, `aiming()`, `burning()`, `line_on()`, `warm_share()`, `can_see(player, trace)`, `aim_point(player)`, `far_point(reach)`, `line_reach(players)`; fields `state`, `yaw`, `warm`, `target_id`, `mount`. Events `EV_AIM`, `EV_CANCEL`, `EV_BURN`, `EV_HIT` (with `amount`), all with `player_id`.
- `DroneBrain.new(cfg, at, route)`: `step(delta, players, trace) -> events`, `wake()`, `reset()`, `awake()`, `alive()`, `calling()`, `call_share()`, `bars_lit()`, `spot_sees(player, trace)`, `take_hit(damage)`, `eye()`; fields `state`, `pos`, `yaw`, `health`, `target_id`, `route`. Events `EV_CALL_START`, `EV_BAR` (`bar`), `EV_CALL_BROKEN`, `EV_CALLED` (`player_id`, `at`).
- `CustodianVoice.new(cfg)`: `say(event) -> line or ""`, `step(delta)`, `reset()`.
- `CustodianTrace.new(cover, world, exclude)`: `line(from, to) -> {clear, point}`.

A drone's `route` is fractions of its `space` and may fall outside 0-1 (T023: the survey's patrol crosses rooms). It flies straight through shut doors; see `docs/handoffs/auto-T023.md`.

## Signals
`Custodian.player_hit(player_id, source, amount, from, who)`, `spoke(line)`, `woke(reason)`, `revealed(unit, at)`, `stalker_wanted(player_id, at, from)`, `called(player_id, how)` (`CALLED_CUTTER`, `CALLED_STALKER`).

## Data keys (`data/custodian.json`)
`wake` {reason: voice line}; `voice` {`global_cooldown_s`, `lines` {key: {`text`, `cooldown_s`, `urgent`}}}; `lens` {`color`, `dim_energy`, `bright_energy`, `unknown_share`, `size_m`}; `shell` {`ivory`, `teal`, `dark`, `roughness`}; `terminals` {`size_m`, `height_m`, `lens_out_m`, `word`, `word_font_size`, `word_pixel_size`, `word_up_m`, `at` [{`space`, `at`}]}; `cutter` {`label`, `killer_key`, `source`, `mount_height_m`, `aim_floor_m`, `range_m`, `sweep_deg_s`, `slew_deg_s`, `track_deg_s`, `aligned_deg`, `warmup_s`, `burn_s`, `damage`, `hit_radius_m`, `cool_s`, `cancel_hold_s`, `body_size_m`, `lens_up_m`, `line` {...}, `beam` {...}, `ring` {...}, `reveal` {...}, `warm_sound`, `burn_sound`}; `cutters` [{`name`, `space`, `at`, `home_yaw_deg`, `arc_half_deg`, `on_wake`}]; `drone` {`label`, `health`, `hit_radius_m`, `shot_height_m`, `speed_m_s`, `turn_deg_s`, `move_within_deg`, `arrive_m`, `eye_height_m`, `spot_range_m`, `spot_half_deg`, `call_s`, `bars`, `track_deg_s`, `reacquire_s`, `call_cooldown_s`, sizes, `tell_*`, `wreck_tilt_deg`, `spot` {...}, `chirp` {...}, `unit_size_m`}; `call` {`wake_cutter_m`}; `words` {`called_cutter`, `called_stalker`}; `drones` [{`name`, `space`, `at`, `route` [[fx, fz]]}].

Tests: `tests/test_custodian.gd`. Literal scan: `tests/test_weapons.gd`. Bots: `tools/t015_bots.gd` (what a tell is worth), `tools/t015_shift_bots.gd` (whole shifts, reading the ring). Capture shots: `t015_*` on `shift_deck`; sheet `tools/t015_sheet.py`.
