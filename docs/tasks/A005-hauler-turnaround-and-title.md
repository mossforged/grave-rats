# A005 - Orange hauler turnaround, suit-OS HUD, title and logo set (art)

**Read:** `AGENTS.md`, `docs/handoffs/game-brief.md`, `docs/design/tone-bible.md`, `docs/decisions.md` (the 2026-10-30 art picks), `docs/playtests/log.md` (the 2026-10-30 entry's art lines), and these sources: `assets/source/A001-crew-threat/A001-01.png`, `A001-08.png`; `assets/source/A003-ui/A003-01.png`, `A003-02.png`; `assets/source/A004-title/A004-01.png`, `A004-04.png`, `A004-05.png`, `A004-07.png`, `A004-08.png`. **Needs:** nothing.
**Autonomy:** human-gated (John approves the directions developed).

John picked the directions. This pass develops them so stage 3 has something to model from and the game has a face.

## Do
Save each as `assets/source/A005-dev/A005-NN.png` with `A005-NN.prompt.md` beside it.

1. **Orange hauler model sheet (A005-01 … 03).** Develop A001-01 into a sheet a 3D modeller can work from. Keep the design and colour accent. Neutral background, flat even light, no perspective distortion.
   - **01:** front, back and side orthographic views at the same scale, with a 1.8 m height line.
   - **02:** a three-quarter view, plus close-ups of the helmet, life-support pack, tool belt and one hand holding the rifle.
   - **03:** the hauler from the game camera (steep overhead three-quarter, about 60° pitch), at game size and at 4× zoom. Check the silhouette, helmet and orange accent read from above.
2. **Crew variety, first look (A005-04).** John wants "variation in their look and size eventually". One sheet: the hauler beside three crew-mates of clearly different build and height (a small wiry one, a big heavy one, an average one), all from the same company-issue suit language, each with its own colour accent. Front view, same scale.
3. **Suit OS HUD, developed (A005-05, 06).** John picked A003-02 (suit OS) and liked the ring around the operator in A003-01.
   - **05:** the A003-02 HUD over a dark game view, with A003-01's ring around the operator added (status, ammo or noise on the ring; your call).
   - **06:** the same HUD in a tense moment: low suit integrity, the acid alarm, a low-ammo warning, and an `IN COVER` mark.
   Keep the rental watermark and the oxygen "billed per minute".
4. **Title art, recomposed (A005-07).** A004-08, recomposed as John asked: one crew member working the airlock door (cutting or overriding it) while another walks up behind. Same wide 16:9 framing and logo space.
5. **Logo set (A005-08).** One sheet: the A004-01 hull stencil wordmark, cleaned for small sizes (fewer paint chips), with A004-04's cracked-visor treatment as a variant, and A004-05/07's rat crew patch as a companion emblem. Show each at large size and at 64 px tall.
6. **Contact sheet** `docs/screens/A005/sheet.png`, labelled.

## Acceptance
- Eight images with prompts, plus the sheet.
- `docs/handoffs/auto-A005.md`: a line per image, anything refused or garbled, and whether you think 01–03 are clean enough to model from.
- **Human (John):** approves the hauler for modelling, picks the crew-variety direction, the HUD layout and the title art.

Out of scope: 3D, threats beyond the acid stalker, environment (A002 stands as picked), UI implementation.
