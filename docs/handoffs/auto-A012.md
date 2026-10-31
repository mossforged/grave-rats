# A012 — End-of-shift screens

Status: complete for human review. John must approve layouts, rates and copy before a build task. No approval is claimed. Work stops at this packet gate.

## Deliverables

- **A012-01** — Contract briefing; 1180 px ACCEPT versus 304 px DECLINE, known hazards and four crew slots. Source: `assets/source/A012-screens/A012-01.png`; matching `.prompt.md`.

- **A012-02** — Itemised payslip; 2,480 gross − 2,470 deductions = 10 CR net. Source: `assets/source/A012-screens/A012-02.png`; matching `.prompt.md`.

- **A012-03** — Death bill; 180 + 1,640 + 420 = 2,240 CR to next of kin, cause evidence separate from accounting. Source: `assets/source/A012-screens/A012-03.png`; matching `.prompt.md`.

- **A012-04** — Three boxed field diagrams, twenty deduction lines and fifteen death-bill cause/context variants. Source: `assets/source/A012-screens/A012-04.png`; matching `.prompt.md`.

Review: `docs/screens/A012/sheet.png` (2024 × 1316; all originals shown at 50%). All four originals are opaque RGB PNG, **1920 × 1080**. Editable deterministic source: `assets/source/A012-screens/build.py`. Run with Python 3 + Pillow on macOS; system fonts: DIN Condensed Bold, Arial/Arial Bold, Andale Mono. Fonts are referenced, not redistributed. All copy is typeset, not image-generated. No image tool was called, no refusal occurred, no garbled text.

## Graphic and build specification

A010 Remnant language: ivory #eee9d9, ink #171b1c, yellow #f5cc24, restrained red #aa302d, dark surround #12191c. Clipped 16 px corners, crisp dividers, condensed headings, plain body and monospaced evidence. No speculative new company logo. No combat artwork, grime, fake scan codes or baked scene background. A005 suit-OS informs terse evidence labels and administrative grouping.

Screen safe area: 56 px sides, header to y=126, title y=152, content begins y=244; footer y=1033. Body 23–30 px; primary headers 72 px. A012-04 is an engineering diagram: 17 px field labels, 20 px library entries. Scale UI as a layout rather than stretching a PNG. These are layout references, not shipped UI textures.

Repeated ledger rows: preserve description, quantity × rate and right-aligned CR columns. Variable lists scroll within their panel when longer than the example; keep gross/net, total due and actions pinned. Wrap labels to two lines and increase row height; never shrink player copy below 23 px. Empty hazards: “No hazards confirmed.” Empty salvage: “No recoveries recorded.” Crew supports 1–4 rows. Missing values render “Not recorded”; a real recorded zero stays 0. Negative net pay displays a minus sign and label “NET PAY / BALANCE DUE”; no silent clamping. No continue button is specified for the death screen; navigation belongs to a later build packet.

## Evidence boundary and proposed inputs

The packet requires data absent from the current CONTRACT.md. The layouts are buildable proposals, not a claim that these fields already exist. This does not block layout review. All fixture names, hazards, credits, rates and return status are illustrative. A012-02 is a successful-return fixture; A012-03 is a separate fatal fixture, not the same run. The current log has no successful extraction outcome, so `ended=quit` must never imply returned.

**C / existing:** `started_at`, `ended`, `time_alive_s`, `shots_fired`, `shots_hit`, `damage_by_source.{spit,puddle,lunge,rifle}`, `hits_in_cover`, `hits_in_open`, `times_protected`, `killed_by`, `time_locked_s`, `shots_blocked_for_you`, `your_shots_blocked`. `ended` is death/respawn/quit. It has no death location, oxygen usage, equipment inventory or monetary values.

**P / contract metadata proposed:** `contract.id`, `contract.vessel_name`, `contract.status`, `contract.estimated_value_cr`, `contract.known_hazards[].{description,location}`, `contract.crew[].{name,role}`, `contract.contractor_name`, `contract.next_of_kin`. Hazards must come from actual discovered intel; do not reveal unobserved threats. `contract.status` example is “probably abandoned”. Fixed liability clauses remain fixed for this design.

**P / event and settlement inputs proposed:** `salvage[].{label,quantity,unit_value_cr}`, `airlock_cycles` (completed cycles only), `death.location` (room at lethal hit), `equipment_unreturned_cr` (ledger valuation), `settlement.status` (authoritative returned/not-returned, not guessed from quit), `invoice.id` (account metadata). Without these, hide affected charge rows, label missing metadata “Not recorded”, and show totals as “Pending records” if monetary inputs are incomplete. Do not replace absent data with fabricated charges.

