# Grave Rats — status

**Stage:** 2 (core loop, grey box): John played it 2026-10-30; gate not passed then. T006 (dangerous stalker, his fixes) is built and needs his play. A005 (hauler turnaround, HUD, title) queued.

## Stage plan (each stage ends in a gate John answers by playing)
0. **Skeleton.** Godot project, headless tests, capture tool, runners. Gate: none (lead checks). **Done 2026-10-30.**
1. **Camera and scale (grey box).** Perspective camera rig and a grey-box deck at the chosen proportions. Gate: *"Does this framing feel like the concept?"*
2. **Core loop (grey box).** Move, aim, shoot, crouch, flashlight sight, doors, one enemy type, one small deck. Gate: *"Is moving through these rooms with a flashlight tense and fun?"*
3. **Vertical slice art.** Medbay, corridor and cargo at concept quality: kit, materials, lighting, crew model and animation. Gate: *"Does it match or beat the concept?"*
4. **Systems.** Cover with height, loot and carry decisions, extraction, threat variety, sound. Gate per system.
5. **Co-op.** 2–4 players over the network. Gate: a real session with the Monday crew.
Later (parked): competitive modes, ship generation, contracts and meta, the threat roster.

## What builders need now
- Code: T006 awaiting merge and John's play (`docs/handoffs/auto-T006.md`). Next, by the lead's plan: T007, a shooting enemy.
- Art: A005 queued (orange hauler model sheet, crew variety, suit-OS HUD with the ring, title art recomposed, logo set).

## Open questions (for John)
- Stage 2 gate, on T006: tense and fun with a dangerous stalker? Too much?
- Flashlight flicker: not reproduced, so not confirmed fixed. Does it still happen, and which F1 lever clears it?
- Should a gunshot through a shut door start a stalker breaking it? (Built that way.)
- Room and character scale: untested (the keys only work in `scenes/study/scale_deck.tscn`, not the stalker deck).
- A shooting enemy next (security robot or rival pirate), then lock-to-cover (his Gears idea)? Lead's plan: yes, T007 after T006.
- `tools/capture.sh` reached 1920×1080 on the 2026-10-30 T006 runs (it was 1920×954 in T005); still worth a look if it drops again.

## Parked
- Lock-to-cover, Gears style (John): brace against cover and shoot over it. Waits for a shooting enemy.
- Visible aim cone may go in the final game (John); keep for testing.
- Competitive modes; procedural ship generation; contracts and meta-progression; the in-game "shift" framing (runs as shifts, timecard end screen).
- T002 capture: auto-walk during the frame-time window so camera motion and cut-away are measured.
- Physics interpolation: the operator steps at 60 Hz, so a faster display may show slight camera jitter.
- Legacy clips: a real walk (the run clips stand in), a crouch walk with real steps, turn-in-place feet. Foot slide numbers in auto-T003.
- `tests/test_deck.gd` `test_props_at_real_size` logs a string-format error (`%` with an array) while passing.
- Sight leaks: the floor aim cone stops at unseen walls, tracers and prompts draw over the mask, hidden targets pop in with no fade.
- T005 limits: the cover shield can show a stalker you can't see; a tipped bed can land on a stalker; 13 `invalid UID` import warnings for `operator.glb`.
- Quiet-machine frame-time baseline for the asset viewer (T001 runs had other load on the Mac).
- `src/study` deck dressing and the deck copy in `stalker_deck` want a real level module.
- Stalker: a hit interrupting a wind-up; a player death animation; a fade for stalkers coming into sight (matters more at dash speed).
- Sight mask edges are stair-stepped in captures; possible flicker contributor, untested.
- Bot that sidesteps the lunge; the current bots only stand or walk straight.

## Last session
2026-10-30 (code): built T006 on `auto/t006-mac`: 181/181 tests, 8 of 8 deliberate breaks caught. Standing bot dies at 4.98 s (was 8.57 s); the ambush hits both bots in 12 of 12 runs (was 1 of 12). Corkscrew found and fixed. Open: flicker not reproduced; a perfect-aim bot lands hits more easily than before. Nobody has played it.
