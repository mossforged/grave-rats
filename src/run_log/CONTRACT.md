# run_log

One JSON file per life, for the lead to read beside John's comments (T005).

## Owns
- `run_log.gd`: scene-free counters and the file. On John's Mac the files land in `~/Library/Application Support/Godot/app_userdata/Grave Rats/runs/`.

## Does not own
- Deciding what happened: the scene calls the `note_*` methods.

## Public API
`RunLog.new(dir := "user://runs")`: `begin()`, `note_time(delta)`, `note_shot(hit)`, `note_damage(source, amount, in_cover)`, `note_protected()`, `note_death(who, how, kind := "stalker")`, `note_locked(delta)`, `note_shot_blocked_for_you()`, `note_your_shot_blocked()`, `to_dict(ended)`, `write(ended) -> path or ""` (once per life, never overwrites); fields `enabled` (captures turn it off), `last_path`, `dir`, `shift_report` (a `() -> Dictionary`, set by a deck with a shift).

## File fields
`started_at`, `ended` ("death", "respawn", "quit", "left"), `time_alive_s`, `shots_fired`, `shots_hit`, `damage_by_source` {`spit`, `puddle`, `lunge`, `rifle`}, `hits_in_cover`, `hits_in_open` (puddles and running out of air count as neither), `times_protected`, `killed_by` {`stalker`, `pirate` or `suit`: the name, `how`} or null, `cause_of_death` (`how`, or null), `time_locked_s`, `shots_blocked_for_you` (rounds aimed at you that cover stopped), `your_shots_blocked` (your rounds that cover stopped on their way to a pirate).
Shift fields (T012; decks with no shift get `NO_SHIFT`'s values): `shift_outcome` ("extracted", "wiped", "abandoned", or "" if you quit mid-shift), `oxygen_at_exit_s`, `deposited_by_class` {class: {`count`, `value`}}, `deposited_items`, `deposited_value` (true value), `banked_value` (the same if anyone got out, else 0), `items_lost` and `items_lost_value` (lifted and not in the hold), `prize_taken`, `tier_reached`, `survivors` (player IDs).
"In cover" means cover stood on the straight line from the thrower to your torso at that moment, so a glob lobbed over your bed is a hit in cover. "Protected" means cover stopped a glob aimed within `spit.protect_radius_m` of you.

## Signals
None.

## Data keys
None.

A rifle hit counts as "in cover" when `IN COVER` is showing as it lands (cover near you, but not on that round's line).

Tests: `tests/test_health.gd`, `tests/test_enemies.gd`, `tests/test_pirates.gd`.
