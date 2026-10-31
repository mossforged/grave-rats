# T013 handoff: scripted props in the deck slots

Branch `auto/t013-mac`. Look at `docs/screens/T013/t011_rooms_medbay.png` first, then `t011_rooms_junction.png`.

The console (three widths), cabinet and locker bank are in the game in place of boxes, wearing the kit's materials. The consoles and cabinets look right. **The locker bank reads as a dark slab from the game camera; see "Needs John's eye".** The bed is still the box, as the packet says.

## What changed
- **Files:** copies in `assets/game/props/`, mapped in `data/kit.json` `slots`. Nothing in `assets/source/` was edited.
- **Materials (`KitPieces.slot_mesh`):** each surface is rebuilt through `KitMesh` and wears the kit material its slot is named after. The file's colours are never used.
- **UVs:** the files have positions and normals only, with no UVs or tangents. `KitMesh.add_triangles` box-projects them at each material's `uv_m`, so density matches the walls, and adds tangents and the same height grime as kit pieces.
- **Console choice (`KitPieces.slot_file`):** the width matching the prop's long side, else the widest that fits.
- **Facing (`KitPieces.prop_yaw`):** front toward the room's centre, across the short side, unless that floor is blocked and the other side is open. Blocked floor flipped nothing on the main deck: its six fronts all face the centre.
- **Fallback:** a file that doesn't fit its footprint, or won't load, gives the box.

## Checks
| Check | Result |
| --- | --- |
| Headless tests | **321/321** on three full runs (the last on the final code) (315 old, 6 new; one old test replaced by `test_the_bed_stays_the_box`) |
| Import | No errors |
| Each slot loads its file | Pass (5 files) |
| Console variant matches deck width | Pass: 1.4, 1.2 and 1.0 exact; 1.6 gets 1.4 (below) |
| Every material slot binds to a kit material | Pass, by name and by material object |
| UV density and grime | Pass: axis-facing edges over 5 cm measure 1 / `uv_m` tiles per metre; cabinet darkest at the floor shade, 1.0 up high |
| Inside footprints, on both decks | Pass, within 1 cm |
| T009 snapshot | `tests/fixtures/t009_deck_snapshot.json` not edited; its test passes |

`test_crates_match_a006` now skips props with a slot file, since they aren't exactly `size` in their own frame. The new footprint test covers them.

### Frame time, 1920x1080 on the M2 Pro (ms, average / p95)
Alternating runs, three rounds of 15 s each, load average about 3.8. "Boxes" is the same build with `slots` blanked. Raw runs: `docs/screens/T013/frame_times.json`.

| Deck | Boxes | Props | Difference |
| --- | --- | --- | --- |
| `pirate_deck` | 7.10 / 9.27 | 7.17 / 9.51 | +0.07 / +0.24 |
| `stalker_deck` | 6.20 / 8.31 | 6.23 / 8.36 | +0.03 / +0.05 |
| `shift_deck` (main scene) | 6.70 / 9.71 | 6.75 / 9.74 | +0.05 / +0.03 |

The pirate deck's T011 target (under 7.5 / under 9.5) is met on average and misses on p95 by 0.01, in the mean of three runs. Boxes ranged 9.09 to 9.52 and props 9.40 to 9.64, so its +0.24 is about the size of the noise, and that deck has only one console from these files. Not a quiet Mac.

## Screenshots (`docs/screens/T013/`)
- **Default camera:** `camera_default`, `junction_default`, `stalker_deck`.
- **T011 stands:** `t011_rooms_medbay`, `t011_rooms_junction`, `t011_01b_off`, `t011_01b_play`, `t011_04b_off`, `t011_04b_play`. I took only these two of the four T011 frames, the ones showing the medbay and junction.
- **Pirate deck:** `pirate/deck_overview`, where the junction is mostly in the dark.
- **Locker bank:** `t013_lockers_west`, `t013_lockers_lit`. These came from a temporary stand I added and removed; it isn't in the code, so they can't be reproduced by a command.
- I made no T013 sheet; the packet didn't ask for one.

## Needs John's eye
1. **Locker bank as a dark slab.** Its top is `steel`, as the lead's file says, and the kit's steel is dark. The game camera is steep, so you see mostly the top; the doors show only when the bank is well off to one side of the screen. Even in `t013_lockers_lit` I could not make out the door detail. I kept the binding the packet asks for. The fix, if wanted, is a lighter top material in `tools/blender/props.py`, or a repaint of that slot.
2. **Its front faces west,** toward the beds, because it stands just east of the room's centre. From the east you get the plain back. To flip it, the rule or the deck position would have to change.
3. **The beds now stand out** as the plainest things in the medbay. John's Meshy bed should fix that.

## Calls I made, for the lead to overrule
- **The pirate deck's 1.6 m console has no file.** The packet lists 1.4, 1.2 and 1.0, but `data/pirates.json` has a 0.6 × 1.1 × 1.6 console. It shows the 1.4 centred, leaving 10 cm of invisible collision at each end. I didn't stretch it (the trim would distort) or change its size (the snapshot holds it). Options: add `console_1600` to `props.py`, or accept the gap.
- **Worn rims:** the kit cuts wall faces into nine so the rim lands on the edge; the props aren't cut. Instead each prop's centre sits on the tile's centre, which keeps the rim off faces shorter than the tile. Faces longer than the usable tile, such as the bank's 2.4 m in steel (1.5 m tile), can show a rim across them. It didn't stand out in the shots, where the bank is dark anyway.
- **Same tile placement on every copy:** the two side-by-side cabinets wear identical textures.

## Edits outside `src/kit/`
- `src/study/deck_builder.gd`: one line setting the prop's yaw, since `prop` alone doesn't know the room. `src/study/CONTRACT.md`: one clause.
- `tests/test_kit.gd`, `data/kit.json`, `assets/game/props/`.
- `src/enemies/stalker_deck.gd` was edited only for the temporary stand and restored; the commit doesn't touch it.

## Not checked
Real play or motion, any resolution above 1080p, and a quiet-Mac frame time. The T006/T007 bots weren't run, though no rule or collision changed. I didn't re-measure flicker (`tools/t008_flicker.gd`), so whether the new detail adds shimmer when turning is unknown.

The untracked `tools/qa/t006_seeded.gd.uid` and `t007_seeded.gd.uid` were there when I started; I left them out of the commits.
