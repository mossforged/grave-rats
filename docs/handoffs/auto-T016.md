# T016 handoff: bed, medbay dressing, salvage models, live anti-aliasing toggle

Branch `auto/t016-mac`. Look at `docs/screens/T016/sheet.png` first, then `aa_sheet.png`.

All packet items are in. **Tests 410/410** (383 old, 27 new), and the project imports with no errors. John still has to judge the look and pick the AA mode by eye; the default stays MSAA 2x.

## What changed
- **Bed:** the `bed` slot wears `bed.glb`, on deck and as the `TipBed` mesh. Collision, cover and `tip_s` are unchanged.
- **Dressing:** a new `dressing` list in `data/deck.json`, read by `src/kit/dressing.gd`. In the medbay: lamp at the foot of bed 1, IV by the foot of bed 2, trolley south of the cabinets, `med_station` on the north wall at `mount_y_m` 1.0.
- **Gurney:** low cover, a normal `props` entry in the medbay's north-east corner, so collision, nav and cover need no new code.
- **Salvage:** each kind has `file` in `data/salvage.json`. Models wear kit materials by slot name, including `brass`, on the floor and in hand. Rims are untouched.
- **AA:** F1 → Display has the four modes, live frame time beside them, and saves to `data/display.json` on pick. Godot 4.7 offers both SMAA and FXAA, so the modes are as the packet lists.
- **Tools:** `scenes/dev/t016_stand.tscn` (capture stands), `tools/t016_aa_bench.py`, `tools/t016_sheet.py`, `tools/t016_bot_trace.gd`.

## Where I departed from the packet, or it was wrong
1. **The tip pose changed.** The packet says tipping already turns the plated underside away from the player. It didn't: T005's hinge left the mattress facing away and the plate facing the player. I changed the motion so the plate faces away, as acceptance asks. The far edge now rears up and the bed rides over, landing in the same footprint in the same time. **Nobody has seen it move at speed.** The mid-tip frame looks fine; the slide is about 1.65 m in 0.8 s. To undo it, restore `_apply_pose` in `src/cover/tip_bed.gd`.
2. **Bed and gurney files are long in Z.** The slot code assumed width along X and would have rejected them, so `_fitted_slot` and `prop_yaw` now handle both.
3. **`med_station`'s origin isn't at its back,** as the catalogue implies (z runs -0.11 to 0.12). Placement uses the mesh bounds, so the back sits on the wall.
4. **All clutter has no collision** (the packet allows this). Small bodies would stop rounds and catch stalkers unless the nav knew about them. So you can walk through the trolley. Parked.
5. **The lamp isn't literally over a bed.** Its head is directly above its base, and the sides of a bed are its tip landing zones. At the foot end, the steep camera makes the head appear over the bed.
6. **The salvage body tint is my addition,** to keep the colour code on the body: `body_tint_share` 0.6, lights left alone. It's there because a carried item has no rim. At 0 you get plain kit materials.

## Checks
| Check | Result |
| --- | --- |
| Headless tests | 410/410 |
| Import | No errors |
| Every slot and salvage kind loads its file | Pass (12 slot files, 9 kinds) |
| Clutter off doors, props, low cover's long sides, bed landings on both sides | Pass |
| Dressing off spawns, patrol points, salvage, targets | Pass, by stalker radius 0.55 m |
| Dressing off the T012 bots' routes | Pass, half a nav cell (0.25 m) from planned nearest-first routes, both bots |
| Plated face on the shield side | Pass, both falls and both bed directions; lands in the unchanged footprint, never under the floor |
| AA modes switch and save | Pass, saved to a temp folder in the test; the live switch also ran on the real GPU in captures |
| T009 snapshot | Fixture not edited. The test leaves out the gurney, the one deliberate addition |

Tests I edited: `test_the_bed_stays_the_box` became `test_a_file_that_wont_fit_is_the_box`; the slot count went from 6 to 12; the facing test now knows files long in Z. The density test now requires all three of a triangle's normals to be axis-facing, because the lamp's smooth head tripped it.

### Bots on the real deck (12 seeds)
| | Greedy survived | Greedy banked | Cautious survived | Cautious banked |
| --- | --- | --- | --- | --- |
| T015, ignores tells | 1 | 160 | 12 | 1,319 |
| T016, ignores tells | 2 | 372 | **11** | 1,206 |
| T015, reads the ring | 1 | 101 | 12 | 1,204 |
| T016, reads the ring | 1 | 101 | 12 | 1,282 |

