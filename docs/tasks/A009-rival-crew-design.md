# A009 - The rival crew: design sheet and Meshy inputs (art)

**Read:** `AGENTS.md`, `docs/handoffs/game-brief.md`, `docs/design/tone-bible.md`, `docs/screens/A001/sheet.png` (A001-13, rival pirate crew), `docs/screens/A005/sheet.png` (our crew), `assets/source/A008-hauler-apose/` and `assets/source/meshy/input/hauler-apose-front.png`, `docs/screens/T007/` (the grey-box pirates, recoloured white and navy). **Needs:** nothing.
**Autonomy:** human-gated (John picks the rival crew's look).

The rival crews (T007) are our hauler recoloured. They need their own identity: the satirical opposite of ours, **better funded, worse people**. A crew from a slicker, richer salvage outfit: clean matching suits, a corporate sponsor, real armour, smug branding. They must read apart from our orange crew instantly from the game camera.

## Do
Save to `assets/source/A009-rivals/` as `A009-NN.png` with a `.prompt.md` beside each.
1. **Rival outfit identity (A009-01):** one sheet. An invented company name and logo (deadpan, no real brands), a colour scheme (white and navy is the starting point; push it so it never confuses with our orange), and three short taglines in the tone-bible voice.
2. **Rival crew lineup (A009-02):** three to four members of the rival crew, front view, the same scale as A005-04: a squad leader, a heavy, a scout, a tech. Matching, expensive gear against our patched rentals. **Show them empty-handed** (the image tool refuses guns); a holster or sling is fine.
3. **From the game camera (A009-03):** the rival lineup beside our orange hauler, from a steep overhead three-quarter view at game size and at 4× zoom. They must read apart at a glance.
4. **Meshy inputs:** the rival squad leader in the **A008 rigging pose** (arms out about 45°, hands open and clear of the hips, legs apart, nothing dangling into the gaps), as front, side, back and three-quarter views, on the A007 studio background. Save as `assets/source/meshy/input/rival-apose-{front,side,back,34}.png`.
5. **Contact sheet** `docs/screens/A009/sheet.png`.

## Acceptance
- The images with prompts, plus the sheet.
- `docs/handoffs/auto-A009.md`: a line per image, how well the views match, anything refused, and your pick.
- **Human (John):** picks the rival look; then he can make the rival in Meshy.
