# T006 handoff: a dangerous stalker, plus John's playtest fixes

Branch `auto/t006-mac`. Play it: press F5 in the editor, or `godot --path .`; the main scene is now `stalker_deck`.
New key: 6 returns to the new default camera (1-5 are the old presets, unchanged).

**Nobody has played this, and nobody has heard the door bangs.** The numbers below come from bots and stills. The stage 2 gate is still open.

**Two things did not fully land:**
1. **The flashlight flicker is not confirmed fixed.** I never reproduced what John described (details below).
2. **"Harder to land" is only partly met.** A bot with human-like lag hits about as often as before or a little less, but a perfect-aim bot hits more often and kills faster than before.

## What changed
- **Stalker:**
  - Moves in dashes (6.5 m/s for 0.4-0.7 s, skittering side to side) with 0.2-0.55 s pauses, facing you when stopped.
  - Dodges a hit, a near miss, or the light first landing on it, with a 0.9 s cooldown.
  - Spit: 0.4 s wind-up, 16 m/s, 22 damage. Lunge: 5 m reach, 0.3 s wind-up, 2.4 s cooldown, 34 damage (staggers).
  - After an attack it backs off for 1.3 s and may change sides. It replans as soon as it arrives.
  - Health is unchanged: 7 rifle hits.
- **Ambush:** out in 0.25 s, then straight at you with no pauses, lunging as soon as it's in reach.
- **Doors:** a stalker never opens one. It bangs for 8 s of contact (`data/doors.json` `bash.break_s`) while the panel shakes, bows and dents, then the door lies flat and stays broken until respawn. Two stalkers are no faster.
- **John's list:** crouch corkscrew fixed, `LIGHT OFF` on the HUD, `IN COVER` beside `CROUCHED`, shields 44 → 76 px and moved above the crouch readout, new default camera (pitch 60°, 20.5 m, fov 35°), awareness 2.2 m, 1.2 m crates block sight, main scene set.
- **F1:** new sections for Stalker dash, Stalker dodge and Door breaking, plus Dust motes strength. The Stalk m/s slider is gone, because dash speed replaced that number.

**Edits outside the named modules:** `data/deck.json` (the four `crate_high` props become `tall`, which the packet asked for) and the new tool `tools/t006_bots.gd`.

### The crouch corkscrew
It was in the legs. `L_Idle` and `L_Crouch_Idle` hold each thigh half a turn about its own length from the walk clips and rest pose. Godot blends rotations away from rest, so going into a crouch swung each foot in a loop about 0.4 m around the body. `operator_anim.gd` now rewrites those keys at load: same pose, the short way.
- Measured: feet end where they did to within 1 cm and now travel straight.
- Foot slide (`tools/t003_footslide.gd`) is no worse in any direction, and better walking back (68% → 59% of body speed) and sprinting (43% → 35%). The rest are within about 5 points.

### The flashlight flicker: what I found and didn't
| Suspect | Result |
| --- | --- |
| Sight polygon | Ruled out: 0 of 596,736 vertices leaked through an occluder across 8,000 aim steps; no area jumps over 1 m² |
| Mouse-aim feedback through the camera | No oscillation found at 60 or 144 fps |
| Motes, beam, spot shadow | No single one dominates: movie-mode twinkle 1.47% with all on, 1.42-1.46% with any one off, 1.16% light off. The gap fits the larger lit area |
| Open door panel against its post | **Real and fixed:** a blue strip flashed through the yellow post in one saved frame, and flipping pixels went from 8 to 0 with the panel hidden |

- **Fixed:** the open panel is now hidden, since it lies inside the wall.
- **Fixed, but no before/after measured:** the beam dropped polygon points closer than the muzzle, joining their neighbours in one big triangle that could snap in and out near walls. Points are now pushed out instead.
- **One unexplained reading:** a single early pass showed 47% of the screen twinkling in its worst frame. It didn't repeat in later runs, including a recreation of that opening, so I treated it as a startup artifact without proving it.
- **Still untested:**
  - The operator moves at 60 Hz while the camera moves at display rate (already in Parked), which my 60 fps movie runs can't show.
  - The sight mask's stair-stepped edges, visible in the captures, which may crawl in motion.

**John:** if it still flickers, set F1 Dust motes strength and Beam strength to 0 one at a time, tell us which clears it, and say whether it happens standing or moving.

## Checks run
**Headless: 181 passed, 0 failed, 0 load errors** (153 before T006). `--import` exits 0 with no errors; it still prints the 13 `invalid UID` warnings for `operator.glb`.

| Packet check | Test |
| --- | --- |
| dash beats the walk | `test_a_dash_is_faster_than_the_players_walk_and_comes_in_bursts` |
| shot → dodge, cooldown holds | `test_a_shot_triggers_a_dodge_and_the_cooldown_holds`, plus near-miss and light tests |
| spit from data | `test_the_faster_spit_comes_from_data` |
| ambush bots | `test_the_ambush_bites_a_player_who_only_reacts_to_the_sound`, `test_a_player_who_turns_at_once_fires_before_being_hit` |
| door bang time, never opened | `test_a_stalker_breaks_a_shut_door_after_the_bang_time_and_never_opens_it`, plus five more door tests |
| crouch | `test_crouching_from_standing_does_not_swing_the_legs_around` |
| `IN COVER` | `test_in_cover_shows_behind_low_cover_with_nobody_hunting` |
| camera default | `test_the_new_camera_is_the_default_in_every_deck_and_old_presets_keep_their_keys` |

Old tests changed for John's numbers or the new behaviour: the sight fixture now uses `crate_low`, one cover-glob test blocks the stalker's own extra spit, and the lunge test compares against dash speed.

