# T018: co-op groundwork (auto, code)

Branch `auto/t018-mac`. The game now has the structure for 1–4 players, with one local player playing as before. No networking. **Nobody has played this, solo or with two.** The proof is the tests and the captures.

**Dependency, for the lead:** the packet says "Needs: T017 merged", and T017 isn't merged (it's waiting on John's ear). I left it out, as T017 did with T016, so merging T018 can't carry T017 past that gate. The runner had also branched from a `main` older than `origin/main`, so I merged `origin/main` in (T016, Q002). Merge order is your call; the trial merge below works, but it needs hand resolution.

## What changed
- **`src/session/` (new):** `Session` holds the players (ID, crew, input source), the command layer (`send`), the one seeded RNG, `is_authority()` and what the crew shares (hold, "if anyone extracts", quota). `data/session.json` has the numbers. `player_id` moved out of `data/shift.json`.
- **One spawn path:** `weight_deck.spawn_player(id, crew, source)`. `shift_deck.join_player` adds a crewmate's suit, log, sight and light. `operator` still means the local player, and is what the camera, HUD and fog follow.
- **Commands:** move, aim, fire, reload, crouch, interact, take, drop, door, tip and leave all travel as commands with a player ID, through `Session.send`. Keys and `scripted` become commands in `Operator._send_local_input`. A remote or scripted player is moved only by commands.
- **Authority:** damage, loot, doors, the clock and world step, spawns, the alarm, a new ship and the quota all check `is_authority()` first. It's always true for now; a test turns it off and confirms nothing shared moves.
- **Per player:** suit, carry, sight and memory, run log and light. Oxygen is `oxygen_of(id)`: the shared clock plus a per-player tank extra, which is 0 today.
- **Shared:** the hold, the shift outcome, the quota.
- **Randomness:** the shift's existing RNG is now the session's, so a seed still rolls the same ship. Rifles and stalkers now seed from it too; they used to randomize. The paperwork seed no longer comes from the clock.
- **Debug launch:** `godot --path . res://scenes/session/two_player_deck.tscn`. You, plus a scripted player 2 (`mate_bot.gd`) who carries the junction's salvage to the airlock and waits there. It's one window with plain shifts and no forms; I took the packet's "scripted second player" option.
- **Contracts updated:** player, shift, salvage, doors, run_log; session is new.

## Checks
- **Import:** `godot --headless --path . --import` exits 0.
- **Headless:** 452 passed, 0 failed, 0 load errors. That's the 410 existing tests with no test file edited, plus 42 new in `tests/test_session.gd`:
  - two players: both spawn; own sight, memory and carry; shared hold; two can't lift one item; a crewmate can carry on a dropped item;
  - shared loss: either player down and the other extracts, the haul counts; both down, it's 0;
  - no global shortcut to the player, and the shift rules keyed on a player (grep checks);
  - all randomness from the session (a grep, with a named exemption list);
  - two runs with one seed match on items, stalker paths, shots and positions, across 240 steps including a tier.
- **Solo bots:** `tools/t012_bots.gd` with 2 seeds ran to the end, before the last small commit. I only read the end of its output, so this is a smoke run, not a check for script errors or balance.
- **Windowed, two-player run:** both operators are on screen in `two_operators_spawned.png` and `two_player_deck.png`. The run printed:
  - mate down, you extract: outcome `extracted`, banked 583;
  - both down: outcome `wiped`, banked 0, with 59 still in the hold.
- **Frame time, 1920x953, real GPU, shift_deck's measuring window:**

| Run | avg ms | p95 ms |
|---|---|---|
| `main`, solo, run 1 | 6.67 | 9.71 |
| T018, solo, run 1 | 6.83 | 9.90 |
| `main`, solo, run 2 | 6.58 | 9.24 |
| T018, solo, run 2 | 6.77 | 9.37 |
| T018, two players (one run) | 7.19 | 9.63 |

