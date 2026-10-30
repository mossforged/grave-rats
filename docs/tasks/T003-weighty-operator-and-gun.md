# T003 - The weighty operator and the gun (code)

**Modules:** new: `src/player/`, `src/weapons/`, `src/debug/` (extend). **Read:** `CLAUDE.md`, `docs/studies/2026-10-29-weight-without-lag.md`, the `src/camera/` contract (T002), `data/deck.json`. **Needs:** T002 merged.
**Autonomy:** human-gated (John tunes the feel by playing; the code can merge before he does).

Pillar 3 is "Weight, not speed". This is where it becomes real: an operator who reacts the instant you ask but takes honest time to turn, settle, fire and reload, in the T002 grey-box deck. Read the study first. Its core rule is **the intent responds instantly; the completion takes time**: anything that feels like input lag is a bug.

## Do
1. **Player controller** (`src/player/`):
   - WASD movement relative to the camera, with acceleration and deceleration.
   - A walk speed and a slower crouch speed (hold C or Ctrl).
   - Collision against the deck.
   - Sprint (Shift) that widens the aim cone and blocks firing.
2. **Aiming:**
   - The cursor is free.
   - The body turns toward it at a capped rate, with separate rates standing, firing and crouched.
   - The torso may lead the hips by a limited angle; beyond that the legs turn too.
   - Show the turn: a faint arc from the gun's current facing to the cursor while turning.
3. **Aim-settle cone:**
   - Spread starts wide after moving or turning and closes while planted.
   - Moving keeps a minimum spread.
   - Draw the cone on the floor (subtle, readable), so every miss is explainable.
4. **Rifle** (`src/weapons/`):
   - Hitscan within the cone; magazine and reserve.
   - Per-shot recoil that kicks the aim and recovers.
   - A small camera kick.
   - Muzzle flash and a tracer (simple and placeholder, but **no black boxes**: test against the post-processing).
   - Hits on grey-box targets.
5. **Reload commitment:**
   - R starts a reload that takes its full time.
   - Firing doesn't cancel it; sprinting does, and loses the magazine in progress.
   - Visible on the character and in a minimal HUD.
6. **Animation hookup.** Use the legacy operator clips: blend `L_Run_F/B`, `L_Strafe_L/R` and `L_Idle` by move direction relative to the torso, with `U_Aim`, `U_Reload` and `U_LowReady` on the upper body. Fix the old prototype's bug: **compute speed from the move before applying it** (the prototype measured after, so the walk never animated). Foot sliding is acceptable for now; note how bad it is.
7. **Tuning panel** (F1, dev only):
   - A slider for every weight lever in the study.
   - Read from and writable back to `data/player.json` and `data/weapons.json` with a Save button, so John's tuning persists as a data change.
8. **Targets.** Six grey-box target dummies in the deck that take hits, react with a flinch and reset.

## Acceptance
- **Headless:**
  - turn-rate math (a 180° turn takes `180/rate` seconds within a frame);
  - the cone closes over the settle time and respects the moving minimum;
  - a reload can't be cancelled by firing and is cancelled by sprinting;
  - speed is computed before the move (regression test for the walk bug);
  - all numbers come from `data/`.
- **Windowed:** `docs/screens/T003/`:
  - the operator mid-turn with the arc showing;
  - the cone wide, then settled;
  - a shot with the tracer;
  - a mid-reload frame;
  - a 6-frame strip of walking showing the legs animate;
  - frame time from `tools/capture.sh` in the deck.
- **Human (John):** *"Does it feel heavy without feeling laggy?"* He tunes with F1; his saved numbers are the result.

Out of scope: enemies, sight and fog (T004), cover rules, damage to the player, roll and dodge.
