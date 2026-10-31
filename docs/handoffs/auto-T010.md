# T010 handoff: the slice kit, materials and lighting

Branch `auto/t010-mac`. Play it: `godot --path .` (`pirate_deck`), or open `scenes/enemies/stalker_deck.tscn` for the medbay. Start with `docs/screens/T010/sheet.png`.

**My read of the gate: not there yet.** The mood, palette, scale and structure are recognisably the paint-overs. They still look cleaner and flatter, and they have less wear and gloss. The rest of the gap is the bed, console, lockers and stalker, which are still boxes and are the centre of every paint-over. John decides. Nobody has seen any of this move: all checks are headless tests and stills.

## What changed
1. **Kit (`src/kit/`, `data/kit.json`):** walls (corridor plain, pipe/vent, cargo reinforced, medbay clinical, plus a plain outer hull face), corner posts, cap stubs, jambs, header, leaf, plated floors with grates, drains, hazard edging, thresholds and rivets, and the crates. `deck_builder.gd` puts them where it put boxes.
2. **Built in the engine, not Blender.** Pieces take exact lengths from the layout, so closing pieces need no export step and keep their trim sizes. Tests measure them headless, and everything reads one data file.
3. **Materials:** A006-08's families. `tools/t010_textures.py` generates albedo, normal and ORM from `data/kit.json`. Grime is vertex colour, low and in corners. Signs are cut from A002-08b; A010 isn't merged.
4. **Lighting (`deck_lighting.gd`):** cool strips in the medbay, sodium in cargo, a mix in the junction, 13 practicals on the full deck, 2 of them shadowed. Dark ambient, AgX, glow, low SSAO, fog in a ship-sized box. Each space's lights only touch that space's render layer, so nothing shines through a wall.
5. **Doors:** one leaf mesh. The T006 damage value drives its blend shape directly, bulging away from the blows, with a warm seam and spill. It lies flat when broken. A state strip on the header repeats the lamp colour.

## Checks
| Check | Result |
| --- | --- |
| Headless tests | **263/263** on the final run (247 old, 16 new in `tests/test_kit.gd`) |
| Same tests, repeated | `test_hauler::test_a_turn_in_place_plays_only_when_the_hips_are_dragged` is flaky: it failed 1 run of 4 on **unchanged main** and 1 of 2 on an earlier T010 build. It counts frames. Not fixed, outside this packet |
| Import | No errors |
| Kit against A006 within 1 cm | Pass: bays, closing pieces, cap, corner post, jamb, header, leaf, crates |
| Collision, blockers, cover against T009 | Identical on the main and pirate decks. The snapshot came from the T009 builder before any change |
| Doors, door body and sight rect | All five states tested. Body and sight rect are unchanged |
| From the builder, values from data | Pass: every deck mesh has `kit_piece`, and scenes outside `scenes/dev` place no meshes. `kit_materials.gd` and `deck_lighting.gd` hold no number literals beyond the 0/1/2/0.5 the repo's literal tests allow, and no kit script spells out a colour. `kit_pieces.gd` still has shape constants in the dent and crate code |

### Frame time, 1920×1080 on the M2 Pro (ms)
Budget: under 8.3 average. **Both decks pass.** `mediaanalysisd` was using about 67% CPU during these runs (load average near 4), so a quiet Mac may do a little better.

| Run | pirate_deck avg / p95 | stalker_deck avg / p95 |
| --- | --- | --- |
| T009 grey box | 4.28 / 5.71 | 4.24 / 5.99 |
| **T010 full** | **7.81 / 9.95** | **7.12 / 9.34** |
| Fog off | 7.13 / 9.18 | 6.50 / 8.57 |
| Practicals off | 6.29 / 8.07 | 5.90 / 8.06 |
| SSAO off | 6.79 / 8.61 | 6.28 / 8.49 |
| Glow off | 7.30 / 9.30 | 6.62 / 8.67 |
| Kit only (all four off) | 4.52 / 6.07 | 4.43 / 6.15 |

