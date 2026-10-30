# T005 - The stalker, cover with height, and getting hurt (code)

**Modules:** new: `src/enemies/`, `src/cover/`, `src/health/`. **Read:** `CLAUDE.md`, `docs/studies/2026-10-29-weight-without-lag.md`, the `src/player/`, `src/weapons/`, `src/sight/` and `src/doors/` contracts, `docs/screens/A001/sheet.png` (A001-11, the acid stalker), `docs/screens/A002/sheet.png` (A002-07, the cover-height read). **Needs:** T004 merged.
**Autonomy:** human-gated (stage 2 gate: *"Is moving through these rooms with a flashlight tense and fun?"*).

This closes the grey-box core loop. John's own picture of the game is: crouch behind an overturned medical table while something acid-spitting stalks into the room, and something bursting through a bulkhead behind you is scary because you can't spin and kill it instantly. Build exactly that, in grey box, playable.

## Do
1. **Cover with height** (`src/cover/`, pure logic plus adapter):
   - Props carry `cover: none | low | tall` in deck data.
   - **Low cover** (~0.9 m: an overturned bed, crates, a console) blocks shots aimed at a **crouched** body behind it, and doesn't block shots at a standing body.
   - **Tall cover** blocks shots and sight (it's already an occluder in T004).
   - Shots trace in 3D against cover height, from a muzzle height to a target height (standing torso about 1.3 m, crouched about 0.8 m).
   - Leaning or peeking isn't needed; firing from crouch over low cover raises you to a "braced" height that is exposed.
   - Show protection clearly: a small shield mark on the HUD when the shooter's line is blocked, computed per shooter, not per "near a box".
2. **The overturned bed:** a grey-box prop the player can **tip over** with E (a 0.8 s commitment) to turn an upright bed (no cover) into low cover facing away from the player.
3. **Health** (`src/health/`):
   - Suit integrity for the player.
   - **Hit reactions:** a big hit (≥ 25% of health) staggers you, so you lose control for 0.35 s and your aim cone blows wide.
   - **Acid damage over time** while standing in a puddle.
   - Death and a quick restart.
   - All numbers in `data/health.json`.
4. **The stalker** (`src/enemies/`), grey-box body (a low, wide capsule-and-boxes creature, about 1.1 m tall, clearly not human):
   - **Senses:** hears gunfire and sprinting within radii from data; sees only in a forward cone; obeys doors and walls like the player.
   - **States:** prowl (patrols between points slowly), investigate (moves to the last noise), stalk (approaches using cover and corners, not in a straight line, when it knows where you are), spit, lunge, recover.
   - **Spit:** a telegraphed wind-up (0.6 s, readable glow), then an arcing glob that leaves an **acid puddle** for a few seconds. Low cover blocks the glob; it can arc *over* low cover at short range, so cover isn't a perfect answer up close.
   - **Lunge:** a short-range charge with a 0.4 s wind-up and a 0.9 s recovery where it's vulnerable.
   - **It obeys weight too:** it turns slowly while prowling, quickly when it lunges. It is the one thing that breaks the rule, on purpose.
   - Hit flinch; dies in 6–8 rifle hits; numbers in `data/enemies.json`.
5. **The bulkhead ambush:** one scripted moment in the deck. A sealed wall panel in the junction **bursts open** after the player passes it (a trigger behind the player), and a stalker comes out. It needs:
   - a loud bang;
   - a camera kick;
   - debris (simple cubes are fine).
   This is the pillar-3 test: the player hears it and has to turn.
6. **Deck dressing for the test:** in the medbay, two upright beds (tippable), one already overturned, and consoles. One stalker prowls the cargo hold, one waits for the ambush. A respawn key resets everything.
7. **Run log** (`src/run_log/`, small): each life writes `user://runs/<timestamp>.json`:
   - time alive;
   - shots fired and hit;
   - damage taken by source (spit, puddle, lunge);
   - times in cover when hit or protected;
   - which stalker killed you and how.
   The lead reads these beside John's comments.

## Acceptance
- **Headless:**
  - low cover blocks a crouched target and not a standing one;
  - braced firing exposes you;
  - tall cover blocks both;
  - tipping the bed changes its cover class;
  - a stagger triggers at the threshold;
  - puddle damage over time;
  - the stalker's state transitions (hears a shot → investigate; sees the player → stalk; in range → spit/lunge);
  - a spit is blocked by low cover at long range but can arc over at short range;
  - the ambush fires once, only behind the player;
  - the run-log file is written with the fields above;
  - all numbers come from data.
- **Windowed** (`docs/screens/T005/`):
  - crouched behind the overturned bed with the protected mark showing;
  - the spit wind-up;
  - an acid puddle;
  - a lunge;
  - the ambush, 3 frames from burst to the stalker coming out;
  - frame time with two stalkers active.
- **Human (John):** the stage 2 gate question, played with the F1 tuning panel open.

Out of scope: art (grey box only), sound beyond placeholder bangs and spits, other enemy types, co-op, loot.
