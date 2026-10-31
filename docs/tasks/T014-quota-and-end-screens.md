# T014 - The run loop, part 2: the quota over three shifts, and the company paperwork (code)

**Modules:** `src/shift/` (quota and session), new `src/paperwork/` (briefing, payslip, death bill, termination notice screens), `src/run_log/` (any fields the screens need), `src/hud/` only to show the quota. **Read:** `CLAUDE.md`, `docs/design/run-loop.md`, `docs/handoffs/auto-T012.md`, `docs/handoffs/auto-A012.md` (**layouts, copy, the field spec and the deduction and cause libraries; John approved them**), `assets/source/A012-screens/` (A012-01…04 and `build.py`), `docs/handoffs/auto-A010.md` (the company voice), `docs/studies/2026-10-30-comparable-games.md` (tone: lines filled from what happened; every fee should change a decision), the `src/shift/` and `src/run_log/` contracts. **Needs:** T013 merged.
**Autonomy:** human-gated (John: *"Does the quota make you take risks? Do the payslip and death bill land?"*).

T012 made one shift. This makes the session around it, and puts the satire where the study says it lasts: in the paperwork, filled from the run.

## Do
1. **Quota and session** (`data/shift.json`):
   - A quota is due at the end of 3 shifts (starting value about 70% of what the cautious T012 bot banks in three shifts, so caution alone falls short; tune from the bots).
   - Meet it: the next cycle's quota is ×1.5 (data), and the surplus carries over.
   - Miss it: the **termination notice** (the crew is "let go"), then a full reset.
   - The HUD shows quota, banked so far, and shifts left (terse, suit-OS).
2. **Contract briefing** (A012-01) before each shift:
   - the vessel name (from a small data list);
   - "probably abandoned";
   - estimated salvage value (the ship's real total ±20%);
   - known hazards as found so far (fill from the previous shifts' run logs: which threats were seen);
   - the crew list (one row now);
   - the fine print;
   - ACCEPT much larger than DECLINE. DECLINE skips a shift (it still counts against the quota) after a deadpan confirm line.
3. **End-of-shift payslip** (A012-02) after LEAVE:
   - credits recovered by item;
   - deductions from the A012 library, computed from the run: suit rental, ammunition at company-store prices (`shots_fired`), oxygen billed per started minute, airlock cycling (deposits), "morale", plus run-specific lines (cover occupancy, corrosive contact treatment, …) **only when the run log shows the cause**;
   - net pay (can be negative: "NET PAY / BALANCE DUE");
   - then the quota progress.
   Deduction rates from data; the payslip must still leave a cautious crew able to make quota, and a greedy crew more.
4. **Death bill** (A012-03) when you die: posthumous processing, unreturned equipment (what you carried and your suit), biohazard cleanup, the cause of death as recorded (killer, method, location: add the death location to the run log), and the outstanding balance passed to next of kin. Use the cause library; never invent a cause the log doesn't show. "Recovery does not include rescue."
5. **Termination notice:** a new screen in the same language: the crew's quota shortfall, final deductions, "Thank you for choosing independent recovery." Write the copy in the A010/A012 voice and list it in the handoff for John.
6. **Screens** are real UI built from the A012 layouts (scalable, the A012 safe area, the A010 colours, the Barlow Condensed font from T008), not stretched images. All copy lives in data (`data/paperwork.json`) with conditions and cooldowns, so lines don't repeat back to back.

## Acceptance
- **Headless:**
  - all tests pass;
  - quota math (meet, carry-over, ×1.5, miss and reset);
  - the briefing's estimate is within ±20% of truth and its hazards come only from past logs;
  - each payslip deduction appears only when its cause is in the log, and the arithmetic adds up;
  - negative net pay shows as a balance due;
  - the death bill's cause matches the log (spit, puddle, lunge, rifle, oxygen) and the location is recorded;
  - the termination notice fires on a miss;
  - all copy and rates come from data.
- **Bot report:** greedy versus cautious over 3-shift cycles, 12 seeds: quota met rate, average surplus, deaths. Cautious should usually miss later quotas; greedy should sometimes make them big and sometimes die.
- **Windowed** (`docs/screens/T014/`): a briefing, a payslip (good shift), a payslip (bad shift, negative net), a death bill, a termination notice, the quota HUD.
- **Human (John):** does the quota make you take risks? Do the payslip and death bill land?

Out of scope: progression purchases, co-op crew rows beyond one, CUSTODIAN (T015), voice.
