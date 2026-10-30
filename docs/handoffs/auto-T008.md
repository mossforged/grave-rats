# T008 handoff: flashlight flicker, door noise rule, suit-OS HUD with the noise ring

Branch `auto/t008-mac`. Play it: F5 in the editor or `godot --path .` (still `pirate_deck`). Stalker deck: `godot --path . scenes/enemies/stalker_deck.tscn`. New key: **H** hides the key help.

**Nobody has played this.** The numbers come from tests, bots and frame captures, and the pictures are stills, so motion and feel are unjudged. Only John can say the flicker he saw is gone.

## What changed
1. **Flicker:** the beam was the second shape. It's now one soft glow from the muzzle, in the spot's own cone. The pirates' lights use the same code.
2. **Door rule:** only a stalker already hunting you breaks a door. A gunshot through a shut door brings it up to the door to linger, then it gives up. Through a shut door, hearing is 50% (`stalker.senses.through_door_factor`).
3. **HUD:** the suit OS in the A005-05 layout replaces the grey-box pieces in all four decks, with a noise ring on the floor drawn from the AI's own hearing numbers.

## 1. The flicker
**Confirmed first:** with the beam mesh hidden, the second shape goes away. `flicker_before_beam_on` shows a hard-edged triangle from the muzzle, below the real light pool and drawn over the sight mask. `flicker_before_beam_off` shows one light.

**Why it jittered:** the old mesh was rebuilt from the sight polygon each frame, so its vertices came and went as corners crossed the wedge.

**The fix (`src/sight/beam_fan.gd`):**
- A fixed fan of rays from the muzzle, as wide and long as the spot, along its pitch, clipped only at walls.
- The vertex count never changes, and each ray's reach changes at no more than 30 m/s.
- Soft sides and fade are computed in beam space, so they don't depend on the vertices.
- The sheet checks the sight mask, as the pirates' already did, so it can't shine over the dark.

**Measured on the real GPU, stalker deck, medbay doorway, 1920×1080, 60 consecutive frames** (`tools/t008_flicker.gd`, `tools/t008_flicker_diff.py`). Twinkle means pixels that changed one way and straight back within two frames.

| Turning slowly, 10°/s | Before, beam on | Before, beam off | **Fixed, beam on** |
| --- | --- | --- | --- |
| Twinkle, mean % of screen | 0.0557 | 0.0346 | **0.0344** |
| Twinkle, worst frame % | 0.3361 | 0.0777 | **0.0762** |
| Beam vertex count changes in 60 frames | 36 | - | **0** |
| Worst single-frame beam movement | 6.94 m (outline) | - | **0.50 m** (vertex; the cap) |

Standing still, all three are the same within noise (twinkle 0.0002-0.0003%), and the beam's worst vertex move is 0.004 m, from the idle animation. So in this measure the old beam only misbehaved while turning.

**Limits of this measure:**
- It's slow turning at a fixed 60 fps in one spot. Walking and a faster display weren't measured, and the 60 Hz operator step (in Parked) is still there. If John still sees flicker, that's the next suspect.
- The remaining 0.034% is the same with the beam off. I didn't track down what it is; much of it is probably real edges moving as the view turns.
- My first run read 7.9% twinkle, which was wrong: the ambush had fired and its camera kick was shaking the frame. The tool now disables the ambush. Those numbers are discarded.

**Sight mask stair-steps:** not a meaningful flicker source. Doubling `mask.px_per_m` from 16 to 32 only moved turning twinkle from 0.0344% to 0.0308%, so I left it at 16. The stair-steps still show in stills.

**Pirates' lights:** same fan and shader. Twinkle was tiny before and after (turning: 0.0004% both), so there was no measurable flicker to remove in that staged shot. Their outline now moves under the same cap, verified by test, though they ask the walls at only 20 Hz.

## 2. The door rule
| Situation | Result |
| --- | --- |
| Hunting you when you go behind a door | Breaks it |
| Hears a shot through a shut door | Walks to the door, lingers `investigate.linger_s` (2.5 s) facing it, goes back to prowling |
| You fire into the door it's standing behind | Still only investigating. It needed its own fix: the round counted as a near miss, which started a hunt |
| 18 s of gunfire in the medbay, stalker in cargo | Never bashes; no door marked |

"Through a shut door" means no open walking route to the noise, so a wall with an open way round still carries the full radius.

**A mistake caught along the way:** my first near-miss check used line of sight, which made stalkers near walls and crates stop noticing rounds and pushed the lag bot's hit rate from 45% to 59%. I narrowed it to "no open way to the shooter", and the rate went back to 44%.

## 3. The HUD and ring
- **Ring (`src/hud/noise_state.gd`, `noise_ring.gd`):** reads the enemies' `senses` dictionary itself, with no copy. Each deck passes its own: stalker numbers by default, pirate numbers in `pirate_deck`.

