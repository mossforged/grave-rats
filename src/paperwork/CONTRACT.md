# paperwork

The company speaking: the briefing, payslip, death bill and termination notice (T014). Filled from the run log. Layouts, copy and field spec: `docs/handoffs/auto-A012.md`; tone: "loud outside danger, every fee should change a decision".

## Owns
- `paperwork.gd`: scene-free. Run logs and quota facts in, documents out: flat dictionaries with printed strings and, beside them, the `_cr` numbers they came from. All arithmetic.
- `line_book.gd`: scene-free. Picks copy: `requires` (facts), `weight`, `cooldown` (picks of that pool to sit out), per pool, so lines don't repeat back to back.
- `paperwork_screen.gd`: the forms on screen. An interpreter for the op lists in `data/paperwork.json`, placed on the A012 1920x1080 sheet and scaled to the window, with Barlow Condensed. Not images.

## Does not own
- What happened (`src/run_log`, told by the deck). The quota (`src/shift/quota_state.gd`). When a form opens (`src/shift/shift_deck.gd`).

## Rules
- **A line prints only if its cause is in the log.** A tariff line names a key of `quantities(log)`; zero means no row. An unknown method prints verbatim as "Unclassified fatal incident", never guessed.
- **Net goes on the quota, and can take it down.** A death bill doesn't: its balance passes to next of kin (the design says the shift's haul is lost; the clock ticks).
- Credits group by kind. Each item has its own value, so several print as "3 × assessed" with their true sum.
- Nothing is credited unless the shift came home (`shift_outcome` "extracted").
- The CUSTODIAN charge prints only with `custodian_hits` in the log: a drone's call or a stalker's hit doesn't count.
- Hazards come only from `threats_seen` in past logs, in data order, `contract.hazard_rows` on the form.
- The estimate is within `contract.estimate_spread` of the ship's real total, round but never outside it.
- A long ledger tightens to `min_fit`, then scrolls by whole rows (wheel, up/down), with total and actions pinned.
- Input: Enter presses the primary button, the mouse any; `screen.input_lock_s` after opening, so a held key or a stray click can't sign. All input stops at an open form.

## Public API
- `Paperwork.new(cfg)`: `reseed(n)`, `contract(number, ship_total, past_logs, quota_facts)`, `decline_line()`, `payslip(log, contract)`, `quota_fields(quota_facts)`, `death_bill(log, contract, quota_facts)`, `termination(contract, quota_facts)`, `known_hazards(past_logs)`, `estimate(total)`, `quantities(log)`, `deductions(log)`, `credits(log)`, `death_facts(log)`, `cr(n)`, `clock(s)`; field `book`.
- `LineBook`: `pick(pool_name, pool)`, `pick_first(pool_name, pool)`, `forget()`, static `meets(line, facts)`, `allowed(pool, facts)`; field `rng`.
- `PaperworkScreen`: `open(screen, doc)`, `update(doc)`, `close()`, `is_open()`, `press(button)`, `buttons()`; fields `doc`, `screen_name`, `cfg`.

## Signals
`PaperworkScreen.pressed(button)`: "accept", "decline", "confirm_decline", "acknowledge".

## Data keys (`data/paperwork.json`)
`screen` {`layer`, `sheet`, fonts, `input_lock_s`, `clip_px`, `rule_px`, `frame_px`, `button_font_px`, `row_slack_px`, `stripe`, `colors`}; `format`; `words`; `space_words`; `killer_keys`; `salvage_labels`; `contract` {`id_format`, `id_base`, `status`, `estimate_spread`, `estimate_round_to`, `hazard_rows`, `crew`, `next_of_kin`, `vessels`}; `hazards` [{`kind`, `text`}]; `decline_lines`; `note_cooldown`; `tariff` [{`id`, `label`, `note`, `qty`, `unit`, `units`, `enabled`, `rate`}]: the twenty A012 lines, six switched off so nothing stacks, plus `custodian_charge` (T015); `causes` {`primary`, `party`, `context`} (A012's fifteen plus oxygen, plus T015's cutter cause, CUSTODIAN party line and thermal context); `death`; `termination` {`deductions`, `lines`}; `base` and `screens` {name: ops}. An op is one of `text` (`at`, `size`, `font`, `color`, `align`, `wrap`; `{field}`s from the doc), `panel`, `rule`, `stripe`, `bar` (`value`), `button` (`rect`, `label`, `primary`), `list` (`top`, `bottom`, `min_fit`, `styles` {style: {`pitch`, `cells`}}, `more`), any with `if` or `unless` naming a doc field.

Tests: `tests/test_paperwork.gd`. Literal scan: `tests/test_weapons.gd`. Bots: `tools/t014_bots.gd`, `tools/t014_report.py`.
