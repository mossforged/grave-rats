# T011 handoff: slice polish

Branch `auto/t011-mac`. Play it: `godot --path .` (`pirate_deck`), or open `scenes/enemies/stalker_deck.tscn` for the medbay. Start with `docs/screens/T011/sheet.png`.

**My read of the gate: closer, not there.** Walls and floors moved the most: chips now sit on edges, the floors have a broken wet sheen with no splats, and the signs give the rooms a history. The biggest remaining gap is the bed, console, lockers and stalker, which are still boxes and out of scope. The paint-overs are also richer and busier in their floors and brighter mid-room than this. John decides. Nobody has played this: all checks are headless tests, stills and one flicker measurement.

**One acceptance number depends on when it's measured.** The frame-time target was met in the first window (about 7.07 / 9.1 ms) and missed later when the Mac got busier (about 7.7 / 10.4 ms). The same later runs put T010 at about 8.2 / 10.5, so T011 is faster on average but its p95 barely moves. Details below.

## What changed
1. **Decals (`tools/t011_decals.py`, `data/kit.json` `decals`, `signage`):** 34 cut-outs from A010's five sheets, with alpha. All A002-08b signs are gone. 43 placements on the main deck, on north, east and west walls and floors. Vesper Reach graphics are washed out and worn; Remnant stickers and tape are fresh and sit a layer above them, some tilted.
2. **Edges (`kit_mesh.gd`, `tools/t010_textures.py`):** large faces are cut into nine, so their rim always lands on the texture's rim, at its real size. The tile's chips crowd that rim and its corners, with rust running down from them, and the middle stays nearly clean. Faces under 0.3 m stay one quad, because cutting all of them cost 0.5 ms.
3. **Floors (`floor_wear.gd`, `kit_floor.gdshader`):** a map from the layout holds foot traffic (door to door through each room, plus thresholds) and damp (drains, grates, a few data patches). The polish and stain patches are gone from the tile. My first damp pass made hard black splats, so it's now a gradient broken up by fine grain, with no edges.
4. **Depth:** stronger normals on panels (a pressed panel line, thicker chip edges) and grates (`normal_scale` 1.6).
5. **Wet sheen: one reflection probe per room,** reflecting in floors only. Measured against SSR below.
6. **Aim cone:** masked by sight (shown where you see, 25% where you remember, not at all in the dark), and much fainter (fill alpha 0x30 to 0x04, edges 0xC0 to 0x0C). The ring under the aim point stays unmasked.
7. **Faded walls:** a faded surface now applies the mask to its own light (`fade_mask.gd`, `faded_surface.gdshader`). `src/camera` is untouched. Signs and strips on those walls follow.
8. **Side doors:** a state strip on the floor each side of the threshold, the same light as the lamp and header. Each of the five states has its own colour; bashed (`lamp_bashed`) is new.
9. **Fairness:**
   - Door lights and the ambush tell are beacons: full strength anywhere you've ever seen, outside the cone included.
   - A pirate's shot opens a wall-clipped patch of sight round them (2.6 m, 0.12 s hold, 0.4 s fade) and shows them. It goes into no memory and changes no rule. Before this, a hidden pirate's muzzle flash and tracer were hidden too, because they're children of the model.
   - Hits from out of sight draw an arc round the player: red for bullets and lunges, green for acid. This covers stalkers too.
10. **Flaky test:** `test_a_turn_in_place...` counted frames, and a slow frame runs extra physics ticks, so the turn could already be over. It now steps by hand.

## Checks
| Check | Result |
| --- | --- |
| Headless tests | **282/282, three full runs in a row**, twice, on the final code (263 old, 19 new in `tests/test_slice_polish.gd`) |
| Flaky hauler test | Also 4 of 4 passes right after the fix. My very first baseline run, before any change, was 262/263; I only kept the count, so I can't prove that failure was this test |
| Import | No errors |
| Decals from data | One quad per data entry, none dropped; all sheets are A010; no leftover A002 file; a stencil has real alpha |
| Aim cone, faded walls masked | Material, mask texture and data values checked headless; a headless run can't check pixels. Pixels: `t011_faded_walls_under_mask`, `t011_02b_play` |
| Side-door indicator | Follows all five states, on every door |
| Muzzle reveal, hit arc | From data; shooter shows, memory unchanged, fades; arc for an unseen shooter, none for a seen one |
| Collision, cover, occluders against T009 | Existing snapshot test still passes |

### Frame time, 1920x1080 on the M2 Pro (ms, average / p95)
Target, pirate deck: **under 7.5 and under 9.5.** T010's handoff: 7.81 / 9.95.

| Window | T010 | T011 pirate | T011 stalker | Target |
| --- | --- | --- | --- | --- |
| First (21:03-21:14), load average 3-4 | not run | **7.07 / 9.07, 7.07 / 9.18** | 6.23 / 8.39 | **met** |
| Second (21:30-21:47), Mac busier | 8.13-8.26 / 10.46-10.52 | 7.54-7.89 / 10.15-10.61 | 7.28 / 10.72 | **missed** |

- **The slowdown isn't the code.** An export of the earlier commit that measured 7.07 gave 7.69 and 7.84 in the second window. I found no thermal warning and no single culprit; WindowServer, Camera Hub and the Claude app were the top processes. On average T011 beat T010 by about 0.48 ms there, but p95 only by about 0.1.
- **The first-window figures predate one cleanup:** I removed room culling after them. With culling already disabled it measured 7.09 / 9.19, the same within noise, but the final code itself was only measured in the second window.
- **What would settle it:** alternate T010 and T011 on a quiet Mac, with `CAPTURE_ONLY=none tools/capture.sh`.

