# Q001 handoff: repeatable health check

Branch `auto/q001-mac`. The first report is **green, with no game regression found**: `docs/qa/health-2026-10-30.md` (hand-written QA notes at the top). One call is open: which foot-slide number to believe (below).

## How to run it
`tools/qa/health_check.sh` from `~/Projects/grave-rats-qa`. Add `--write-baseline` to replace the numbers in `docs/qa/baseline.json`; thresholds there are kept. Exit 0 is no red, 1 is red, 2 is no report.

**How long:** about 18.5 min when the code lane is idle (clone 2 min, frame time 3, tests 7.5, bots and foot slide 4.5, flicker 1.5), plus up to 2 hours of waiting if it's busy. Anything launching it needs a time budget of about 2.5 hours. My own 1-hour limit killed run 2's wait.

**What it writes:**
- `docs/qa/health-<date>.md` and `.json`. A second run on the same date overwrites them.
- `docs/qa/logs-<date>/`. Full test and flicker logs are kept only if that step failed, because they run to hundreds of KB of known noise.
- `docs/screens/qa-<date>/`: one still per deck.

## What changed
Only new files, nothing in the game:
- `tools/qa/health_check.sh`: the run.
- `tools/qa/health_report.py`: the comparison and report.
- `tools/qa/t006_seeded.gd`, `t007_seeded.gd`: the bot tools with their seeding fixed; the originals are untouched.
- `docs/qa/`, `docs/screens/qa-2026-10-30/`.

## Results
| Area | Result |
| --- | --- |
| Fresh clone | Import exit 0, 0 errors, in both runs |
| Tests | 282/282, three times in each run; no flaky test |
| Frame time, pirate (avg / p95 ms, 1920x1080, MSAA 2x) | Baseline 7.12 / 9.34; now 7.03 / 9.18 |
| Frame time, stalker | Baseline 6.60 / 9.47; now 6.24 / 8.40 |
| Bots, seeded | 0 of 152 T006/T007 metric values moved |
| Foot slide | Fixed step identical; real time within about 11% |
| Flicker, turning | 0.1193% twinkle, baseline 0.1193% |

Load averages were about 3 to 4, or up to 6.6 right after run 1's last window. The baseline is run 1 on `050b0b0`; the report is run 2 on `8e9da2c`, because main moved between them.

Levels: over a threshold is amber, over twice it is red. The packet sets the thresholds; these are my calls:
- the red multiplier of 2;
- the 25% threshold on twinkle (the packet names none);
- frame-time flags fire only on slower, not faster;
- two 30 s windows per scene, averaged, because a single window is noisy;
- frame time runs before the tests, so their CPU use doesn't land in the windows.

## Needs a decision
**Foot slide: which number do we believe?** Fixed step reads 1.5 to 5 times lower than real time (walk forward 0.38 against 1.97 m/s). T009's table is real time. I didn't find the cause. The check records both, so nothing is lost while this waits.

## Checked
- Report flags, on doctored inputs: amber and red frame time, a moved bot metric, a metric gone missing, moved twinkle, a flaky test, a test failing every run, a test run that never finished, an import error, a missing capture, empty bot and flicker logs, the under-load note.
- Code-lane detector with real Godot processes: idle with none, idle in another folder, busy for `--path .` in a folder named `grave-rats-code`. The real T012 run then tripped it too.
- Hang guard: killed a hung command on time and left no false "killed" line on a clean one.

## Couldn't check or measure
- **The 2-hour give-up path end to end.** The wait only reached 50 min, because a gap opened. Its report note was tested on a doctored run.
- **Fallback to the local clone if GitHub is down:** written, never triggered.
- **A quiet Mac.** The baseline is on a normally busy one; re-baseline when a quiet one is available.
- **Code-lane Godot starting mid-window.** The detector looks only before each window. It also doesn't see a code-lane agent that isn't running Godot at that moment.
- **Anything about feel.** A still or a number can't say whether the game plays right. The frame-time windows are each deck's scripted `_demo_step` fight, and its enemies aren't seeded, so no two windows are the same frames.

## Left alone
- `docs/STATUS.md` isn't updated, because this run may only write in the QA folders plus this handoff. For the lead:
  - Stage line: Q001 done on `auto/q001-mac`, first report green.
  - The open question about `capture.sh` reaching only 1920×954 looks out of date: all eight windows reached 1920x1080.
  - T007's "same seeds" claim doesn't hold.
- The bugs in the report's findings are for the code lane; QA doesn't fix.
