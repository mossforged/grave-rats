# Grave Rats — status

**Stage:** 3 in progress. Stage 2 passed (tag `stage-2`, pushed by John). T009 merged. T010 done on `auto/t010-mac`, waiting on John's gate: *does it match or beat the concept?*

## Stage plan (each stage ends in a gate John answers by playing)
0. **Skeleton.** Godot project, headless tests, capture tool, runners. Gate: none (lead checks). **Done 2026-10-30.**
1. **Camera and scale (grey box).** Perspective camera rig and a grey-box deck at the chosen proportions. Gate: *"Does this framing feel like the concept?"*
2. **Core loop (grey box).** Move, aim, shoot, crouch, flashlight sight, doors, one enemy type, one small deck. Gate: *"Is moving through these rooms with a flashlight tense and fun?"*
3. **Vertical slice art.** Medbay, corridor and cargo at concept quality: kit, materials, lighting, crew model and animation. Gate: *"Does it match or beat the concept?"*
4. **Systems.** Cover with height, loot and carry decisions, extraction, threat variety, sound. Gate per system.
5. **Co-op.** 2–4 players over the network. Gate: a real session with the Monday crew.
Later (parked): Open Tender (competitive mode, decided 2026-10-31; see decisions), ship generation, contracts and meta, the threat roster.

## What builders need now
- Queue order (lead): T010 awaiting review and John's gate. Meshy bed, console and stalker slot in next (`data/kit.json` "slots").
- Code: T009 merged. T010 on `auto/t010-mac`: 263/263 tests; 7.81 ms pirate_deck, 7.12 ms stalker_deck; see `docs/handoffs/auto-T010.md`.
- Art: A006 merged and approved. A007 merged: Meshy inputs for stalker, bed and console in `assets/source/meshy/input/`; the rifle was refused by the image tool. The hauler is in the game (`assets/game/hauler/`).

## Open questions (for John)
- T010 gate: sheet at `docs/screens/T010/sheet.png`, then play. My read: mood and palette are there; surfaces are too clean and the Meshy props are still boxes. Watch for fog shimmer and whether a side door's state reads.
- T009 play: does the hauler look and move right from the game camera? Known: the head bows forward when aiming, the left hand sits below the foregrip, feet slide on strafes, and firing has no clip yet. Next clips worth fetching from Mixamo: strafe run left/right, run backward, rifle firing, crouch backward/strafes, low-ready walk.
- T009 play: does the hauler look and move right from the game camera? Nobody has seen it move. Watch strafing and walking backward (feet slide most, slow clips sped up), the bowed head when aiming, and turning on the spot. Clips to fetch: handoff.
- T008 play: is the flicker gone? Does the suit-OS HUD read? Does the noise ring help? (Placeholder O2 and salvage counters.)
- T007 play (`scenes/pirates/pirate_deck.tscn`, now the main scene): does cover matter? Is lock-to-cover (Space, RMB) better than plain crouch (F1 toggle)? Too lethal (3.4 s in the open)? Do the crew read as rivals? Do the barks give too much away? Bots: cover doubles survival; lock is no better than crouch when fighting from one spot.
- Meshy models from John (`docs/handoffs/meshy-shortlist.md`): hauler, stalker, bed, console, rifle.
- T006 open: is 8 s of door banging right?
- T006 decisions: 1.2 m crates are now tall cover (you can't fire over them); locked doors hold stalkers; your light makes a prowler hunt you.
- Stage 1: John picked rooms ×0.85, character ×1.15, fade cut-away (T006 addendum makes them default). Confirm the framing after T006.
- `tools/capture.sh` only reaches 1920×954 on this display; accept, or make the capture window borderless?

## Parked
- Lock-to-cover, Gears style (John): brace against cover and shoot over it. Waits for a shooting enemy.
- Visible aim cone may go in the final game (John); keep for testing.
- Competitive modes; procedural ship generation; contracts and meta-progression; the in-game "shift" framing (runs as shifts, timecard end screen).
- T002 capture: auto-walk during the frame-time window so camera motion and cut-away are measured.
- Physics interpolation: the operator steps at 60 Hz, so a faster display may show slight camera jitter.
- Legacy clips: a real walk (the run clips stand in), a crouch walk with real steps, turn-in-place feet. Foot slide numbers in auto-T003.
- `tests/test_deck.gd` `test_props_at_real_size` logs a string-format error (`%` with an array) while passing.
- Sight leaks: the floor aim cone stops at unseen walls, tracers and prompts draw over the mask, hidden targets pop in with no fade.
- T005 limits: the cover shield can show a stalker you can't see; 1.2 m crate physics boxes may stop 1.2 m rounds; a tipped bed can land on a stalker; 13 `invalid UID` import warnings for `operator.glb`.
- Quiet-machine frame-time baseline for the asset viewer (T001 runs had other load on the Mac).
- `src/study` deck dressing and the deck copy in `stalker_deck` want a real level module.
- Stalker: a hit interrupting a wind-up.
- A roll move: the hauler has the clip (`anim.play_state("roll")`), but no key or rule uses it yet.
- `stalker_deck` stagger doesn't call `operator.play_hit` (`src/enemies` was outside T009); its death does play the clip.
- Flaky test: `test_hauler` turn-in-place counts frames; failed 1 run of 4 on unchanged main.
- T010: reflection probes for wet floor sheen; hide the aim cone for the final look; faded walls draw over the sight mask.
- Hauler: left-hand IK onto the foregrip; separate left and right strafe clip speeds; the Meshy clips' feet aren't auto-grounded.

## Last session
2026-10-31 (code, unattended): T010: kit, materials, practicals, fog and signage generated from `data/kit.json`; door leaf dents from the T006 value; collision, occluders and cover identical to T009 by snapshot. Not seen in motion; T008 flicker not re-measured with fog.
