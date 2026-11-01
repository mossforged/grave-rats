# Q003 handoff: health after props, sound, co-op and effects

Branch `auto/q003-mac`, on main `a4a5f73`. Report: `docs/qa/health-2026-10-31-q003.md` (hand notes first). Baseline updated, with notes, in `docs/qa/baseline.json`. Nothing in the game changed.

## Unexplained regressions
**None that matter.** T006's `killed_it_s` went 1.64 to 1.65 (+0.6%, green) and I didn't trace it; it may be rounding. The script says RED on three areas, and every flag traces to a merged packet (table in the report).

## Per-packet frame cost (fight windows, 30 s, 1920x1080, MSAA 2x; avg / p95 ms)
| Packet | `pirate_deck` | `stalker_deck` | `shift_deck` |
| --- | --- | --- | --- |
| T019 against T018 (one window each, close to noise) | +0.21 / +0.16 | +0.14 / +0.23 | -0.02 / 0.00 |
| T020 against T019 (one window each) | +0.63 / +0.94 | +0.02 / -0.06 | +0.68 / +0.74 |
| T021 to T023 | within spread | within spread | within spread |
| **T018 to main** | **+0.82 / +1.27** | +0.30 / +0.41 | +0.41 / +0.45 |
| **main, clean recheck** | **7.84 / 10.33** | 6.51 / 8.89 | 7.61 / 11.06 |

- **Mag dump on main (275 rounds in 30 s, AI stopped):** pirate 5.67 / 6.41, stalker 6.41 / 7.29, shift 6.84 / 7.78. Against the same stand on T018: +0.66 to +0.79 / +0.92 to +1.17.
- **Every environment effect on main (AI stopped):** pirate 5.61 / 6.16, stalker 6.48 / 7.14, shift 6.98 / 7.78.
- **Conditions:** 0 of 102 windows touched by another Godot or the code lane, and the code lane stayed idle. But load was 3 to 6, other projects' agents were running, and a remote desktop held the screen at scale 1.0. These are clean windows, not a quiet Mac. Scale 2.0 is still unmeasured.

## Solo feel
- **Input to motion: identical across T018,** step for step in all 11 cases, T017 to main. There was no earlier number, so I wrote `tools/qa/input_to_motion.gd` and ran it on the old commits. It catches a one-step delay on movement and crouch; fire, reload, E and aim weren't shown to fail. Events are synthetic, not a real keyboard.
- **T006, T007:** unchanged, apart from the +0.6% above.
- **T012: moved, from T023's bot fix.** BOTS_EVIDENCE
- **Foot slide: moved, from T022, checked commit by commit.** T021 matches the old table to the digit. Most cases improved; **sprint forward is worse,** 0.65 to 1.29 m/s (T022 reported it).

## Needs the lead
1. **`pirate_deck` and T011's target (7.5 / 9.5):** T019 meets it, T020 and main don't. Move the target, or ask T020 for about 0.4 ms avg and 0.9 ms p95 back.
2. **`--import` sometimes crashes on a fresh clone,** then passes on retry: exit -11 seen directly on `64aa58f`, about 4 of 22 imports this run, none of 6 on main. A half-loaded deck runs and reads very fast with no warning. It spoiled T019's first windows; I threw those out. John's paste command stops on a failed import, which is the safe way round; he'd only need to run it again. `health_check.sh` and `frame_recheck.sh` still don't guard against it.
3. **`docs/STATUS.md` not updated:** this run may only write QA paths and this handoff. Lines for it: Q003 done; the baseline now sits on `a4a5f73`; the two items above. To park: `t003_footslide` never ends on a half-imported clone (16 GB log, deleted).

## Needs John
**Balance read, after T023's bot fix:** cautious meets 45 of 48 quotas and dies in 8.3% of shifts; greedy meets 0 of 12 first quotas and dies in 36 of 36 shifts. These bots never leave early, so it's a question for play, as on his list.

## What changed in the tools
- `tools/qa/health_check.sh`: `QA_DATE`, so a second run in a day keeps the first's report.
- `tools/qa/frame_recheck.sh`: uses the wider `guard.sh`.
- New in `tools/qa/`: `guard.sh`, `packet_cost.py`, `input_to_motion.gd`, `q003_fx_*` (one state per window, runs before T020 too), `t014_old_press.gd`, `q003_baseline.py`.
- `docs/qa/baseline.json`: frame time, foot slide, T012, T014, T015 shift and flicker moved to main, each with a note; the old frame numbers are kept under `updates`. T006, T007 and T015 tell bots untouched.

## Couldn't check
Play, feel, sound; scale 2.0; survey vessel and two-player frame time; T016 and T017 split out; T020's dump apart from T021 to T023 (its stands hit the bad import, no time to rerun); a plume that really fills the screen.