Breaking the code on purpose, then restoring it:
| Break | Tests that fail |
| --- | --- |
| a hit doesn't dodge | 2 |
| no dodge cooldown | 1 |
| door breaks in half the time | 2 |
| stalker opens the door | 5 |
| no leg untwist | 1 |
| `IN COVER` needs a hunter | 1 |
| the rush doesn't dash | 3 |
| ambush back to 0.55 s | 1 |

### Bot report (`tools/t006_bots.gd`, 12 runs each; "before" is commit 77d6c9d)
| Bot | Before | After |
| --- | --- | --- |
| Standing still, after the burst: dies at | 8.57 s (first hit 3.00 s) | **4.98 s** (first hit 1.57 s) |
| Crouched behind the bed, stalker 6 m off: dies at | 10.40 s (first hit 4.83 s) | **6.99 s** (first hit 3.32 s) |
| Ambush, walks on 0.45 s then reacts: hit in | 1 of 12 runs | **12 of 12**, at 1.48 s (first shot 1.07 s) |
| Ambush, turns at once: hit in | 1 of 12 runs | **12 of 12**, at 1.22 s (first shot 0.52 s) |
| Tracks with 0.2 s lag: hit rate, kill time | 39%, 3.12 s | 31-38%, 2.60-3.24 s (two runs) |
| Tracks perfectly: hit rate, kill time | 43%, 2.74 s | 61%, 1.62 s |

- **Before the tuning pass,** the perfect tracker was at 71% and 1.40 s, and the lag tracker at 48% and 1.89 s. Skitter, a tighter hit disc (0.6 → 0.45 m) and the shorter dodge cooldown brought them down.
- **Why perfect aim still does better:** the stalker now reaches you sooner and stands still in its wind-ups, and dodges don't interrupt those. I kept it that way because a dodge out of a wind-up would let your first hit cancel the ambush lunge.
- **The bots are limited:** they stand still and fire whatever the cone says. The two tracking bots never die, so these runs can't say how the fight feels. The cover bot never moves either.
- **Also worth knowing:** even the bot that turns at once gets hit. It gets a shot off first, as the packet asks, and only moving out of the charge line avoids the lunge. No bot tries that.

### Frame time with two stalkers (15 s windows, 1920×1080, M2 Pro, Metal, MSAA 4x, vsync off)
| Build | Average ms | p95 ms | p99 ms | Max ms |
| --- | --- | --- | --- | --- |
| T006 (2 runs before the door polish) | 8.41, 8.49 | 13.49, 13.32 | 16.28, 18.29 | 71.0, 122.3 |
| T006 final capture | 8.57 | 13.78 | 20.56 | 82.9 |
| T005 (same conditions, 2 runs) | 8.44, 8.45 | 14.21, 14.16 | 17.48, 18.89 | 34.4, 64.0 |

**No measurable average cost compared with T005, but this isn't a quiet-machine number.** Zoom and Chrome were running (load average about 5-6), so don't compare it with T005's 3.50 ms. Max spikes were higher in the T006 runs, but on this few runs and this load I can't tell whether that's real.

## Screenshots (`docs/screens/T006/`)
`dash_mid_motion`, `dodge`, `spit_windup_fast`, `lunge_charge`, `door_mid_bash`, `door_broken`, `in_cover_readout`, `cover_protected`, `cover_braced_exposed`, `light_off_hud`, `ambush_1_bang`, `ambush_2_out_and_dashing`, `ambush_3_lunging`, `camera_default`, `camera_preset_1`, `death_screen`, `stalker_deck`, `stalker_deck_overlay`, `frametime.json`.

Positions are staged by script, except the ambush. In the door shots the stalker walks up and bangs for real, but the damage is jumped ahead. Only stills were reviewed, so motion hasn't been judged.

## Decisions made without you (easy to change)
- **Cover class:** the 1.2 m crates are now `tall`. They stop shots, spit and stalker sight at any stance, instead of counting as 0.9 m low cover. You can no longer fire over them, and this removes the T005 question about rounds grazing them. Consoles (1.1 m) and low crates stay low.
- **A noise also counts as "knows you're behind the door".** Firing where a stalker can hear you, through a shut door, starts it breaking through. This is the one most likely to need your call: it makes every shot a clock.
- **Locked doors hold.** Stalkers don't try them, so a room reachable only through a locked door is safe.
- **Your light gives you away:** a prowling stalker caught in the beam starts hunting you, out to the light's 15 m, past its own 11 m sight.
- **Dodging waits during a recovery,** so that 1.5× damage window stays yours; it dodges as soon as the recovery ends.
- **`IN COVER`** counts any cover within 1.0 m in any direction, low or tall, and hides while you rise to fire. It says where you are, not who it stops; the shields say that.
- **Door damage stays** if the stalker leaves. You can still open a dented door.
- **Investigating stalkers** walk faster (1.7 → 2.6 m/s); prowling is unchanged.

## Known limits
- The door's "knows" isn't refreshed: a stalker keeps banging even after you've left, unless a way round opens up.
- The broken panel has no collision and no effect on cover.
- In the player's sight, a stalker still pops in with no fade, which matters more at dash speed.
- Dash and door bash are placeholder motion and sound: the body stretches and leans, and the bang is generated noise.

## Needs John's eye
1. *"Is moving through these rooms with a flashlight tense and fun?"* Play with F1 open.
2. **Is it too much now?** Standing still you're dead in 5 s. First levers: Dash m/s, Skitter, Dodge cooldown, lunge Damage.
3. **Does it still flicker?** See the steps above.
4. **Do you see the corkscrew again?** Stand still and press C.
5. **Are hits hard enough to land, and do dodges read as dodging?**
6. **Is 8 s of banging right, and is the bang loud enough through a door?**
7. **Should a gunshot start a stalker on a door?**