| Noise | Stalker deck | Pirate deck |
| --- | --- | --- |
| Standing still | no ring | no ring |
| Crouch-walk | 1.5 m (new) | 1.5 m (new) |
| Walk | 3 m (new) | 3 m (new) |
| Sprint | 9 m | 9 m |
| Gunfire | 22 m | 24 m |

- **Docks:** Remnant mark and one crew row, O2 ticker "billed per minute" (placeholder, starts 06:40, does nothing at zero), suit, ammo, salvage (placeholder 1,240 CR), `RENTAL UNIT 04`, alarm strip, cover shields.
- **States:** `IN COVER`, `LOCKED`, `LOCKED: EXPOSED`, `CROUCHED`, `LIGHT OFF`, plus the old `RELOADING`, `EMPTY - R` and sprint words.
- **Font:** Barlow Condensed, SIL Open Font License 1.1, licence in `assets/game/fonts/OFL.txt`. Copied from John's own Dead Circuit handoff folder; the copyright and licence URL were read from the font files' metadata. I wrote `OFL.txt` from the standard licence text from memory, without a copy to diff it against, so check it against the official one before shipping.
- **Data:** `data/hud.json`, with F1 sections "Suit OS HUD" and "Noise (what the ring shows)". Two beam sliders were added under Sight.

## Checks run
**Headless: 231 passed, 0 failed, 0 load errors** (210 before). `--import` exits without errors and still prints the 13 known `invalid UID` warnings for `operator.glb`.

| Packet check | Test |
| --- | --- |
| Beam vertex change, still | `test_the_beam_holds_still_when_you_do` (under 0.0005 m) |
| Beam vertex change, turning slowly | `test_the_beam_moves_only_as_fast_as_you_turn_it`, `test_the_pirates_light_is_the_same_beam` (sweep + rate cap) |
| Shot through a door: investigate, give up, no bash | `test_a_shot_through_a_shut_door_brings_it_to_the_door_and_it_gives_up`, `test_a_shot_at_the_door_it_stands_behind_does_not_start_it_bashing` |
| A hunting stalker still breaks the door | `test_a_hunting_stalker_still_breaks_the_door_you_went_behind`, plus T006's door tests |
| Through-door radius from data | `test_the_through_door_radius_comes_from_data` |
| Fight in one room, stalker two rooms away | `test_a_fight_in_one_room_does_not_set_off_a_stalker_two_rooms_away` |
| Ring equals AI radius for walk, sprint, crouch, gunfire | `test_the_ring_is_exactly_what_the_stalkers_hear` (heard just inside, not just outside), `test_the_ring_shares_the_numbers_it_never_copies_them`, `test_the_pirate_deck_ring_shows_the_pirates_ears` |
| Every HUD number from data | the literal scan in `tests/test_weapons.gd` now covers `src/hud` and `beam_fan.gd`; `test_hud_numbers_and_words_come_from_data` |

**Old tests changed:** `test_a_noise_behind_a_shut_door_brings_it_to_bash` is replaced, since it tested the rule John removed. `test_light_off_shows_on_the_hud` now reads the suit OS.

Breaking the code on purpose, then restoring it:

