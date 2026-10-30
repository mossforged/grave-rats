extends "res://tests/test_case.gd"
## T005 health: the suit, the stagger threshold, puddles. And the run log.

const Suit := preload("res://src/health/suit.gd")
const PuddleField := preload("res://src/health/puddle_field.gd")
const RunLog := preload("res://src/run_log/run_log.gd")
const DT := 1.0 / 60.0
const TEST_DIR := "user://test_runs"


func _cfg() -> Dictionary:
	return (Data.load_data("health") as Dictionary).duplicate(true)


func after_each() -> void:
	var d := DirAccess.open(TEST_DIR)
	if d:
		for f in d.get_files():
			d.remove(f)


func test_a_stagger_triggers_at_the_threshold_and_not_under_it() -> void:
	var cfg := _cfg()
	var threshold := float(cfg.stagger.threshold_fraction) * float(cfg.suit.max)
	var s := Suit.new(cfg)
	check(not bool(s.take(threshold - 0.01, "spit").staggered), "just under doesn't stagger")
	check(not s.staggered(), "and no stagger is running")
	s.reset()
	check(bool(s.take(threshold, "lunge").staggered), "exactly at the threshold staggers")
	check_eq(s.stagger_left, float(cfg.stagger.control_loss_s), "for control_loss_s")
	for i in roundi(float(cfg.stagger.control_loss_s) / DT) + 1:
		s.step(DT)
	check(not s.staggered(), "and it ends")


func test_the_threshold_comes_from_data() -> void:
	var cfg := _cfg()
	cfg.stagger.threshold_fraction = 0.5
	var s := Suit.new(cfg)
	check(not bool(s.take(float(cfg.suit.max) * 0.4, "lunge").staggered), "edited threshold is used")


func test_many_small_hits_do_not_stagger_and_death_is_final() -> void:
	var cfg := _cfg()
	var s := Suit.new(cfg)
	var died := false
	while not died:
		var r := s.take(float(cfg.suit.max) * 0.1, "puddle")
		check(not bool(r.staggered), "small hit, no stagger")
		died = bool(r.died)
	check(s.dead, "dead at zero")
	check_eq(s.integrity, 0.0, "integrity stops at zero")
	check_eq(float(s.take(10.0, "spit").amount), 0.0, "a dead suit takes nothing")
	s.reset()
	check(not s.dead and s.fraction() == 1.0, "a restart gives it all back")


func test_puddle_damage_over_time_only_while_standing_in_it() -> void:
	var dps := float(_cfg().acid.puddle_dps)
	var f := PuddleField.new(dps)
	f.add(Vector2.ZERO, 1.0, 3.0, "a", 8)
	check_eq(f.damage_at(Vector2(5, 0), 1.0), 0.0, "outside it, nothing")
	var total := 0.0
	for i in 60:
		total += f.damage_at(Vector2(0.5, 0), DT)
		f.step(DT)
	check(absf(total - dps) < 0.01, "one second in it costs puddle_dps (%.3f)" % total)
	for i in 121:
		f.step(DT)
	check_eq(f.damage_at(Vector2(0.5, 0), 1.0), 0.0, "and it dries up after its life")
	check(f.puddles.is_empty(), "gone from the list")


func test_overlapping_puddles_do_not_stack_and_old_ones_make_way() -> void:
	var f := PuddleField.new(5.0)
	f.add(Vector2.ZERO, 1.0, 3.0, "a", 2)
	f.add(Vector2.ZERO, 1.0, 3.0, "b", 2)
	check_eq(f.damage_at(Vector2.ZERO, 1.0), 5.0, "two puddles still hurt as one")
	f.add(Vector2(4, 0), 1.0, 3.0, "c", 2)
	check_eq(f.puddles.size(), 2, "max_count holds")
	check_eq(f.puddles[0].owner, "b", "the oldest went first")


func test_the_run_log_file_is_written_with_every_field() -> void:
	var log := RunLog.new(TEST_DIR)
	log.note_time(12.5)
	log.note_shot(true)
	log.note_shot(false)
	log.note_damage("spit", 16.0, true)
	log.note_damage("lunge", 34.0, false)
	log.note_damage("puddle", 3.0, false)
	log.note_protected()
	log.note_death("cargo stalker", "lunge")
	var path := log.write("death")
	check(path.begins_with(TEST_DIR), "written under its directory: %s" % path)
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	check_eq(d.time_alive_s, 12.5, "time alive")
	check_eq(d.shots_fired, 2.0, "shots fired")
	check_eq(d.shots_hit, 1.0, "shots hit")
	check_eq(d.damage_by_source.spit, 16.0, "spit damage")
	check_eq(d.damage_by_source.puddle, 3.0, "puddle damage")
	check_eq(d.damage_by_source.lunge, 34.0, "lunge damage")
	check_eq(d.hits_in_cover, 1.0, "hits in cover")
	check_eq(d.hits_in_open, 1.0, "hits in the open; a puddle isn't either")
	check_eq(d.times_protected, 1.0, "times protected")
	check_eq(d.killed_by.stalker, "cargo stalker", "which stalker")
	check_eq(d.killed_by.how, "lunge", "how")
	check_eq(d.ended, "death", "how the life ended")


func test_the_run_log_writes_once_per_life_and_never_overwrites() -> void:
	var log := RunLog.new(TEST_DIR)
	var a := log.write("death")
	check_eq(log.write("respawn"), "", "a second write of the same life does nothing")
	log.begin()
	var b := log.write("respawn")
	check(a != "" and b != "" and a != b, "two lives, two files, even in the same second: %s %s" % [a, b])
	log.begin()
	log.enabled = false
	check_eq(log.write("quit"), "", "off writes nothing")
