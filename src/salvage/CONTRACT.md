# salvage

What's on the ship and what carrying it does to you (T012). Weight is greed made physical (`docs/design/run-loop.md`).

## Owns
- `salvage_item.gd`: scene-free. One item: `id`, `kind`, `klass`, `word`, `base` (what the suit estimates), `value` (the truth, kept for the payslip), `prize`, `at`, `taken_by` (player ID, 0 nobody).
- `salvage_rules.gd`: scene-free. Rolls items, says what a class costs.
- `carry_state.gd`: scene-free. One per player: pockets, the in-hand item, committed lifts and drops.
- `hold.gd`: scene-free. What's banked for the crew: estimate, truth, by class.
- `salvage_field.gd`: the items in the world: grey boxes in class colours, each on a ring of light (`src/sight` beacon, `rim.unknown_share` where you've never looked: the fairness rule).

## Does not own
- The clock, tiers, alarm, LEAVE (`src/shift`). How penalties take effect (`Operator.set_carry`, `src/player`). Who hears a drop (`StalkerPack.noise`).

## Rules
- Small: pocketed up to `pocket_limit`, no penalty. Medium: one in hand; slower, no sprint, fires with a wider cone. Heavy: two hands; slower still, no sprint, no firing. Pockets still work with your hands full.
- Lifting takes `pickup_s` and holds you. A medium drop takes `drop_s` and holds you. A heavy drop has `drop_s` 0: instant, with `drop_noise` "thud". **Resolved packet vs design:** the packet says drops are committed and also "instant and loud"; the design table says only heavy is instant. Followed the design, and it's all data.
- `value` is `base` ± `value_spread`. The HUD shows the sum of `base` with an approximate sign; the true sum goes to the run log.
- E takes the nearest item in `reach_m`, so nothing sits inside the prize's reach (test).
- Items don't block anything: no collision, not cover, no nav blocker.
- Small items can't be dropped by hand; they leave at the hold or where you fall.

## Public API
- `SalvageRules.new(cfg)`: `class_of(item)`, `kind_spec(kind)`, `roll(kind, id, rng)`, `penalties(in_hand)`; static `penalties_of(class)`.
- `CarryState.new(rules, player_id)`: `can_take(item)`, `begin_take(item)` -> `OK` or `BUSY`, `POCKETS_FULL`, `HANDS_FULL`; `drop()` -> events, `step(delta)` -> events, `busy()`, `busy_type()`, `busy_share()`, `busy_left()`, `carried()`, `empty_out()`, `penalties()`; fields `pockets`, `in_hand`, `player_id`. Events {`type` `EV_TAKEN`|`EV_DROPPED`, `item`, `noise`}.
- `Hold`: `deposit(item)`, `estimate()`, `actual()`, `by_class()`, `clear()`; field `items`.
- `SalvageField`: `setup(cfg, layout, bind)`, `reset(rng)`, `nearest(p)`, `on_floor()`, `lay_down(item, at)`, `put_away(item)`, `hold_up(item, xform)`; fields `rules`, `items`.

## Signals
None.

## Data keys (`data/salvage.json`)
`pocket_limit`, `value_spread`, `reach_m`, `drop_scatter_m`; `classes` {`small`, `medium`, `heavy`: `word`, `value_min`, `value_max`, `pocketed`, `speed_mult`, `can_sprint`, `can_fire`, `cone_extra_deg`, `pickup_s`, `drop_s`, `drop_noise` (a stalker `senses` kind, or ""), `size_m`, `color`, `rim_color`, `rim_radius_m`, `carry_at`}; `kinds` {name: `word`, `class`, optional `prize`, `value_min`, `value_max`, `color`, `rim_color`}; `rim` {`energy`, `width_m`, `height_m`, `segments`, `unknown_share`}; `placements` [{`kind`, `space`, `at`}].

Tests: `tests/test_shift.gd`. Literal scan: `tests/test_weapons.gd`.
