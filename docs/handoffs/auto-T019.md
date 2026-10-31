# T019 handoff: corridor wall depth from the hallway set

Branch `auto/t019-mac`. Look at `docs/screens/T019/sheet.png` first (before on the left, after on the right).

The packet is done except the spark flicker, which it allowed me to park. **Tests 511/511** (492 old, 19 new), and the project imports with no errors. **Nobody has walked it**: the look, and anything in motion, is John's to judge. The shots are dark on purpose (game lighting, unbrightened).

## What changed
- **Twenty hallway files** copied to `assets/game/props/`, wearing kit materials by slot. `assets/source/` is untouched.
- **`src/kit/corridor_dressing.gd`** places the dressing by rule from `data/deck.json` `corridor_dressing`, in metres, against the deck it's on. The pirate deck needed no list of its own: 63 pieces on the shift deck, 60 on the pirate deck.
- **What goes where:**

| Corridor | Ribs (every 2.7 m, staggered) | High run | Low run | Grim pieces |
| --- | --- | --- | --- | --- |
| Junction | West and east walls | `pipe_run_high`, west | `pipe_run_low`, east | None |
| Side corridor | North and south walls | `air_duct`, south | `pipe_run_low`, north | Breached panel, hanging cables and debris on the north wall, near the mouth |

- **Doors:** jambs and a lintel fitted to the aperture on each door's corridor face.
- **Light fixtures:** all six corridor lights now have a hallway fixture instead of the plain strip (`prop` in `data/kit.json`). Lit parts take the light's colour, and a fixture goes out when its section fails, through the existing `section_lights` code.
- **Fading:** wall pieces hang on the wall pivot behind them, so they fade with the cut-away. This also removes the "north walls only" limit T016 had for this code.
- **Tools:** `scenes/dev/t019_stand.tscn` (stands), `tools/t019_bench.py`, `tools/t019_sheet.py`, and env `KIT_CORRIDORS=off`.

## Checks
| Check | Result |
| --- | --- |
| Headless tests | 511/511 |
| Import | No errors |
| Every hallway slot loads its file (20) | Pass |
| Nothing past 0.3 m from the wall below 2.0 m, read from the mesh triangles | Pass on both decks. Only `corner_pillar` and `wall_panel_breached` are exempt, as the packet says |
| Off doorways, props and cover lines | Pass on both decks |
| Off the T012 routes (half a nav cell, both bots) | Pass on the shift deck. Parts above 2.0 m don't count |
| No new collision or blockers; nav route lengths the same with and without | Pass |
| Real T012 bot run, 6 seeds each, before and after | **Identical results, every seed** (cautious 199.9 to 205.3 s, greedy 208.8 to 336.7 s) |

