# Lead handoff (for a fresh lead chat)

**Lead:** Claude chat (cloud), started 2026-10-29. If a newer lead takes over, mark it here: "taken over by <session>".

## Lanes
| Lane | Who | Where | Queue | Branches |
| --- | --- | --- | --- | --- |
| Code | Claude Code, unattended | Mac mini `~/Projects/grave-rats-code` | `docs/queue/code.txt` | `auto/t0nn-mac` |
| Art | Codex (ImageGen), unattended | Mac mini `~/Projects/grave-rats-art` | `docs/queue/art.txt` | `auto/a0nn` |
| QA | Claude Code, unattended | Mac mini `~/Projects/grave-rats-qa` | `docs/queue/qa.txt` | `auto/q0nn-mac` |
| Models | John, case by case | drops into `assets/source/john/` | - | - |

Runner logs on the Mac: `~/Library/Logs/grave-rats-<lane>-runner.log`.

## Routine
Queue a packet by committing its ID to the lane's queue file on main and pushing. Review `auto/` branches from the repo: tests, diff, screenshots, frame times. Merge with a normal merge commit. Record settled choices in `docs/decisions.md` and John's play feedback in `docs/playtests/log.md`.

## Standing preferences (John)
- Plain words, no tool names.
- Builders run on the Mac by default; cloud only as a fallback.
- No GitHub Actions, no LFS, no spending.
- Irreverent humour is welcome.
- He judges feel and taste; agents never pass a gate that needs him.

## In flight
| ID | Lane | State |
| --- | --- | --- |
| T001–T005 | code | merged 2026-10-30; John played T005 2026-10-30, gate not passed |
| A001–A004 | art | merged 2026-10-30; John picked 2026-10-30 |
| T006 | code | merged 2026-10-30; waits for John's play |
| T007 | code | merged 2026-10-30; waits for John's play |
| T008 | code | merged 2026-10-30; waits for John's play (flicker gone? HUD? ring?) |
| T009 | code | merged 2026-10-31; waits for John's play |
| T010 | code | written: scripted slice kit, materials, lighting (stage 3). queued 2026-10-31 |
| A005 | art | merged and approved 2026-10-30 |
| A006 | art | merged and approved 2026-10-30 |
| A007 | art | merged 2026-10-30 (rifle refused by the image tool) |
| A008 | art | merged 2026-10-30: hauler A-pose inputs |
| A009 | art | merged 2026-10-31; waits for John's pick (Prior Claim recommended) |
| A010 | art | merged and approved 2026-10-31 |
| Q001 | qa | written: repeatable health check. queued 2026-10-31 |
| A011 | art | merged and approved 2026-10-31 (cutter + drone first) |
| A012 | art | merged and approved 2026-10-31 |
| T012 | code | merged 2026-10-31; waits for John's play (one more room? black box scary?) |
| T013 | code | merged 2026-10-31; lead then reworked the locker bank and added console_1600 |
| T014 | code | merged 2026-10-31; waits for John's play (balance flags in STATUS) |
| T015 | code | merged 2026-10-31; waits for John's play |
| Q002 | qa | merged: health rerun; no unexplained regressions; frame time needs a quiet-Mac re-measure; greedy dies 34 of 36 with CUSTODIAN |
| (pause) | code | no new gameplay/balance until John plays T012–T015; non-balance work continues |
| T016 | code | merged: bed, medbay dressing, salvage models; AA toggle (John picks by eye) |
| T017 | code | merged: placeholder sound (44 cues); John listens |
| T018 | code | merged: co-op groundwork; solo must feel unchanged |
| T019 | code | merged: corridor dressing; John judges depth and darkness |
| T020 | code | merged: gun feel and effects; John fires a mag in the dark |
| T021 | code | merged: bed stripe, wall-top z-fight fix, lock commands |
| A013 | art | merged and approved 2026-10-31 |
| A014 | art | merged; John picked B, biological survey vessel; mining tug likely ship 3 |
| Q003 | qa | written, NOT queued: queue once T022 merges and the code lane is idle |
| T023 | code | queued after T022: build the survey vessel as a second ship (A014 plan, room props, A013 decals, effects); default ship unchanged |
| T022 | code | queued: John's 88 Mixamo clips on the hauler (8-way locomotion, fire, reloads, hits, deaths, actions, heavy carry) |

## Lesson
- Twice an addendum missed its task because the runner had already branched. Before adding an addendum, check `git branch -r` for the task's `auto/` branch; if it exists or might, write a new packet instead.
