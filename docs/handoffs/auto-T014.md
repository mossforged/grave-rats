# T014 handoff: the quota over three shifts, and the company paperwork

Branch `auto/t014-mac`. Play it: `godot --path .` (it now opens on the briefing). Start with `docs/screens/T014/sheet.png`.

**Status: the packet is built and every headless check passes, but nobody has played it.** The gate questions ("does the quota make you take risks?", "do the payslip and death bill land?") are John's. The evidence so far is tests, stills and bots.

**Keys on the forms:** Enter or click the yellow button, click DECLINE, wheel or up/down on a long ledger. **In a shift:** Backspace now abandons it (billed, and it counts).

## What changed
1. **`src/shift/quota_state.gd`, `data/shift.json` `quota`, `session`:** scene-free quota: 2,400 CR due after 3 shifts, ×1.5 on a meet, surplus carries, a miss holds the numbers for the notice, then a full reset.
2. **`src/paperwork/` (new), `data/paperwork.json`:** `paperwork.gd` turns logs into documents, `line_book.gd` picks copy (`requires`, `weight`, `cooldown`), `paperwork_screen.gd` draws forms from op lists in data on the A012 sheet, scaled to the window, in Barlow Condensed. All copy, rates and layout are data.
3. **`src/shift/shift_deck.gd`:** the session: briefing (ship rolled, frozen behind the form), shift, payslip or death bill, next briefing or the notice. It starts only when the deck is the running main scene or something calls `start_session()`, so tests, T012 bots and captures still get plain shifts.
4. **`src/run_log/`, `shift_state.gd`:** `death_location`, `threats_seen`, `airlock_cycles`, `salvage` (what's in the hold), `carried_at_death`, `carried_at_death_value`.
5. **`src/hud/`:** a quota plate top right: banked / due, shifts left, a bar. Empty with no session.
6. **Tools:** `tools/t014_bots.gd` (whole sessions, splits across processes), `tools/t014_report.py`, `tools/t014_sheet.py`.

## Checks
| Check | Result |
| --- | --- |
| Headless tests | **360/360, two full runs in a row on the final code** (321 old, 39 new in `tests/test_paperwork.gd`); no script errors |
| Old tests edited | None. The literal scan in `test_weapons.gd` gained the four new scripts |
| Import | Exit 0, no errors |
| Quota math | Meet, carry-over, ×growth from data, exactly the quota is a meet, miss and full reset |
| Briefing | Estimate within ±20% over 1,000 rolls and five totals; hazards only from past logs, and only those; first contract says "No hazards confirmed." |
| Deductions | Every enabled tariff line appears with its cause and is absent without it, one case each; the six switched-off lines never print |
| Arithmetic | Quantity × rate per row, total, net; rate change in data moves the amount |
| Balance due | Negative net shows "NET PAY / BALANCE DUE" and a plain minus, no clamp |
| Death bill | Cause matches the log for spit, puddle, lunge, rifle, oxygen; location recorded on the real deck; no killer and an unknown method aren't guessed |
| Notice | Fires on a miss via declines and via a payslip, then full reset |
| Copy from data | A scan finds no sentences in the scripts; every `{field}` a form names exists on its document |
| Real input | Keys and clicks pushed through the viewport: lock on open, Backspace stops at a form, Enter signs, click declines, Backspace abandons a shift |
| Main scene | One headless launch of the real main scene: session live, briefing open |

The tests still log the non-script `p_size` engine error from drawing with no window (653 lines). The runner doesn't count it.

### Bots: 12 sessions each, stopped at 4 quotas met (`docs/screens/T014/bots.txt`)
| | Greedy | Cautious |
| --- | --- | --- |
| Quota 1 (2,400) met | 11 of 12 | **10 of 12** |
| Quota 2 (3,600) met | 11 of 11 | **2 of 10** |
| Quota 3 (5,400) met | 10 of 11 | **0 of 2** |
| Quota 4 (8,100) met | 10 of 10 | never reached |
| Quotas met per session, mean | 3.5 (10 of 12 hit the cap) | 1.0 (all 12 fired) |
| Average surplus when met | 7,066 | 424 |
| Deaths | **60 of 132 shifts (45%)** | 3 of 72 (4%) |
| Net per shift, deaths at 0 | 2,098 | 869 |
| Survivors' gross / deductions / net | 4,438 / 592 / 3,847 | 1,268 / 361 / 907 |
| Negative payslips | 0 of 72 | 0 of 69 |

Cautious matches the packet: it makes the first quota, then usually misses. **Greedy dies a lot and it barely matters.** One good shift pays for two deaths, so it isn't fired until quota 5 or later (I capped the bots). "Sometimes die" is true, but so far the quota doesn't punish it. Limits: the same bots as T012 (no cover, no sneaking, 0.2 s aim lag), and they never decline or abandon, so no bot ever saw a negative payslip. Only the captures show one.

After the run I changed the hazards' data order, the scroll hint's place and when the capture shows the plate. No bot reads any of these. I didn't re-run them.

### Frame time, 1920x1080 on the M2 Pro (ms, average / p95)
Shift deck, three stalkers hunting, quota plate on, three 15 s windows: **6.63 / 9.62, 6.47 / 9.40, 6.75 / 9.61, mean 6.62 / 9.54**. T013's main scene was 6.75 / 9.74. No visible cost, within noise. Load average about 4, not a quiet Mac. The forms themselves weren't timed: the world still renders behind the opaque sheet.

### Screens (`docs/screens/T014/`)
`sheet.png`, plus `t014_briefing`, `t014_decline_confirm`, `t014_payslip_good`, `t014_payslip_bad` (negative), `t014_payslip_long` (a full ship, scrolling), `t014_death_bill`, `t014_termination`, `t014_quota_hud`. The forms go through the real flow, but the run's numbers are set by hand. `frametime.json`, `frame_times.json`, `bots.txt`.

## Decisions I made (all data unless noted)
- **Net pay goes on the quota, not gross.** The packet says the payslip must still leave a cautious crew able to make quota, which only matters if deductions count. A balance due takes it down.
- **Quota 2,400, not 2,750.** That's about 66% of the cautious bot's three-shift gross on these seeds (3,804). At 2,750 with the first rates it made quota 1 only 3 of 12 times.
- **A012's rates cut hard.** A012 called them illustrative and left the rest unset. Suit 640 to 80, morale 280 to 20, round 20 to 4, cycle 50 to 15; oxygen stays 20. At A012's rates a cautious shift loses more than it earns. Run-specific rates are mine: 2 CR per point of damage, 10 to 20 per incident.
- **Six of A012's twenty lines are off** (`enabled: false`), by A012's own "don't stack": missed rounds, impact reconciliation, obstruction, open-position review, salvage handling, and early closure (no screen follows closing the window).
- **Deaths add nothing to the quota.** The bill goes to next of kin, as the copy says, and the shift is used up. So leaving empty-handed (about -160) costs more than dying (0). A funny fact, and maybe a wrong incentive.
- **Backspace in a session writes the shift off:** nothing credited, a 150 CR replacement fee, and it counts. Otherwise it's a free retry. Outside a session it's still a new shift.
- **Several of a kind print "3 × assessed"** with their true sum: each item has its own value, so qty × unit wouldn't add up.
- **The death screen holds 2.5 s,** then the bill, with an ACKNOWLEDGE button A012 left to this packet.
- **Death bill layout:** tighter evidence rows, and the cause heading and lines added below them. Payslip sidebar: the quota block added, so the net sits higher. Both from A012's sheet; compare if the hierarchy feels off.
- **Hazards are per session, not per vessel:** a new ship still lists what the last one had. That reads as company carelessness, but it's a call. Three rows show, picked by data order.
- **An estimate rounds to 100,** clamped to stay within ±20%.
- **The next of kin is VALE, the contractor ROOK, from A012's fixture.** Killers print as logged ("cargo stalker").

## New copy for John (the rest is A012's)
**Termination notice:** title "YOUR CREW HAS BEEN LET GO."; EMPLOYMENT STATUS / LET GO; SERVICE RECORD (QUOTA CYCLE, SHIFTS BILLED, DECLINED, BALANCES PASSED TO NEXT OF KIN); QUOTA RECONCILIATION (Quota due, Banked at close of cycle, SHORTFALL); FINAL DEDUCTIONS: Contract closure administration 180, Suit recall 240, Exit interview (waived) 90; FINAL BALANCE / FINAL BALANCE DUE; "Balance carries no further. Neither does the contract."; "Thank you for choosing independent recovery."; "Replacement contractor assigned. Name retained for administrative convenience."
Two of these print each time, by what's true:
- The crew has been let go. The vessel has not been told.
- Remnant wishes you every success in your next liability.
- References are available at company-store prices.
- Prior quotas met do not constitute a pattern. (met one)
- No quota was met during this engagement. This has been noted as consistency. (met none)
- Next of kin have been notified of their balance. (a death)
- Declined contracts have been counted as attendance. (a decline)
- Negative earnings have been recorded as earnings. (in debt)

**Decline confirm:** "Declining is a shift. It counts. Confirm?" / "A declined contract still occupies your schedule. Confirm?" / "The quota has not declined. Confirm?"; button CONFIRM DECLINE.
**Oxygen cause (A012 had none; the packet needs one):** "Oxygen exhausted" / "Supply ended. Billing did not."
**Vessels:** MERIDIAN DUE (A012), CASSIA LINE, SECOND TENDER, ORIN'S PATIENCE, HALF MEASURE, VESPER COURTESY, LOW ASSURANCE, THE GOOD STANDING.
**Hazards:** Corrosive organism sighted and Armed rival crew reported (A012); Corrosive discharge recorded, Corrosive residue on deck, Close-contact incident, Asset tamper alarm, Movement in the vents, Section power failure.
**Quota lines:** "QUOTA MET. {n} CR CARRIED OVER. NEXT QUOTA {n} CR." / "QUOTA MISSED BY {n} CR."

## What needs John's eye
1. **The gate:** does the quota make you take risks? Do the payslip and death bill land?
2. **Greedy is too safe from the quota.** It met 42 of 44 quotas while dying in 45% of shifts. Levers: `quota.growth`, or the black box's value (1,500 to 1,800 is about 69% of the first quota, where the design says a third). Or charge deaths to the quota, which would change the "next of kin" joke. Bots don't play like people, so I left it for your play.
3. **Fees are small next to a good shift:** 592 of 4,438 for greedy. Do they change a decision? Ammo at 4 CR a round may not.
4. **Dying costs less on the quota than going home empty-handed.** Keep it?
5. **The ledger's full-ship case scrolls,** and it hides the run-specific lines, which are the jokes. It only happens with most of the ship on one slip. See `t014_payslip_long`.
6. **Barlow Condensed for everything:** the packet asked for it, where A012's picture has mono and Arial. Evidence labels lose the typewriter feel.

## Not checked
Real play and feel, any resolution above 1080p (the scaling has only been drawn at 1080p and headless), a quiet-Mac frame time, frame time with a form up, a bot on a negative payslip, and T006/T007 bots. Declining and abandoning were only tested, never played by a bot.
