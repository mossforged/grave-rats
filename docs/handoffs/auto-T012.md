# T012 handoff: salvage, the oxygen clock, escalation, extraction

Branch `auto/t012-mac`. Play it: `godot --path .` (the main scene is now `scenes/shift/shift_deck.tscn`). Start with `docs/screens/T012/sheet.png`.

**Status: the packet is built and every headless check passes, but nobody has played it.** The gate questions ("one more room?", "is grabbing the black box scary?") are John's. The evidence so far is tests, stills and bots.

**Keys:** E take / door / tip bed, G drop, walk into the airlock to deposit, hold E there to leave, Backspace next shift.

## What changed
1. **`src/salvage/` (new), `data/salvage.json`:** 20 small, 8 medium, 4 heavy and the black box, placed from data. Grey boxes in class colours on rings of light. Pocket limit, in-hand penalties and committed lifts and drops are all data.
2. **`src/shift/` (new), `data/shift.json`:** the 8:00 clock, then a suit drain of 2%/s. Tiers at 60% and 30%, the airlock as the hold, LEAVE on a 1.5 s hold, the prize alarm, section lights, and `shift_deck.gd`, which extends `stalker_deck`.
3. **`src/enemies/`:** `spawn_picker.gd`, `StalkerPack.spawn_out_of_view`, `alert`, `StalkerBrain.alert`, `thud_m`, six spawn points. `stalker_deck` gained two small hooks (quiet hurts, killer kind).
4. **`src/hud/`:** real oxygen ticker, carry plate, `≈` hold total, announcements, progress bar over the operator, alarm words. Decks with no shift keep the placeholders.
5. **`src/player/`:** `Operator.set_carry` and `OperatorModel.speed_mult` / `can_sprint`. Penalties only.
6. **`src/run_log/`:** shift outcome, oxygen at exit, deposited by class and value, banked value, items lost, prize, tier, cause of death, survivors.
7. **CUSTODIAN hook for T014:** `wake_hooks["custodian"]`, named by tier 2's `wake` list. It does nothing until something registers.

## Checks
| Check | Result |
| --- | --- |
| Headless tests | **315/315, three full runs in a row on the final code** (282 old, 33 new in `tests/test_shift.gd`) |
| Old test edited | One: `test_awareness_circle_and_main_scene` now expects the shift deck, since it asserts "F5 runs the latest build" |
| Import | Exit 0, no errors |
| Carry rules from data | Tests change the data and see speed, sprint, firing, cone and pocket limit follow |
| Pick-up and drop timing | Lift 0.5 s, medium drop 0.2 s, heavy drop instant; held and released on time |
| Deposit, LEAVE, log | Deposit adds up (estimate and truth apart); LEAVE needs the full hold in the airlock, and letting go restarts it; the JSON file is read back |
| Oxygen | Drains in seconds; at zero the suit loses 2%/s; it can kill; logged as `oxygen`, not as a hit |
| Tiers | Fire once at thresholds from data; a big step can't skip one |
| Spawns out of sight | Player looks straight at each spawn point, 40 seeds each: it picks another. All watched: waits and retries |
| Prize | Alarm, 10 s marker that pulses and follows, panel stalker released; a stalker from across the ship closes to under half the distance |
| Literals | Scan extended to the new scripts and the rules part of `shift_deck.gd` |

The tests log a non-script engine error, `p_size <= 0` from HUD text at zero canvas size in headless (549 lines). It's from drawing with no window, and the runner doesn't count it. I didn't chase it.

### Bots: greedy vs cautious, 12 seeds (`tools/t012_bots.gd`, `docs/screens/T012/bots.txt`)
| | Greedy | Cautious |
| --- | --- | --- |
| Survived | **6 of 12 (50%)** | **12 of 12 (100%)** |
| Value banked, mean (dead runs count 0) | **2,380** | **1,309** |
| Value banked, median | 3,044 | 1,316 |
| Range | 0 to 5,617 | 832 to 1,620 |
| Items deposited, mean | 19.0 | 14.4 |
| Prize taken | 10 of 12 | never |
| Shift length, mean | 357 s | 204 s |

