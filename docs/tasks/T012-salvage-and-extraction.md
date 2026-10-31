# T012 - The run loop, part 1: salvage, the oxygen clock, escalation, extraction (code)

**Modules:** new `src/salvage/`, new `src/shift/` (the shift state: oxygen, tiers, hold, extraction); `src/enemies/` (spawning out of view, the alarm converge), `src/hud/` (oxygen ticker becomes real; a carry readout), `src/player/` (carry penalties only), `src/run_log/` (new fields). **Read:** `CLAUDE.md`, `docs/design/run-loop.md` (**the design; follow it**), `docs/studies/2026-10-30-comparable-games.md` (progression section), the contracts of the modules above. **Needs:** T011 merged.
**Autonomy:** human-gated (John: *"Does 'one more room?' happen? Is grabbing the black box scary?"*).

The core loop is fun to fight in, but there's no game around it yet. This builds one shift, end to end, solo. The quota across shifts and the end-of-shift screens come in T013.

## Do
1. **Salvage** (`src/salvage/`, `data/salvage.json`): small, medium and heavy classes with value ranges and carry rules as in the design: pocket limit; in-hand speed penalties; no sprint; one-handed fire with a wider cone for medium; no firing for heavy; committed pick-up and drop times; drop is instant and loud. Grey-box items, colour-coded by class, with an emissive rim so they read in the dark (fairness rule). Placed on the deck from data: about 20 small, 8 medium, 4 heavy, plus one **big prize**.
2. **The hold and extraction:** the airlock is the hold. Deposit by walking in with items. "LEAVE" (hold E in the airlock for 1.5 s) ends the shift. The shift result goes to the run log: deposited items and value, carried-but-lost, survivors.
3. **Oxygen:** a real clock (about 8:00, from data) driving the suit-OS ticker, "billed per minute". At zero, suit integrity drains (about 2%/s). Deposited in the hold, oxygen isn't refilled (the clock is the shift).
4. **Escalation tiers** at oxygen thresholds (data):
   - tier 1: one extra stalker spawned out of view (vents and closets in data, never inside any player's sight), plus an announcement;
   - tier 2: another stalker, and one section's lights fail (practicals off with a flicker), plus an announcement.
   Leave a hook for CUSTODIAN (T014) to wake at a tier.
5. **The big prize:** picking it up trips the alarm: every stalker gets your position (hunt), and your position is revealed for 10 s (a pulsing marker; this matters for co-op later). A loud siren placeholder.
6. **HUD:** the oxygen ticker is real; a carry readout shows pocket slots, the in-hand item and its value class; a hold total shows "≈" while unconfirmed; tier announcements in the suit-OS voice, terse, no quips.
7. **Run log:** shift outcome, oxygen at exit, items deposited by class and value, items lost, prize taken or not, the tier reached, cause of death.
8. **Deck:** use the T011 main deck (`stalker_deck`, the medbay / junction / cargo slice), with the airlock at the spawn end. A respawn key starts a new shift.

## Acceptance
- **Headless:**
  - all old tests pass (three runs, no flakes);
  - the carry rules (speed, no sprint, firing rules, pocket limit) come from data;
  - pick-up and drop timings are correct;
  - deposit adds to the hold;
  - LEAVE ends the shift and logs it;
  - oxygen drains, then the suit drains at zero;
  - tiers fire at their thresholds and spawn only out of sight (test with the player looking at a spawn point: it must pick another);
  - the prize trips the alarm and stalkers converge;
  - the run log has the new fields;
  - all numbers come from data.
- **Bot report:** a "greedy" bot that grabs everything versus a "cautious" bot that leaves at tier 1: value banked, survival rate, over 12 seeds.
- **Windowed** (`docs/screens/T012/`):
  - carrying each class;
  - the hold deposit;
  - a tier-2 lights failure;
  - the prize alarm, in 3 frames;
  - oxygen at zero;
  - leaving;
  - frame time with three stalkers.
- **Human (John):** does "one more room?" happen? Is grabbing the black box scary?

Out of scope: the quota across shifts, end screens and the termination notice (T013), CUSTODIAN units (T014), co-op, progression purchases.
