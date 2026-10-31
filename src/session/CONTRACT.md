# session

Who's playing and who decides (T018). Structure for 1–4 players, no networking. One local player is a session of one and plays as before. Stack this leads to: host-authoritative listen server, GodotSteam later (`docs/studies/2026-10-30-comparable-games.md`, multiplayer).

## Owns
- `session.gd`: scene-free. The players, the command layer (`send`), the one seeded RNG, `is_authority()`, and what the crew shares (`hold`, `haul_counts`, `banked`, `close_quota`).
- `session_player.gd`: one player: `id`, `crew`, `source`, join `index`, and their own `operator`, `suit`, `run_log`, `sight`, `flashlight`, `light_on`, `leave_held`, `brace_left`, `noise_left`.
- `commands.gd`: every player action, as a dictionary with `type` and `player_id`.
- `player_sight.gd`: another player's sight: their own polygon and memory (a `SightSystem` that leaves `SightTarget`s alone: what shows on this screen is the local player's).
- `mate_bot.gd`: a scripted crewmate that plays through commands only.
- `two_player_deck.gd`, `scenes/session/two_player_deck.tscn`: the debug launch.

## Does not own
- Spawning (`weight_deck.spawn_player`, the one spawn path; `shift_deck.join_player` adds what a crewmate needs). The shift's rules (`src/shift`). Networking: there is none.

## Rules
- **Commands.** Local input makes commands (`Operator._send_local_input`, `shift_deck.interact`, `drop_item`, the LEAVE poll), and so does anything else that plays. `send` hands MOVE, AIM, FIRE, RELOAD, CROUCH to that player's operator and the rest to `world_commands` (the shift deck). Later a client hands them to the host in `send`. A command naming nobody goes nowhere.
- **Sources.** `SOURCE_LOCAL` reads keys and mouse, or `operator.scripted` with input off, as ever. `SOURCE_SCRIPTED` and `SOURCE_REMOTE` set `operator.remote`: only commands move it.
- **Authority.** `is_authority()` is true for now; `authority` exists so tests can prove the guards. Damage (`shift_deck._hurt`, `hurt_player`), loot (`_act_*`, deposits), doors (`DoorSystem`, `Door`), the clock and the world step (`simulate_world`, `_step_shift`), spawns (`_step_spawns`), the alarm, a new ship (`respawn`) and the quota (`close_quota`) check it first.
- **Randomness.** `reseed(value)` (0 rolls) starts the session's RNG; `rng` is the same stream the deck rolled from before T018, so a seed gives the same ship. `seed_for(key)` gives a named stream without drawing on `rng`: `rifle:<id>`, `stalker:<i>` at each shift start. Spawned stalkers seed from `rng`. Not from the seed, on purpose: camera shake and bulkhead debris (this screen only, no rule reads them), and `src/pirates` (not on the shift deck). `tests/test_session.gd` greps for anything else.
- **Same seed, same run** holds for fixed steps with no frames between (the test). A real run has wall-clock physics frames, so it isn't lockstep.

## Public API
- `Session.new(cfg)`: `add_player(id, crew, source)` (null if taken or full), `player(id)`, `has_player(id)`, `local()`, `ids()`, `spawn_offset(p)`, `send(cmd) -> bool`, `reseed(value := 0)`, `seed_for(key)`, `is_authority()`, `hold()`, `haul_counts()`, `banked()`, `close_quota(net_cr, how)`; fields `players`, `local_id`, `rng`, `seed_value`, `authority`, `shift`, `quota`, `world_commands`, `commands_sent`.
- `Commands`: `move(id, keys, sprint, yaw_deg)`, `aim(id, point)`, `fire(id, held)`, `reload_gun(id)`, `crouch(id, held)`, `interact(id)`, `take(id)`, `drop(id)`, `door(id)`, `tip(id)`, `leave(id, held)`, `lock(id)`; `is_body(type)`; constants, `BODY`, `ALL`.
- `MateBot.new(cfg, id, deck)`: `step(delta)`; field `leave_when_done`.
- Debug launch: `godot --path . res://scenes/session/two_player_deck.tscn`. You, plus a scripted player 2 who carries the junction's salvage home and waits in the airlock. Plain shifts, no forms.

## Signals
None.

## Data keys (`data/session.json`)
`local_player_id`, `max_players`, `crew`, `spawn_spacing_m`; `two_player` {`mate_id`, `mate_bot` {`space`, `arrive_m`, `reach_share`, `wait_s`}}.

Tests: `tests/test_session.gd`.