The closest any bot's centre came to a piece: lamp 0.70 m, the others over 1.5 m, so none got in the way. **The numbers did shift, and a repeat run gave identical results, so this is the branch and not run noise.** Cautious lost one tell-ignoring shift to a lunge. My guess, not tested, is that the gurney adds four stalk spots beside cover, which changes where stalkers go in a seed. I don't think it's a balance change, but I didn't run the deck without the gurney to prove it.

### AA cost (ms, average / p95)
1920×953 (this display's limit), M2 Pro, vsync off, three alternating rounds of 15 s, load average about 4.5, so not a quiet Mac. Round-to-round spread on averages was 0.4 ms or less. Raw runs: `docs/screens/T016/frame_times.json`.

| Mode | `pirate_deck` | `stalker_deck` | `shift_deck` (3 stalkers, CUSTODIAN awake) |
| --- | --- | --- | --- |
| MSAA 2x | 6.16 / 8.08 | 5.82 / 7.90 | 6.84 / 9.90 |
| MSAA 4x | 7.14 / 9.15 | 6.64 / 8.88 | 7.62 / 11.01 |
| MSAA 2x + SMAA | 6.46 / 8.42 | 6.10 / 8.40 | 7.16 / 10.28 |
| MSAA 2x + FXAA | 6.29 / 8.23 | 5.98 / 8.16 | 6.88 / 9.89 |

So 4x costs about 0.8 to 1.0 ms, SMAA about 0.3, FXAA 0.15 or less. 4x meets T011's pirate target (under 7.5 / under 9.5) here, but T011's misses were measured at a higher resolution, so don't read that as 4x now fitting.

I have no clean before/after for the props: T015's `shift_deck` number (6.88 / 10.15) was at 1920×1080.

## Screenshots (`docs/screens/T016/`)
`sheet.png` has every frame; `aa_sheet.png` has the crops with frame times. To reproduce: `tools/capture.sh scenes/dev/t016_stand.tscn docs/screens/T016 2`, then `python3 tools/t016_sheet.py`.

## Needs John's eye
1. **Pick the AA mode** in play (F1 → Display). In the crops, FXAA visibly softens signs and text; SMAA and 4x clean edges without that. My pick for the shift deck would be 2x + SMAA, as the cheap one that doesn't blur, but the crops are stills and shimmer when turning is what T011 flagged, and I measured none.
2. **The wall top changes between identical shots, whatever the AA mode.** The pale band and hazard stripes on the wall cap came and went between two runs of the same stand, same mode, world frozen. That band differed by anywhere from 0.28 to 13.9 grey levels. Fog, glow and sheen off didn't stop it; SSAO off or practicals off came lower, on one pair each, which proves nothing. **Cause not found, and I didn't check whether it predates T016.** Judge AA on the light strip and door edges, not that band; `aa_sheet.png` includes a repeat of 2x to show it. If you see it flicker in play, it deserves its own task.
3. **The overturned bed by the door is now hard to see.** It's dark steel and dark rubber in a dim corner of the room, where the old box was pale. From the steep camera you mostly see its top edge, so the plate rarely shows (`t016_bed_plate_closeup` is a non-game camera). Low cover you can't see is a gameplay problem. Levers: lighter material in the file's slots, or a practical light nearby.
4. **Does the tip motion look right?** See item 1 above.
5. **Salvage tint:** the pod reads quite red and the medium items brown-gold. Is 0.6 right, or too painted?
6. **Carried items** are in the shots but dark, since that stand is in the dim junction. The test confirms the same mesh is used; the look isn't really shown.

## Edits outside the named modules
- `src/study/deck_builder.gd`: two lines to add the dressing node; `src/study/CONTRACT.md`: the data key.
- `src/debug/capture.gd`: one line reporting screen-space AA.
- `data/cover.json`: removed the bed's `color`, `mattress_m`, `mattress_color`, now unused.

## Not checked
Real play or motion; a quiet-Mac frame time; 1080p or above; flicker (`tools/t008_flicker.gd` not rerun); the T014 session bots; room scales other than 0.85 for dressing positions (the fractions would move, and only 0.85 is tested).

The pirate deck has no medbay, so it gets no dressing and no gurney.