**Cost of each thing today** (first window, full build minus the off-switch run):

| | Fog | Practicals | SSAO | Glow | Probes | Kit only |
| --- | --- | --- | --- | --- | --- | --- |
| Pirate | 0.34 | 0.88 | 0.66 | 0.36 | 0.46 | 4.57 total |
| Stalker | 0.10 | 0.51 | 0.64 | 0.36 | 0.43 | 4.22 total |

**Sheen, measured both ways:** probes 0.46 ms on the pirate deck, SSR 0.91 (0.43 and 0.71 on the stalker deck). Picked probes. Before restricting them to floors, they cost about 0.8.

**What each lever won** (pirate deck, putting just that one back to T010's value):

| Lever | Avg | p95 |
| --- | --- | --- |
| MSAA 4x to 2x | 1.17 | 1.41 |
| Practical ranges 8 and 6 m to 6 and 4.5 m | 0.56 | 0.94 |
| No shadowed practicals (was 2, 1 on this deck) | 0.45 | 0.87 |
| SSAO low to very low, 1 blur pass | 0.15 | 0.27 |
| Fog 48x48x32 to 32x32x24 | 0.10 | 0.22 |
| Glow 3 levels to 2 | 0.08 | 0.17 |

**Tried and dropped:**
- Turning off lamps in rooms nobody has seen: no gain (7.07 against 7.09), so I took the code out. T010's per-room light layers stay.
- Pirate flashlight shadows off: no gain in a direct comparison (7.76 against 7.67-7.73), so they stay on.
- Fewer practicals and a smaller SSAO radius: about 0.1 each, within noise, and not worth the look.

### Flicker (`tools/t008_flicker.gd`, 60 frames, twinkle % of screen)
| | T008 grey box | T010 (run now) | T011 |
| --- | --- | --- | --- |
| Standing still | not compared | 0.0003 | **0.0003** |
| Turning at 10°/s | 0.0344 | 0.0920 | **0.1193** |

T011 twinkles about 30% more than T010 when turning, and about 3.5 times the grey box. It isn't the fog (0.156 with fog off), the beam or the probes (unchanged without them). My guess is the stronger texture detail under the moving light. It's a number, not a judgement: T010 never measured this, and only eyes can say whether it reads as flicker.

## Screenshots (`docs/screens/T011/`)
`sheet.png` has A006 | T010 | T011 | T011 in play for the four frames, decals in each room, side and front doors in five states, a hit from out of sight, faded walls under the mask, the tell and the frame-time table. Rebuild with `tools/t011_sheet.py`. The numbers are in `frame_times.json`. The hit shot's camera is re-framed on the round landing so shooter and player both show; at the normal camera a shooter that far behind can be off screen, and then only the arc and the beam tell you.

## Calls I made, for John or the lead to overrule
- **MSAA 4x to 2x (`project.godot`) is the biggest single win, and the packet didn't list it.** Without it the pirate deck is 8.24 / 10.48. Thin lights and wall tops have rougher edges at 2x. If John objects, the target needs another 1 ms from somewhere.
- **Rooms are dimmer mid-floor**, because of the shorter light ranges. This may help "fear the corner", but the paint-overs are brighter there.
- **No practical casts a shadow now.** Props get contact shading from SSAO and shadows from flashlights only.
- **The ambush panel now has a tell,** which it never had: a dim warm hairline along its foot, once you've seen that wall. T010 deliberately had nothing give it away, but the packet asks for one. To soften it, lower `ambush.tell.energy` in `data/enemies.json`.
- **A door you've never seen shows no light.** To change that, raise `door_look.floor_strip.unknown_share`.
- **The ring under the aim point stays unmasked,** or you couldn't aim into the dark. It's the one floor drawing that still shows over unknown space.
- **Hit arcs show only for unseen attackers** (`hit_direction.only_out_of_sight`).
- **Broken doors' lamp** went from `3a2a20` to `6a6058` so it shows at all, and `lamp_energy` from 2.5 to 1.1, because bright red and green washed out to pink and mint.

## Edits outside the named modules, all small
- `src/study/deck_builder.gd`: decals on any wall, layers and tilt, the floor material and layer.
- `src/player/aim_visuals.gd`, `data/player.json`: `use_mask`, the toned-down colours.
- `src/hud/`: `hit_direction.gd` and drawing it. `src/pirates/`: signal `fired`, the capture shot, `muzzle_reveal`. `src/enemies/`: the tell, hit arcs, capture shots.
- `tests/test_kit.gd`: reads `state_color()` where it read the lamp material's emission. `project.godot`: MSAA. `.gitignore`: `__pycache__/`.

## Not checked
Motion and feel of all of it: walking, cut-away fade in motion, flash timing, and whether arcs and door strips are too loud in a real fight. The T006/T007 bots (no rule changed; `seen` drives only visibility, and captures). Any resolution above 1080p. `scale_deck` and `weight_deck` look. The study's other fairness items (motion tracker, audio twins, salvage, which doesn't exist yet).

## For John's eye
Sheet first, then play medbay to junction to cargo. Does it match or beat the concept? Are 2x MSAA edges acceptable? Does turning shimmer on the floors? Is the ambush tell too much or too little? Do door strips read in a hurry, and are they too bright against the dark?
