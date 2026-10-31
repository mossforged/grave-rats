# Grave Rats — status

**Stage:** 3 in progress. Stage 2 passed (tag `stage-2`, pushed by John). T009 done on `auto/t009-mac`, waiting on John: his hauler is now the player and the pirates' body. T010 is next once it merges.

## Stage plan (each stage ends in a gate John answers by playing)
0. **Skeleton.** Godot project, headless tests, capture tool, runners. Gate: none (lead checks). **Done 2026-10-30.**
1. **Camera and scale (grey box).** Perspective camera rig and a grey-box deck at the chosen proportions. Gate: *"Does this framing feel like the concept?"*
2. **Core loop (grey box).** Move, aim, shoot, crouch, flashlight sight, doors, one enemy type, one small deck. Gate: *"Is moving through these rooms with a flashlight tense and fun?"*
3. **Vertical slice art.** Medbay, corridor and cargo at concept quality: kit, materials, lighting, crew model and animation. Gate: *"Does it match or beat the concept?"*
4. **Systems.** Cover with height, loot and carry decisions, extraction, threat variety, sound. Gate per system.
5. **Co-op.** 2–4 players over the network. Gate: a real session with the Monday crew.
Later (parked): Open Tender (competitive mode, decided 2026-10-31; see decisions), ship generation, contracts and meta, the threat roster.

## What builders need now
- Queue order (lead): T009 awaiting review and John's gate → T010 (slice kit, held until T009 merges).
- Code: T008 merged. T009 on `auto/t009-mac`: 247/247 tests; see `docs/handoffs/auto-T009.md`.
- Art: A006 merged and approved. A007 merged: Meshy inputs for stalker, bed and console in `assets/source/meshy/input/`; the rifle was refused by the image tool. The hauler is in the game (`assets/game/hauler/`).

## Open questions (for John)
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
- Hauler: left-hand IK onto the foregrip; separate left and right strafe clip speeds; the Meshy clips' feet aren't auto-grounded.

## Last session
2026-10-31 (lead): merged T009 (247/247 reproduced); queued T010. Open Tender decided as the competitive mode. A009 and A010 queued for the art lane.
2026-10-31 (code, unattended): T009: hauler imported at 1.80 m; Meshy and Mixamo clips retargeted per state in `data/hauler_anim.json`; root motion pinned; rifle on the right hand; pirates repainted navy by shader; `body` switch keeps the legacy model.
