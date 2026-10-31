# A012 - End-of-shift screens, final layouts for building (art)

**Read:** `AGENTS.md`, `docs/design/tone-bible.md`, `docs/screens/A003/sheet.png` (A003-04 briefing, 05 payslip, 06 death bill), `docs/screens/A005/sheet.png` (the suit-OS HUD style), `docs/screens/A010/sheet.png` and `docs/handoffs/auto-A010.md` (approved company graphics and voice), `docs/studies/2026-10-30-comparable-games.md` (tone section: satire built into the rules lasts; lines filled in from what happened in the run; every fee should change a decision), `src/run_log/CONTRACT.md` (what a run records). **Needs:** nothing.
**Autonomy:** human-gated (John approves layouts and copy before a code task builds them).

A003 explored the briefing, payslip and death bill as moods. Now they become **buildable**: final 1920×1080 layouts in the A010 graphic language, with every changing value marked, so a code task can fill them from the run log. The joke is that the paperwork is real: your death bill itemises how you actually died.

## Do
Save to `assets/source/A012-screens/` as `A012-NN.png` with a `.prompt.md` each. Clean, flat UI, legible and correctly spelled text; if the tool garbles text, keep the layout and say so.
1. **Contract briefing (A012-01):** vessel name, "probably abandoned", estimated salvage value, known hazards (as found so far), crew list, fine-print liability clauses, an ACCEPT button bigger than DECLINE.
2. **End-of-shift payslip (A012-02):** credits recovered by item, then deductions with run-specific lines (suit rental, ammunition at company-store prices, oxygen billed per minute, airlock cycling, "morale"), net pay.
3. **Death bill (A012-03):** what Remnant invoices when you don't come back: posthumous processing, unreturned equipment, "biohazard cleanup (you)", the **cause of death as recorded** (killer, method, location), and the outstanding balance passed to next of kin.
4. **Field spec (A012-04):** the three screens again with every variable field boxed and labelled (e.g. `{killer}`, `{damage_by_source.spit}`, `{shots_fired}`), plus a list of 20 deduction lines and 15 death-bill causes in the tone-bible voice, each tied to something the run log can know. Put the full copy as text in the handoff too.
5. **Contact sheet** `docs/screens/A012/sheet.png`.

## Acceptance
- Four images with prompts, plus the sheet.
- `docs/handoffs/auto-A012.md`: a line per image, all copy and field names as text, anything garbled, and your three favourite lines.
- **Human (John):** approves the layouts and copy for a build task.
