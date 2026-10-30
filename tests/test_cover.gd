extends "res://tests/test_case.gd"
## T005 cover: low cover against crouched and standing bodies, bracing, tall cover, tipping beds,
## the 3D shot and the deck's classes.

const CoverField := preload("res://src/cover/cover_field.gd")
const TipState := preload("res://src/cover/tip_state.gd")
const ShotTracer := preload("res://src/cover/shot_tracer.gd")
const DeckLayout := preload("res://src/study/deck_layout.gd")
const DT := 1.0 / 60.0
const NUMBER_FREE := ["res://src/cover/cover_field.gd", "res://src/cover/tip_state.gd",
	"res://src/cover/shot_tracer.gd", "res://src/cover/tip_bed.gd", "res://src/cover/protection_mark.gd",
	"res://src/health/suit.gd", "res://src/health/puddle_field.gd", "res://src/health/health_hud.gd",
	"res://src/enemies/stalker_brain.gd", "res://src/enemies/stalker_nav.gd", "res://src/enemies/ambush_trigger.gd",
	"res://src/enemies/stalker.gd", "res://src/enemies/stalker_body.gd", "res://src/enemies/spit_system.gd",
	"res://src/enemies/stalker_pack.gd", "res://src/enemies/bulkhead.gd", "res://src/enemies/stalker_deck.gd",
	"res://src/run_log/run_log.gd"]


func _cfg() -> Dictionary:
	return (Data.load_data("cover") as Dictionary).duplicate(true)


## A shooter 6 m east at muzzle height; a 2 m wide box half a metre east of the target at the origin.
func _shot(field: CoverField, height: float) -> bool:
	return field.line_blocked(Vector3(6.0, float(Data.value("player", "aim_height_m")), 0.0), Vector3(0.0, height, 0.0))


func _field(kind: String) -> CoverField:
	var f := CoverField.new(_cfg())
	f.set_piece("box", Rect2(0.5, -1.0, 0.4, 2.0), kind)
	return f


func test_low_cover_blocks_a_crouched_target_and_not_a_standing_one() -> void:
	var f := _field(CoverField.LOW)
	check(_shot(f, f.torso_height(1.0, false)), "crouched behind low cover is covered")
	check(not _shot(f, f.torso_height(0.0, false)), "standing behind low cover is not")


func test_braced_firing_exposes_you() -> void:
	var f := _field(CoverField.LOW)
	var braced := f.torso_height(1.0, true)
	check_eq(braced, float(_cfg().braced_torso_m), "braced torso comes from data")
	check(not _shot(f, braced), "firing from a crouch raises you into the line")


func test_tall_cover_blocks_both() -> void:
	var f := _field(CoverField.TALL)
	check(_shot(f, f.torso_height(1.0, false)), "tall blocks crouched")
	check(_shot(f, f.torso_height(0.0, false)), "tall blocks standing")


func test_no_cover_blocks_nothing_and_classes_change() -> void:
	var f := _field(CoverField.NONE)
	check(not _shot(f, f.torso_height(1.0, false)), "class none is no cover")
	f.set_piece("box", Rect2(0.5, -1.0, 0.4, 2.0), CoverField.LOW)
	check_eq(f.kind_of("box"), CoverField.LOW, "a piece can change class")


func test_shots_trace_in_3d_so_distance_from_the_cover_matters() -> void:
	var f := CoverField.new(_cfg())
	# The same crouched body, but with the box hard against the shooter: the line is still high there.
	f.set_piece("box", Rect2(5.0, -1.0, 0.4, 2.0), CoverField.LOW)
	check(not _shot(f, f.torso_height(1.0, false)), "low cover by the muzzle doesn't protect a far crouched body")


func test_low_cover_height_comes_from_data() -> void:
	var cfg := _cfg()
	cfg.low_height_m = 0.5
	var f := CoverField.new(cfg)
	f.set_piece("box", Rect2(0.5, -1.0, 0.4, 2.0), CoverField.LOW)
	check(not _shot(f, f.torso_height(1.0, false)), "edited low_height_m is used")


func test_segment_hit_says_where_and_what() -> void:
	var f := _field(CoverField.LOW)
	var hit := f.segment_hit(Vector3(6.0, 0.5, 0.0), Vector3(0.0, 0.5, 0.0))
	check_eq(hit.id, "box", "hit the box")
	check(absf((hit.point as Vector3).x - 0.9) < 0.001, "at its near face (%.3f)" % (hit.point as Vector3).x)
	check(f.segment_hit(Vector3(6.0, 2.0, 0.0), Vector3(0.0, 2.0, 0.0)).is_empty(), "over the top is clear")


func test_tipping_the_bed_changes_its_cover_class_after_the_commitment() -> void:
	var cfg: Dictionary = _cfg().bed
	var t := TipState.new(cfg)
	check_eq(t.cover_class(), CoverField.NONE, "upright is no cover")
	check(t.start(1.0), "E starts it")
	check(t.progress == 0.0 and t.state == TipState.State.TIPPING, "it begins the same step")
	check(not t.start(1.0), "can't start twice")
	for i in roundi(float(cfg.tip_s) / DT) - 2:
		check(not t.step(DT), "not yet landed")
	check_eq(t.cover_class(), CoverField.NONE, "no cover while it's still falling")
	var landed := false
	for i in 3:
		landed = t.step(DT) or landed
	check(landed, "lands after tip_s")
	check_eq(t.cover_class(), CoverField.LOW, "overturned is low cover")


