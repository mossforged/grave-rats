# Q002 - Health rerun after T012–T015 (QA)

**Read:** `QA.md`, `docs/handoffs/auto-Q001.md`, `docs/qa/baseline.json`, the handoffs `auto-T012.md` … `auto-T015.md`. **Needs:** nothing (wait if the code lane is busy, as Q001 does).
**Autonomy:** auto-ok.

Four big code tasks landed since the baseline (the shift loop, the props, the quota and paperwork, CUSTODIAN). Run `tools/qa/health_check.sh` against the existing baseline **without** rewriting it, and report.

## Do
1. Run the health check as is. Note that the main scene is now `shift_deck` with a session; the frame-time windows still measure `pirate_deck` and `stalker_deck`. Add a third window on `shift_deck` (no session, three stalkers, CUSTODIAN awake) to the script, and record its first numbers as new baseline entries only for that scene.
2. Expected moves are not regressions: the test count grew (282 → 383), the T006 and T007 bots run on decks that now include props. For any amber or red, say whether it's explained by a merged packet (name it) or unexplained.
3. Add the T012, T014 and T015 bot tools to the check if they run unattended in under 10 minutes total, with fixed seeds, and record their baselines.

## Acceptance
- `docs/qa/health-<date>.md` and `.json`, summary first.
- `docs/handoffs/auto-Q002.md`: what changed in the script, any unexplained regressions at the top.