Greedy pays about 1.8× on average and loses everything half the time, which is the shape the design wants. Limits of this:
- The bots step at 30 Hz, aim with a 0.2 s lag, and don't use cover or sneak. Real players will differ.
- The cautious bot is close to risk-free, because tier 1 at 3:12 is a safe time to leave. It may be too safe. The quota in T013 is what would push against it.
- The greedy bot rarely clears the ship: it gets 11 to 25 of 33 items and goes home with about 100 s of air left once nothing reachable is left on its list. That partly reflects bot pathing (it gives up on an item after 12 s), so don't read "33 items don't fit in 8:00" from it.
- These numbers were taken before the last changes, which only touch rim visibility, label placement and capture code, none of which a bot reads. I didn't re-run them.

### Frame time, 1920x1080 on the M2 Pro (ms, average / p95)
| Run | Result |
| --- | --- |
| Shift deck, three stalkers hunting (confirmed by a printed count), final code | **6.82 / 9.87** |
| Same scene, earlier runs this session | 6.53 / 9.35, 6.57 / 9.45, 6.61 / 9.65, 6.61 / 9.63 |
| `stalker_deck` measuring window, two stalkers, alternating with the above | 6.20 / 8.29, 6.20 / 8.33 |

The packet sets no number. T011's pirate-deck target was under 7.5 / 9.5: the average clears it, and the p95 straddles it. The two decks' windows have different stands and views, so the difference isn't purely the cost of T012. This wasn't a quiet Mac: a QA run was alive alongside this one. Re-measure when it's quiet.

### Screens (`docs/screens/T012/`)
`sheet.png`, plus each class carried, rims with the light off, hold deposit, tier 1, tier 2 lights before / flicker / failed, prize alarm in 3 frames, oxygen at zero, leaving, left. `frametime.json`.

Prize alarm frame 3 doesn't show a stalker arriving: at 6 s they're still outside your sight, and the sight rule hides them. Convergence is proved by the test, not this frame.

## Decisions I made (all data unless noted)
- **Deck:** the packet calls `stalker_deck` the main deck, but the main scene was `pirate_deck`. I made a new scene on top of `stalker_deck` and pointed the main scene at it (`project.godot`). The pirate deck is unchanged and still opens directly.
- **Airlock is a marked zone, not a room:** the south end of the junction, with a light outline and sign. A real room means changing the layout and the kit, outside this packet.
- **Drops:** the packet says "committed drop times" and "instant and loud"; I followed the design table. Medium 0.2 s and quiet, heavy instant and loud (`thud_m` 15 m). Small can't be dropped by hand.
- **Prize placement:** I first put it at the corridor's west end, which turned out to be about 10 m from the airlock, since the side corridor opens onto the junction. It now sits behind the tall crates in cargo's far corner. A test holds it among the furthest items, with nothing else in its reach.
- **Rings in unseen rooms show nothing** (`rim.unknown_share` 0, the door lights' rule). I tried 0.28 first: it showed the whole ship's loot from the first second, which I judged bad for "fear the corner" and "one more room?". Once seen, a ring reads from anywhere.
- **The alarm blows the bulkhead** if it's still sealed, because the packet says "every stalker".
- **Values, 5,200-ish on the ship plus a 1,500 to 1,800 prize:** placeholders until T013 sets a quota. The design wants the prize at about a third of a quota.
- **Spawned stalkers prowl their spawn room** until they sense something. Tier stalkers are placed but don't get told where you are.
- **Spawn vents and closets aren't drawn:** points in data only.
- **A small "SHIFT CLOSED" banner** stands in until T013's screens.

## What needs John's eye
1. **The gate:** does "one more room?" happen? Is grabbing the black box scary?
2. **Tier stalkers can be quick:** in one capture, a tier stalker spawned out of sight (the rule keeps it at least 7 m away; I didn't record the exact spot) and hit a player standing still in about 2 s. That obeys "never in sight", but it may feel unfair. `spawning.min_player_m` is the lever.
3. **Lights failing is modest:** strips and practicals go out, but ambient and fog stay, and no rule reads the lights. Is it dark enough to matter?
4. **Rings:** are 0 in unseen rooms and full strength once seen right? Try `rim.unknown_share`.
5. **Carrying has no pose:** the item floats in front of the body with the rifle still up.
6. **Siren, chirp and thud are placeholders,** and I couldn't hear them. No check covers how they sound.

## Not checked
Real play and feel, audio, any resolution above 1080p, a quiet-Mac frame time, and the T006/T007 bots. Tier spawning under real play was only seen in tests, the bots and captures.