func test_the_bed_falls_away_from_the_player() -> void:
	var cfg: Dictionary = _cfg().bed
	var rect := Rect2(0.0, 0.0, 0.9, 2.0)
	var t := TipState.new(cfg)
	t.start(1.0)  # player on the east
	t.progress = 1.0
	t.state = TipState.State.OVERTURNED
	var r := t.footprint(rect, 0.75)
	check(r.end.x <= rect.position.x + 0.001, "it lands on the far (west) side: %s" % str(r))
	var t2 := TipState.new(cfg)
	t2.start(-1.0)
	t2.state = TipState.State.OVERTURNED
	check(t2.footprint(rect, 0.75).position.x >= rect.end.x - 0.001, "and the other way from the west")


func test_tip_time_comes_from_data() -> void:
	var cfg: Dictionary = _cfg().bed
	cfg.tip_s = 10.0
	var t := TipState.new(cfg)
	t.start(1.0)
	for i in 60:
		t.step(DT)
	check(absf(t.progress - 0.1) < 0.001, "edited tip_s is used (%.3f)" % t.progress)


func test_a_shot_at_a_body_behind_low_cover_stops_at_the_cover() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var f := CoverField.new(_cfg())
	f.set_piece("box", Rect2(1.0, -1.0, 0.4, 2.0), CoverField.LOW)
	var tracer := ShotTracer.new(f, tree.root.get_world_3d())
	var body := _Body.new()
	body.center = Vector2.ZERO
	body.height = 0.5
	tracer.bodies = [body]
	var aim := float(Data.value("player", "aim_height_m"))
	var hit := tracer.trace(Vector3(8.0, aim, 0.0), Vector3.LEFT, 20.0)
	check_eq(hit.collider, null, "cover stops a shot down at a low body close behind it")
	check(absf((hit.position as Vector3).x - 1.4) < 0.01, "at the cover's face")
	body.center = Vector2(-5.0, 0.0)
	hit = tracer.trace(Vector3(3.0, aim, 0.0), Vector3.LEFT, 20.0)
	check_eq(hit.collider, body, "with the body far behind the cover and the muzzle close, the line clears it")


func test_a_shot_ignores_bodies_off_its_line_and_dead_ones() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var tracer := ShotTracer.new(CoverField.new(_cfg()), tree.root.get_world_3d())
	var body := _Body.new()
	body.center = Vector2(-5.0, 3.0)
	tracer.bodies = [body]
	check(tracer.trace(Vector3(8.0, 1.0, 0.0), Vector3.LEFT, 20.0).is_empty(), "off the line")
	body.center = Vector2(-5.0, 0.0)
	body.gone = true
	check(tracer.trace(Vector3(8.0, 1.0, 0.0), Vector3.LEFT, 20.0).is_empty(), "no disc, no hit")


class _Body:
	var center := Vector2.ZERO
	var height := 0.7
	var gone := false

	func shot_disc() -> Dictionary:
		return {} if gone else {"center": center, "radius": 0.5, "height": height}

	func take_hit(_hit: Dictionary) -> void:
		pass


func test_deck_props_carry_a_cover_class_that_matches_sight() -> void:
	var deck: Dictionary = Data.load_data("deck")
	var tall := float(Data.value("sight", "tall_prop_min_m"))
	for spec: Dictionary in deck.props:
		check(spec.has("cover"), "%s has a cover class" % spec.type)
		check(["none", "low", "tall"].has(spec.cover), "%s class is known" % spec.type)
		check((String(spec.cover) == "tall") == (float(spec.size_m[1]) >= tall), "%s: tall cover is exactly what sight blocks" % spec.type)
	var lay := DeckLayout.new(deck, float(deck.room_scale))
	var medbay_beds: Array = lay.props.filter(func(p: Dictionary) -> bool: return p.type == "bed" and p.space == "medbay")
	check_eq(medbay_beds.size(), 3, "three beds in the medbay")
	check_eq(medbay_beds.filter(func(p: Dictionary) -> bool: return p.cover == "low").size(), 1, "one already overturned")
	check(lay.props.filter(func(p: Dictionary) -> bool: return p.type == "console" and p.space == "medbay").size() >= 2, "consoles in the medbay")


## No number a designer might tune in the T005 scripts.
func test_t005_scripts_have_no_tunable_literals() -> void:
	var rx := RegEx.create_from_string("(?<![\\w.\"#%])(\\d+\\.\\d+|\\d+)(?![\\w\"])")
	var allowed := ["0", "1", "2", "0.0", "1.0", "2.0", "0.5"]
	var strip := RegEx.create_from_string("\"[^\"]*\"")
	for path: String in NUMBER_FREE:
		var n := 0
		for raw in FileAccess.get_file_as_string(path).split("\n"):
			n += 1
			if raw.begins_with("# --- capture hooks"):
				break
			var line: String = strip.sub(raw.get_slice("#", 0), "\"\"", true)
			for m in rx.search_all(line):
				if not allowed.has(m.get_string(1)):
					check(false, "%s:%d has the literal %s" % [path, n, m.get_string(1)])
