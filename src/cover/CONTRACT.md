# cover

Cover with height (T005): what stops a shot in 3D, the bed you tip over, the state behind the HUD's shield marks. Lock-to-cover, a prototype you can switch off (T007).

## Owns
- `cover_field.gd`: scene-free pieces (footprint + class) and the straight 3D trace against them. The torso height of a stance.
- `tip_state.gd`: scene-free rules of a tipping bed: upright (no cover), tipping (a commitment, still no cover), overturned (low).
- `tip_bed.gd`: one bed: the kit's bed mesh (`KitPieces.prop`), collision, its piece in the field. The far edge rears up and the bed rides over onto `TipState.footprint`, so it lands past its far long edge with the mattress toward whoever tipped it and the plated underside out, as the shield (T016; it used to fall the other way, underside toward the player).
- `shot_tracer.gd`: `Rifle.shot_tracer`. Walls and doors through physics; bodies on the plan line, aimed at at their torso height; cover in between stops the round.
- `cover_lock.gd`: scene-free lock-to-cover: the slot, the snap, raise and lower, sliding, letting go.
- `lock_driver.gd`: lock-to-cover in a scene: takes the operator's controls while locked, the prompt, and `state_word()` for the suit OS's `LOCKED` readout. It hands them back when free, and touches nothing while free.
- `protection_mark.gd`: the cover readout's state: in cover or not, and one line per shooter. The suit OS (`src/hud`) draws them, and holds the words and sizes.

## Does not own
- Who is shooting (the marks are told, by `src/enemies`), the E key (the scene), sight (`src/sight`; tall cover is already an occluder there).

## Rules
- Low cover stands `low_height_m` whatever its mesh is, so the rule is one number: a 0.8 m crate, a 1.1 m console and a 1.2 m crate all count as 0.9. Tall has no top.
- It's geometry, not "near a box": low cover protects a crouched body only when it is close enough to the body along the line. With the muzzle at 1.2 m and a crouched torso at 0.8 m that is the last quarter of the line.
- Firing from a crouch braces you: torso at `braced_torso_m` for `brace_hold_s` after each shot, the body visibly rising.
- `IN COVER` is about where you are: crouched, within `in_cover_reach_m` of any cover (low or tall), not rising to fire. It doesn't care who's hunting, or which way they are; the shields do.
- The 1.2 m crates are tall cover since T006: they stop shots, spit and sight at any stance.
- A shield is solid when cover stops what that shooter would throw right now (its arc, so it goes hollow when one gets close enough to lob over), and a hollow red "OPEN" otherwise.

## Lock-to-cover
- Only `pirate_deck` has it. `stalker_deck` doesn't, because the stage 2 gate is still open on that deck.
- Space within `lock.reach_m` of **low** cover snaps you to the nearest clear place along that edge in `snap_s`, crouched, turning to face across it for `face_hold_s` at your normal capped rate.
- RMB aims over: up in `raise_s`, exposed from `exposed_at`, able to fire from `fire_at`. LMB also raises you and fires when up. Let go and you stay up `aim_hold_s`, then come down in `lower_s`.
- Down, you slide along the edge and stop at its end. Up, you stay put. Pushing away at `release_dot` or better, Space again, a shove of more than `break_m`, or death lets go.
- `lock.enabled` 0 (F1): the key does nothing, and crouch and braced firing run the plain T006 code.

## Public API
- `CoverLock.new(cfg)`: `enabled()`, `locked()`, `exposed()`, `can_fire()`, `spot_for(field, p, radius, is_free)`, `try_lock(field, p, radius, is_free) -> bool`, `release()`, `step(delta, wish, wants_aim) -> move`, `hold_position(p)`, `facing_point(reach)`; fields `state`, `raise`, `slot`, `normal`, `tangent`, `piece_id`.
- `LockDriver`: `setup(operator, field, cfg, is_free)`, `press() -> bool`, `tap_fire()`, `release()`, `step(delta)` (before the operator's), `show_state(alive)`, `state_word()`, `spot_here()`; fields `lock`, `scripted` {`keys`, `aim`, `fire`}, `hide_prompt`.
- `CoverField.new(cfg)`: `set_piece(id, rect, kind)` ("none" removes), `kind_of(id)`, `height_of(kind)`, `segment_hit(a, b) -> {} or {t, point, id, kind}`, `line_blocked(a, b)`, `near(p, reach)`, `low_near(p, reach) -> {} or {id, rect}`, `torso_height(crouch_amount, braced)`. Constants `NONE`, `LOW`, `TALL`.
- `TipState.new(cfg, overturned := false, fall_side := 1.0)`: `start(from_side) -> bool`, `step(delta) -> bool` (true on landing), `cover_class()`, `footprint(rect, thickness)`; fields `state`, `progress`, `side`.
- `TipBed`: `setup(spec, rect, cover_field, cfg)`, `reset()`, `tick(delta)`, `try_tip(p) -> bool`, `can_tip()`, `distance_to_point(p)`, `footprint()`; fields `tip`, `upright_rect`.
- `ShotTracer.new(cover, world)`: `trace(origin, dir, length)`; fields `bodies`, `exclude`. A body has `shot_disc() -> {} or {center: Vector2, radius, height}` and `take_hit(hit)`.
- `ProtectionMark`: `set_lines(array of bool)`, `set_in_cover(bool)`, `protected_count()`, `lines`, `in_cover`.

## Signals
`TipBed.landed(bed)`, `TipBed.footprint_changed(bed)`, `ShotTracer.cover_stopped(body)`.

## Data keys (`data/cover.json`)
`low_height_m`, `standing_torso_m`, `crouched_torso_m`, `braced_torso_m`, `brace_hold_s`, `brace_crouch_shown`, `brace_rate_per_s`; `lock` {`enabled`, `reach_m`, `gap_m`, `edge_inset_m`, `search_step_m`, `snap_s`, `raise_s`, `lower_s`, `release_dot`, `break_m`, `exposed_at`, `fire_at`, `face_hold_s`, `aim_hold_s`, `prompt`, `prompt_height_m`, `prompt_pixel_size`, `prompt_font_size`, `prompt_color`}; `bed` {`tip_s`, `reach_m`, `lying_height_m`, `prompt`, `prompt_height_m`, `prompt_pixel_size`, `prompt_font_size`, `prompt_color`}; `mark` {`in_cover_reach_m`, `in_cover_min_crouch`}. Props' classes are in `data/deck.json`.

Tests: `tests/test_cover.gd`, `tests/test_pirates.gd`, `tests/test_dressing.gd`.