### Frame time (ms, average / p95)
1920×953 (this display's limit), MSAA 2x, vsync off, three alternating rounds of 15 s. Load average was 4 to 7, so not a quiet Mac. Raw runs: `docs/screens/T019/frame_times.json`.

| Deck | Before | After | Cost |
| --- | --- | --- | --- |
| `shift_deck` | 6.78 / 9.81 | 7.06 / 10.16 | +0.28 / +0.35 |
| `pirate_deck` | 6.10 / 7.98 | 6.35 / 8.34 | +0.25 / +0.36 |

Before is `KIT_CORRIDORS=off`. Those runs also keep the new fixtures, so the plain-strip swap isn't in the cost. On the shift deck, averages across rounds were 6.58 to 6.95 before and 6.99 to 7.19 after. The player stands still in these runs, so walking and cut-away fades weren't priced.

## Wall-top readability (packet item 5)
**I kept the runs at their heights and dropped none.** Every high run tops out below the 2.6 m wall top (2.50, 2.55), so from the camera's side of a wall it can't cover the top; a test holds this. Ribs, jambs and lintels end level with it, and their tops read as buttresses on the wall line.

The real problem was the wall *face*. A 0.5 m duct would hide about 1.4 m of wall below it, signs included. So on the side corridor I put the **duct on the south wall and the low pipes on the north**. The cost is that you rarely see that duct: the south wall's room face only shows through the cut-away.

## Where I departed from the packet, or it was wrong
1. **Flicker parked.** There is no T008 flicker to reuse: that task removed a beam bug. T012's flicker lives in `src/shift` and works on whole sections. The spark tip glows steadily.
2. **Jambs sit past the door posts, not against the opening,** because flush jambs would hide the door's state lamp. They are also sunk 2 cm into the wall (`sink_m`): the file is 0.319 m deep, over the limit.
3. **`conduit_tray` is unused.** It reaches 0.327 m below 2.0 m, over the limit. The packet offered three choices, so I took the other two.
4. **`corner_pillar` is really 0.45 × 0.48 m,** not 0.4 m square. Four are placed: the junction's two south corners and the side corridor's two east corners. A console and a crate rule out the junction's north corners.
5. **The grim spot moved twice.** On the junction's west wall you barely see the panel from the steep camera. Further along the side corridor, a T012 route hugs the north wall towards the door. It's now near the corridor mouth.
6. **I moved one sign:** the "ENGINEERING" plate and its arrow went from 0.13 to 0.065 along that wall, in `data/kit.json`, to make room for the panel.
7. **Debris is 5% narrower and its back sinks about 7 cm into the wall,** to clear the crate's cover line and the patrol line.
8. **Only two floor grates, both in the airlock zone.** Everywhere else the route and patrol rules squeeze them out, even though a grate is flush and walkable. Exempting grates is an easy change if John wants more.
9. **Ribs skip what's in the way,** then restart the rhythm: signs, door zones, cover lines. The side corridor's north wall, the one you see, gets only two ribs for that reason. Spacing is exactly 2.7 m wherever nothing interrupts.
10. **Doors are dressed on their corridor face only;** room faces are unchanged. Parked.
11. **Fixture changes:** vertical strips became horizontal, because the file is horizontal. Amber lights use `emergency_lamp` glowing amber, not its file's red, so the fixture matches its light. The west strip sits 0.66 m from its light to clear a jamb (`prop_at`); the light didn't move.

## Needs John's eye
1. **Does the junction look deep enough?** This is the main limit. The camera looks almost straight along the junction's side walls, so you see the tops of ribs and jambs, not their faces. North-facing walls (`door_jambs_lintel`, `grimmest`, `inner_corner`) gain far more. More wall pieces won't fix it; floor-level detail or more light there might.
2. **Much of the detail is lost in the dark,** especially in the `_play` shots. Should corridors get brighter, or is that the horror?
3. **The door jamb tops** look like heavy black slabs on the junction's east wall. Too heavy?
4. **The torn panel's plate** reads as a pale flat sheet. Does it say "something tore this", or is it just a sheet?
5. **Small lights stay on in a failed section** (valve and jamb lamps, the spark). I left them as emergency power; a dark section is slightly less dark than before.

## Edits outside the named modules
- `src/study/deck_builder.gd`: two lines to add the node; `src/study/CONTRACT.md`: the data key.
- `src/debug/t019_stand.gd`, `src/debug/CONTRACT.md`: the capture stand.
- `tests/test_kit.gd`: slot count from 12 to 32. No other existing test changed.

## Not checked
Real play or motion; a quiet Mac; 1080p or above; clipping when a player or stalker hugs a wall (the 0.3 m limit is meant to prevent it, but I only tested footprints); pirate bots, T015 shift bots and T014 session bots (no collision or nav changed, so I expect no change); room scales other than 0.85. On the pirate deck I saw one overview shot only, in passing; the stands are shift deck only.

## Screenshots (`docs/screens/T019/`)
**The "before" shots aren't the old build.** They are this branch with `KIT_CORRIDORS=off`, so they already have the new light fixtures and the moved ENGINEERING plate. They show only what the dressing adds.

`sheet.png`, plus `t019_<stand>_before.png` and `_after.png` for: `long_corridor_north`, `long_corridor_south`, `long_corridor_play`, `side_corridor`, `door_jambs_lintel`, `door_side`, `inner_corner`, `grimmest`, `grimmest_play`. To reproduce: `tools/capture.sh scenes/dev/t019_stand.tscn docs/screens/T019 2`, the same with `KIT_CORRIDORS=off`, then `python3 tools/t019_sheet.py`.
