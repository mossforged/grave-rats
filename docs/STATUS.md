# Grave Rats — status

**Stage:** 1 (camera and scale) merged; gate waits for John. T003 (weighty operator and gun) built on `auto/t003-mac`, waiting for lead review. **Next:** John plays `scenes/study/scale_deck.tscn` (keys 1–5 camera, 6/7/8 room scale, 9/0 character scale, C cut-away) and picks a preset and scale (a data edit), then plays `scenes/player/weight_deck.tscn` and tunes with F1: *"Does it feel heavy without feeling laggy?"*

## Stage plan (each stage ends in a gate John answers by playing)
0. **Skeleton.** Godot project, headless tests, capture tool, runners. Gate: none (lead checks). **Done 2026-10-30.**
1. **Camera and scale (grey box).** Perspective camera rig and a grey-box deck at the chosen proportions. Gate: *"Does this framing feel like the concept?"*
2. **Core loop (grey box).** Move, aim, shoot, crouch, flashlight sight, doors, one enemy type, one small deck. Gate: *"Is moving through these rooms with a flashlight tense and fun?"*
3. **Vertical slice art.** Medbay, corridor and cargo at concept quality: kit, materials, lighting, crew model and animation. Gate: *"Does it match or beat the concept?"*
4. **Systems.** Cover with height, loot and carry decisions, extraction, threat variety, sound. Gate per system.
5. **Co-op.** 2–4 players over the network. Gate: a real session with the Monday crew.
Later (parked): competitive modes, ship generation, contracts and meta, the threat roster.

## What builders need now
- Code: T002 merged; John's gate still open. T003 built, needs lead review and merge (`docs/handoffs/auto-T003.md`). T004 (sight, flashlight, doors) queues after T003 merges.
- Art: A001 and A002 merged. A003 (HUD and company screens) queued. Crew/threat and environment development wait on John's A001/A002 picks.

## Open questions (for John)
- Stage 1 gate: which camera preset and room/character scale? At 55–65° pitch a real-size operator can't be both ~8% of view height and framed like the panel; preset 1 favours operator size, preset 3 the composition (see auto-T002).
- `tools/capture.sh` only reaches 1920×954 on this display (title bar); accept, or make the capture window borderless (src/debug task)?
- A001 picks: which crew looks and threat directions to develop (art lane's recommendation: 01 orange hauler; 11 acid stalker, with 09 rogue AI as the systemic complement).
- A002 picks: walls, doors, floors, props, signage (08b) and lighting (09b) for stage 3 (art lane recommends all, with caveats in auto-A002).
- How weighty? F1 in `weight_deck` tunes every lever; Save writes `data/`.
- Aim marker: the cone is on the floor but the cursor aims at gun height, so the cursor sits about 0.8 m screen-up of the cone's line at the concept camera. A ring marks the floor point under the aim. Keep that, or aim on the floor and accept that shots at a dummy's chest pass behind it? (auto-T003)

## Parked
- Competitive modes; procedural ship generation; contracts and meta-progression; the in-game "shift" framing (runs as shifts, timecard end screen).
- T002 capture: auto-walk during the frame-time window so camera motion and cut-away are measured.
- Physics interpolation: the operator steps at 60 Hz, so a faster display may show slight camera jitter.
- Legacy clips: a real walk (the run clips stand in), a crouch walk with real steps, turn-in-place feet. Foot slide numbers in auto-T003.
- `tests/test_deck.gd` `test_props_at_real_size` logs a string-format error (`%` with an array) while passing.
- Quiet-machine frame-time baseline for the asset viewer (T001 runs had other load on the Mac).

## Last session
2026-10-30 (code, unattended): T003 built: `src/player`, `src/weapons`, F1 tuning panel, `scenes/player/weight_deck.tscn`, `data/player.json`, `data/weapons.json`. 71/71 tests pass, import clean. 2.08 ms avg, 2.50 ms p95 at 1920×954 while walking, turning and firing. Captures in `docs/screens/T003/`. Feel is untested by a human.
