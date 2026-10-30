# Grave Rats — status

**Stage:** 0 (skeleton), T001 done on `auto/t001-mac`, awaiting lead review. **Next:** T002 (camera and scale study, human-gated).

## Stage plan (each stage ends in a gate John answers by playing)
0. **Skeleton.** Godot project, headless tests, capture tool, runners. Gate: none (lead checks).
1. **Camera and scale (grey box).** Perspective camera rig and a grey-box deck at the chosen proportions. Gate: *"Does this framing feel like the concept?"*
2. **Core loop (grey box).** Move, aim, shoot, roll, crouch, flashlight sight, doors, one enemy type, one small deck. Gate: *"Is moving through these rooms with a flashlight tense and fun?"*
3. **Vertical slice art.** Medbay, corridor and cargo at concept quality: kit, materials, lighting, crew model and animation. Gate: *"Does it match or beat the concept?"*
4. **Systems.** Cover with height, loot and carry decisions, extraction, threat variety, sound. Gate per system.
5. **Co-op.** 2–4 players over the network. Gate: a real session with the Monday crew.
Later (parked): competitive modes, ship generation, contracts and meta, the "weird things" roster.

## What builders need now
- Code: T001 built (see `docs/handoffs/auto-T001.md`); T002 next.
- Art: A001 (crew and threat concept exploration) is ready to queue once John confirms the pillars.

## Open questions (for John)
- Pillars in `docs/handoffs/game-brief.md`: confirm or edit.
- Who or what took over the ships? (robots, an organism, something stranger; pick later, A001 explores)
- May the code lane add an empty `assets/source/.gdignore` so Godot stops writing `.import` files into the art sources? (T001 handoff)

## Parked
- Competitive modes; procedural ship generation; contracts and meta-progression; the in-game "shift" framing (runs as shifts, timecard end screen).
- Quiet-machine frame-time baseline for the asset viewer (T001 runs had other load on the Mac).

## Last session
2026-10-29 (code, T001): Godot 4.7 project, `Data` loader, headless test runner (12 passed, 0 failed, 0 load errors), legacy operator/robot/kit imported into `assets/game/legacy/` with named ORM materials, asset viewer and `tools/capture.sh`.
Viewer at 1920×1080, MSAA 4×: 7.7 ms avg, 14.5 ms p95 over 30 s on the M2 Pro. Captures in `docs/screens/T001/`.
