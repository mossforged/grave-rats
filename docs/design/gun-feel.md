# Gun feel: everything one shot needs (lead, 2026-10-31)

John: "make sure that we have everything we need to make the firing of the guns seem as realistic and accurate as possible in terms of effects and sounds."

A shot reads as real when many small layers land in the same frame, with variety so no two shots match. Below is the full list in order of what the player notices. **Have** = in the game now (T003/T011, `data/weapons.json` "fx"); everything else is T020 (visual) or the audio bank (T017 placeholders, then real files). Every number lives in `data/weapons.json` or `data/vfx.json`.

## 1. The muzzle (frame 0)
| Layer | Detail | State |
| --- | --- | --- |
| Muzzle light | Warm burst lighting the walls and the operator for 1 frame, then a 50 ms decay. In a dark ship this is the biggest single realism cue. | **have** |
| Flash sprite | `muzzle_flash.png`: a random side-cone frame along the barrel plus a small front star at the tip; random roll and ±20% scale; 1 to 2 frames on screen. | have a quad; swap in the sheet |
| Muzzle smoke | 1 `smoke_puff` per shot, small and rising. Sustained fire builds a light haze around the shooter, capped. After a burst of 10 or more rounds, barrel wisps for 1.5 s. | new |
| Recoil | Weapon/arm kick (additive anim), camera kick, cone bloom. | **have** (cone, camera); arm kick new |
| Tracer | Hot streak to the hit point. `tracer_every` in data (1 = every shot; real rifles are 1 in 4 or 5). Keep 1 until John says otherwise: it shows where you're shooting. | **have** |

## 2. The brass (frames 0-60)
- **Casing ejection:** `shell_casing.glb` thrown right and up from the ejection port with random speed and spin. It falls, bounces once or twice and settles. It glints in the flashlight and stays up to `casing_cap` (start at 60, oldest removed). Scale it ×1.5–2 in data so it reads from the steep camera. No collision with players or AI.
- **Casing tinks:** one per bounce, picked by surface (deck plate bright, grate rattly), quiet, never the same sample twice in a row.
- **Reload:** the old magazine drops (`spent_magazine.glb`), clatters by surface, and stays up to a cap. A full reload (mag still holding rounds) and an empty one differ: the empty one adds the charging-handle pull.

## 3. The hit (same frame; hitscan)
| Surface | Visual | Sound |
| --- | --- | --- |
| Bare metal (steel, hull) | 8–14 `spark_streak` particles: gravity, one bounce, short life; a `glow_dot` flash; a metal bullet hole (`decal_bullet_holes` row 0) | ping or thunk; ricochet whine on 15% of shallow hits |
| Clinical panels | `impact_dust` tinted beige; 2–4 paint-chip flecks; a panel hole (row 1) | crack, plastic snap |
| Glass | small white chips; holes only if the glass is a mesh panel | tick or crack |
| Stalker | ichor spray (`glow_dot`/`smoke_puff` tinted ichor, fast, gravity); an ichor splat decal on whatever is 1.5 m behind the hit (ray continued); the existing hit flash and flinch | wet impact, the stalker's pain chirp (rate-limited) |
| Rival pirate | the same spray in red-brown, smaller; a floor splat | flesh impact; grunt (rate-limited) |
| Cover being chewed (T005) | extra dust and sparks scaled by damage taken | heavier impact layer |

Decals are pooled (`decal_cap`, start 96). Oldest fade first. They project onto floor, walls and props.

## 4. The sound of one shot (layered, per shot)
1. **Mechanical:** the action's clack, close to the gun. Only the shooter hears it loudly.
2. **Body:** the punch of the shot. 4–6 variants in round-robin, pitch ±3%, volume ±1.5 dB, never the same one twice in a row.
3. **Tail:** the room answering. Pick it by the room the shooter is in: a corridor gets a short slap, a medbay a medium room, a cargo hold a long boomy tail. Data: `room_tail` per space.
4. **Low thump:** the local player's own gun only (felt more than heard).
5. **Last rounds:** for the final 5 rounds in the magazine, a slightly brighter mechanical layer, so you hear the magazine running out before the click. Real guns don't do this; good games do.
6. **Dry fire:** a hard click and a short "nothing" tail.

**Distance and walls:** other players' and pirates' shots are low-pass filtered with range and carry more tail. With no line of sight they are muffled (occlusion low-pass). This matters for the information pillar: you should hear a firefight two rooms away as a firefight two rooms away.

**Mix:** cap voices per gun at 8. Heavy fire ducks the ambience bus by 3 dB, recovering over 0.5 s. A limiter on the master bus. The AI's noise rings (T008) stay separate from what players hear.

## 5. Environment effects (same system, used by the decks)
- **Sparking console:** an `electric_arc` flicker, spark bursts at random intervals, a flickering glow light and a buzz loop with crackle one-shots.
- **Smoke plume:** a stream of dark `smoke_puff` rising and drifting with a per-room `draft` vector. It thins sight a little if deck data says so (later).
- **Steam jet:** white, fast, sideways from a broken pipe, with a hiss loop. It pulses.
- **Fire:** 2–3 layered `fire_loop`s, embers (`glow_dot` rising), a warm flickering light and smoke above, with a crackle loop.
- **Acid or slime pool:** a puddle decal mask with `liquid_noise` scrolled in a shader (emissive edge, slow surface), `acid_bubble` particles popping at random, a faint coloured light and a sizzle loop. Visual only until a packet makes hazards.
- **Explosion:** a light flash, the `explosion` flipbook, sparks and debris, a scorch decal, and camera shake by distance. The sound is a near and far pair chosen by distance, with a tail by room.
- **Dust motes:** slow `glow_dot`s that only show inside a flashlight cone. Cheap, and it sells the dead air.

## 6. What makes it feel wrong (avoid)
- Identical shots (no variation); a flash that lasts more than 2 frames; sparks on flesh or blood on steel; decals floating off curved props (project, don't stick); casings that pass through the floor; tails that ignore the room; every effect at full brightness, which washes out the flashlight's job.
