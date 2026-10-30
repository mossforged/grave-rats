# cover

Cover with height (T005): what stops a shot in 3D, the bed you tip over, the HUD's shield marks.

## Owns
- `cover_field.gd`: scene-free pieces (footprint + class) and the straight 3D trace against them. The torso height of a stance.
- `tip_state.gd`: scene-free rules of a tipping bed: upright (no cover), tipping (a commitment, still no cover), overturned (low).
- `tip_bed.gd`: one bed: mesh hinged on its far long edge, collision, its piece in the field.
- `shot_tracer.gd`: `Rifle.shot_tracer`. Walls and doors through physics; bodies on the plan line, aimed at at their torso height; cover in between stops the round.
- `protection_mark.gd`: one shield per shooter.

## Does not own
- Who is shooting (the marks are told, by `src/enemies`), the E key (the scene), sight (`src/sight`; tall cover is already an occluder there).

## Rules
- Low cover stands `low_height_m` whatever its mesh is, so the rule is one number: a 0.8 m crate, a 1.1 m console and a 1.2 m crate all count as 0.9. Tall has no top.
- It's geometry, not "near a box": low cover protects a crouched body only when it is close enough to the body along the line. With the muzzle at 1.2 m and a crouched torso at 0.8 m that is the last quarter of the line.
- Firing from a crouch braces you: torso at `braced_torso_m` for `brace_hold_s` after each shot, the body visibly rising.
- A shield is solid when cover stops what that shooter would throw right now (its arc, so it goes hollow when one gets close enough to lob over), and a hollow red "OPEN" otherwise.

## Public API
- `CoverField.new(cfg)`: `set_piece(id, rect, kind)` ("none" removes), `kind_of(id)`, `height_of(kind)`, `segment_hit(a, b) -> {} or {t, point, id, kind}`, `line_blocked(a, b)`, `torso_height(crouch_amount, braced)`. Constants `NONE`, `LOW`, `TALL`.
- `TipState.new(cfg, overturned := false, fall_side := 1.0)`: `start(from_side) -> bool`, `step(delta) -> bool` (true on landing), `cover_class()`, `footprint(rect, thickness)`; fields `state`, `progress`, `side`.
- `TipBed`: `setup(spec, rect, cover_field, cfg)`, `reset()`, `tick(delta)`, `try_tip(p) -> bool`, `can_tip()`, `distance_to_point(p)`, `footprint()`; fields `tip`, `upright_rect`.
- `ShotTracer.new(cover, world)`: `trace(origin, dir, length)`; fields `bodies`, `exclude`. A body has `shot_disc() -> {} or {center: Vector2, radius, height}` and `take_hit(hit)`.
- `ProtectionMark`: `set_lines(array of bool)`, `protected_count()`, `lines`.

## Signals
`TipBed.landed(bed)`, `TipBed.footprint_changed(bed)`.

## Data keys (`data/cover.json`)
`low_height_m`, `standing_torso_m`, `crouched_torso_m`, `braced_torso_m`, `brace_hold_s`, `brace_crouch_shown`, `brace_rate_per_s`; `bed` {`tip_s`, `reach_m`, `lying_height_m`, `mattress_m`, `color`, `mattress_color`, `prompt`, `prompt_height_m`, `prompt_pixel_size`, `prompt_font_size`, `prompt_color`}; `mark` {`layer`, `size_px`, `word_gap_px`, `gap_px`, `from_bottom_px`, `line_px`, `protected_color`, `exposed_color`, `word_protected`, `word_exposed`, `font_size`}. Props' classes are in `data/deck.json`.

Tests: `tests/test_cover.gd`.
