# health

Suit integrity and what acid does (T005).

## Owns
- `suit.gd`: scene-free integrity, the big-hit stagger, death.
- `puddle_field.gd`: scene-free acid puddles: where, how long, the damage for standing in one. Overlaps don't stack.
- `health_hud.gd`: bar, "ACID" warning, hit flash, death screen.

## Does not own
- What a stagger does to the operator (the scene: `Operator.hold_control`, opens the cone, kicks the camera). Spit and lunge damage and puddle size and life (`data/enemies.json`). Drawing puddles (`src/enemies/spit_system.gd`).

## Public API
- `Suit.new(cfg)`: `take(amount, source) -> {amount, staggered, died}`, `step(delta)`, `reset()`, `fraction()`, `staggered()`; fields `integrity`, `stagger_left`, `dead`, `last_source`. A hit of at least `threshold_fraction` of the full suit staggers; the threshold is per hit, so a puddle's ticks never do.
- `PuddleField.new(dps)`: `add(at, radius, life, owner_name, max_count)`, `step(delta)`, `clear()`, `puddle_at(p)`, `damage_at(p, delta)`; field `puddles`.
- `HealthHud`: `suit`, `in_acid`, `flash()`, `show_death(line)` ("" hides it).

## Signals
None.

## Data keys (`data/health.json`)
`suit` {`max`}; `stagger` {`threshold_fraction`, `control_loss_s`, `cone_deg`, `camera_kick_m`, `kick_recover_s`}; `acid` {`puddle_dps`}; `hud` {`layer`, `bar_width_px`, `bar_height_px`, `margin_px`, `label_font_size`, `death_font_size`, `detail_font_size`, `outline_px`, `flash_s`, `acid_color`, `bar_color`, `low_color`, `low_fraction`, `flash_color`, `death_color`, `death_word`, `restart_word`}.

Tests: `tests/test_health.gd`.
