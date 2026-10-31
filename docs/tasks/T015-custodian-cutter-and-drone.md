# T015 - CUSTODIAN wakes: the cutter turret and the patrol drone (code)

**Modules:** new `src/custodian/`; `src/shift/` (the tier-2 wake hook T012 left), `src/hud/` (announcements), `src/run_log/` and `data/paperwork.json` (new killers and causes). **Read:** `CLAUDE.md`, `docs/handoffs/auto-A011.md` (**the design: each unit's one rule and one tell; John approved, cutter and drone first**), `docs/screens/A011/sheet.png`, `docs/studies/2026-10-30-comparable-games.md` (combat section: one rule and one tell; nothing hurts unseen; every audio cue has a visual twin), `docs/design/run-loop.md`, the `src/shift/`, `src/enemies/`, `src/sight/`, `src/cover/` and `src/paperwork/` contracts. **Needs:** T014 merged.
**Autonomy:** human-gated (John: *"Does the ship itself feel like a threat? Can you read the turret and the drone in time?"*).

The stalker hunts you. CUSTODIAN, Vesper Reach's maintenance AI, protects company property from "unauthorised salvage", which means you. It's systemic, readable, and gives cover and line of sight a second job. Grey box only (Meshy models come later): the drone and loader inputs exist, the turret is a wall/ceiling box.

## Do
1. **Identity:** mint lens (`#A6E7C4`-ish, from data) on terminals and units; deadpan announcements from A011's copy ("Unauthorised salvage detected. Your account has been charged.", "Please remain clear of company property.", "Crew authority expired. Asset protection continues."), at state changes, with cooldowns, never every attack. Its charges can appear on the payslip as a deduction line, **only when the log shows a CUSTODIAN hit**.
2. **Cutter turret** (ceiling or wall mount, 2–3 placed from data, dormant until woken):
   - **rule:** it needs a clear line to you, and **tall cover breaks it** (low cover doesn't);
   - **tell:** a sweeping mint targeting line that stops at occluders, and a segmented ring that fills during the warm-up (about 1.2 s) before a cutting beam (a short, high-damage burn).
   - Line of sight uses the same 3D trace as the guns. It never fires at someone it can't see, and its line is visible whenever it's aiming at you (the fairness rule).
3. **Patrol drone** (1–2, patrol routes from data):
   - **rule:** break its spotlight's line of sight **before its call completes**, or it summons reinforcements (it wakes a nearby dormant turret, or alerts the nearest stalker to your position);
   - **tell:** a spotlight cone, three roof bars filling in sequence, and a rising chirp (with its visual twin, the bars);
   - fragile (2–3 rifle hits), slow, never attacks directly.
4. **Waking:**
   - CUSTODIAN registers on T012's `wake_hooks["custodian"]`; tier 2 wakes it;
   - the big-prize alarm wakes it early, with a line ("Asset tamper confirmed.");
   - dormant units show their lens dim, awake ones bright.
5. **Paperwork and log:** killers `custodian_cutter`; causes ("Thermal cutting incident", "Property protection enforcement") through the death bill's cause library; `threats_seen` gains CUSTODIAN for the briefing's hazards.
6. **Bots:**
   - a bot that ignores the turret tell versus one that steps behind tall cover on the ring: damage taken;
   - a bot that breaks drone line of sight versus one that doesn't: reinforcement rate.

## Acceptance
- **Headless:**
  - all tests pass;
  - tall cover blocks the cutter, low cover doesn't;
  - the cutter never fires without line of sight and always shows its line while aiming;
  - the warm-up time comes from data;
  - breaking the drone's line of sight before the call completes cancels the call, and a completed call wakes a turret or alerts a stalker;
  - tier 2 and the prize wake CUSTODIAN once;
  - announcement cooldowns hold;
  - the death bill names the new causes;
  - the payslip line appears only with a CUSTODIAN hit;
  - all numbers come from data.
- **Windowed** (`docs/screens/T015/`):
  - the turret line and ring (warm-up), the beam, a line stopped by tall cover;
  - the drone spotlight with its bars filling, a call completing;
  - the dormant versus awake lens;
  - a death bill from the cutter;
  - frame time with CUSTODIAN awake plus three stalkers.
- **Human (John):** does the ship itself feel like a threat? Can you read the turret and drone in time?

Out of scope: the cargo loader (after the charge timing is playtested), door locking and venting, Meshy models, voice.
