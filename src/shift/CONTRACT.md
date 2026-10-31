# shift

One shift, solo, end to end (T012): oxygen, tiers, the alarm, the hold, LEAVE. The quota across shifts and the end screens are T013. Design: `docs/design/run-loop.md`.

## Owns
- `shift_state.gd`: scene-free. The clock, tier crossings, alarm timer, roster keyed by player ID, the hold, LEAVE, outcome and the run log's fields.
- `shift_deck.gd`: root of `scenes/shift/shift_deck.tscn` (the main scene). Extends `src/enemies/stalker_deck.gd`, wires the rules to the world, and has the T012 capture shots.
- `section_lights.gd`: one section's practicals and strips flicker, then go out. Reads `DeckLighting.lights` by name and the fixtures by render layer, without editing `src/kit`. Lights fail in looks only: no sight or AI rule reads them.
- `alarm_marker.gd`: the pulsing ring and column over a revealed player. Unmasked, so it reads through the dark.
- `airlock.gd`: where the airlock is, its outline and sign. A marked stretch of the junction's south end (the spawn end), not a room: no door, no walls, grey box.
- `placeholder_siren.gd`: a swept sine, until real sound.

## Does not own
- Salvage rules (`src/salvage`), spawning and alert (`StalkerPack`, `SpawnPicker`, `StalkerBrain.alert`), drawing the HUD (`src/hud`), carry penalties in motion (`src/player`), the log file (`src/run_log`).

## Rules
- **Oxygen** runs from `oxygen_s`; the hold doesn't refill it. At zero, the suit loses `out_of_air.suit_fraction_per_s` of a full suit per second. That's source "oxygen": no flash, no stagger, not a hit in the log; a death by it is `killed_by {suit, how: "oxygen"}`.
- **Tiers** land once each when oxygen's share falls to `at_oxygen`. Each can owe `stalkers`, fail one of `lights` (picked by the shift's seeded RNG), name `wake` hooks, and announce. A big step can't skip one.
- **Spawning:** a stalker owed comes in at a `spawn_points` entry (`data/enemies.json`), never in any player's sight and at least `spawning.min_player_m` from any player, never the same point twice in a shift. If none will do, it asks again every `spawning.retry_s`. Spawned stalkers prowl their point's room until they sense something.
- **Prize:** on the lift's completion, once a shift: every stalker gets your position, again every `alarm.refresh_s` for `alarm.reveal_s`, with the marker and siren. A dormant stalker's panel blows at once. A second lift of a dropped prize trips nothing.
- **Deposit:** standing in the airlock empties your pockets and hands into the hold. A lift in progress isn't deposited.
- **LEAVE:** hold E in the airlock for `leave.hold_s`. Letting go or stepping out starts it over. It ends the shift for whoever's in there. The deck under it stops: no stalkers, no clock.
- **Death:** what you carried lands around you. Whole crew down is outcome `wiped`, and `banked()` is 0.
- **Respawn** (Backspace) starts a new shift; one in progress logs as `abandoned`.
- E order: salvage in reach, then a bed, then a door.

## Public API
- `ShiftState.new(cfg, salvage_rules)`: `begin()`, `add_player(id)`, `carry(id)`, `alive(id)`, `step(delta)` -> events, `suit_loss(delta)`, `note_taken(item)`, `trip_alarm(id)`, `deposit(id)`, `step_leave(id, delta, in_airlock, held)`, `leave_share(id)`, `player_died(id)`, `abandon()`, `banked()`, `lost_items()`, `report()`, `ended()`, `oxygen_fraction()`, `oxygen_out()`; fields `oxygen_left`, `hold`, `tier_reached`, `prize_taken`, `alarm_left`, `outcome`, `survivors`. Events {`type`: `EV_TIER` (with `index`, `spec`), `EV_OXYGEN_OUT`, `EV_ALARM_OVER`}. Outcomes `EXTRACTED`, `WIPED`, `ABANDONED`.
- `SectionLights`: `setup(cfg, layout, lights, walls)`, `fail(space)`, `tick(delta)`, `reset()`, `state_of(space)`, `lit_lights(space)`, `light_count(space)`, `fixture_count(space)`; field `rng`.
- `AlarmMarker`: `setup(cfg)`, `show_for(s)`, `hide_now()`, `tick(delta, at)`, `alpha()`; fields `on`, `time_left`.
- `Airlock`: `setup(cfg, layout, bind)`, `has_point(p)`; field `rect`.
- `shift_deck`: `interact()`, `drop_item()`, `simulate_world(delta)`, `respawn()`; fields `shift`, `field`, `section`, `marker`, `airlock`, `player_id`, `rng`, `next_seed` (next shift's seed; 0 rolls one), `wake_hooks`. `operator.scripted` gains `leave`.
- Keys: E take/door/bed, hold E in the airlock to leave, G drop, Backspace next shift.
- **CUSTODIAN hook (T014):** put a Callable in `wake_hooks["custodian"]`, `(tier_index) -> void`. Tier 2's `wake` list names it; with nothing registered, it does nothing. There's also the signal.

## Signals
`shift_deck.tier_fired(index, spec)`.

## Data keys (`data/shift.json`)
`player_id`, `oxygen_s`; `out_of_air` {`suit_fraction_per_s`, `who`}; `tiers` [{`at_oxygen`, `stalkers`, `lights`, `wake`, `announce` (`%s` is the section)}]; `section_words`; `lights` {`flicker_s`, `gap_min_s`, `gap_max_s`, `flicker_energy`}; `airlock` {`space`, `from`, `to`, `strip_m`, `strip_height_m`, `color`, `energy`, `unknown_share`, `sign`, `sign_height_m`, `sign_pixel_size`, `sign_font_size`, `sign_color`}; `leave` {`hold_s`, `hold_after_s`}; `alarm` {`reveal_s`, `refresh_s`, `announce`, `marker` {...}, `siren` {...}}; `tier_chirp`, `mix_rate`; `drop_sound` {noise: pack sound}; `prompt`, `words`, `demo`, `help`.

Tests: `tests/test_shift.gd`. Bots: `tools/t012_bots.gd`.
