# T015: CUSTODIAN wakes, the cutter and the patrol drone

2026-10-31, unattended code run. Done, waiting on John's gate. **One balance decision is his (below): the prize route is now close to fatal for a bot that stays.**

## What changed
- **`src/custodian/` (new), `data/custodian.json`:** scene-free cutter, drone and voice rules, a line trace that reads walls, doors and cover as the guns do, grey-box units, wall terminals. See its `CONTRACT.md`.
- **Cutter:** 3 placed, 2 wake with CUSTODIAN and 1 is held back for drone calls. Line sweeps, swings onto you, a segmented ring fills for 1.2 s (on the mount and under you), then a 0.35 s burn for 30. Tall cover cancels it on that step. Low cover doesn't.
- **Drone:** 2, patrol routes from data, 3 rifle rounds, no attack. Cone, three roof bars and a chirp rising per bar. Breaking the line before 2.4 s cancels the call. A completed call wakes the nearest sleeping cutter, or alerts the nearest stalker that's up.
- **`src/shift/`:** registers on `wake_hooks["custodian"]`, the prize wakes it early, hits go through `_hurt`, rounds can hit drones.
- **`src/hud/`:** CUSTODIAN's own mint line under the suit's, so neither overwrites the other. `CUTTER LOCK` and `DRONE CALLING` on the alarm strip, plus the hit arc.
- **`src/run_log/`, `data/paperwork.json`:** `cutter` damage source, `custodian_hits`, `custodian_calls`, killer `custodian_cutter`, the two causes, the hazard row, a payslip line only with a hit.

## Outside the packet's module list
- `src/paperwork/paperwork.gd`: three facts and one quantity. The causes' `requires` and the tariff's `qty` are computed there, so data alone couldn't do it.
- `data/hud.json`, `tests/test_weapons.gd` (literal scan list), `tests/test_paperwork.gd` (the new tariff case).

## Checks
- **Headless:** 383 passed, 0 failed, 0 load errors (`tests/test_custodian.gd` is new, 23 tests). All the packet's headless items have a test. "All numbers from data" is the literal scan plus a test that damage and call time follow changed data.
- **Import:** no errors beyond the known `invalid UID` warnings.
- **Frame time, 1920x1080, CUSTODIAN awake plus three stalkers, on the real GPU:** 6.88 ms avg / 10.15 ms p95, then 6.82 / 9.81 on a second run. T014 was 6.75 / 9.61. Nothing else from this run was going at the time, but I can't vouch for the rest of the Mac.

## Bots (`docs/screens/T015/bots.txt`, 12 seeds)
Tell value, cargo hold, stalkers removed, means per 90 s, 0.3 s reaction:

| | Ignores the tell | Reads the tell |
| --- | --- | --- |
| Cutter damage taken | 365 (12.2 hits) | 50 (1.7 hits) |
| Drone calls completed | 3.0 of 5.8 started (52%) | 0.5 of 7.8 started (6%) |

Whole shifts, T012's bots:

| | Greedy survived | Greedy banked (mean) | Cautious survived | Cautious banked (mean) |
| --- | --- | --- | --- | --- |
| T012, before CUSTODIAN | 6 of 12 | 2,380 | 12 of 12 | 1,309 |
| Now, ignores tells | 1 of 12 | 160 | 12 of 12 | 1,319 |
| Now, reads the cutter ring | 1 of 12 | 101 | 12 of 12 | 1,204 |

Cautious goes home at tier 1, so it never meets CUSTODIAN. Greedy's deaths: cutter 8 and puddle 3 ignoring tells; cutter 5, puddle 4, spit 1, lunge 1 reading the ring.

**Limits of those numbers:** greedy never leaves early, so it's the extreme case, and a solo death banks nothing even with about 2,800 deposited. The reading bot dodges only the cutter, not the drones, and doesn't choose its route. The session-level bots (`tools/t014_bots.gd`) were not rerun, so the quota numbers are unmeasured with CUSTODIAN.

**Tuning done:** first values were damage 40, cool 3.0 s, cancel hold 0.7 s. They gave greedy 0 of 12 ignoring tells and 1 of 12 reading the ring. The current 30 / 4.5 / 2.0 cut the damage to a bot ignoring the tell from 607 to 365, but greedy still survives 1 of 12 whole shifts. So I stopped; more of this just makes the cutter weak. At 30 the burn sits between spit (22) and lunge (34), which is lower than "high-damage" may mean.

## Decision for John
**Is the prize route too lethal?** The black box sits close to the cargo cutter, the prize wakes that cutter at once, and the heavy load slows you by 35% with stalkers alerted. T014 flagged greedy as too safe (42 of 44 quotas); this may overshoot. My recommendation: play it before changing anything, and if it's too much, move or re-aim the cargo cutter off the prize's route first (`cutters` in data). It keeps the prize's wake-up as the packet asks. Other levers: `warmup_s`, `cancel_hold_s`, holding that cutter back with `on_wake` false.

## My calls, each one line in data
- Crouching behind low cover can hide you from the drone (its eye is low, same trace), though never from the cutter.
- The drone can be shot while dormant, and has no collider, so you walk through it.
- A cutter has an arc (`arc_half_deg`) and range 13 m. Junction has no cutter, because it has no tall cover to answer one.
- A cancelled warm-up makes it look away for 2 s, so you can move on from cover.

## New copy, for approval
A011's lines are used as written, apart from the payslip note, cut to "Your account has been charged." to fit the form. New: "Cut complete. Invoice to follow.", "The property was protected.", "Prior cuts remain on the account.", "Thermal damage on file", "Property protection charge", hazard "Property protection active", suit lines "DRONE CALL COMPLETE. CUTTER ONLINE." and "DRONE CALL COMPLETE. POSITION SHARED.", alarms "CUTTER LOCK", "DRONE CALLING".

## Screenshots
`docs/screens/T015/sheet.png`, plus `t015_lens_dormant`, `t015_lens_awake`, `t015_cutter_sweep`, `t015_cutter_warmup`, `t015_cutter_beam`, `t015_cutter_stopped_by_tall`, `t015_cutter_over_low`, `t015_drone_patrol`, `t015_drone_bars_1/2/3`, `t015_drone_call_complete`, `t015_death_bill`, `t015_payslip`. The forms' numbers are set by hand, through the real flow. In the sweep, warm-up and burn frames the cargo drone is also calling on the player: true to the deck, but not a tell on its own.

## Not checked
- Real play: whether the tells read in time at speed is John's question, and no bot can answer it.
- All sound: chirp, warm-up and burn were never heard, only generated.
- Colourblind reading of mint on the deck. The cutter's hit arc and ring are mint, the stalker's spit arc is green.
- Godot printed `7 RIDs of type "Texture" were leaked` at capture exit. I didn't check whether T014 does the same.

**John's eye:** the sheet, then play past tier 2 and take the black box. Does the ship itself feel like a threat? Can you read the turret and drone in time?
