# audio

Everything the player hears (T017). Every sound is a labelled placeholder: `ph_<cue>.wav`, `"placeholder": true`.

## Owns
- `audio.gd`: autoload `Audio`. Buses and the master limiter from data, one stream per cue, a fixed pool of voices, the listener, room tones, the suit's breathing.
- `audio_bank.gd`: scene-free. The cues, and each one's cooldown on its own clock.
- `sound_rules.gd`: scene-free. `StepClock`, gait, breath stress, reload stages crossed, the cutter hum's and the chirp's pitch, the room crossfade.
- `tools/audio/gen_placeholder_audio.py` writes `assets/game/audio/<group>/ph_<cue>.wav`. Same script, same files. Then `godot --headless --path . --import`.

## Does not own
- **The AI's hearing.** `StalkerPack.noise` and the noise ring (`src/hud`) never read this module, and this module never tells them anything. Playing a cue changes nothing in the game. A test holds this.
- When anything happens: the modules below call `Audio` at their own events.

## Replacing a placeholder
Drop the real file in `assets/game/`, point the cue's `file` at it, clear `placeholder` and import. A `.ogg` works; `loop` applies to either format. A real `stalker_spit_windup` should run for the wind-up in `data/enemies.json`. `suit_breath`, `cutter_warm` and `drone_chirp` get their urgency from pitch, so they should sound right at the pitches in `breathing`, `cutter_warm` and `drone_chirp`. `tests/test_audio.gd` checks the `ph_` name, so loosen that test as real files land.

## Public API (`Audio`)
- `play(cue, at := Vector3.ZERO, opts := {}) -> bool`: false if resting or not in the bank (an error). `at` is ignored by flat cues. opts: `pitch`, `volume_db`, `delay`.
- `loop(key, cue, at, pitch)`, `stop_loop(key)`, `looping(key)`, `loop_pitch(key)`, `set_loop_pitch(key, pitch)`, `set_loop_volume(key, extra_db)`. Keys in use: `alarm`, `breath`, `room:<cue>`, `CutterUnit.warm_key()`.
- `follow(node)`: the listener stands at this node (`listener.height_m` up), turned with the camera. Without one the camera hears. For co-op, each client follows its own player.
- `start_ambience()`, `set_room(space)`, `current_room_tone()`, `room_share(cue)`.
- `breathe(suit_fraction, oxygen_fraction)`.
- `advance(delta)`: the clock; `_process` calls it, tests may `set_process(false)` and step it. `stop_all()`: the deck's gone. `reset()`: and fresh cooldowns.
- A run with `--capture-out=` is muted, so unattended captures stay quiet.

## Signals
`played(cue, at, pitch)`: each one-shot as it starts (after any delay). `loop_started(key, cue)`, `loop_stopped(key)`.

## Who calls what
- `src/weapons`: `rifle_shot`, `rifle_casing` (delayed), `rifle_dry`, `rifle_mag_out`, and `reload_stages`.
- `src/pirates`: `rifle_shot`, at each pirate's muzzle (T021).
- `src/player`: footsteps by `footsteps.surfaces` and gait, `crouch_rustle`. `weight_deck` calls `follow` and, as it leaves, `stop_all`.
- `src/enemies`: `stalker_click`, `stalker_chirp`, `stalker_spit_windup`, `stalker_spit`, `stalker_lunge`, `stalker_hit`, `stalker_death`, `stalker_scuttle`, `stalker_bash`, `bulkhead_burst`.
- `src/custodian`: `cutter_warm` (a loop rising with the ring), `cutter_burn`, `drone_chirp` (rising per bar), `custodian_chime`.
- `src/doors`: `door_open`, `door_close`, `door_locked` (also when someone's in the way), `door_break`.
- `src/shift`: room tones, breathing, `alarm_siren`, `lights_fail`, `oxygen_warning` (each tier, and repeating once the air's gone), carry cues, stamps, `ledger_tick`.

## Data keys (`data/audio.json`)
`buses` {name: {`volume_db`}}, `master` {`volume_db`, `limiter` {`ceiling_db`, `pre_gain_db`, `release_s`}}: F1 sliders in `data/debug.json` move these live. `voices` {`positional`, `flat`}; `positional` {`unit_size_m`, `max_db`}; `listener` {`height_m`}; `footsteps` {`gaits` {walk, sprint, crouch: {`stride_m`, `volume_db`}}, `min_speed_m_s`, `surfaces` {space: surface}, `default_surface`, `cues` {surface: cue}}; `breathing` {`cue`, `low_suit`, `low_oxygen`, `max_rate`, `max_extra_db`}; `reload_stages` [{`at`, `cue`}]; `stalker_idle` {`gap_min_s`, `gap_max_s`, `chirp_share`}; `cutter_warm` {`pitch_from`, `pitch_to`}; `drone_chirp` {`pitch_step`}; `ambience` {`fade_s`, `silent_db`, `rooms` {space: cue}}; `carry` {`pickup`, `drop` {class: cue}}; `paper_stamps` {button: cue}; `ledger` {`cue`, `gap_s`, `max_ticks`}.

`cues` {name: {`file`, `volume_db`, `pitch_variance` (± share), `max_distance_m` (0 is flat; above 0 is positional, fading out to there), `cooldown_s`, `bus`, `placeholder`, and optionally `loop`, `delay_s`}}.
