# Grave Rats — status

**Stage:** 2 gate **passed** 2026-10-30 (tag `stage-2`). T007 (rival pirates, lock-to-cover, plus the scale/fade defaults, the flicker fix and the door-noise rule) queued. Stage 1 framing confirmation waits for T007's new defaults; stage 3 (vertical slice art) next.

## Stage plan (each stage ends in a gate John answers by playing)
0. **Skeleton.** Godot project, headless tests, capture tool, runners. Gate: none (lead checks). **Done 2026-10-30.**
1. **Camera and scale (grey box).** Perspective camera rig and a grey-box deck at the chosen proportions. Gate: *"Does this framing feel like the concept?"*
2. **Core loop (grey box).** Move, aim, shoot, crouch, flashlight sight, doors, one enemy type, one small deck. Gate: *"Is moving through these rooms with a flashlight tense and fun?"*
3. **Vertical slice art.** Medbay, corridor and cargo at concept quality: kit, materials, lighting, crew model and animation. Gate: *"Does it match or beat the concept?"*
4. **Systems.** Cover with height, loot and carry decisions, extraction, threat variety, sound. Gate per system.
5. **Co-op.** 2–4 players over the network. Gate: a real session with the Monday crew.
Later (parked): competitive modes, ship generation, contracts and meta, the threat roster.

## What builders need now
- Code: T006 merged (lead reviewed, 181/181 reproduced). T007 queued; its step 0 applies John's stage 1 scale and fade picks.
- Art: A006 merged (paint-overs of real frames, kit sheets at game dimensions, material board). Lane idle until John approves the slice target and says which pieces he models.

## Open questions (for John)
- A006: is the slice target right (paint-overs 01b, 02b, 03c, 04b)? Which pieces will John model himself (walls 05b, doors 06c, props 07b), and which do scripts build? The paint-overs show T006's scale (×1.0), not his ×0.85/×1.15.
- T006 open: is 8 s of door banging right?
- T006 decisions: 1.2 m crates are now tall cover (you can't fire over them); locked doors hold stalkers; your light makes a prowler hunt you.
- Stage 1: John picked rooms ×0.85, character ×1.15, fade cut-away (T006 addendum makes them default). Confirm the framing after T006.
- `tools/capture.sh` only reaches 1920×954 on this display; accept, or make the capture window borderless?

## Parked
- Next code candidate (after T007): the suit-OS HUD with the noise ring (decided 2026-10-30).
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
2026-10-30 (lead): merged T006 (181/181 reproduced; it predates the scale/fade addendum, so that moved into T007 step 0) and A005; queued T007.
2026-10-30 (code, unattended): T006: dash, dodge, faster spit, an ambush that hits 12/12 bots, doors broken in 8 s, crouch corkscrew fixed, IN COVER, LIGHT OFF, camera 60°/20.5 m. Flicker not reproduced; one door-panel flash fixed.
