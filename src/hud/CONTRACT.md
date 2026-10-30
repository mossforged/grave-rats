# hud

The company-issue suit OS (T008, picked by John: A003-02 / A005-05), with a ring on the floor showing noise.

## Owns
- `noise_state.gd`: scene-free ring: how far you can be heard right now, swell, bloom, hold, shrink, the pulse from a shot.
- `noise_ring.gd`, `noise_ring.gdshader`: the ring in the world: thin additive segments on the floor around the operator.
- `suit_os.gd`: scene-free readouts: state words, alarms, low thresholds, the oxygen ticker, how credits read.
- `suit_os_hud.gd`: draws everything on screen: mark, crew row, oxygen dock, watermark, right dock, alarm strip, cover shields, states over the operator, key help.

## Does not own
- The numbers the ring shows: those are the enemies' `senses` (`data/enemies.json` `stalker.senses`, `data/pirates.json` `senses`), passed in by reference and never copied. Who hears what (`src/enemies`, `src/pirates`). What noise your feet make (`OperatorModel.noise_kind()`). Whether you're in cover (`src/cover`). The hit flash and death screen (`src/health`). Door prompts (`src/doors`, `src/cover`: 3D labels in the world).

## Rules
- **The ring's radius is a hearing radius.** Walk, crouch-walk, sprint and gunfire each settle exactly on `<kind>_m`. Standing still it's empty and draws nothing.
- **It shows the open-air radius.** Through a shut door a stalker hears `through_door_factor` of it; the ring doesn't draw that.
- Each deck passes its own ears through `_noise_senses()`: stalkers by default, pirates in `pirate_deck`.
- A shot goes out to `gunfire_m` in `bloom_s`, holds `hold_s`, comes back over `shrink_s`. At the default camera the gunfire radius is mostly off screen, so each shot also sends a pulse, restarted once the last has run `ripple_restart_m`.
- Over the sight mask, under walls and props (depth-tested): it shows across rooms you haven't seen.
- Placeholders: oxygen counts down and does nothing at zero; salvage credits are a data value; one crew row, its bar being your suit.
- Decks without a suit read as a full suit.
- Sizes are at `ref_height_px` and scale with the window's height. Data is read live, so the F1 panel works.

## Public API
- `NoiseState.new(ring_cfg, senses)`: `step(delta, feet_kind)`, `fire()`, `reset()`, `heard_at(kind)`, `alpha_at(r)`, `heat_at(r)`; fields `kind`, `radius`, `ripple`.
- `NoiseRing`: `setup(ring_cfg, senses)`, `tick(delta, at, feet_kind)`; field `state`.
- `SuitOs.new(cfg)`: `step(delta)`, `reset()`, `oxygen_text()`, `oxygen_fraction()`, `suit_low(f)`, `ammo_low(mag)`, `credits_text(n)`, `alerts(in_acid, mag)`, `status(facts)`.
- `SuitOsHud`: set `operator`, `camera_rig`, `suit`, `mark`, `in_acid`, `light_off`, `lock_state`, `scene_help`; `reset()`, `toggle_help()`, `status_now()`, `suit_fraction()`; fields `cfg`, `os_state`, `help_on`.
- Key: H toggles the help (handled in `weight_deck`).

## Signals
None. The deck connects `Rifle.fired` to `NoiseState.fire()`.

## Data keys (`data/hud.json`)
`layer`, `ref_height_px`; `font` {`regular`, `bold`}; `colors` {`plate`, `line`, `track`, `bar`, `accent`, `text`, `text_dim`, `watermark`, `good`, `warn`, `danger`}; `words`; `mark`; `crew`; `oxygen`; `watermark`; `dock`; `suit` {`word`, `unit`, `percent`, `low_fraction`}; `ammo` {`word`, `digits`, `low_rounds`}; `salvage` {`word`, `unit`, `credits`, `fill`, `group_digits`, `separator`}; `alert`; `shields`; `status`; `help` {`start_on`, `text`, `font_px`, `line_px`, `pad_px`, `from_bottom_px`}; `icons` (polygons and circles in a unit box); `ring` {`height_m`, `line_m`, `segments`, `gap`, `bloom_s`, `hold_s`, `shrink_s`, `swell_m_s`, `ripple_restart_m`, `cold_color`, `hot_color`, `alpha` {`walk`, `sprint`, `gunfire`, `ripple`}}.

Font: Barlow Condensed, SIL Open Font License 1.1 (`assets/game/fonts/OFL.txt`). If it won't load, the HUD falls back to Godot's default.

Tests: `tests/test_hud.gd`. The literal scan in `tests/test_weapons.gd` covers this module's scripts.
