# Grave Rats — status

**Stage:** 0 (skeleton) done (T001 merged). **Next:** T002 (camera and scale study, human-gated) running on the Mac.

## Stage plan (each stage ends in a gate John answers by playing)
0. **Skeleton.** Godot project, headless tests, capture tool, runners. Gate: none (lead checks). **Done 2026-10-30.**
1. **Camera and scale (grey box).** Perspective camera rig and a grey-box deck at the chosen proportions. Gate: *"Does this framing feel like the concept?"*
2. **Core loop (grey box).** Move, aim, shoot, crouch, flashlight sight, doors, one enemy type, one small deck. Gate: *"Is moving through these rooms with a flashlight tense and fun?"*
3. **Vertical slice art.** Medbay, corridor and cargo at concept quality: kit, materials, lighting, crew model and animation. Gate: *"Does it match or beat the concept?"*
4. **Systems.** Cover with height, loot and carry decisions, extraction, threat variety, sound. Gate per system.
5. **Co-op.** 2–4 players over the network. Gate: a real session with the Monday crew.
Later (parked): competitive modes, ship generation, contracts and meta, the threat roster.

## What builders need now
- Code: T002 queued. T003 (weighty operator and gun) and T004 (sight, flashlight, doors) are written; each queues after the previous one is merged.
- Art: A001 merged (15 concepts). The next art packet waits on John's picks for the crew and threats; environment work can run meanwhile.

## Open questions (for John)
- A001 picks: which crew looks and threat directions to develop (art lane's recommendation: 01 orange hauler; 11 acid stalker, with 09 rogue AI as the systemic complement).
- How weighty? Turn speed, aim settle and reload times get tuned in stage 2 by playing.

## Parked
- Competitive modes; procedural ship generation; contracts and meta-progression; the in-game "shift" framing (runs as shifts, timecard end screen).
- Quiet-machine frame-time baseline for the asset viewer (T001 runs had other load on the Mac).

## Last session
2026-10-30 (lead): reviewed and merged T001 (12/12 tests reproduced on a clean checkout; viewer 7.7 ms avg, 14.5 ms p95 at 1080p on the M2 Pro) and A001. Added `assets/source/.gdignore` (lead decision, see decisions.md). Queued T002.
