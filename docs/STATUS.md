# Grave Rats — status

**Stage:** 2 (core loop, grey box): John played it 2026-10-30. Gate not passed: the stalker is too slow and weak to scare. T006 (make it dangerous, plus his fixes) and A005 (hauler turnaround, HUD, title) queued.

## Stage plan (each stage ends in a gate John answers by playing)
0. **Skeleton.** Godot project, headless tests, capture tool, runners. Gate: none (lead checks). **Done 2026-10-30.**
1. **Camera and scale (grey box).** Perspective camera rig and a grey-box deck at the chosen proportions. Gate: *"Does this framing feel like the concept?"*
2. **Core loop (grey box).** Move, aim, shoot, crouch, flashlight sight, doors, one enemy type, one small deck. Gate: *"Is moving through these rooms with a flashlight tense and fun?"*
3. **Vertical slice art.** Medbay, corridor and cargo at concept quality: kit, materials, lighting, crew model and animation. Gate: *"Does it match or beat the concept?"*
4. **Systems.** Cover with height, loot and carry decisions, extraction, threat variety, sound. Gate per system.
5. **Co-op.** 2–4 players over the network. Gate: a real session with the Monday crew.
Later (parked): competitive modes, ship generation, contracts and meta, the threat roster.

## What builders need now
- Code: T006 queued (faster, dodging stalker; ambush that bites; doors broken slowly; crouch corkscrew, flashlight flicker, cover readout, camera between presets 1 and 2, awareness 2.2 m, tall crates block sight, stalker_deck as main scene).
- Art: A005 queued (orange hauler model sheet, crew variety, suit-OS HUD with the ring, title art recomposed, logo set).

## Open questions (for John)
- Stage 2 gate, again after T006: tense and fun with a dangerous stalker?
- Stage 1: John picked rooms ×0.85, character ×1.15, fade cut-away (T006 addendum makes them default). Confirm the framing after T006.
- A shooting enemy next (security robot or rival pirate), then lock-to-cover (his Gears idea)? Lead's plan: yes, T007 after T006.
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
- Stalker: a hit interrupting a wind-up; a player death animation.

## Last session
2026-10-30 (lead): John played the stalker deck. Feedback in `docs/playtests/log.md`; picks in `docs/decisions.md`. Wrote and queued T006 and A005.
2026-10-30 (lead, earlier): merged T005 (153/153 reproduced); morning report published.
