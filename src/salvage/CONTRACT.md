# salvage

What's on the ship and what carrying it does to you (T012). Weight is greed made physical (`docs/design/run-loop.md`).

## Owns
- `salvage_item.gd`: scene-free. One item: `id`, `kind`, `klass`, `word`, `base` (what the suit estimates), `value` (the truth, kept for the payslip), `prize`, `at`, `taken_by` (player ID, 0 nobody).
- `salvage_rules.gd`: scene-free. Rolls items, says what a class costs.
- `carry_state.gd`: scene-free. One per player: pockets, the in-hand item, committed lifts and drops.
- `hold.gd`: scene-free. What's banked for the crew: estimate, truth, by class.
- `salvage_field.gd`: the items in the world: each kind's model (`kinds.file`, through `KitPieces.slot_mesh`, the box if it won't load) in kit materials tinted toward the class colour, lights left alone, each on a ring of light (a `src/sight` beacon: the fairness rule). Like a door's lights, a ring reads from anywhere once you've seen it, cone or no cone; `rim.unknown_share` is what shows where you've never looked (0: nothing, so a new room is still a question).

## Does not own
- The clock, tiers, alarm, LEAVE (`src/shift`). How penalties take effect (`Operator.set_carry`, `src/player`). Who hears a drop (`StalkerPack.noise`).

## Rules
- Small: pocketed up to `pocket_limit`, no penalty. Medium: one in hand; slower, no sprint, fires with a wider cone. Heavy: two hands; slower still, no sprint, no firing. Pockets still work with your hands full.
- Lifting takes `pickup_s` and holds you. A medium drop takes `drop_s` and holds you. A heavy drop has `drop_s` 0: instant, with `drop_noise` "thud". **Resolved packet vs design:** the packet says drops are committed and also "instant and loud"; the design table says only heavy is instant. Followed the design, and it's all data.
- `value` is `base` ± `value_spread`. The HUD shows the sum of `base` with an approximate sign; the true sum goes to the run log.
- E takes the nearest item in `reach_m`, so nothing sits inside the prize's reach (test).
- Two players can't lift one item: it's reserved (`taken_by`) as the lift starts. A dropped item can be carried on by a crewmate (`tests/test_session.gd`).
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
`pocket_limit`, `value_spread`, `reach_m`, `drop_scatter_m`; `classes` {`small`, `medium`, `heavy`: `word`, `value_min`, `value_max`, `pocketed`, `speed_mult`, `can_sprint`, `can_fire`, `cone_extra_deg`, `pickup_s`, `drop_s`, `drop_noise` (a stalker `senses` kind, or ""), `size_m`, `color`, `rim_color`, `rim_radius_m`, `carry_at`}; `kinds` {name: `file`, `word`, `class`, optional `prize`, `value_min`, `value_max`, `color`, `rim_color`}; `body_tint_share` (0 the kit's own colours, 1 fully the class hue); `rim` {`energy`, `width_m`, `height_m`, `segments`, `unknown_share`}; `placements` [{`kind`, `space`, `at`}].

Tests: `tests/test_shift.gd`, `tests/test_dressing.gd`. Literal scan: `tests/test_weapons.gd`.
