# Q003 - Health check after props, sound, co-op and effects (QA)

**Read:** `CLAUDE.md`, `docs/tasks/Q002-health-rerun.md`, `docs/handoffs/auto-Q002.md` (its findings and the provisional baseline), `docs/qa/baseline.json`, the handoffs of everything merged since Q002 (T016–T021).
**Needs:** T023 merged, and the code lane idle (Q002 finding: the code lane's runs spoil frame windows).
**Autonomy:** auto-ok.

Five packets have landed since the last health check: the bed and medbay props, sound, co-op groundwork, corridor dressing, gun feel and effects, and polish. Each added frame cost or rewired input. Check nothing quietly regressed, and get the clean frame-time numbers Q002 couldn't.

## Do
1. Run `tools/qa/health_check.sh` on the merged main.
2. Use `tools/qa/frame_recheck.sh` so every frame window is checked as untouched by other work. If the code lane starts mid-run, stop and rerun rather than report spoiled windows.
3. **Measure the frame cost of each recent packet:**
   - T019 (corridors) and T020 (effects) against T018's commit;
   - all three decks;
   - also a 30-round mag dump into a metal wall, and every environment effect running.
4. **Solo feel after T018's command layer:**
   - run the T006/T007/T012 bots and compare to baseline;
   - check that the foot-slide and input-to-motion numbers didn't move.
5. Update the baseline where the change is explained by a merged packet; mark anything unexplained.

## Acceptance
- `docs/qa/health-<date>.md` with a summary first.
- The baseline updated, with notes.
- `docs/handoffs/auto-Q003.md`:
  - unexplained regressions (or none);
  - per-packet frame costs;
  - what needs the lead or John.
