# T020: gun feel and environment effects (auto, code)

Branch `auto/t020-mac`. **Nobody has heard any of this, me included, and nobody has fired it by hand.** I read every look below from frozen screenshots. Whether the rifle feels heavy and real is John's call.

## What changed
- **`src/vfx/` (new), autoload `Vfx`:** recipes in `data/vfx.json`, 16 of them. Everything is built at start and reused. Particles are fixed rings on MultiMeshes: a spawn writes one slot and the shader works out the rest, which is why it's so cheap. Flipbooks and blend modes come from the manifest. Decals are real projected `Decal` nodes.
- **`src/weapons/shot_timeline.gd` (new):** every layer of a shot. `rifle_fx.gd` now flashes from the sheet (side cone plus front star, at most 2 frames). The old orange impact quad is gone, since it put sparks on flesh.
- **The shot, sections 1–3:** muzzle smoke, capped haze from round 6, 1.5 s of barrel wisps after 10+ rounds, casings with 1–2 bounces (cap 60), magazine drops (cap 10), impacts by surface, ichor on what's behind a stalker, a floor splat for a pirate, chewed cover scaled by damage, the arm kick.
- **The sound, section 4:** 88 placeholder files (was 44), all from T017's generator. Mechanical, 5 body variants round-robin, tail by room, thump, last five rounds, dry click and tail, tinks and clatter by surface at the moment they land, impacts, ricochet, ambience duck, 8 voices per gun. Range and walls go through three filter buses that follow the SFX slider. `rifle_shot` and `rifle_casing` are gone.
- **Pirates now fire through the same timeline and bank.** Their private sound is gone, along with `src/enemies/placeholder_sound.gd` and `sound` in `data/pirates.json`.
- **Environment:** `effects` lists in `data/deck.json` and `data/pirates.json`: one sparking console, one plume, one steam jet, dust motes per room. Fire, acid pool and explosion are gallery-only.
- **Gallery:** F1 → Effects. Pick a recipe; P spawns it at the cursor; O stands a steel, hull, clinical and glass wall in front of you and fires on each; also a row of every environment effect, and Clear.
- **Outside the packet's module list, small and needed:** `weight_deck` and `sight_deck` (wiring, shake), `spine_twist`, `hauler_anim`, `operator_anim`, `operator` (arm kick), `tuning_panel` (the section), `pirate_deck` (its effects list), `project.godot` (the autoload), one line each of `tests/test_audio.gd` (renamed cues) and `tests/test_session.gd` (RNG exemption for `vfx.gd`).

## Checks
- **Import:** exits 0, no errors.
- **Headless tests:** 540 passed, 0 failed, 0 load errors (492 before; `tests/test_vfx.gd` is new, 48). The packet's list, all held by tests:
  - every recipe loads, every texture exists;
  - pools don't grow: same counts and nodes after 500 more shots. The engine-wide object count may differ by up to 2, a slack I allowed because it rose by 1 once;
  - caps hold after 500 shots: particles, 96 decals, 60 casings, 10 magazines;
  - every kit material maps to an impact, and metal alone throws sparks;
  - 1000 draws with no body variant twice running, also checked on the real rifle;
  - last-rounds layer on rounds 26–30 exactly, on the real magazine.
- **Frame time, 1920x953, Apple M2 Pro, 2x MSAA, vsync off, one run each.** The mag dump is three 30-round mags into a metal wall from 2.6 m. Effects means the deck's list plus the gallery row. **The AI is stopped in all of these**, so it's the effects' cost, not a fight's.

