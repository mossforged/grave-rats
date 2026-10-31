# A014 - The second derelict: layout and mood concept (art)

**Read:**
- `AGENTS.md`;
- `docs/handoffs/game-brief.md`;
- `docs/design/run-loop.md` (a shift is 8 minutes of oxygen; the black box is the prize; carry classes);
- `docs/screens/A006/sheet.png` (the approved look of the first derelict);
- `docs/screens/props/rooms_sheet.jpg`, `expansion_sheet.jpg`, `hall_*.jpg` (the props and corridor kit the lead has modelled);
- `data/deck.json` (room sizes, wall height 2.6 m, door width, 0.5 m grid, room scale 0.85).

**Needs:** nothing. **Autonomy:** human-gated (John approves before the code lane builds it).

John said yes to a second derelict ship built around the new room types: engineering, bio lab, bridge, crew quarters, mess, with dressed corridors. This packet sets its layout and mood. A code task builds it after John approves.

## Do
Save each to `assets/source/A014-derelict-2/A014-NN.png` with a `.prompt.md`.

1. **A different kind of ship (A014-01):** three short pitches with a thumbnail each, and say which you'd pick. The first derelict is a mid-size hospital/cargo vessel. Make this one different in purpose and mood. Some starting points:
   - a long-haul crew transport that died slowly (quarters, mess, the bridge);
   - a research vessel where the bio lab is the reason everyone is dead;
   - a mining tug whose engineering section is half the ship.

   For each: why the black box is aboard, and one story told by the rooms themselves.
2. **Floor plan (A014-02):** a top-down plan on the 0.5 m grid at game dimensions. Requirements:
   - 6–9 spaces, with the airlock;
   - at least one of each new room type;
   - corridors with at least one loop, so a stalker can cut you off and you can circle;
   - one dead end that is worth the risk;
   - the black box's room far from the airlock.

   Mark:
   - doors, low and tall cover, salvage spots by class, stalker vents and closets;
   - light sources and their colour per room;
   - where CUSTODIAN's cutter and drone would work.

   Keep routes at least 1.5 m wide.
3. **Mood paint-overs (A014-03 … 05):** three frames from the game's steep camera, using the approved A006 language and the modelled props:
   - the bridge in emergency red;
   - the bio lab with the specimen tanks glowing;
   - a dressed corridor (ribs, pipe runs, a breached panel, hanging cables).
4. **Contact sheet** at `docs/screens/A014/sheet.png`.

## Acceptance
- The images and prompts, plus the sheet.
- `docs/handoffs/auto-A014.md`:
  - the pitch you'd pick and why;
  - the plan's dimensions checked against `data/deck.json`;
  - what John needs to decide.
