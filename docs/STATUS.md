# Grave Rats — status

**Stage:** 2 (core loop, grey box): T003 and T004 merged; T005 (stalker, cover, damage, ambush) running. Gates for stage 1 (camera/scale) and the T003/T004 feel wait for John.

## Stage plan (each stage ends in a gate John answers by playing)
0. **Skeleton.** Godot project, headless tests, capture tool, runners. Gate: none (lead checks). **Done 2026-10-30.**
1. **Camera and scale (grey box).** Perspective camera rig and a grey-box deck at the chosen proportions. Gate: *"Does this framing feel like the concept?"*
2. **Core loop (grey box).** Move, aim, shoot, crouch, flashlight sight, doors, one enemy type, one small deck. Gate: *"Is moving through these rooms with a flashlight tense and fun?"*
3. **Vertical slice art.** Medbay, corridor and cargo at concept quality: kit, materials, lighting, crew model and animation. Gate: *"Does it match or beat the concept?"*
4. **Systems.** Cover with height, loot and carry decisions, extraction, threat variety, sound. Gate per system.
5. **Co-op.** 2–4 players over the network. Gate: a real session with the Monday crew.
Later (parked): competitive modes, ship generation, contracts and meta, the threat roster.

## What builders need now
- Code: T004 merged (lead reviewed, 96/96 reproduced). T005 queued.
- Art: A001–A004 merged. Lane idle on purpose: crew/threat, environment, HUD and logo development all wait on John's picks.

## Open questions (for John)
- Stage 1 gate: which camera preset and room/character scale? At 55–65° pitch a real-size operator can't be both ~8% of view height and framed like the panel; preset 1 favours operator size, preset 3 the composition (see auto-T002).
- `tools/capture.sh` only reaches 1920×954 on this display (title bar); accept, or make the capture window borderless (src/debug task)?
- A001 picks: which crew looks and threat directions to develop (art lane's recommendation: 01 orange hauler; 11 acid stalker, with 09 rogue AI as the systemic complement).
- A002 picks: walls, doors, floors, props, signage (08b) and lighting (09b) for stage 3 (art lane recommends all, with caveats in auto-A002).
- A003 picks: HUD direction (01 minimal / 02 suit OS / 03 watch strip, art lane recommends 03) and the tone of the briefing, payslip and death bill.
- T003 feel: play `scenes/player/weight_deck.tscn`, tune with F1 and Save. Open: cursor sits ~0.8 m screen-up of the floor cone (aim at gun height); is the 1.5° settled cone readable?
- T004 dread: *"Do I feel the corners?"* Play `scenes/sight/sight_deck.tscn` (F light, E door, F2 debug, F1 "Sight" sliders). Is 2.6 m awareness too generous? How dark? Should 1.2 m crates block sight? (auto-T004)
- A004 picks: wordmark (art lane recommends 01 hull stencil, fallback 03 hazard label), keep the rat emblem (07)?, title art direction (08/09).
- T004 feel: `scenes/sight/sight_deck.tscn`: do the corners feel uncertain? Awareness circle 2.6 m too generous? How dark should remembered/unknown be? Should 1.2 m crates block sight?
- How weighty? F1 in `weight_deck` tunes every lever; Save writes `data/`.
- Aim marker: the cone is on the floor but the cursor aims at gun height, so the cursor sits about 0.8 m screen-up of the cone's line at the concept camera. A ring marks the floor point under the aim. Keep that, or aim on the floor and accept that shots at a dummy's chest pass behind it? (auto-T003)

## Parked
- Competitive modes; procedural ship generation; contracts and meta-progression; the in-game "shift" framing (runs as shifts, timecard end screen).
- T002 capture: auto-walk during the frame-time window so camera motion and cut-away are measured.
- Physics interpolation: the operator steps at 60 Hz, so a faster display may show slight camera jitter.
- Legacy clips: a real walk (the run clips stand in), a crouch walk with real steps, turn-in-place feet. Foot slide numbers in auto-T003.
- `tests/test_deck.gd` `test_props_at_real_size` logs a string-format error (`%` with an array) while passing.
- Sight leaks: the floor aim cone stops at unseen walls, tracers and prompts draw over the mask, hidden targets pop in with no fade.
- Quiet-machine frame-time baseline for the asset viewer (T001 runs had other load on the Mac).

## Last session
2026-10-30 (lead): merged T004 (96/96 reproduced; flashlight ~0.35 ms) and A004; queued T005.
2026-10-30 (code, unattended): T004 built: `src/sight`, `src/doors`, `scenes/sight/sight_deck.tscn`, `data/sight.json`, `data/doors.json`; `data/deck.json` gains a fourth (locked) door and two tall props. 96/96 tests, import clean.
Flashlight costs about 0.35 ms (3.51 vs 3.16 ms avg) at 1920×954, not a true 1080p, on a loaded Mac. Captures in `docs/screens/T004/`. Nobody has played it; the dread is untested.