Solo reads 0.16–0.19 ms slower on average in both pairs. That's only two pairs, `main` always ran first, and I didn't find the cause or check how quiet the Mac was. It may be real.

## T017 trial merge
I merged `origin/auto/t017-mac` onto this branch in a scratch worktree, since removed. Result: **492 passed, 0 failed, 0 load errors, import exits 0.** Nothing from it is committed. Git stops on conflicts in `docs/STATUS.md`, `src/shift/CONTRACT.md`, `src/player/operator.gd`, `src/player/weight_deck.gd` and `src/shift/shift_deck.gd`, all small. How I resolved the code:
- `operator.gd`: keep both preloads.
- `weight_deck.gd`: keep T017's `_exit_tree` and T018's spawn functions.
- `shift_deck.gd`:
  - `_step_shift`: keep the authority guard, then `_step_sounds()`.
  - Everywhere: replace `_siren.stop()` with `_stop_siren()`, **including T018's new `_after_death` and `_start_shift`, which git won't flag**.
  - `_on_carry_event`: use T017's sound lines with `p.operator.global_position`, and drop the old `drop_sound` lines.
  - `_die`: keep T018's body; the siren stop now lives in `_after_death`.
  - `_open_form`: T018's loop plus `Audio.stop_loop("breath")`.
- After merging, T017's `_step_sounds` still follows only the local player, which is right, but it reads the clock's oxygen rather than `oxygen_of`. They're equal today.

## Not done or not checked
- **Lock to cover isn't routed.** The `LOCK` command exists and nothing consumes it. The lock only exists on the pirate deck, and `src/pirates` and `src/cover` are outside the packet, so `LockDriver` still reads Space and RMB directly.
- **The older dev decks** (sight, stalker, pirate) get the spawn path and body commands, but their E key still goes straight to their own code. Only the shift deck, the main scene, routes world commands.
- **`src/pirates` still randomizes** (brains, barks). It isn't on the shift deck. Camera shake and bulkhead debris also stay off the seed on purpose: this screen only, no rule reads them.
- **"Same seed, same run" means fixed steps with no frames in between**, which is what the test does. A live run has wall-clock physics frames, so this isn't lockstep.
- **A crew in a session (the forms) is written but untested.** The debug scene and the two-player tests run plain shifts. A local player left behind still gets a payslip, where the design says a death bill.
- **Not exercised:** a real second input device, more than two players, the bot leaving the junction (it walks straight lines and opens no doors), and a real death by stalker in the two-player tests (hits are injected through the deck's handlers).

## Calls I made (each easy to change)
- **The pack hunts one target at a time:** the living player nearest a stalker that's up. Per-stalker targets need `src/enemies`, which is outside the packet. The HUD's cover-shield lines follow that target too, so they can show the other player's.
- **No friendly fire:** rounds pass through the crew.
- **LEAVE** takes everyone alive in the airlock; anyone else alive is `left_behind`, per the run-loop design. It's on file, with no bill yet.
- **Oxygen stays one shared clock** with a per-player read, because the tiers hang off it.
- **A crewmate shows only when the local player can see them**, and their floor cone is hidden.
- **A crewmate's run log writes its own file** with `player_id`, and a death log waits for the shift's end so it knows the outcome.

## Made
`docs/screens/T018/`: `two_operators_spawned.png`, `two_operators_carrying.png`, `two_players_mate_down_you_extract.png`, `two_players_both_down.png`, `two_player_deck.png` (mid-fight in the measuring window), `two_player_deck_overlay.png`, `frametime.json`.

## For John's eye
Solo should feel exactly as it did; `godot --path .` and play a shift. Tell the lead if aim, firing or E feels different, because all of it now goes through the command layer.

In the two-player scene, two things looked weak in the captures:
- In `two_operators_carrying.png` the carried items are hard to see.
- Player 2's beam barely reads as its own beam.
Neither is a decision yet, just worth a look.
