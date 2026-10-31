# run_log

One JSON file per life, for the lead to read beside John's comments (T005).

## Owns
- `run_log.gd`: scene-free counters and the file. On John's Mac the files land in `~/Library/Application Support/Godot/app_userdata/Grave Rats/runs/`.

## Does not own
- Deciding what happened: the scene calls the `note_*` methods.

## Public API
`RunLog.new(dir := "user://runs")`: `begin()`, `note_time(delta)`, `note_shot(hit)`, `note_damage(source, amount, in_cover)`, `note_protected()`, `note_death(who, how, kind := "stalker")`, `note_death_location(space)`, `note_threat(kind, space)`, `note_custodian_call()`, `note_locked(delta)`, `note_shot_blocked_for_you()`, `note_your_shot_blocked()`, `to_dict(ended)`, `write(ended) -> path or ""` (once per life, never overwrites), `flush_held() -> path or ""`; fields `player_id`, `crew`, `hold_back` (T018: down while the crew isn't: `write` waits, so the file knows how the shift ended), `enabled` (captures turn it off), `last_path`, `dir`, `shift_report` (a `() -> Dictionary`, set by a deck with a shift).

## File fields
`player_id`, `crew` (T018; one log per player), `started_at`, `ended` ("death", "respawn", "quit", "left", "left_behind"), `time_alive_s`, `shots_fired`, `shots_hit`, `damage_by_source` {`spit`, `puddle`, `lunge`, `rifle`, `cutter`}, `hits_in_cover`, `hits_in_open` (puddles and running out of air count as neither), `times_protected`, `killed_by` {`stalker`, `pirate`, `custodian_cutter` or `suit`: the name, `how`} or null, `cause_of_death` (`how`, or null), `time_locked_s`, `shots_blocked_for_you` (rounds aimed at you that cover stopped), `your_shots_blocked` (your rounds that cover stopped on their way to a pirate), `death_location` (T014: the deck space the fatal hit found you in, "" a doorway, null if nobody said), `threats_seen` (T014: {kind: first space}; kinds `stalker` seen, sources hit by, `alarm`, `vents`, `power_loss`, `custodian`), `custodian_hits` (T015: what the payslip charges for), `custodian_calls` (drone calls that went through).
Shift fields (T012; decks with no shift get `NO_SHIFT`'s values): `shift_outcome` ("extracted", "wiped", "abandoned", or "" if you quit mid-shift), `oxygen_at_exit_s`, `deposited_by_class` {class: {`count`, `value`}}, `deposited_items`, `deposited_value` (true value), `banked_value` (the same if anyone got out, else 0), `items_lost` and `items_lost_value` (lifted and not in the hold), `prize_taken`, `tier_reached`, `survivors` (player IDs), `left_behind` (T018); T014: `airlock_cycles`, `salvage` [{`kind`, `word`, `class`, `value`, `prize`}] (what's in the hold), `carried_at_death`, `carried_at_death_value`.
"In cover" means cover stood on the straight line from the thrower to your torso at that moment, so a glob lobbed over your bed is a hit in cover. "Protected" means cover stopped a glob aimed within `spit.protect_radius_m` of you.

## Signals
None.

## Data keys
None.

A rifle hit counts as "in cover" when `IN COVER` is showing as it lands (cover near you, but not on that round's line).

Tests: `tests/test_health.gd`, `tests/test_enemies.gd`, `tests/test_pirates.gd`.