- **Approximate cost of each, from the off-switch runs:** fog 0.6–0.7, practicals 1.2–1.5, SSAO 0.8–1.0, glow 0.5.
- **Kit alone:** about 0.2 over the grey box.
- **Headroom:** the pirate deck has only 0.5 ms left, and its p95 is about 10 ms, so spikes pass 8.3.
- **How the matrix was run:** the off-switch rows predate the last paint-colour change, which only changed albedo. The full rows were re-measured after it. Env `KIT_FOG`, `KIT_PRACTICALS`, `KIT_SSAO`, `KIT_GLOW` = `off` reproduce them.

## Screenshots (`docs/screens/T010/`)
`sheet.png` has each paint-over beside the same stand and camera three ways: mask off, all known, in play. Below that: both door views in all five states (crops of the `t010_door_*` shots), cut-away fade on and off, and the frame-time table. Rebuild with `tools/t010_sheet.py`. Frames A006-02b and 03c used `in_cover_readout` and `door_mid_bash`. 04b is a stand I rebuilt from the frame-time pose, without the stalker beside the operator.

## Calls I made, for John or the lead to overrule
- **The header isn't solid.** It has A006's 2.0 × 0.4 × 0.5 m bounds but a slot along the top. A solid one would hide a side door's leaf from the game camera, and with it the door's state.
- **Leaf against collision:** the leaf you see is 0.12 m thick and 2.2 m tall. Collision and sight keep T006's 0.2 m, full-height panel so no rule moves. Jambs likewise look exact, with collision still 5 cm proud.
- **Closing pieces:** T009's layout divides each wall run evenly, so many pieces are under 2 m instead of 2 m bays plus one closer. Changing that would move collision, so I kept it. Trim sizes don't stretch; panels do the absorbing.
- **The L corner isn't one mesh:** it's bay + corner post + bay, so each leg fades alone. A test checks one 2.0 m outer leg, 0.5 m thick; the L itself isn't measured as a whole.
- **Look changes to existing data:**
  - Flashlight energy 7 → 10.
  - Remembered areas brightness 0.3 → 0.4, saturation 0.25 → 0.6, so memory keeps the room's colour. What you know is unchanged, but remembered rooms read clearer.
  - Tipped-bed colour lightened to ivory.
  - Removed the door dent-box keys and the bulkhead's flat colour.
- **Edits outside the named modules, all small:**
  - `src/enemies/bulkhead.gd`: uses a kit wall, because a flat box in a kit wall gives the ambush away.
  - `src/enemies/stalker_deck.gd`: capture shots.
  - `src/player/weight_deck.gd`: a zero-energy sun stays hidden.
  - `src/sight/sight_deck.gd` and `sight_mask.gd`: lighting hook and capture views.
  - `src/debug/capture.gd`: env `CAPTURE_ONLY`.
  - `tests/test_deck.gd`: one assertion read `BoxMesh.size` and now reads the mesh's AABB. Same height check.

## Known problems
- **Side doors read weakly from above**, especially closed against locked. Check this in play. Front-facing doors read well.
- **The aim cone** still draws over the art, bright and unmasked. The paint-overs removed it.
- **Faded walls are transparent**, so they draw after the sight mask, and a faded wall in unknown space isn't darkened. This predates T010, but lit kit walls make it more visible.
- **Reflections:** there are no reflection probes, so floors don't have the paint-overs' wet sheen.
- **Texture look:** chips still look spotty on large panels, and the floor's polished patches can look like splats. Generated textures are the weakest part next to the paint-overs.

## Not checked
Motion, fog shimmer and the T008 flicker measurement (`tools/t008_flicker.gd` not re-run, and fog is new). The T006/T007 bots (no rule changed). Any resolution above 1080p. The `scale_deck` and `weight_deck` look (kit geometry with their old plain lighting, no practicals; tests only).

## For John's eye
Sheet first, then play: walk medbay to junction to cargo. Does it match or beat the concept? Are the room lights too bright for "fear the corner"? Does the fog shimmer? Can you tell a side door's state?
