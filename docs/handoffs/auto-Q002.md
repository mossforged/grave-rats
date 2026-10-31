# Q002 handoff: health rerun after T012 to T015

Branch `auto/q002-mac`. Report: `docs/qa/health-2026-10-31.md` (summary first, then hand notes).

## Unexplained regressions
**None found, but frame time isn't settled.** The script says RED on frame time. That traces to T016's code-lane agent, which started one minute into the run, not to a merged packet. This is inferred from timing and load: only window 1 of each scene is bad, and window 2 is inside the thresholds (pirate 7.00 / 9.05, stalker 5.98 / 8.24). The recheck got one clean window, pirate 6.99 / 8.92 (baseline 7.12 / 9.34). Stalker's only recheck window was touched by the code lane, and `shift_deck` got none.

**Needs a re-measure:** run `tools/qa/frame_recheck.sh <commit> <out-dir> <HH:MM>` with the code lane idle, ideally at John's normal display (see below).

## Needs John's decision
**Is the prize route too lethal?** First T014 session rerun with CUSTODIAN: greedy met 0 of 12 first quotas and died in 34 of 36 shifts, 28 by cutter (T014: 42 of 44 quotas met, 45% deaths). This is T015's open question with a bigger number. These bots never leave early and mostly read no tells, so play first. First lever, from T015: move the cargo cutter off the prize route.

## What changed in the script
- **`tools/qa/health_check.sh`:**
  - A third frame window on `shift_deck` (no session, three stalkers, CUSTODIAN awake).
  - A new step running the T012, T014, T015 and T015 shift bots together: 477 s by itself, under the packet's 10 minutes. T014 alone takes 24 min in one process, so it runs as 4 processes of 3 seeds.
  - `--add-baseline`: adds only entries the baseline lacks.
  - Falls back to a borderless window, through an `override.cfg` in the clone only, when a titled one can't reach 1080. Records whether a remote desktop host is running.
- **`tools/qa/health_report.py`:** the new scene and bot sets, deaths by cause, display conditions, `--add-baseline`.
- **`tools/qa/frame_recheck.sh` (new):** frame windows alone. It watches during each window and rejects any the code lane touched.
- **`docs/qa/baseline.json`:** added `frame_time.shift_deck`, `bots.t012`, `t014`, `t015`, `t015_shift`. Existing numbers, thresholds and commit are unchanged, checked value by value against `42930d6`; the new entries carry two explanatory notes. Nothing in the game changed.

**A full run now takes about 31 min when idle** (41 min today with a 10 min wait).

## Results
| Area | Result |
| --- | --- |
| Fresh clone | Import exit 0, 0 errors |
| Tests | 383/383, three runs, no flaky test |
| Frame time, 1920x1080, MSAA 2x (avg / p95 ms) | See above. `shift_deck` first numbers 7.07 / 10.33, provisional |
| T006/T007 bots | 0 of 152 values moved |
| Foot slide | Fixed step 0 of 18 moved; real time walk forward +45% (amber), noise under load |
| Flicker | Green; turning 0.1193 to 0.1242% (+4.1%) |
| New bots | T012 and T015 byte-identical across runs and match T015's handoff; T014 repeats only for a fixed split |

## Checked
- Report on real bot output with a temp baseline: `--add-baseline` left every old number alone; a failed T014 part's exit code is read. The failed part's note itself was cut off in my output, so I didn't read it.
- T012, T015 and T015 shift bots: same JSON alone and under parallel load. T014: same JSON on two runs of the fixed split.

## Couldn't check
- **Frame time on a quiet Mac at scale 2.0.** Every run today had a remote desktop session at scale 1.0, and T016 for all but the first. So `shift_deck`'s baseline is marked provisional in the file.
- **Whether borderless changes the numbers on a normal display.** The check uses it only when a titled window falls short.
- **Why T014's numbers depend on order,** and whether T015 moved cautious's first quota (7 of 12, was 10 of 12). I didn't rerun T014's commit.
- **Whether the moved numbers hold on later main.** The report is on `c5cde11`, which differs from `42930d6` only in art sources, Blender scripts and docs. T016 isn't merged, so none of this covers it.
- Play, feel and sound.

## Left alone
`docs/STATUS.md`, as this run may not write it. For the lead:
- Q002 done on `auto/q002-mac`.
- The 1920×954 question is a display matter: a screen of 1080 points (seen with a remote desktop session) can't fit a titled 1080 window.
- T014's session bots with CUSTODIAN are now measured, so that Parked line can go.
- The health check doesn't yet watch during its windows (finding 1); `frame_recheck.sh` does. Avoid queuing code-lane work during a Q run until that's fixed.
