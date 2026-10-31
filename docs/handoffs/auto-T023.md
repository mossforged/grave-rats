# T023: the biological survey vessel (auto, code)

Branch `auto/t023-mac`. Look at `docs/screens/T023/sheet.png` first, then play it: `godot --path . --ship survey`. **Nobody has played or walked this ship.** I judged the looks from stills. The default is still the current ship.

## Before you run anything
1. **Godot won't start on this Mac with sound right now.** It hangs at launch inside macOS CoreAudio (`AudioDeviceCreateIOProcID` never returns; a process sample shows it). An untouched export of `main` hangs the same way, so it isn't the game. It was still hung when I finished. Restarting the Mac or `sudo killall coreaudiod` should clear it; I didn't try either, since that's your machine's audio. To run without sound: `godot --path . --audio-driver Dummy --ship survey`.
2. **T022 isn't merged, though the packet says it needs to be.** This branch was cut from `main` without it, and I didn't pull it in. Nothing here depends on it. A trial merge of the code, before the docs below, had no conflicts. This handoff's STATUS edit may now conflict with T022's on the Stage line; take both. The combined build hasn't been tested. T022's hauler isn't in these screenshots or bot runs.

## What changed
- **Decks by file:** `Data.use_ship(file)`. `load_data("deck")` reads that file, and its `data_overrides` lie over the other data files. On the first ship nothing is merged. This lives in `src/core/data.gd`, outside the packet's modules, because every module already reads through `Data`.
- **`data/deck_survey.json`,** written by `tools/t023_make_deck.py` from A014-02: 8 spaces, 10 doors, 19 cover entries (27 props including the trolley), 10 salvage spots, 6 spawn candidates, 18 lights, the cutter and the drone patrol.
- **Scale policy:** spaces use a new `rect_m` key in final world metres, and `DeckLayout` applies no `room_scale` to them. I did **not** divide by 0.85. Nothing is scaled twice.
- **Dressing:** every room from its catalogue set, 37 prop files copied to `assets/game/props/`.
- **Corridors:** both spines through T019's generator, unchanged.
- **Decals:** all 37 A013 graphics cut to `assets/game/decals/` (`tools/t023_decals.py`) and placed. Stickers on props are a new `signage.stuck` list.
- **Effects:** tanks glow, an acid pool in the lab (no damage, tested), a sparking console on the bridge, steam twice in engineering, dust in all eight spaces.
- **Choosing the ship:** `ships`, `ship_pick` (`first`, `rotate`, `random_seeded`), F1 > Shift picker, `--ship survey`. A change of ship reloads the scene, and the session crosses with it.

