# run_log

One JSON file per life, for the lead to read beside John's comments (T005).

## Owns
- `run_log.gd`: scene-free counters and the file. On John's Mac the files land in `~/Library/Application Support/Godot/app_userdata/Grave Rats/runs/`.

## Does not own
- Deciding what happened: the scene calls the `note_*` methods.

## Public API
`RunLog.new(dir := "user://runs")`: `begin()`, `note_time(delta)`, `note_shot(hit)`, `note_damage(source, amount, in_cover)`, `note_protected()`, `note_death(stalker, how)`, `to_dict(ended)`, `write(ended) -> path or ""` (once per life, never overwrites); fields `enabled` (captures turn it off), `last_path`, `dir`.

## File fields
`started_at`, `ended` ("death", "respawn", "quit"), `time_alive_s`, `shots_fired`, `shots_hit`, `damage_by_source` {`spit`, `puddle`, `lunge`}, `hits_in_cover`, `hits_in_open` (puddles count as neither), `times_protected`, `killed_by` {`stalker`, `how`} or null.
"In cover" means cover stood on the straight line from the thrower to your torso at that moment, so a glob lobbed over your bed is a hit in cover. "Protected" means cover stopped a glob aimed within `spit.protect_radius_m` of you.

## Signals
None.

## Data keys
None.

Tests: `tests/test_health.gd`, `tests/test_enemies.gd`.
