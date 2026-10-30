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
| T008 | code | queued: flicker, door-noise rule, suit-OS HUD with the noise ring |
| T009 | code | written: John's Meshy hauler replaces the operator. **Queue it when T008 merges.** |
| A005 | art | merged and approved 2026-10-30 |
| A006 | art | merged and approved 2026-10-30 |
| A007 | art | merged 2026-10-30 (rifle refused by the image tool) |
| A008 | art | merged 2026-10-30: hauler A-pose inputs |

## Lesson
- Twice an addendum missed its task because the runner had already branched. Before adding an addendum, check `git branch -r` for the task's `auto/` branch; if it exists or might, write a new packet instead.
