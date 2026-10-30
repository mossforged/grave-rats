# sight

Pillar 2, "Know the room, fear the corner" (T004): line of sight, the three states, the mask, the flashlight.

## Owns
- `visibility.gd`: scene-free line of sight on the floor plane. Occluder footprints become outward edges; `polygon()` casts rays at the circle, the wedge and both sides of every corner in reach.
- `sight_grid.gd`: scene-free memory, cells of `memory.cell_m`, each UNKNOWN, REMEMBERED or VISIBLE. **Cells, not rooms:** a sight polygon cuts rooms, and the half you haven't seen is the corner you fear.
- `sight_system.gd`: the Godot adapter. Occluders from the layout and the group, one update per frame, hides targets, emits `sight_updated`.
- `sight_target.gd`: child node of any entity that must hide unless seen (sets the parent's `visible`).
- `sight_mask.gd`, `sight_mask.gdshader`: two deck-wide SubViewports (visible, cleared each frame, 4x MSAA; memory, never cleared, no MSAA) and a fullscreen quad that looks up each pixel's world XZ from depth. Lighting stays real. Drawn first among the transparents (`RENDER_PRIORITY_MIN`), so beam, FX, aim drawings and prompts draw after it, unmasked.
- `flashlight.gd`, `beam.gdshader`, `mote.gdshader`: shadowed `SpotLight3D` at the muzzle, a beam sheet cut to the sight polygon, dust motes that show only inside the wedge and the visible mask.
- `sight_debug.gd`: F2 view.
- `sight_deck.gd`: root of `scenes/sight/sight_deck.tscn`. Extends `src/player/weight_deck.gd`, adding all of the above plus `src/doors`, with darker lighting.

## Does not own
- Doors (`src/doors`), deck geometry (`src/study`), the operator (`src/player`), enemies' own sight (next packet).

## Rules worth knowing
- Walls block sight at their face; the mask spreads sight by `mask.dilate_m` so wall tops and faces show. It must stay under half a wall's thickness minus half a panel's, or sight spills past a door (0.22 m against 0.5 m walls and a 0.2 m panel).
- Props at least `tall_prop_min_m` high block sight and are shown whole once a ray stops on them. Lower ones don't block. Stance doesn't change this yet (cover is a later packet).
- The grid is the rules' truth and updates at `memory.update_hz`; the mask's memory texture is painted from the same polygons every frame, so its edge is smoother than the cells.
- The sight wedge starts at the eye, the light at the muzzle. `Flashlight.spot_angle_deg()` makes them equally wide at full range; nearer in, the wedge is up to `muzzle_ahead_m × tan(half angle)` wider each side.

## Public API
- `Visibility.new(cfg)`: `set_static(rects)`, `set_dynamic(rects)`, `polygon(eye, aim_yaw, light_on) -> PackedVector2Array`, `can_see(eye, aim_yaw, light_on, p)`, `blocked(a, b)`, `cone(light_on)`, `reach(dir_yaw, aim_yaw, cone)`, `edge_count()`; field `hit_dynamic`; static `yaw_dir2(yaw)`. Points are world XZ in `Vector2`; yaw matches `OperatorModel`.
- `SightGrid.new(bounds, cell_m)`: `update(polygon, rects)`, `state_at(p)`, `count(state)`, `clear()`, `boundary(state)`; enum `UNKNOWN`, `REMEMBERED`, `VISIBLE`.
- `SightSystem`: `setup(layout)`, `refresh_occluders()`, `update_sight(from, yaw, light, delta, force_memory)`, `forget()`; fields `visibility`, `grid`, `polygon`, `reveal`, `bounds`, `eye`, `aim_yaw`, `light_on`, `cfg`.
- `SightTarget`: `seen`, `set_seen(bool)`, `floor_position()`.
- `Flashlight`: `setup(cfg)`, `set_on(bool)`, `toggle()`, `on`, `spot`, `follow(muzzle, yaw)`, `draw_beam(polygon, eye, yaw, muzzle)`, `set_mask(texture, bounds)`, `apply_cfg()`, `spot_angle_deg()`.
- `SightMask`: `setup(system)`, `apply_cfg()`, `visible_texture()`.
- Occluder contract: any node in group `sight_occluder` with `sight_rect() -> Rect2` and `blocks_sight() -> bool`. Call `refresh_occluders()` after adding one.
- Scene keys: F flashlight, E door, F2 sight debug, plus everything in `weight_deck`. Env `SIGHT_FLASHLIGHT=on|off` fixes the light for a capture. A respawn forgets the deck.

## Signals
`SightSystem.sight_updated(polygon, reveal)`, `forgotten`; `SightTarget.seen_changed(now_seen)`.

## Data keys (`data/sight.json`)
`tall_prop_min_m`, `awareness_radius_m`, `cone_on` / `cone_off` {`range_m`, `half_angle_deg`}, `arc_step_deg`, `edge_step_deg`, `target_radius_m`; `memory` {`cell_m`, `update_hz`}; `mask` {`px_per_m`, `dilate_m`, `edge_low`, `edge_high`, `remembered_brightness`, `remembered_saturation`, `remembered_tint`, `unknown_brightness`, `unknown_saturation`, `bounds_margin_m`}; `flashlight` {`start_on`, `color`, `energy`, `attenuation`, `angle_attenuation`, `pitch_deg`, `muzzle_ahead_m`, `shadows`, `shadow_blur`}; `beam` {`color`, `strength`, `start_height_m`, `end_height_m`, `fade_power`}; `motes` {`count`, `lifetime_s`, `box_half_m`, `height_m`, `size_m`, `drift_m_s`, `spread_deg`, `color`, `strength`}; `lighting` {overrides of `data/deck.json` "lighting" in this scene}; `debug` {`polygon_color`, `visible_color`, `remembered_color`, `unknown_color`, `floor_y_m`, `outline_hz`}; `help` {`text`, `font_size`, `margin_px`, `from_bottom_px`}.

Tests: `tests/test_sight.gd`. CPU cost: `tools/t004_sight_bench.gd`.
