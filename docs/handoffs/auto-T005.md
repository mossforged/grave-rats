# T005 handoff: the stalker, cover with height, and getting hurt

Branch `auto/t005-mac`. Play it: `godot --path . scenes/enemies/stalker_deck.tscn`.
You start at the south end of the junction with an overturned bed, two tippable beds and consoles in the medbay (door on your left, ahead), one stalker prowling cargo, and one behind a wall panel you'll walk past.
New keys: E tips a bed in reach (otherwise works a door); Backspace resets everything and starts a new life. Everything from `sight_deck` still works (WASD, Shift, C/Ctrl, mouse, LMB, R, F, F1, F2, F3).

**Nobody has played this.** No keyboard or mouse has driven it, and nobody has heard the sounds. The stage 2 gate is still open.

## What changed
- **New modules:** `src/cover/`, `src/health/`, `src/enemies/`, `src/run_log/`, each with a `CONTRACT.md`. New data: `data/cover.json`, `data/health.json`, `data/enemies.json`. New scene: `scenes/enemies/stalker_deck.tscn`.
- **`data/deck.json`:** every prop has a `cover` class. The medbay gains a third bed, already overturned. The two old beds are marked `tippable`.
- **`data/debug.json`:** new F1 sections for Cover, Suit, Stalker senses, body, spit and lunge, and Ambush.

**Edits outside the packet's named modules.** The packet needed these hooks, and I kept them small. Older scenes behave as before, apart from the extra bed:
| File | Change |
| --- | --- |
| `src/weapons/rifle.gd` | Optional `shot_tracer` replaces the flat ray; `take_hit` also gets `origin` |
| `src/player/operator.gd` | `hold_control()` for staggers, tipping and death; `crouch_shown` so a braced shot rises |
| `src/study/deck_layout.gd`, `deck_builder.gd` | Props keep their `cover`; optional `breaches` (wall openings with floor) |
| `src/sight/sight_deck.gd` | `_help_text()` hook |

**The other decks changed slightly.** The third bed also appears as a plain upright box in `weight_deck`, `sight_deck` and `scale_deck`. Their captures weren't retaken.

## Checks run
**Headless: 153 passed, 0 failed, 0 load errors** (96 before T005). `--import` exits 0 with no errors. It still prints 13 `invalid UID` warnings for `operator.glb`, in files I didn't touch; I didn't check whether they predate this branch.

| Packet check | Test |
| --- | --- |
| low cover blocks crouched, not standing | `test_low_cover_blocks_a_crouched_target_and_not_a_standing_one` |
| braced firing exposes you | `test_braced_firing_exposes_you`, `test_the_mark_is_per_shooter_not_per_box` |
| tall cover blocks both | `test_tall_cover_blocks_both` |
| tipping changes the class | `test_tipping_the_bed_changes_its_cover_class_after_the_commitment`, plus the scene test |
| stagger at the threshold | `test_a_stagger_triggers_at_the_threshold_and_not_under_it`, `test_a_big_hit_staggers_in_the_scene` |
| puddle damage over time | `test_puddle_damage_over_time_only_while_standing_in_it`, plus the scene test |
| hears a shot → investigate | `test_a_shot_it_hears_sends_it_to_investigate`, `test_the_rifle_and_sprinting_make_noise_in_the_scene` |
| sees the player → stalk | `test_seeing_the_player_starts_the_stalk` |
| in range → spit / lunge | `test_in_range_it_spits_with_a_telegraphed_windup`, `test_close_up_it_lunges_then_recovers_vulnerable` |
| spit blocked far, arcs over near | `test_a_spit_is_blocked_by_low_cover_at_long_range_and_arcs_over_at_short_range`, `test_a_flying_glob_ends_on_cover_or_on_the_body` |
| ambush fires once, only behind | `test_the_ambush_fires_once_only_behind_the_player`, `test_the_burst_fires_once_behind_the_player_and_lets_it_out` |
| run log has its fields | `test_the_run_log_file_is_written_with_every_field`, `test_death_writes_the_log_and_a_respawn_resets_everything` |
| numbers from data | `test_t005_scripts_have_no_tunable_literals` (18 scripts; capture code exempt), plus edited-value tests |

Also tested: 6 to 8 rifle hits to kill (the numbers give 7), stalk paths leave the straight line and prefer hidden points, shut doors stop paths and bodies, and the E and Backspace key handlers (fed key events directly).

I broke the code on purpose to prove the tests bite, then restored it:
| Break | Tests that fail |
| --- | --- |
| low cover has no height | 8 |
| bracing doesn't raise you | 2 |
| the spit never arcs | 3 |
| ambush fires while you look at it | 2 |
| stagger only above the threshold | 1 |
| log drops `killed_by` | 2 |