**D / presentation fields:** `killer = killed_by.stalker ?? killed_by.pirate ?? "Not recorded"`; `method = killed_by.how` verbatim, fallback “Not recorded”. The CONTRACT lists source keys, not guaranteed `how` vocabulary: a code task must explicitly map recorded values; unknown values display verbatim and use unclassified copy, never guess from damage totals. `started_at` may be displayed in future but is not a changing field on these layouts.

**D / accounting fields:** `credits[].amount_cr = quantity × unit_value_cr`; `gross_cr = sum(credits[].amount_cr)`; `deductions[].{label,quantity,unit,rate_cr,amount_cr}` from selected fee rule; `deductions_total_cr = sum(deductions[].amount_cr)`; `net_cr = gross_cr - deductions_total_cr`; `death_bill.lines[].{label,amount_cr}` from approved rules; `outstanding_cr = sum(death_bill.lines[].amount_cr)`. CR uses integer arithmetic. Format thousands with commas; totals omit a plus sign, credit rows show +, deduction rows show −. `time_alive_s` displays floor(seconds) as mm:ss, hours when needed. Oxygen billed quantity is ceil(time_alive_s/60), not HUD oxygen remaining.

**Proposed rates:** `rates.suit_shift_cr=640`, `rates.round_cr=20`, `rates.oxygen_min_cr=20`, `rates.cycle_cr=50`, `rates.morale_shift_cr=280`. Fatal fixture: `rates.posthumous_cr=180`, `equipment_unreturned_cr=1640`, `rates.cleanup_cr=420`; apply only when `ended=death` is supported by the death invoice flow. All other library rates are intentionally unset (`rate`) pending approval. No fees or debt are implemented. Amounts express potential choices: time, ammunition, routes, salvage and risk affect the settlement.

## Full player-facing copy

Shared header/footer:
```text
REMNANT / ASSET RECOVERY
EVERYTHING HAS A SECOND OWNER.
INDEPENDENT RECOVERY CONTRACTOR / REMNANT ACCOUNTS
```

### A012-01

```text
RECOVERY AGREEMENT
CONTRACT / RAR-041
VESSEL / MERIDIAN DUE / probably abandoned
ESTIMATED SALVAGE VALUE / 8,600 CR
KNOWN HAZARDS / AS FOUND SO FAR
01 Corrosive organism sighted / medbay
02 Armed rival crew reported / cargo
03 Remaining compartments / unverified
Contractor assumes liability for anything that is not abandoned.
Recovery estimates exclude recovery costs.
Recovery does not include rescue.
Acceptance confirms the clauses shown above.
ASSIGNED CREW
01 ROOK / Recovery
02 VALE / Systems
03 MOSS / Medical
04 PIKE / Cargo
ENTRY CONFIRMS ACCEPTANCE.
Liability begins at the airlock.
ACCEPT > / DECLINE
```

Changing fields (every other printed string is fixed):
`{contract.id}`, `{contract.vessel_name}`, `{contract.status}`, `{contract.estimated_value_cr}`, `{contract.known_hazards[].description}`, `{contract.known_hazards[].location}`, `{contract.crew[].name}`, `{contract.crew[].role}`.

### A012-02

```text
SHIFT SETTLEMENT
SHIFT / RAR-041 / ROOK
CREDITS RECOVERED / AMOUNT / CR
Relay assembly / 1 × 1,600 / +1,600
Copper busbar / 4 × 160 / +640
Sealed medical pack / 2 × 120 / +240
GROSS RECOVERED / 2,480
DEDUCTIONS
Suit rental / 1 shift × 640 / -640
Ammunition / company-store prices / 46 rounds × 20 / -920
Oxygen / billed per minute / 19 min × 20 / -380
Airlock cycling / 5 cycles × 50 / -250
Morale / 1 shift × 280 / -280
TOTAL DEDUCTIONS / -2,470
Time aboard 18:24 / Oxygen rounded up to whole minutes.
CONTRACTOR / ROOK
RETURN FILED
NET PAY / 10 CR
2,480 earned.
2,470 recovered by Remnant.
Thank you for choosing independent recovery.
ACKNOWLEDGE >
```

