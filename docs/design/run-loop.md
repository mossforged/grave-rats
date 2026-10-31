# Run loop: shifts, salvage, the clock, the quota (design, approved 2026-10-31)

John approved the lead's recommendations ("yes to all"). Grounded in `docs/studies/2026-10-30-comparable-games.md`: the friend-group hits (Lethal Company, Content Warning, R.E.P.O.) use a short dive against a visible clock, a shared quota, loss that's shared by the crew and lasts only the run, and almost no meta-progression. Every number below is a starting value for `data/`, to be tuned in play.

## The session: a quota over three shifts
- Remnant sets a **credit quota** due at the end of **3 shifts**. Meet it and the next quota is higher (start ×1.0, then about ×1.5 per cycle, from data). Miss it and the crew is **"let go"**: a termination notice (satire screen), then a full reset.
- Each shift is one boarding of one derelict, briefed on the contract screen (A012-01).
- Between shifts: the payslip (A012-02), then the next briefing.

## A shift: greed is the clock
- **Board** at the airlock. The airlock is the extraction point and the **hold**, where deposited salvage is banked for the shift.
- **Oxygen** is the visible hard limit, **billed per minute**: start about 8:00. At zero you don't die instantly; the suit loses integrity steadily (about 2%/s), so a desperate sprint home is possible but costly.
- **The ship gets worse** in tiers, at about 60% and 30% oxygen left (data):
  - more stalkers wake (spawned out of view, from vents and closets, never in sight);
  - lights fail in sections;
  - later, CUSTODIAN wakes.
  Each tier is announced diegetically (alarm, flicker, a CUSTODIAN line) so the player always knows the odds just got worse.
- **The big prize:** each ship has one high-value item (a black box or "the asset", about a third of a quota). Grabbing it **trips an alarm**: stalkers converge on your position and your location shows for about 10 s. This is the sharpest "greed" choice.
- **Leave any time:** stepping into the airlock with "LEAVE" ends the shift for the crew there. Anyone not aboard is left behind (a death bill).

## Salvage: weight is greed made physical
| Class | Examples | Value | Carry |
| --- | --- | --- | --- |
| Small | data chips, med packs, fuses | low | pocketed, up to 6, no penalty |
| Medium | relay assemblies, canisters, busbars | mid | one at a time in hand: −15% speed, no sprint, can fire one-handed with a wider cone |
| Heavy | cargo pods, the black box, engine parts | high | two hands: −35% speed, can't fire; drop instantly (one key), a loud thud (noise) |
- Pick up and drop are committed actions (about 0.5 s and 0.2 s), in keeping with "weight, not speed".
- Dropped items stay where they fall. A crewmate can carry them on later.
- Salvage value has some spread (±20%), so the hold total isn't known exactly until the payslip.

## Death: shared by the crew, only for the run
- You die: what you carried drops where you fell, and your death bill is itemised (A012-03).
- If **anyone** extracts, everything deposited in the hold counts for the crew.
- If **the whole crew** dies, the shift's haul is lost; the quota clock still ticks.
- Nothing is lost between sessions except the quota cycle on a firing.

## Progression: light
- Credits above the quota buy **cosmetics** (suit paint, crew patches) and **side-grade options** (a different rifle, a brighter but louder flashlight, a bigger oxygen tank that slows you). No raw power, no grind.
- Not built yet: this is the direction for later.

## Solo now, co-op later
- Built single-player first, with every rule keyed by player ID, so 1–4 crew is a change of numbers, not of design (CLAUDE.md habits).
- In Open Tender, the hold becomes per crew, extraction is limited, and the big prize's alarm shows the carrier to every crew.
