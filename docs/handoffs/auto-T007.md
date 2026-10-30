# T007 handoff: rival pirates that shoot back, and lock-to-cover

Branch `auto/t007-mac`. Play it: F5 in the editor or `godot --path .`. **The main scene is now `pirate_deck`.** The T006 stalker deck, whose stage 2 gate is still open: `godot --path . scenes/enemies/stalker_deck.tscn`.

New keys in `pirate_deck`: **Space** locks to low cover, or lets go. **RMB** aims over it, and LMB also raises you and fires. E door, 6 default camera, Backspace resets everything.

**Nobody has played this.** The numbers below come from bots and the pictures are stills, so motion, feel and the placeholder gunshot are unjudged.

**What the bots say about John's two questions:**
1. **Does cover matter now? Yes.** A bot that never fires lives 7.7 s behind low cover against 3.4 s in the open, and its cover stops about 20 rounds. It dies because the flanker gets an open line at about 4.4 s.
2. **Is lock-to-cover better than crouching? Not on these bots.** Doing nothing, it's the same. Fighting from one spot, it's worse: plain crouch killed 1.42 pirates on average and 5 of 12 runs were alive at 60 s; lock killed 0.42 and all 12 died. Plain crouch fires the instant you click, which T006 set and this packet says must not change, while lock has to rise first. These bots stand on one spot, so they don't test what lock is for (getting into cover fast, sliding along it). That's John's call.

## What changed
- **Step 0 (first commit):** rooms ×0.85, character ×1.15, fade cut-away at 0.65, with a new F1 slider under Camera.
- **Pirates (`src/pirates/`, `data/pirates.json`):** a squad of 3, Hale, Okoro and Brandt, in the legacy operator recoloured white and navy from data. Same rifle model; the source glTF is untouched. Dead ones tip over, with no death animation.
- **Weight:** they run on your own `OperatorModel`, `AimCone` and `RifleState`, with numbers starting equal to yours. No aim assist.
- **Behaviour:** they loot until they see or hear you, or your light lands on them. Then the nearest suppresses your last known spot, the furthest flanks once that fire starts, and the third supports. They bark, reload behind cover, hand suppression over during a reload, and fall back once when hurt.
- **Rounds:** the same 3D trace as yours, with tracers. A crouched pirate behind low cover is protected, and a braced one is exposed.
- **Lock-to-cover (`src/cover/cover_lock.gd`, `lock_driver.gd`):** as the packet describes, on an F1 toggle, default on. Rules are in `src/cover/CONTRACT.md`.
- **Firefight deck (`scenes/pirates/pirate_deck.tscn`):** the hold, the junction and the side corridor, 21 pieces of cover. You start in the junction south of the shut main door.
- **Run log:** `time_locked_s`, `shots_blocked_for_you`, `your_shots_blocked`, `damage_by_source.rifle`, and `killed_by` {`pirate`, `how`}.
- **F1:** new sections Lock-to-cover, Pirates: weight, Pirates: fight.

**Edits outside the named modules:** `data/deck.json` and `data/camera.json` (step 0), `data/debug.json` (sliders), `project.godot` (main scene), `src/run_log` (the packet asks), `src/player/operator.gd` and `src/sight/sight_deck.gd` (door clearance, below), a junction capture shot in `src/enemies/stalker_deck.gd`, and the new tool `tools/t007_bots.gd`.

## Step 0: the failing test and the fit check
The lead's guess was a test position assuming room ×1.0. **It was the character scale.** The test stood the player 0.45 m from a bed with a 0.46 m capsule, so physics pushed it out 1.1 cm: "can't walk off while tipping". The test now stands clear of the bed by a computed margin, and uses the second bed, because beds 0 and 1 are close enough at ×0.85 that the gap is nearer the other one.

| Fit check at ×0.85 and ×1.15 | Result |
| --- | --- |
| Props inside their space, none in a doorway | OK (new test) |
| Prop overlaps | **Two cargo crates overlapped by 24 cm. Fixed**: moved to x 0.81 and 0.91 |
| Door clearance | **It used the unscaled 0.40 m radius, so a door could shut on 6 cm of you. Fixed**: `Operator.body_radius()` |
| Doors, spawn, stalker patrols, medbay-to-cargo path | OK |
| Ambush panel | Fires and hits: bots below |
| Gap between beds 0 and 1 | Fits, but tight: 1.02 m for a 0.92 m body |

**Operator's share of view height at the default camera: 7.4%** (2.07 m tall, pitch 60°, 20.5 m, fov 35°; projected, standing). Captures: `step0_medbay_defaults`, `step0_junction_defaults`.

**The new scale moved T006's numbers a little** (`tools/t006_bots.gd`, 12 runs). The rooms are tighter, so the stalker has less room to dodge, and **"harder to land" slipped further**:

