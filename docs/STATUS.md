# Grave Rats — status

**Stage:** 1 (camera and scale) built on `auto/t002-mac`, waiting for John's gate. **Next:** John plays `scenes/study/scale_deck.tscn` (keys 1–5 camera, 6/7/8 room scale, 9/0 character scale, C cut-away) and picks a preset and scale; then T003.

## Stage plan (each stage ends in a gate John answers by playing)
0. **Skeleton.** Godot project, headless tests, capture tool, runners. Gate: none (lead checks). **Done 2026-10-30.**
1. **Camera and scale (grey box).** Perspective camera rig and a grey-box deck at the chosen proportions. Gate: *"Does this framing feel like the concept?"*
2. **Core loop (grey box).** Move, aim, shoot, crouch, flashlight sight, doors, one enemy type, one small deck. Gate: *"Is moving through these rooms with a flashlight tense and fun?"*
3. **Vertical slice art.** Medbay, corridor and cargo at concept quality: kit, materials, lighting, crew model and animation. Gate: *"Does it match or beat the concept?"*
4. **Systems.** Cover with height, loot and carry decisions, extraction, threat variety, sound. Gate per system.
5. **Co-op.** 2–4 players over the network. Gate: a real session with the Monday crew.
Later (parked): competitive modes, ship generation, contracts and meta, the threat roster.

## What builders need now
- Code: T002 done on its branch (handoff `docs/handoffs/auto-T002.md`), needs review and John's gate. T003 (weighty operator and gun) and T004 (sight, flashlight, doors) are written; each queues after the previous one is merged.
- Art: A001 merged (15 concepts). A002 (slice environment concepts: kit, props, cover read, signage, lighting) queued. Crew and threat development waits on John's A001 picks.

## Open questions (for John)
- Stage 1 gate: which camera preset and room/character scale? At 55–65° pitch a real-size operator can't be both ~8% of view height and framed like the panel; preset 1 favours operator size, preset 3 the composition (see auto-T002).
- `tools/capture.sh` only reaches 1920×954 on this display (title bar); accept, or make the capture window borderless (src/debug task)?
- A001 picks: which crew looks and threat directions to develop (art lane's recommendation: 01 orange hauler; 11 acid stalker, with 09 rogue AI as the systemic complement).
- How weighty? Turn speed, aim settle and reload times get tuned in stage 2 by playing.

## Parked
- Competitive modes; procedural ship generation; contracts and meta-progression; the in-game "shift" framing (runs as shifts, timecard end screen).
- T002 capture: auto-walk during the frame-time window so camera motion and cut-away are measured.
- Quiet-machine frame-time baseline for the asset viewer (T001 runs had other load on the Mac).

## Last session
2026-10-30 (code, unattended): T002 built: camera rig (`src/camera`), data-driven grey-box deck and stand-in (`src/study`, `scenes/study/scale_deck.tscn`), 5 presets, drop cut-away. 32/32 tests pass, import clean. Concept preset is 2.81 ms avg, 4.41 ms p95 at 1920×954. Captures and sheets are in `docs/screens/T002/`.
