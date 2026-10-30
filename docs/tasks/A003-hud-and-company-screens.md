# A003 - HUD and company screens (art)

**Read:** `AGENTS.md`, `docs/handoffs/game-brief.md`, `docs/design/tone-bible.md`, `docs/screens/A002/sheet.png` (A002-08b signage for the house graphic style), `docs/concepts/C001-dead-circuit-key-art/gameplay-panel.jpg` (its minimal HUD). **Needs:** nothing.
**Autonomy:** human-gated (John picks a direction for the UI).

The satire lives around the run: the briefing, the payslip, the death bill. The HUD lives in the run and must stay out of the way of a dark, readable game view. This pass explores both, so stage 2 can build a real HUD and the end-of-run screens have a look before anyone codes them.

## Do
Save each as `assets/source/A003-ui/A003-NN.png` with `A003-NN.prompt.md` beside it. 16:9 mockups at 1920×1080 composition. Text must be legible and spelled correctly. If ImageGen garbles text, note it, and keep layout and style as the deliverable.

1. **Gameplay HUD, three directions (A003-01 … 03)**, each over a dark ship-interior game view like C001:
   - **(a) minimal diegetic:** as little as possible; ammo and suit integrity near the character or at the screen edge, like the concept;
   - **(b) suit OS:** a cheap company-issued helmet interface with a scratched visor edge, a rental watermark, and an oxygen meter "billed per minute";
   - **(c) your best idea.**
   All must show:
   - ammo (magazine and reserve);
   - suit integrity (health);
   - oxygen;
   - a loot or credits tally;
   - an interaction prompt;
   - a small ship schematic;
   - crew status for 4 players.
2. **Contract briefing (A003-04).** Company terms-of-service energy:
   - the vessel name;
   - "probably abandoned";
   - estimated salvage value;
   - liability clauses in fine print;
   - an ACCEPT button bigger than the decline one.
3. **End-of-shift payslip (A003-05).** Credits recovered, then a deduction list (suit rental, ammunition at company-store prices, oxygen, "morale", airlock cycling fee), and a net pay that's insultingly small.
4. **Death bill (A003-06).** What the company invoices when you don't come back: "posthumous processing", "unreturned equipment", "biohazard cleanup (you)".
5. **Contact sheet** `docs/screens/A003/sheet.png`, labelled.

Style:
- The A002-08b signage language: bold condensed type, yellow and black hazard accents, the Remnant Asset Recovery mark.
- The in-run HUD stays muted so it doesn't fight the lighting.
- All copy is invented and deadpan (see the tone bible); no real brands.

## Acceptance
- Six images with prompts, plus the sheet.
- `docs/handoffs/auto-A003.md`: a line per image, any text that came out garbled, and your pick for the HUD with one sentence why.
- **Human (John):** picks a HUD direction and approves the screens' tone.

Out of scope: implementing UI, fonts licensing (note candidate open-licence fonts if you can identify them), icons beyond what the mockups need.
