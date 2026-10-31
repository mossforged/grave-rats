# A011 - The second threat: the rogue ship AI (art)

**Read:** `AGENTS.md`, `docs/handoffs/game-brief.md`, `docs/design/tone-bible.md`, `docs/screens/A001/sheet.png` (A001-09, rogue AI), `docs/studies/2026-10-30-comparable-games.md` (combat section: each threat needs one learnable rule and a readable tell; nothing that hurts you stays invisible), `docs/screens/A006/sheet.png` and `docs/screens/A010/sheet.png` (the ship's look and the dead owner, Vesper Reach Freight). **Needs:** nothing.
**Autonomy:** human-gated (John picks the direction).

The stalker is the organic threat that hunts you. The second is the **ship itself**: Vesper Reach Freight's maintenance AI, still running its last instructions. Protecting company property from "unauthorised salvage" means protecting it from you. It isn't evil; it's compliant. It's systemic where the stalker is personal, and it gives cover and doors a second purpose.

## Do
Save to `assets/source/A011-rogue-ai/` as `A011-NN.png` with a `.prompt.md` each.
1. **Identity (A011-01):** its name and a deadpan corporate voice (a few announcement lines, e.g. "Unauthorised salvage detected. Your account has been charged."), an interface look (one eye or lens motif, colour that reads as "the ship", never orange or Prior Claim navy) and how its presence shows on walls and screens.
2. **Its bodies (A011-02):** three to four units, each with **one rule and one tell** a player can learn:
   - a ceiling or wall **turret** (tell: a sweeping laser line or warm-up glow; it can't see past tall cover);
   - a small **maintenance drone** that patrols and calls others (tell: a spotlight and chirp);
   - a heavy **cargo loader** repurposed as a bruiser (tell: warning lights and a reversing beep; slow, can't turn fast);
   - optional: the AI locking and unlocking doors, venting a room (tell: a countdown and a red strip).
   Front and three-quarter views, on the A007 studio background, **no weapons pointed at the viewer** (keep it industrial: welders, nail guns, cutting lasers, clamps).
3. **From the game camera (A011-03):** the units at game size beside the orange hauler and the stalker, in the ship's lighting; their tells must read from above.
4. **Meshy inputs:** the drone and the loader as clean single-object views (A007 rules), at `assets/source/meshy/input/drone-{34,front,side,back}.png` and `loader-{34,front,side,back}.png`.
5. **Contact sheet** `docs/screens/A011/sheet.png`.

## Acceptance
- The images with prompts, plus the sheet.
- `docs/handoffs/auto-A011.md`: a line per image, each unit's rule and tell in one sentence, anything refused, your pick.
- **Human (John):** picks the AI's identity and which units to build first.
