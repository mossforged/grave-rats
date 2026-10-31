# Q001 handoff: repeatable health check (interim; final numbers follow)

Branch `auto/q001-mac`. `tools/qa/health_check.sh` is built and ran end to end once (`--write-baseline`, 18.5 min, green). A second run comparing against that baseline is waiting on the code lane for its last step, flicker. If this line is still here, the run ended before that finished: the baseline and tools are good, but `docs/qa/health-2026-10-30.md` is the first run's report.

## How to run it
`tools/qa/health_check.sh` (add `--write-baseline` to replace the baseline's numbers; thresholds are kept). Exit 0 is no red, 1 is red, 2 is no report.