Changing fields (every other printed string is fixed):
`{contract.id}`, `{contract.contractor_name}`, `{salvage[].label}`, `{salvage[].quantity}`, `{salvage[].unit_value_cr}`, `{credits[].amount_cr}`, `{gross_cr}`, `{deductions[].label}`, `{deductions[].quantity}`, `{deductions[].unit}`, `{deductions[].rate_cr}`, `{deductions[].amount_cr}`, `{deductions_total_cr}`, `{time_alive_s}`, `{settlement.status}`, `{net_cr}`.

### A012-03

```text
ACCOUNT CONTINUES.
INVOICE / RAR-041-D / ROOK
RECOVERY STATUS / NOT RETURNED
CAUSE OF DEATH / AS RECORDED
KILLER / Stalker 01
METHOD / spit
LOCATION / Not recorded
TIME ALIVE / 18:24
No location supplied by run log.
POSTHUMOUS INVOICE / AMOUNT / CR
Posthumous processing / 180
Unreturned equipment / 1,640
Biohazard cleanup (you) / 420
OUTSTANDING BALANCE / 2,240 CR
PASSED TO NEXT OF KIN
Nominated contact / VALE
Liability survives the contractor.
Recovery does not include rescue.
```

Changing fields (every other printed string is fixed):
`{invoice.id}`, `{contract.contractor_name}`, `{settlement.status}`, `{killer}`, `{killed_by.how}`, `{death.location}`, `{time_alive_s}`, `{death_bill.lines[].label}`, `{death_bill.lines[].amount_cr}`, `{outstanding_cr}`, `{contract.next_of_kin}`.

### A012-04

```text
BUILD FIELD SPEC
C CURRENT LOG / P PROPOSED INPUT / D DERIVED
Boxed areas replace changing content. Ordered ledger rows repeat; full paths, rules and copy are in auto-A012.md.
01 / RECOVERY AGREEMENT / P {contract.id} / P {contract.vessel_name}  {contract.status} / P {contract.estimated_value_cr} / P {contract.known_hazards[].description} / P {contract.known_hazards[].location} / P {contract.crew[].name}  {..role} / Fixed: liability clauses / ACCEPT  >                     DECLINE
02 / SHIFT SETTLEMENT / P {contract.id}  {contract.contractor_name} / P {salvage[].label} {..quantity} {..unit_value_cr} / D {credits[].amount_cr}  {gross_cr} / D {deductions[].label} {..quantity} {..unit} / D {deductions[].rate_cr} {..amount_cr} / C {time_alive_s}  D {deductions_total_cr} / P {settlement.status}  D {net_cr} / ACKNOWLEDGE  >
03 / ACCOUNT CONTINUES. / P {invoice.id}  {contract.contractor_name} / P {settlement.status}  C {time_alive_s} / D {killer}  C {killed_by.how} / P {death.location} / absent: Not recorded / D {death_bill.lines[].label} / D {death_bill.lines[].amount_cr} / D {outstanding_cr}  P {contract.next_of_kin} / Fixed: liability and rescue clauses
Fees are approval proposals. Cause variants 08–14 are contributing context, never inferred killing blows.
```

## Twenty deduction lines — full copy and triggers

C means existing telemetry can drive quantity/eligibility; prices are proposed. P means extra event data is required. Nonzero quantities only, unless a per-shift rule explicitly applies. These are a library, not twenty simultaneous charges. Select a coherent approved tariff; do not stack ammunition with miss/impact/obstruction charges or overlapping inspection fees by default. Morale is the packet’s required fixed per-shift fee, not a morale counter. No behavioural score is inferred.