| Break | Tests that fail |
| --- | --- |
| An investigating stalker bashes | 2 |
| A hunting stalker never bashes | 5 |
| Through-door radius ignored | 1 |
| A round through a door counts as a near miss | 1 |
| Ring 10% off the AI's radius | 5 |
| Beam reach not eased | 2 |
| A shot doesn't reach the ring | 1 |
| Investigating bashes **and** through-door ignored (T006's behaviour) | 4, including the two-rooms test |

The two-rooms test passes under either door break alone, because each rule covers for the other. It only fails with both gone.

### Bots (12 runs each, same tools as T007)
**Stalker deck, on the final code:**

| Bot | T007 | T008 |
| --- | --- | --- |
| Standing still: dies at | 5.17 s | 5.17 s |
| Crouched behind the bed: dies at | 8.57 s | 8.57 s |
| Ambush, reacts after 0.45 s: first hit | 1.40 s | 1.40 s |
| Ambush, turns at once: first hit | 1.15 s | 1.15 s |
| Tracks with 0.2 s lag: hit rate, kill time | 45%, 2.22 s | 44%, 2.23 s |
| Tracks perfectly: hit rate, kill time | 72%, 1.32 s | 66%, 1.46 s |

**Pirate deck:**

| Bot | T007 | T008 |
| --- | --- | --- |
| Open, never fires: dies at | 3.37 s | 3.13 s |
| Crouched, never fires | 7.66 s | 8.01 s |
| Locked, never fires | 7.77 s | 7.76 s |
| Open, fights | 3.86 s | 3.48 s |
| Crouched, fights: dies at, died, kills | 5.60 s, 7/12, 1.42 | 5.88 s, 8/12, 1.33 |
| Locked, fights: dies at, died, kills | 5.62 s, 12/12, 0.42 | 5.32 s, 12/12, 0.33 |

I haven't explained the pirate-deck differences or the perfect tracker's drop, and I didn't repeat those runs to size the noise. No pirate combat rule changed. These bots rarely walk, so they barely exercise the new walk and crouch noise, and they say nothing about how that plays.

### Frame time (15 s windows, 1920×1080, M2 Pro, Metal, MSAA 4x, vsync off)
| Scene | Average ms | p95 ms | p99 ms | Max ms |
| --- | --- | --- | --- | --- |
| `stalker_deck`, T008 | 8.12 | 12.93 | 16.85 | 21.7 |
| `pirate_deck`, T008 | 8.03 | 12.64 | 16.41 | 21.0 |
| `pirate_deck`, T007 | 8.32 | 15.79 | 18.90 | 25.3 |
| `stalker_deck`, T007 session | 9.11 | 15.64 | 35.52 | 177.6 |

**No measurable cost, but not a quiet-machine number:** load average was about 4-6 with other apps running, and these are single runs on each build.

## Screenshots (`docs/screens/T008/`)
- **Flicker:** `flicker_before_beam_on`, `flicker_before_beam_off`, `flicker_fixed`, `flicker_fixed_beam_off`.
- **Ring:** `hud_rest`, `hud_walk`, `hud_crouch_walk`, `hud_sprint`, `hud_fire_bloom` (0.1 s after a real shot), `hud_fire_shrinking` (1.2 s after).
- **Tense state, like A005-06b:** `hud_tense` (20% suit, acid, 3 rounds, in cover; staged).
- **Other:** `hud_locked`, `hud_locked_exposed`, `hud_shields_under_fire`, `pirate_light_beside_yours`, `sight_deck_hud`, `weight_deck_hud`.
- **Frame time:** `frametime_stalker_deck.json`, `frametime_pirate_deck.json`.

## Decisions made without you (easy to change)
- **Walking and crouch-walking now make real noise: 3 m and 1.5 m.** This is the one most likely to need your call. The packet wants the ring to match what the AI hears for walk and crouch, and the AI heard neither, so I added them to both enemies (halved through a shut door for stalkers). A prowler 3 m away now hears you walk, and one pirate hearing you alerts the squad. For an empty ring when walking, set both to 0 in F1.
- **Gunfire is mostly off screen.** The real radius is 22-24 m and the view is about 23 m wide, so the ring leaves the frame. I added a pulse per shot, restarted once the last has run 7 m, so sustained fire stays visible. The pulse wasn't asked for.
- **The ring shows the open-air radius.** It doesn't draw the 50% through a door.
- **The ring draws over rooms you haven't seen,** and it's hidden behind walls and props.
- **States float over the operator,** as `IN COVER` does in A005-06b, rather than in a dock. Cover shields sit above the right dock.
- **Pirates keep their full hearing through doors.** The packet's door rule is about stalkers, and pirates open doors.
- **Low ammo is 6 rounds or fewer, low suit is 30% or less.**
- **A stalker at a door lingers the normal 2.5 s,** and each new shot it hears restarts that.

**Edits outside the named modules, because the HUD or rule needed them:**
- `src/player`: `player_hud.gd` removed, `weight_deck.gd`, `OperatorModel.noise_kind()`.
- `src/health`: the bar and acid word left `health_hud.gd`; the flash and death screen stay.
- `src/cover`: `protection_mark.gd` is now state only, and `LockDriver.state_word()` replaces its label.
- `src/pirates`: `pirate_light.gd`, `pirate_deck.gd`, `pirate_beam.gdshader` removed.
- `data/cover.json`, `data/health.json`, `data/pirates.json`, `data/debug.json`, `assets/game/fonts/`, and the tools above.

## Known limits
- `scale_deck` keeps its own study readout; it isn't a play deck.
- On the fully lit `weight_deck`, the top-left mark and crew row have no plate and wash out. They read fine in the dark decks.
- The door prompt can overlap the state row and the lock prompt.
- A005-05's cracked-glass frame and the minimap aren't built (minimap out of scope; frame not asked for).
- The fallback to Godot's default font isn't tested. HUD drawing is only checked by eye in windowed stills; headless tests cover its logic, not its pixels.
- I never got a clean still of a stalker at a door: sight hides it through the door. Tests cover that rule, and no picture does.

## Needs John's eye
1. **Is the flicker gone?** Try turning slowly and walking. If it's still there, say whether it's standing or moving, and try F1 Beam strength 0.
2. **Does the HUD read?** Compare `hud_rest` and `hud_tense` with A005-05 and A005-06b. Is it muted enough?
3. **Does the ring help?** Does a walking ring earn its place or should it be empty? Does gunfire read when it mostly leaves the screen?
4. **Does the door rule feel right?** Does a stalker turning up at the door and giving up still feel tense?