| Window (ms avg / p95 / p99 / max) | Shift deck | Pirate deck |
|---|---|---|
| Idle (deck's effects running) | 5.04 / 5.48 / 5.74 / 15.6 | 4.23 / 4.73 / 5.16 / 13.9 |
| Mag dump | 5.50 / 6.25 / 6.64 / 22.3 | 4.59 / 5.29 / 5.66 / 14.6 |
| Every environment effect | 5.68 / 6.24 / 6.66 / 18.6 | 4.58 / 5.02 / 5.22 / 17.9 |

Peak particles were about 200–230 of 1000. The dump adds about 0.4 ms. The 22.3 ms max is a single frame I didn't trace. Lit smoke overdraw close to the camera is the likeliest cost to grow, and I didn't measure a plume filling the screen. There's no number for the deck without T020 from the same run: T017's 6.65 / 9.65 and this run's capture window (6.12 / 6.64) are different scenes of activity.
- **Levels:** the recording peaks at -1.0 dBFS, RMS -20.2. **That's the limiter's ceiling, so a mag dump is touching it**, which T017's mix didn't. Taking the body down 3 dB and the thump 4 dB left the peak where it was, and I didn't find out which layers stack up.

## Not checked
- Anything by ear: layers, tails, muffling, the duck, how any of it sits together. Tests prove cues fire on the right bus, not that they sound right.
- The filters on someone else's gun were only exercised by rule tests, with no recording of a pirate firing from behind a wall. A second player's shots go the same way, unheard.
- The panel's buttons were never clicked; tests call what they call, and P directly.
- The screenshots ran with the AI stopped; pirates firing with the new timeline ran only in headless tests.
- The arm kick: tested as a number falling back, never seen moving. The recording may show it.
- A trial merge with `auto/t019-mac`: see the end.

## Calls I made (each is a data change if wrong)
- **Most of a cargo wall is glass.** The packet says surface comes from the kit material, and the reinforced family's window fills most of each bay. So the hold's walls chip rather than spark, except on frames and posts. If you want sparks there: `surfaces.by_material.glass`, or the wall rule in `surface_map.gd`.
- **No holes on doors or beds.** Decals skip layer 1, because those move. A round there still plays its impact.
- **Effects are only visible where you see now**, not in remembered rooms, so a fire doesn't give itself away through the fog. You can hear loops through walls within their range (9–13 m), filter-free, as with T017's stalkers. First lever: `max_distance_m`.
- **Smoke is lit by the scene**, so it's nearly gone outside light. That's on purpose in a dark ship ("every effect at full brightness" is on the spec's avoid list).
- **A casing checks one wall, when thrown, and the floor or a prop's top where it should land.** It can't bounce off a second wall, and can pass through a prop it wasn't aimed at.
- **The last-rounds layer and the thump are the local player's only.**
- **The old flashlight motes stay** (T004, `data/sight.json`), so `dust_motes` adds to them. To use only the new ones, set `motes.strength` to 0.
- **Tracers and the flash still ignore the sight mask,** as they did. Parked.
- **Explosions and fire look thin to me.** The fireball reads dark red by about 0.4 s and the flames are small from this camera. Their levers are `recipes.explosion`, `recipes.fire`.

## Made
`docs/screens/T020/`: `sheet.jpg` (start here), `mag_dump.mp4` (8 s, picture and sound), `t020_burst_metal`, `_panel`, `_glass`, `t020_stalker_shot`, `t020_brass_and_magazine`, `t020_sequence_walls`, one `t020_gallery_*` per environment effect, `frametime_*.json`, `mag_dump_levels.txt`; `pirate/` the same with no panel wall. Remake with `tools/t020_capture.sh docs/screens/T020`. `sheet.jpg` was made by a one-off crop, not by that script.

## For John's eye and ear
`godot --path .`, go somewhere dark, hold the trigger for a whole magazine, reload, look at your feet. Then F1 → Effects.
- Does the rifle feel heavy and real in a dark room?
- Do you hear the magazine running out before the click? Does the hold boom and the corridor slap?
- Can you read the holes from this camera (`impact_*.decal.size_m`), and the casings (`casing.scale`)? The magazine is a grey sliver at this distance.
- Does the muzzle light wash out the wall you're shooting? It's T003's number, unchanged (`fx.flash_light_energy`).
