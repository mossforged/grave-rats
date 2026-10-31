# A015 - Threat bestiary: concept art across enemy types (art)

**Read:**
- `AGENTS.md`;
- `docs/handoffs/game-brief.md` (pillars 2 and 3: light and sight are the core mechanic; weight, not speed);
- `docs/design/tone-bible.md`;
- `docs/design/run-loop.md`;
- `docs/screens/A001/threats.png` (the first exploration);
- `docs/screens/A009/` (Prior Claim, the rival crew);
- `docs/screens/A011/` (CUSTODIAN, the rogue AI);
- `docs/screens/A014/sheet.png` (the biological survey vessel, approved as the second ship).

**Needs:** nothing. **Autonomy:** human-gated (John picks what gets built).

So far the game has the acid-spitting stalker, Prior Claim's pirates and CUSTODIAN. John wants concept art for possible threats across a variety of enemy types, to choose what comes next. Go wide on purpose, but design every one for **this** game:
- **The camera:** steep, top-down oblique. Every threat needs a silhouette that reads from above at small size, plus one strong colour or light accent.
- **Light and sight:** each threat should have a relationship with light. Examples: it hunts toward light, flees it, is invisible outside it, emits its own, or blinds you.
- **Tells:** every threat warns before it hurts, like the stalker's spit glow and CUSTODIAN's rising ring. Draw the tell.
- **Weight:** players can't spin and kill instantly, so threats are about position, cover and doors, not reflexes.
- **Doable:** a Meshy model on the hauler-style rig, a rigid robot, or a flat standee or particle creature. Note which for each.

## Do
Save each to `assets/source/A015-bestiary/A015-NN.png` with a `.prompt.md`. **Each image is one threat:** a three-quarter hero view, a small game-camera view in a ship interior, and a strip showing its tell. Under 20 threats in total, roughly:

1. **Specimens from the survey vessel** (biological, 4–5):
   - a swarm of small things that flood through vents;
   - a parasite that rides a corpse or a suit;
   - a big slow brute that breaks doors;
   - something that lives in the acid pools;
   - a mimic that sounds like a crewmate on the radio.
2. **Ship machines** (3–4):
   - a security robot with an old company badge, still enforcing an expired contract;
   - maintenance spiders that weld doors shut behind you;
   - a cargo loader (CUSTODIAN's third unit, already designed in A011: redraw it for the game camera only);
   - a mining-tug drill drone (for the likely third ship).
3. **Horrors** (2–3):
   - something wearing the dead crew's suits, which looks like a player until it doesn't;
   - a thing that only exists in the dark, shown as a gap in the flashlight;
   - a "rescue beacon" that lures.
4. **People** (2–3):
   - Prior Claim variants: a heavy with a shield, a medic who revives, a sniper who paints a laser through the dark;
   - a company repo agent who arrives late to claim *your* salvage.
5. **One boss per ship type:** the survey vessel's queen or source specimen; a reactor-bound machine for a mining tug. One sheet each.
6. **A matrix sheet (A015-00):** every threat as a game-camera thumbnail with one line each for role, light relationship, tell, counterplay, build route (Meshy/rigid/standee), and which ship it belongs on. Mark your top five to build next.
7. **Contact sheet** at `docs/screens/A015/sheet.png`.

## Acceptance
- The images and prompts, the matrix, and the sheet.
- `docs/handoffs/auto-A015.md`:
  - your top five and why;
  - which threats reuse existing tech (stalker brain, CUSTODIAN tells, pirate squad);
  - any that would need a new system (swarms, the dark-only thing, the radio mimic), named plainly.
