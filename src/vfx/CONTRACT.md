# vfx

The effect library (T020): every effect is a recipe in `data/vfx.json`. The spec is `docs/design/gun-feel.md`. Looks and sound only: no rule reads anything here.

## Owns
- `vfx.gd`: autoload `Vfx`. Builds the whole budget at start and reuses it: particle rings, decals, casings, magazines, lights, pools, emitters.
- `particle_field.gd`: scene-free. One sheet's particles as a fixed ring of MultiMesh instance data. A spawn writes a slot; the shader does the rest, so a particle costs the CPU nothing after it's born. A full ring overwrites its oldest.
- `vfx_core.gdshaderinc`: that sum, the flipbook, the mask look-up. `vfx_add`, `vfx_blend`, `vfx_lit` shaders are its three looks; `vfx_pool.gdshader` is the acid pool.
- `decal_ring.gd`: scene-free. Decal slots: the cap, oldest-first fading.
- `brass_field.gd`: scene-free. Casings and magazines: thrown, bouncing, settling, capped.
- `surface_map.gd`: scene-free. What a round hit: kit material, surface, recipe.
- `vfx_gallery.gd`: F1 → Effects (dev only). `t020_stage.gd`, `t020_stand_*.gd`: T020's capture stands (dev only).
- `tools/t020_vfx_import.py` copies `assets/source/vfx/` to `assets/game/vfx/` and cuts the decal sheets per frame (a Decal takes one whole texture). `tools/t020_capture.sh <out-dir>` makes the shots, frame times and recording.

## Does not own
- When anything happens: `src/weapons` (`ShotTimeline`), `src/enemies`, `src/pirates` and the decks call in. Sound itself: `src/audio`; a recipe only names cues.
- The AI's hearing or sight: an effect changes neither.

## Rules
- **Everything obeys the sight mask** once a deck calls `use_mask`: one look-up at each particle's centre, seen now or not at all, so no effect shows through the dark. Decals, casings and magazines are opaque-pass surfaces, under the mask anyway. A placed light only touches its room's layer and layer 1.
- **Decals skip layer 1** (people, doors, beds): those move and a hole wouldn't. A round on a door or an upright bed leaves no hole.
- **Smoke and dust are lit** (`look: lit`) and scatter light whichever way the sprite faces, with `emit_share` as a trace outside the light. The sheet's puff fills about half its cell and thins by itself, so `size_m` is about twice what shows and `fade_power` is 0.
- **Surfaces.** Box colliders carry no material. A body says `hit_surface()`; a collider may have meta `kit_material`; a door's panel is `door_material`; a prop goes by `by_prop`; a wall by the room on its face, its family in `data/kit.json` and where on the bay the point is. So most of a cargo bay is **glass** (the reinforced family's window), not metal.
- **`plays_own_hit()`** on a body means it calls `body_hit` itself, and the rifle leaves it alone.
- **Hitches.** A hidden Decal per texture holds the engine's decal atlas steady (it rebuilds when the set changes), and `warm_pipelines` draws every sheet the frames after a deck comes up.
- `rng` is this module's own: exempt from the session's seed.

## Public API (`Vfx`)
- `play(recipe, at, normal, opts) -> bool` (opts `dir`, `scale`, `light_layers`, `quiet`), `land(target, point, normal, dir, damage) -> surface`, `body_hit(surface, hit, body_rid)`, `place_decal(spec, at, normal) -> slot`.
- `start(recipe, at, facing, opts) -> id` (0 if every emitter's busy; opts `box`, `light_layers`, `space`), `move(id, at, facing)`, `stop(id)`, `running(id)`, `running_count()`.
- `eject_casing(port, dir)`, `drop_magazine(port, dir)`, `camera_shake() -> Vector2`.
- `set_layout(layout)`, `use_mask(bind)`, `set_beam(origin, dir2, half_rad, range_m, on)`, `place_effects(entries, layout, layer_of)`, `clear_debris()` (a new ship), `clear()` (the deck's gone), `advance(delta)` (tests step it).
- Readouts: `problems()`, `pool_counts()`, `live_particles()`, `capacity()`, `visible_decals()`; fields `cfg`, `manifest`, `surfaces`, `fields`, `casings`, `magazines`, `decal_ring`, `rng`, `now`.

## Signals
`played(recipe, at)`, `decal_placed(sheet, frame, at, normal)`.

## Data keys (`data/vfx.json`)
`manifest`, `texture_dir`, `budgets` {`max_particles`, `max_decals`, `max_casings`, `max_magazines`, `max_emitters`, `max_lights`, `max_pools`}, `decals` {`fade_band`, `fade_s`, `depth_m`, `normal_fade`, `edge_fade`, `out_m`, `parallel_dot`}, `floor_y_m`, `default_cull_m`, `world_half_m`, `max_spread_deg`, `ball_share`, `flicker_beat`, `warm_frames`; `sheets` {name: `texture`, `share` (of max_particles), `look` add|blend|lit, `align_velocity`, `spin_deg_s`, `fade_power`, `fade_in`, `soft_m`, `priority`, `emit_share`, `scatter`, `alpha_from_luma`, `cone_only`}; `surfaces` {`by_material`, `by_prop`, `default_prop`, `frame_material`, `door_material`, `default_body`, `recipes`, `face_probe_m`, `prop_grow_m`, `window_min_insets`}; `shot` {`smoke`, `haze`, `wisps`, `haze_after_rounds`, `haze_every_s`, `wisps_after_rounds`, `burst_gap_s`}; `casing`, `magazine` {`mesh`, `scale`, `color`, `metallic`, `roughness`, speeds, `spin_deg_s`, `gravity_m_s2`, `restitution`, `friction`, `bounces`, `rest_y_m`, `settle_share`, `wall_reach_m`, casing `port_back_m`, magazine `drop_below_m`}; `room_draft` {space: [x, z]}; `gallery`.
`recipes` {name: `layers` [{`sheet`, `count` or `rate_per_s` or `burst_every_s`+`count`, `life_s`, `speed_m_s`, `spread_deg`, `axis` (up, else the normal), `offset_m`, `lift_m`, `box_m`, `size_m`, `size_end_m`, `gravity_m_s2`, `drag_per_s`, `bounce`, `color`, `energy`, `alpha`, `play` fit|manifest|loop|hold, `fps`}], `loop`, `life_s`, `cull_m`, `draft`, `pulse`, `crackle`, `light`, `decal`, `splat`, `pool`, `sound`, `voice`, `ricochet`, `sound_loop`, `sound_by_distance`, `room_tail`, `shake`, `scale_by_damage`}.
The decks' lists: `effects` in `data/deck.json` and `data/pirates.json` "deck": [{`recipe`, `space`, `at`, `y_m`, `facing`, `box_m`}].

Tests: `tests/test_vfx.gd`.
