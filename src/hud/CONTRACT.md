# hud

The company-issue suit OS (T008, picked by John: A003-02 / A005-05), with a ring on the floor showing noise.

## Owns
- `noise_state.gd`: scene-free ring: how far you can be heard right now, swell, bloom, hold, shrink, the pulse from a shot.
- `noise_ring.gd`, `noise_ring.gdshader`: the ring in the world: thin additive segments on the floor around the operator.
- `suit_os.gd`: scene-free readouts: state words, alarms, low thresholds, the oxygen ticker, how credits read.
- `hit_direction.gd`: scene-free arcs for hits from out of sight (T011): where from, colour by source, fade.
- `suit_os_hud.gd`: draws everything on screen: mark, crew row, oxygen dock, watermark, right dock, alarm strip, cover shields, states over the operator, key help.

## Does not own
- The numbers the ring shows: those are the enemies' `senses` (`data/enemies.json` `stalker.senses`, `data/pirates.json` `senses`), passed in by reference and never copied. Who hears what (`src/enemies`, `src/pirates`). What noise your feet make (`OperatorModel.noise_kind()`). Whether you're in cover (`src/cover`). The hit flash and death screen (`src/health`). Door prompts (`src/doors`, `src/cover`: 3D labels in the world).

## Rules
- **The ring's radius is a hearing radius.** Walk, crouch-walk, sprint and gunfire each settle exactly on `<kind>_m`. Standing still it's empty and draws nothing.
- **It shows the open-air radius.** Through a shut door a stalker hears `through_door_factor` of it; the ring doesn't draw that.
- Each deck passes its own ears through `_noise_senses()`: stalkers by default, pirates in `pirate_deck`.
- A shot goes out to `gunfire_m` in `bloom_s`, holds `hold_s`, comes back over `shrink_s`. At the default camera the gunfire radius is mostly off screen, so each shot also sends a pulse, restarted once the last has run `ripple_restart_m`.
- Over the sight mask, under walls and props (depth-tested): it shows across rooms you haven't seen.
- **Oxygen and salvage (T012):** a deck with a shift calls `os_state.set_oxygen(left, total)` and sets `hold_estimate`; the suit then counts nothing itself. Other decks keep the placeholders: oxygen counts down from data and does nothing at zero, salvage credits are a data value. One crew row, its bar being your suit.
- **The hold reads `≈`** (`salvage.approx`) until the payslip (T013).
- A loud thing other than a shot (a dropped pod) blooms the ring to its own radius with `state.fire(kind)`.
- Announcements are one line at a time, terse, in the suit's voice; a new one replaces the old.
- Decks without a suit read as a full suit.
- Sizes are at `ref_height_px` and scale with the window's height. Data is read live, so the F1 panel works.

## Public API
- `NoiseState.new(ring_cfg, senses)`: `step(delta, feet_kind)`, `fire(loud_kind := "gunfire")`, `reset()`, `heard_at(kind)`, `alpha_at(r)`, `heat_at(r)`; fields `kind`, `radius`, `ripple`.
- `NoiseRing`: `setup(ring_cfg, senses)`, `tick(delta, at, feet_kind)`; field `state`.
- `HitDirection.new(cfg)`: `add(from, source)`, `step(delta)`, `reset()`, `color_for(source)`, `alpha_of(arc)`; field `arcs`.
- `SuitOs.new(cfg)`: `step(delta)`, `reset()`, `oxygen_text()`, `oxygen_fraction()`, `suit_low(f)`, `ammo_low(mag)`, `credits_text(n)`, `alerts(in_acid, mag, urgent := [])` (`urgent`: keys of `words`, listed first), `status(facts)` (facts may add `hands_full`), `set_oxygen(left, total)`, `hold_text(estimate)`, `announce(line)`, `announcement()`, `announcement_alpha()`; fields `oxygen_left`, `oxygen_total`, `driven`.
- `SuitOsHud`: set `operator`, `camera_rig`, `suit`, `mark`, `in_acid`, `light_off`, `lock_state`, `scene_help`, `hold_estimate` (below zero: the placeholder), `carry` {`slots_used`, `slots_max`, `in_hand`, `class_word`, `class_key`} (empty: no plate), `action` {`word`, `share`}, `urgent_alerts`, `hands_full`, `banner` [big, lines...]; `reset()`, `toggle_help()`, `status_now()`, `suit_fraction()`; fields `cfg`, `os_state`, `hits`, `help_on`.
- Key: H toggles the help (handled in `weight_deck`).

## Signals
None. The deck connects `Rifle.fired` to `NoiseState.fire()`.

## Data keys (`data/hud.json`)
`layer`, `ref_height_px`; `font` {`regular`, `bold`}; `colors` {`plate`, `line`, `track`, `bar`, `accent`, `text`, `text_dim`, `watermark`, `good`, `warn`, `danger`}; `words`; `mark`; `crew`; `oxygen`; `watermark`; `dock`; `suit` {`word`, `unit`, `percent`, `low_fraction`}; `ammo` {`word`, `digits`, `low_rounds`}; `salvage` {`word`, `unit`, `credits`, `fill`, `approx`, `group_digits`, `separator`}; `carry` {`word`, `x_px`, `from_bottom_px`, `w_px`, `h_px`, `label_px`, `slot_px`, `slot_gap_px`, `slots_x_px`, `line_gap_px`, `font_px`, `empty`, `hand`, `slot_filled`, `class_colors`}; `announce` {`y_px`, `h_px`, `pad_px`, `font_px`, `font_drop_px`, `life_s`, `fade_s`}; `action` {`above_m`, `w_px`, `h_px`, `font_px`, `gap_px`}; `banner` {`y_px`, `h_px`, `w_px`, `big_px`, `font_px`, `line_px`}; `alert`; `shields`; `status`; `help` {`start_on`, `text`, `font_px`, `line_px`, `pad_px`, `from_bottom_px`}; `icons` (polygons and circles in a unit box); `hit_direction` {`only_out_of_sight`, `life_s`, `fade_s`, `merge_m`, `max_arcs`, `radius_px`, `width_px`, `tip_px`, `span_deg`, `segments`, `colors` {`default`, source names}}; `ring` {`height_m`, `line_m`, `segments`, `gap`, `bloom_s`, `hold_s`, `shrink_s`, `swell_m_s`, `ripple_restart_m`, `cold_color`, `hot_color`, `alpha` {`walk`, `sprint`, `gunfire`, `ripple`}}.

Font: Barlow Condensed, SIL Open Font License 1.1 (`assets/game/fonts/OFL.txt`). If it won't load, the HUD falls back to Godot's default.

Tests: `tests/test_hud.gd`. The literal scan in `tests/test_weapons.gd` covers this module's scripts.
