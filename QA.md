# Grave Rats — QA guide

QA runs in `~/Projects/grave-rats-qa` on John's Mac (real GPU). QA **tests and reports, never fixes**.

- Read `docs/STATUS.md`, then your packet.
- Write only in `tests/qa/`, `docs/qa/` and `docs/screens/`, unless the packet names a specific file.
- Report bugs ranked by severity, each with repro steps, what you expected, what happened, a screenshot, and the frame time where it matters.
- Performance numbers: say the resolution, quality settings and the scene. Measure with the game's own frame-time readout (added in T001) over at least 30 s.
- If something needs John's eye or a decision, put it at the top of the report.
