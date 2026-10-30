# Grave Rats — status

**Stage:** 3 starting. Stage 2 passed (tag `stage-2`, pushed by John). T008 built on `auto/t008-mac`, awaiting lead review and John's play: flicker fix, door-noise rule, suit-OS HUD with the noise ring. A007 (Meshy input images) queued. John is modelling from the Meshy shortlist.

## Stage plan (each stage ends in a gate John answers by playing)
0. **Skeleton.** Godot project, headless tests, capture tool, runners. Gate: none (lead checks). **Done 2026-10-30.**
1. **Camera and scale (grey box).** Perspective camera rig and a grey-box deck at the chosen proportions. Gate: *"Does this framing feel like the concept?"*
2. **Core loop (grey box).** Move, aim, shoot, crouch, flashlight sight, doors, one enemy type, one small deck. Gate: *"Is moving through these rooms with a flashlight tense and fun?"*
3. **Vertical slice art.** Medbay, corridor and cargo at concept quality: kit, materials, lighting, crew model and animation. Gate: *"Does it match or beat the concept?"*
4. **Systems.** Cover with height, loot and carry decisions, extraction, threat variety, sound. Gate per system.
5. **Co-op.** 2–4 players over the network. Gate: a real session with the Monday crew.
Later (parked): competitive modes, ship generation, contracts and meta, the threat roster.

## What builders need now
- Code: T008 done on its branch (231/231), not merged. Handoff: `docs/handoffs/auto-T008.md`.
- Art: A006 merged and approved. A007 queued (clean Meshy input images: stalker, bed, console, rifle).

## Open questions (for John)
- T008 play: is the flicker gone (only slow turning at 60 fps was measured)? Does the HUD read? Does the ring help? Walking and crouch-walking now make real noise to the AI (3 m, 1.5 m): keep, or 0 for an empty ring? Gunfire's 22-24 m radius leaves the screen, so each shot also sends a pulse: does it read?
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
- A005-05's cracked-glass HUD frame isn't built. `scale_deck` keeps its own study readout. On the fully lit `weight_deck` the HUD's top-left text washes out.
- Sight leaks: the floor aim cone stops at unseen walls, tracers and prompts draw over the mask, hidden targets pop in with no fade.
- T005 limits: the cover shield can show a stalker you can't see; 1.2 m crate physics boxes may stop 1.2 m rounds; a tipped bed can land on a stalker; 13 `invalid UID` import warnings for `operator.glb`.
- Quiet-machine frame-time baseline for the asset viewer (T001 runs had other load on the Mac).
- `src/study` deck dressing and the deck copy in `stalker_deck` want a real level module.
- Stalker: a hit interrupting a wind-up; a player death animation.

## Last session
2026-10-30 (code, unattended): T008: the beam was the second light shape; it's now a fixed fan in the spot's cone, shared with pirates (turning twinkle matches beam off). Only a hunting stalker breaks doors; a shot through one brings it to the door to give up. Suit OS and noise ring replace the grey-box HUD in every deck. Nobody has played it.