| # | Line / supporting copy | Eligibility or quantity | Input |
|---|---|---|---|
| 01 | **Suit rental** — One shift. No ownership implied. | `time_alive_s > 0; 1 × rates.suit_shift_cr` | C |
| 02 | **Ammunition / company-store prices** — Every discharge is a purchase. | `shots_fired × rates.round_cr` | C |
| 03 | **Oxygen / billed per minute** — Partial minutes remain breathable. | `ceil(time_alive_s / 60) × rates.oxygen_min_cr` | C |
| 04 | **Airlock cycling** — Return journeys are separate journeys. | `airlock_cycles × rates.cycle_cr` | P |
| 05 | **Morale** — Participation confirms satisfaction. | `time_alive_s > 0; 1 × rates.morale_shift_cr` | C |
| 06 | **Missed-round disposal** — Unrecovered rounds remain sold. | `max(0, shots_fired - shots_hit) × rate` | C |
| 07 | **Impact reconciliation** — Successful delivery confirmed. | `shots_hit × rate` | C |
| 08 | **Obstruction damage assessment** — Cover is company-adjacent property. | `your_shots_blocked × rate` | C |
| 09 | **Ballistic shelter service** — Protection has been itemised. | `shots_blocked_for_you × rate` | C |
| 10 | **Corrosive interception** — Exposure avoided. Service supplied. | `times_protected × rate` | C |
| 11 | **Cover occupancy** — Shelter is billed while occupied. | `ceil(time_locked_s / 60) × rate` | C |
| 12 | **Open-position incident review** — The review does not reverse the incident. | `hits_in_open × rate` | C |
| 13 | **Covered-position incident review** — Cover does not imply coverage. | `hits_in_cover × rate` | C |
| 14 | **Corrosive contact treatment** — Contact has been established. | `damage_by_source.spit × rate` | C |
| 15 | **Floor-residue decontamination** — Residue transfers with the contractor. | `damage_by_source.puddle × rate` | C |
| 16 | **Impact seal inspection** — Suit integrity requires verification. | `damage_by_source.lunge × rate` | C |
| 17 | **Ballistic seal inspection** — Third-party damage. First-party invoice. | `damage_by_source.rifle × rate` | C |
| 18 | **Early closure administration** — Departure does not cancel the account. | `ended == quit; 1 × rate` | C |
| 19 | **Replacement-shift administration** — A new start is a separate service. | `ended == respawn; 1 × rate` | C |
| 20 | **Salvage handling** — Recovery includes a handling charge. | `sum(salvage[].quantity) × rates.handling_cr` | P |

## Fifteen death-bill causes and context variants — full copy

All require `ended=death`. Pick one primary cause (01–05), one killer descriptor (06–07, if known), and at most one context line (08–14). Variant 15 replaces primary cause when `killed_by` is null. 08–14 describe the recorded damage history or prior protection; they never assert the fatal blow or position at death. Each variant is exclusive within its group, uses fixed priority 01→15 within that group, and may be suppressed after repeated use by a future presentation layer. No fee amount is inferred from a cause label.

| # | Cause/context heading | Predicate | Exact supporting copy |
|---|---|---|---|
| 01 | Corrosive discharge | `method == spit` | Contact recorded. Liability retained. |
| 02 | Residual corrosive exposure | `method == puddle` | Exposure continued after delivery. |
| 03 | Close-contact impact | `method == lunge` | Personal space is not insured. |
| 04 | Ballistic injury | `method == rifle` | Third-party fire. Contractor account. |
| 05 | Unclassified fatal incident | `method missing or unrecognised` | Classification pending. Processing complete. |
| 06 | Stalker involvement | `killed_by.stalker exists` | Organism liability could not be established. |
| 07 | Rival-contractor involvement | `killed_by.pirate exists` | Competing claim acknowledged. |
| 08 | Multiple exposure classes | `count(damage_by_source > 0) >= 2` | Separate incidents. One account. |
| 09 | Cover-related injury history | `hits_in_cover > 0` | Cover was present. Coverage was not. |
| 10 | Open-position injury history | `hits_in_open > 0` | Exposure review added to file. |
| 11 | Corrosive residue on file | `damage_by_source.puddle > 0` | Decontamination remains chargeable. |
| 12 | Close-contact damage on file | `damage_by_source.lunge > 0` | Seal inspection remains chargeable. |
| 13 | Ballistic damage on file | `damage_by_source.rifle > 0` | Inspection excludes projectile recovery. |
| 14 | Shelter service on file | `shots_blocked_for_you + times_protected > 0` | Prior protection does not void this invoice. |
| 15 | Cause unavailable | `killed_by == null` | Evidence unavailable. Balance available. |

Location remains “Not recorded” until a location event exists. A known killer with a missing/unknown method uses 05. A missing killer uses 15. Unknown killer types display the available evidence without assigning stalker/pirate. Absence of telemetry cannot establish suffocation, friendly fire, decompression, being abandoned by crew or any other unrecorded cause.

## Three favourite lines

1. **Cover does not imply coverage.**
2. **Unrecovered rounds remain sold.**
3. **Evidence unavailable. Balance available.**

## Verification and scope

All four PNGs decoded and dimensions checked; review sheet and originals visually inspected for clipping and hierarchy. Arithmetic fixtures checked (2,480 − 2,470 = 10; 180 + 1,640 + 420 = 2,240). No game code, scenes, data, tests or tools changed. No legacy source assets touched, no source asset IDs reused, and no git commands run. Only the new A012 source folder, A012 review folder and this handoff were written.

Pending human gate: approve layouts and copy (including proposed tariffs and telemetry additions) before a code build packet. No additional human decision was required to prepare this review.