## Checks
| Check | Result |
| --- | --- |
| Headless tests | **599 passed, 0 failed, 0 load errors** (566 before, 33 new in `tests/test_survey_deck.gd`). No existing test edited |
| Import | No errors |
| Current ship, old bots, 12 seeds each, against a clean export of `main` | **Identical on all 48 runs** (T012 and T015 shift bots, greedy and cautious) |
| Doors, salvage, spawn candidates, cover vs the layout file | Pass. Centres within 0.25 m. Doors and spaces exact |
| Routes 1.5 m clear, all dressing counted solid | Pass (a flush floor grate doesn't count) |
| Black box from the hold, both ways round the loop | Pass, with either bridge door shut |
| No clutter on bot routes | Pass |
| Every A013 decal loads and is placed | Pass, 37 of 37 |
| `rotate` across ships, F1 picker, `--ship` | Pass (`tools/t023_ship_check.gd`) |

### Bots: read this before using old numbers
**I found and fixed a bug in the T012 bot, and it affects every bot number since T012.** It pressed E every step while a door was opening, which flipped the door back and forth. On the survey it never left the hold. On the current ship it lost much of its time at doors, so **earlier bot numbers understate what the bots reach: the cautious bot banks about twice as much with the fix.** `--old-door-press` reproduces the old numbers, and the identical-runs row above used it. The table uses the fixed bot on both ships.

12 seeds each. For information; nothing is tuned.

| Bot | Ship | Survived | Banked (mean) | Items | Prize | Time (mean) | Deaths |
| --- | --- | --- | --- | --- | --- | --- | --- |
| T012 greedy | Current | 0 | 0 | 24.9 | 11 | 267 s | cutter 11, lunge 1 |
| T012 greedy | Survey | 9 | 1,435 | 5.0 | 9 | 160 s | cutter 2, puddle 1 |
| T012 cautious | Current | 12 | 2,409 | 23.9 | 0 | 206 s | none |
| T012 cautious | Survey | 12 | 386 | 3.7 | 0 | 115 s | none |
| T015 greedy | Current | 0 | 0 | 25.0 | 12 | 266 s | cutter 12 |
| T015 greedy | Survey | 7 | 1,054 | 4.8 | 9 | 156 s | cutter 5 |
| T015 cautious | Current | 12 | 2,366 | 23.3 | 0 | 206 s | none |
| T015 cautious | Survey | 11 | 375 | 3.8 | 0 | 113 s | spit 1 |

- **The survey holds far less salvage: the plan's 10 spots against the current ship's 33.** Bots empty it and leave at about 2.5 minutes, before tier 1 (192 s), so the tiers rarely fire. Cautious banks about 16% of the current ship's figure. **As built, this ship can't meet the current quota without the black box.** This is the first thing to decide after playing.
- Greedy deaths on the survey are mostly the cutter, in the east spine, after the prize wakes it.
- A rerun of T012 on the survey gave identical results on all 24 runs.
- Raw numbers: `docs/screens/T023/bots/`.

Routes (`tools/t023_routes.gd`, doors open, nobody in the way, 3.4 m/s out, 65% home with the box):

| Route | Length | Out | Home, heavy |
| --- | --- | --- | --- |
| Current: hold to black box | 28.4 m | 8.4 s | 12.9 s |
| Survey: hold to black box, west | 33.7 m | 9.9 s | 15.2 s |
| Survey: same, round the east | 47.2 m | 13.9 s | 21.4 s |
| Survey: hold to engine part | 37.9 m | 11.1 s | 17.1 s |

### Frame time (ms, average / p95)
1920×957, three alternating rounds of 15 s, player still, light on, **dummy audio**, load average 4 to 7, so not a quiet Mac. Raw: `docs/screens/T023/frame_times.json`.

| Stand | Current | Survey | Cost |
| --- | --- | --- | --- |
| Spawn | 4.99 / 5.77 | 5.48 / 6.46 | +0.49 / +0.69 |
| Biggest room (medbay / bio lab) | 5.65 / 6.49 | 6.45 / 7.28 | +0.80 / +0.79 |
| Corridor (junction / east spine) | 6.52 / 7.37 | 6.90 / 7.83 | +0.38 / +0.46 |

No fights, walking or cut-away fades were priced. These numbers leave out audio's cost, so don't compare them with earlier handoffs.

## Screenshots (`docs/screens/T023/`)
`sheet.png` puts A014-03/04/05 beside the built rooms, then every other stand. Each room, both spines, `bio_lab_seal_trolley` (the trolley), `bridge_black_box`, `engineering_dead_end`, plus `_play` shots through the real mask. The A014 frames are mood paintings, not overlays, so this compares mood and not layout. To rebuild: `GODOT=<wrapper adding --audio-driver Dummy> tools/capture.sh scenes/dev/t023_stand.tscn docs/screens/T023 2`, then `python3 tools/t023_sheet.py`.

## Where I departed from the packet, or it was wrong
1. **A013's manifest has no crops.** It lists atlases only. I found the boxes by image, got exactly its 37, checked them by eye, and put them in `data/kit.json` `room_decals`.
2. **Catalogue props don't match the plan's rects.** Centres hold to half a cell. A prop may reach up to 0.3 m past its rect, not 0.25: only the mess tables need that (1.6 m deep in a 1 m rect). Some rects are filled by a group, and many props are smaller than their rect (tanks 0.9 m in a 1.5 × 2 m rect).
3. **The plan has no bulkhead closet, so this ship has no ambush.** `ambush.none` turns it off. Instead of a bulkhead stalker there's a second prowler: one in the lab, one in engineering guarding the reward. **My call, not the plan's.**
4. **The trolley is a solid prop, not dressing, and at D5.** The bots' lane hugs the door wall and left no room to keep clutter off it, so you step round the trolley. It has no cover class, and rounds stop on it.
5. **Tier 2's lights fail in the bio lab and the mess** (my pick); salvage kinds per class, stalker patrols, terminals, wall families and sound per room are also mine, all in the deck file.
6. **The drone flies straight through shut doors.** Its patrol crosses four, as the plan draws it. Its sight stops at them, but you can see it clip through. Giving it doors changes the game (it would let stalkers out), so I left it. See below.
7. **I dimmed emissive props on this ship.** At the kit's full energy the reactor and tanks bloomed through the sight mask and gave dark rooms away.
8. **Props pulled toward walls.** A bot wedged itself for about 300 s behind the lab freezers, in a slot wide enough for a player but too narrow for the nav's 0.55 m radius. I closed that slot and several like it.
9. **Effects:** T020 has no tank-glow recipe, so the glow is materials and the plan's three lights.
10. **`t015_bots.gd` wasn't run on the survey:** it only walks the current ship's cargo hold. `t015_shift_bots.gd` was.

**Edits outside the packet's modules:** `src/core/data.gd`, `src/debug/tuning_panel.gd` (the picker, and Save now refuses on any ship but the first, because it would write that ship's overrides over the base files), `src/debug/t023_stand.gd`, `src/vfx/vfx.gd` (one line: surfaces rebuild per deck), `tools/t012_bots.gd`.

## Needs John's eye
1. **Does it feel like a different ship, and is the black-box run tense?** (The packet's question.)
2. **Salvage and quota:** 10 spots may be too few (above). Add spots, or give this ship a different quota?
3. **Should the drone open doors, take another route, or stay as it is?**
4. **Faint shapes in the dark:** tanks and the holo projector still show as very dim silhouettes through the mask in rooms you haven't seen (`bridge_black_box_play`). Dim enough?
5. **Slots still open:** behind the tanks (0.8 m), and 0.9 to 1.0 m behind the autopsy table and the engineering racks. A player can stand where a stalker can't path. An escape, or an exploit? The tanks can't move further without leaving the plan's half cell. No bot wedged in the final runs.
6. **The engineering light:** the room reads green-teal rather than the plan's cyan. Fine?

## Not checked
Real play or motion; **any sound on the survey** (captures ran on dummy audio, so room tones and tails are data only); co-op on this ship; `rotate` in real hands (the check drives it by script); other room scales don't apply; the combined build with T022; whether the briefing's copy suits this ship (vessel names are still the old list).