**Frame time with two stalkers hunting: 3.50 ms average, 5.20 ms p95.** Against `sight_deck`, that is +0.26 ms average and +1.5 ms p95.
| Scene | Average ms | p95 ms | p99 ms | Max ms |
| --- | --- | --- | --- | --- |
| `stalker_deck` (3 runs) | 3.50, 3.49, 3.51 | 5.20, 5.21, 5.20 | 5.65, 5.53, 5.75 | 18.0, 16.3, 17.0 |
| `sight_deck` (2 runs) | 3.24, 3.24 | 3.66, 3.66 | 4.09, 4.05 | 18.8, 19.9 |

- **Conditions:** 15 s windows at 1920×954 (not a true 1080p), M2 Pro, Metal, MSAA 4x, vsync off, load average 1.6 to 3.4. `frametime.json` holds the last run.
- **The two demos differ:** the `sight_deck` demo paces a doorway and sweeps the light, so this comparison is rough. Neither fires.
- **Where the p95 goes:** one world step of stalkers and cover costs 1.89 ms on average and 5.93 ms at worst, measured headless over 600 steps. It runs at 60 Hz, which is my explanation for the p95 rising more than the average; I didn't profile it further.

**Headless bot runs (not a test, just a look at behaviour):**
- Standing still after the burst: the first lunge began about 1.7 s after the stalker woke, and the suit was gone at about 12 s, mostly to lunges.
- Crouched behind the overturned bed with a stalker 6 m away through the door: the first spit stopped on the bed. The stalker then closed in, and the second spit came over at 3 m. The bot never moved, so the puddles did half the damage.

## Screenshots (`docs/screens/T005/`)
- `cover_protected`: crouched behind the overturned bed, green shield.
- `cover_braced_exposed`: firing from the same spot, shield open, stalker flashing from the hit.
- `bed_tipping`, `spit_windup`, `acid_puddle`, `lunge_charge`, `lunge_recover`, `death_screen`.
- `ambush_1_burst`, `ambush_2_turning`, `ambush_3_coming_out`: the turn is scripted to start right after the burst, at real turn rates.
- `stalker_deck`, `stalker_deck_overlay`: the end of the measuring window.

Stalkers are placed by script in these shots, except in the ambush. The positions are staged; the states and timing are real. Only stills were reviewed, so motion hasn't been judged.

## Decisions made without you (easy to change)
- **Stalkers can't open doors.** A shut door holds one, and a noise brings it up to the door. That makes doors a real tool and makes opening one scary, but you can shut yourself in a room and be safe. This is the decision most likely to need your call.
- **Crouching behind low cover hides you from its eyes,** not just from its spit, unless you're within 2.6 m. Firing tells it where you are.
- **Low cover counts as 0.9 m whatever the mesh is:** the 0.8 m crates, 1.1 m consoles and 1.2 m crates are all the same. Ammo crates (0.6 m) are no cover.
- **Close range lobs, far range is flat.** It arcs over within about 3 to 5 m, which is the packet's rule rather than physics.
- **One shield per hunting stalker.** It counts only stalkers with no wall or shut door between you. It uses the real arc, so it goes hollow when one gets close enough to lob over.
- **The spawn moves south of the panel in this scene only,** so you have to walk past it. The closet behind the panel exists only here too.
- **Start numbers:** suit 100, spit 16, lunge 34 (staggers), puddle 9 per second for 6 s, stalker health 126 (7 rifle hits), stalk speed 2.5 m/s (you walk at 3.4). Taking hits during recovery costs it 1.5 times the damage.
- **A direct spit also leaves a puddle at your feet,** so it pushes you off your spot.
- **Hits don't interrupt a wind-up.** A flinch slows it and flashes it, and nothing more.
- **No death animation:** the operator stops, and the death screen shows who killed you and how.

## Known limits
- **The mark can tell you something you can't see:** a shield appears for a hunting stalker outside your light, as long as no wall is between you. That may be good dread or a leak.
- **Shots still hit stalkers you can't see,** and hidden stalkers pop in with no fade (both as with T004's targets).
- **Rounds fly flat at 1.2 m, exactly the top of the 1.2 m crates' physics boxes.** I didn't test a shot grazing one, so those crates may stop rounds that their 0.9 m cover height wouldn't.
- **The panel is off-screen at the moment of the burst** when you face north, because the camera leads your aim. That is the point of the pillar, but it means you hear it before you see anything, and the sound is only a placeholder.
- **A bed can land on a stalker:** a tipped bed's collision appears when it lands, even if one is standing there. Not seen, not tested.
- **The run log is written on death, on Backspace and on window close.** The close path is tested by sending the notification, not by a real quit. Files: `~/Library/Application Support/Godot/app_userdata/Grave Rats/runs/`.

## Needs John's eye
1. *"Is moving through these rooms with a flashlight tense and fun?"* Play it with F1 open.
2. **Does the burst work?** Do you hear it, turn, and still feel late? First levers: F1 "Ambush", and the 0.55 s before it comes out.
3. **Should stalkers open doors?**
4. **Is the bed worth tipping?** You lose 0.8 s for cover that a close stalker lobs over.
5. **Are the sounds loud enough to warn you?** They're generated noise, and nobody has heard them.
