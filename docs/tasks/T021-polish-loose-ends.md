# T021 - Loose ends from T016 to T018 (code)

**Modules:**
- `src/cover/` (bed visibility);
- `src/kit/` (wall-top band);
- `src/pirates/` (gunfire through the audio bank; lock command);
- `src/session/` (the `LOCK` command consumer).

**Read:**
- `CLAUDE.md`;
- `docs/handoffs/auto-T016.md` ("Needs John's eye" 2 and 3);
- `docs/handoffs/auto-T017.md` ("Not checked": pirate gunfire);
- `docs/handoffs/auto-T018.md` ("Not done": lock to cover);
- the contracts of the modules above.

**Needs:** T020 merged.
**Autonomy:** auto-ok.

Small fixes the last three handoffs flagged. No balance changes.

## Do
1. **The overturned bed reads in the dark.**
   - T016 found it nearly invisible in its dim corner, and low cover you can't see is a gameplay problem.
   - Make its silhouette read from the steep camera. Options: lighter material slots on the top edge, or a hazard stripe along the plated face's top edge (in kit materials). Choose one.
   - Show before and after.
   - Do not add a light: lighting is the deck's job.
2. **The wall-top band that changes between identical frames.**
   - Find the cause: T016 measured up to 13.9 grey levels of difference with the world frozen.
   - First, check whether it predates T016 (run the same stand on T015's commit).
   - Fix it if it is ours, such as an unseeded random, a temporal effect, or a race in the kit's grime.
   - If it is the engine (TAA-like history or SSAO noise), say so with evidence and park it.
3. **Pirate gunfire on the audio bank.** Route `src/pirates`' shots through `Audio` with the T017 cues (or the T020 layered shot if merged), on the SFX bus, with distance and occlusion as T020 gives players' shots.
4. **Lock to cover through commands.** `LockDriver` reads Space and RMB directly. Route the lock through `Session.send` as a `LOCK` command with a player ID, as T018 did for everything else. Solo feel unchanged.

## Acceptance
- **Headless:**
  - all tests pass;
  - the wall-top band test shows identical frames are identical, or names the engine cause;
  - pirate shots play bank cues;
  - lock works from a scripted command with no keyboard.
- **Windowed** (`docs/screens/T021/`): the bed before and after from the game camera; the wall-top repeat pair.
