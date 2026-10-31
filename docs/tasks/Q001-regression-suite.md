# Q001 - A repeatable regression and health check (QA)

**Read:** `QA.md`, `docs/STATUS.md`, the bot tools in `tools/` (`t003_footslide.gd`, `t006_bots.gd`, `t007_bots.gd`, `t008_flicker.gd`), the frame-time capture (`tools/capture.sh`, `src/debug/`), and the latest handoffs (`docs/handoffs/auto-T009.md` … `auto-T011.md` if present). **Needs:** nothing (run it when the code lane is idle; see below).
**Autonomy:** auto-ok (a report; nothing in the game changes).

The lead reviews each code branch by hand, but nothing checks that the game *stays* healthy over time: frame time creeping up, bots behaving differently, flaky tests, a fresh clone failing to import. Build one repeatable check, then run it once and report.

## Do
1. **One command:** `tools/qa/health_check.sh` that runs, on the real GPU:
   - **fresh clone:** clone `main` into a temp folder, `--import`, run the headless tests **three times**, and record any test that fails in any run (flaky);
   - **frame time:** 30 s windows in `pirate_deck` and `stalker_deck` at 1920×1080 (or the display's best; say which), plus the machine's load average at the time;
   - **bot replays:** the T006 stalker bots and the T007 pirate bots, with fixed seeds, and foot slide;
   - **flicker:** `tools/t008_flicker.gd` turning-slowly twinkle.
   It writes `docs/qa/health-<date>.md` and a machine-readable `docs/qa/health-<date>.json`.
2. **Baseline and thresholds:** `docs/qa/baseline.json` holds today's numbers. The report compares against it and flags: frame time average +0.5 ms or p95 +1 ms, any bot metric moving more than 25%, any flaky test, any import error. The thresholds live in the baseline file.
3. **Run it once now** and write the first report, with the baseline.
4. **Don't run while the code lane is busy:** if a Godot process is running from `~/Projects/grave-rats-code`, wait (poll every 5 minutes, up to 2 hours), and note in the report if you had to measure under load.

## Acceptance
- `tools/qa/health_check.sh` runs end to end unattended and writes both files.
- `docs/qa/health-<date>.md`: summary first (green, amber or red per area), then details, with repro steps for anything red.
- `docs/handoffs/auto-Q001.md`: how to run it, how long it takes, anything that couldn't be measured.