| Stalker deck bot | T006 | At the new defaults |
| --- | --- | --- |
| Standing still: dies at | 4.98 s | 5.17 s |
| Crouched behind the bed: dies at | 6.99 s | 8.57 s |
| Ambush, reacts after 0.45 s: hit in, at | 12/12, 1.48 s | 12/12, 1.40 s |
| Ambush, turns at once: hit in, at | 12/12, 1.22 s | 12/12, 1.15 s |
| Tracks with 0.2 s lag: hit rate, kill time | 31-38%, 2.60-3.24 s | 45%, 2.22 s |
| Tracks perfectly: hit rate, kill time | 61%, 1.62 s | 72%, 1.32 s |

I left the stalker's numbers alone: the packet doesn't ask, and John hasn't played it.

## Checks run
**Headless: 210 passed, 0 failed, 0 load errors** (181 before T007). After I fixed one random test, 209 of them passed 5 runs in a row; the last test (tall cover) came after that and has passed its 2 full runs since. `--import` exits 0 with no errors, and still prints the 13 known `invalid UID` warnings for `operator.glb`.

| Packet check | Test in `tests/test_pirates.gd` |
| --- | --- |
| turn, settle and reload numbers from data, matching your rules | `test_their_numbers_come_from_data_and_start_equal_to_yours`, `test_it_turns_at_your_cap_however_much_it_wants_to`, `test_its_aim_settles_and_recoil_kicks_as_yours_do`, `test_a_reload_is_a_commitment_for_it_too` |
| crouched protected, braced exposed | `test_crouched_behind_low_cover_is_protected_and_braced_is_exposed` |
| suppressor fires while flanker reaches an open line | `test_the_suppressor_fires_at_your_cover_while_the_flanker_gets_an_open_line` |
| lock: only low cover, protected, exposed aiming over, releases | `test_lock_snaps_only_next_to_low_cover`, `test_lock_raises_and_lowers_on_data_times_and_slides_and_releases`, `test_locked_in_the_scene_is_protected_then_exposed_then_released` |
| toggle off: crouch unchanged | `test_with_the_toggle_off_the_key_does_nothing_and_crouch_is_the_plain_one` |
| run log fields | `test_the_run_log_has_the_new_fields_and_names_a_pirate`, `test_a_pirate_kill_lands_in_the_log` |

The toggle test checks T006's rules in this deck (instant fire, brace on firing, `brace_hold_s`, `IN COVER`, no snap). Separately, the plain crouch code path is what T006 shipped: while free, the driver touches nothing.

Breaking the code on purpose, then restoring it:

| Break | Tests that fail |
| --- | --- |
| a crouched pirate counts as braced | 1 |
| lock accepts tall cover | 1 |
| the suppressor never engages | 1 |
| a pirate turns instantly | 1 |
| moving away doesn't release the lock | 2 |
| the lock toggle is ignored | 1 |

### Bot report (`tools/t007_bots.gd`, 12 runs each, same seeds, final numbers)
All bots start at the same long crate in the hold, with doors open and the squad told where they are. The "fights" bots see only the real sight wedge and circle, react after 0.3 s, aim 0.2 s behind the target, and fire 0.45 s bursts every 1.55 s.

| Bot | Time to die, mean (range) | First hit | Died | Pirates killed | Rounds your cover stopped |
| --- | --- | --- | --- | --- | --- |
| Open, never fires | **3.37 s** (2.73-3.97) | 1.02 s | 12/12 | 0 | 0 |
| Crouched, never fires | **7.66 s** (7.28-8.45) | 4.42 s | 12/12 | 0 | 19.8 |
| Locked, never fires | **7.77 s** (7.27-9.08) | 4.43 s | 12/12 | 0 | 19.6 |
| Open, fights | **3.86 s** (2.85-5.35) | 1.02 s | 12/12 | 0.17 | 0 |
| Crouched, fights | **5.60 s** (5.10-6.58) when it died | 1.72 s | 7/12 | 1.42 | 2.8 |
| Locked, fights | **5.62 s** (4.93-6.15) | 1.74 s | 12/12 | 0.42 | 5.6 |

- **The 5 crouch runs that lived to 60 s** were a stalemate, not a win. No bot ever cleared the squad. A lone pirate holds its cover and won't come for you, and the bot never moves.
- **Lock timings were already shortened** after a first run (raise 0.2 → 0.12 s, lower 0.15 → 0.12 s, hold 0.45 → 0.2 s), and it's still behind. First lever: F1 Raise to braced s.
- **By the data, not measured:** from 1 m away, lock has you protected in about 0.18 s (snap 0.16 s, crouch 0.18 s). Walking there and crouching takes longer, and it's what no bot here tests.
- **The bots are limited:** they hold one spot, never retreat and never reposition. They say more about the squad than about how a person will fight.

