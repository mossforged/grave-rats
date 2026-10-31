# T018 - Co-op groundwork: structure for 1–4 players, no networking yet (code)

**Modules:** `src/player/`, `src/shift/`, `src/salvage/`, `src/doors/`, `src/run_log/`, a new `src/session/` (players and the command layer). **Read:** `CLAUDE.md` (the multiplayer-ready habits), `docs/studies/2026-10-30-comparable-games.md` (the multiplayer section: host-authoritative listen server, GodotSteam later; cheap structure now), `docs/decisions.md` (Open Tender), the contracts of the modules above. **Needs:** T017 merged.
**Autonomy:** auto-ok (no behaviour change for one player; the two-window test is the proof).

Co-op and Open Tender come later, but retrofitting is expensive. Make the game's structure multiplayer-shaped now, with exactly one local player behaving as today.

## Do
1. **Players:** a `Session` with a list of players (id, crew, input source). One spawn path keyed by player id; nothing assumes a single global player (search for it: `get_first_node_in_group("player")`-style shortcuts, singletons holding "the" operator).
2. **Commands:** player actions (move, aim, fire, reload, crouch, pick up, drop, door, tip, leave, lock to cover) go through a command layer with a player id, so later the host can receive them from clients. Local input produces commands; the simulation consumes them.
3. **Authority:** damage, loot, doors, the shift clock, spawns and the quota are changed only through functions guarded by `is_authority()` (always true for now). Randomness comes from one seeded RNG owned by the session.
4. **Per-player:** sight and fog, carry, suit, oxygen and the HUD read the local player's state; the crew-shared rules (the hold, the "if anyone extracts" death rule, the quota) read the session.
5. **A two-window local test:** a debug launch option that runs two local players in one game (split by two input devices or a scripted second player), to prove two players can exist, carry, die and extract with the shared-loss rule. No network.

## Acceptance
- **Headless:**
  - all tests pass with one player, unchanged;
  - new tests with two players: both spawn, each has their own sight and carry, the hold is shared, "if anyone extracts the haul counts" holds, and both dying loses the haul;
  - no code path assumes one player (a grep check in a test);
  - all randomness comes from the session's seed (two runs with one seed match).
- **Windowed:** the two-player debug run, two operators on screen.