### Frame time, squad of 3 fighting (15 s window, 1920×1080, M2 Pro, Metal, MSAA 4x, vsync off)
| Run | Average ms | p95 ms | p99 ms | Max ms |
| --- | --- | --- | --- | --- |
| `pirate_deck`, final capture | 8.32 | 15.79 | 18.90 | 25.3 |
| `pirate_deck`, earlier runs of the same scene | 8.57, 8.50, 7.92 | 14.87, 14.63, 16.96 | 20.69, -, 24.39 | 91.6, -, 67.7 |
| `pirate_deck`, pirate light shadows off, one run | 8.33 | 15.02 | 18.27 | 21.9 |
| `stalker_deck`, same session, one run | 9.11 | 15.64 | 35.52 | 177.6 |

**About the same as `stalker_deck`, and not a quiet-machine number:** load average was 5-9 throughout, with other apps running. So don't compare it with T005's 3.50 ms. Turning off the pirates' shadows showed no clear saving in one run. Nothing dies in this window, and the player fires 60-odd rounds. A headless replay of the same script counted pirate rounds at 8, 31 and 9 in 15 s, so all three fire, but most of the window is moving and waiting, not all three shooting at once.

## Screenshots (`docs/screens/T007/`)
`pirate_beside_operator` (the camera is moved in, with an extra light; only this shot), `pirate_braced_firing`, `flank_1_called`, `flank_2_moving`, `flank_3_open_line`, `lock_1_protected`, `lock_2_aiming_over`, `lock_prompt`, `squad_looting`, `pirate_light_beside_yours`, `deck_overview` (sight mask off, to show the layout), `death_screen`, `step0_medbay_defaults`, `step0_junction_defaults`, `pirate_deck`, `pirate_deck_overlay`, `frametime.json`, `frametime_stalker_deck_same_session.json`.

`pirate_braced_firing` has the hit flash removed by the script, since it reds out the frame. Positions are staged except the flank, where the squad runs itself. `pirate_light_beside_yours` shows the colder beam beside yours. I did not get a clean shot of a beam arriving ahead of a hidden pirate, so **that tell is unconfirmed in a picture**.

## Decisions made without you (easy to change)
- **Main scene is now `pirate_deck`,** following the "F5 runs the latest build" rule. This is the one most likely to get in the way, since stage 2 still waits on your play of the stalker deck: command at the top.
- **Pirate rounds do 8, yours 18,** although their rifle is otherwise yours. At 18 a bot in the open died very fast (tries in the open: 12 → 1.8 s, on an earlier version of the bot clock; 10 → 2.3 s; 8 → 3.4 s). F1: Round damage.
- **Stagger from rounds adding up:** a single round is never a quarter of a suit, so "staggers on big hits" could never fire. Now a quarter of the suit inside 0.6 s counts, for them (2 of your rounds) and for you in this deck (4 of theirs). The stalker deck is unchanged.
- **Lock-to-cover is only in `pirate_deck`,** so the stalker deck under the stage 2 gate doesn't change.
- **Medbay removed** from this deck; it plays on a copy, so the data is untouched. The north cargo door is unlocked here, giving flank routes through it and through the side corridor.
- **Barks show through walls.** A voice carries, and being heard calling "Flanking!" is your warning. It does give their position away.
- **Pirate rounds pass through other pirates,** and a pirate holds fire with a friend on the line. They also walk through each other: one dug in on a lane stopped a flanker dead.
- **Nav cell 0.25 m** rather than the stalker's 0.5 m, which cut the hold into pockets.
- **The flanker waits** for covering fire (or 3 s), and its route stays 3 m from you. Before that, one sprinted past the player through the same door.
- **Added beyond the packet, because it needed them:** a placeholder gunshot and a `LOCKED` / `LOCKED: EXPOSED` readout.

## Known limits
- A lone pirate never advances, and the squad never pushes you out of cover except by flanking.
- Pirates don't fire on the move or from standing, and don't throw anything.
- Tall-cover peeking is tested on the rules, but I haven't seen it in a capture.
- Sliding along cover stops at the end of that piece: no turning corners or crossing to the next piece.
- The `Space` prompt shows whenever low cover is in reach, even crouched, and it can overlap the door prompt.
- A remembered room shows a pirate's light dimly, even from outside it. That's real lighting under the mask, and I left it as a tell.
- Pirates pop in with no fade, like stalkers.

## Needs John's eye
1. *"Does cover matter now? Is lock-to-cover better than plain crouching?"* Try both: F1, Lock-to-cover 1 or 0.
2. **Too lethal?** 3.4 s in the open, with the flanker on you in about 4.4 s. First levers: Round damage, Flanker gap, Flank at least °.
3. **If lock feels worse too,** try Raise to braced s near 0 first. Otherwise, the real option is making plain crouch fire slower, which this packet ruled out.
4. **Does the crew read as rivals?** White and navy, no orange.
5. **Do the barks work, or do they give too much away?**
