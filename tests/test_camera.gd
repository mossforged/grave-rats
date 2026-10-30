extends "res://tests/test_case.gd"
## src/camera: preset math, the target stays in view at every preset (with look-ahead and follow
## lag), presets come from data/camera.json, and the cut-away zone.

const CameraMath := preload("res://src/camera/camera_math.gd")
const ASPECTS := [16.0 / 9.0, 16.0 / 10.0]
const EDGE := 0.85  # the operator must stay inside the middle 85% of the screen

var cam: Dictionary
var deck: Dictionary


func before_each() -> void:
	cam = Data.load_data("camera")
	deck = Data.load_data("deck")


func _model_height() -> float:
	var biggest := 0.0
	for s in deck.character_scale_options:
		biggest = maxf(biggest, float(s))
	return 2.0 * biggest  # legacy operator is 1.96 m with its helmet


func _check_in_view(preset: Dictionary, focus: Vector3, player: Vector3, what: String) -> void:
	var xf := CameraMath.camera_transform(focus, preset)
	for aspect in ASPECTS:
		for h in [0.0, _model_height()]:
			var p := CameraMath.project_ndc(xf, preset, player + Vector3.UP * h, aspect)
			check(p.z > 0.0 and absf(p.x) < EDGE and absf(p.y) < EDGE,
					"%s: %s point at %.1f m in view (ndc %.2f, %.2f) at aspect %.2f" % [preset.name, what, h, p.x, p.y, aspect])


func test_presets_from_data() -> void:
	var presets: Array = cam.presets
	check(presets.size() >= 5, "at least five presets (keys 1-5)")
	var ortho := presets.filter(func(p: Dictionary) -> bool: return CameraMath.is_ortho(p))
	check(ortho.size() >= 1, "an orthographic preset for comparison")
	var concept: Dictionary = presets[int(cam.default_preset)]
	check(not CameraMath.is_ortho(concept), "the default (concept) preset is perspective")
	check(float(concept.pitch_deg) >= 55.0 and float(concept.pitch_deg) <= 65.0, "concept pitch in the 55-65 range")


func test_camera_looks_at_focus_from_pitch() -> void:
	for preset in cam.presets:
		var focus := Vector3(3, 0.9, -2)
		var xf := CameraMath.camera_transform(focus, preset)
		var fwd := -xf.basis.z
		check(fwd.dot((focus - xf.origin).normalized()) > 0.9999, "%s looks at the focus" % preset.name)
		var pitch := rad_to_deg(asin(-fwd.y))
		check(absf(pitch - float(preset.pitch_deg)) < 0.01, "%s pitch %.2f" % [preset.name, pitch])
		check(is_equal_approx(xf.origin.distance_to(focus), float(preset.distance_m)), "%s distance" % preset.name)
		var c := CameraMath.project_ndc(xf, preset, focus, 16.0 / 9.0)
		check(c.z > 0.0 and absf(c.x) < 1e-4 and absf(c.y) < 1e-4, "%s focus projects to screen centre" % preset.name)


func test_target_in_view_with_look_ahead_every_preset() -> void:
	var f: Dictionary = cam.follow
	var player := Vector3(10, 0, 5)
	for preset in cam.presets:
		for k in 16:
			var a := TAU * k / 16.0
			var aim := Vector3(sin(a), 0, -cos(a)) * float(f.look_ahead_m)
			_check_in_view(preset, player + aim + Vector3.UP * float(f.focus_height_m), player, "look-ahead %d" % k)


func test_target_in_view_while_running_every_preset() -> void:
	# Run at full speed for 3 s in each direction with the aim pointing the other way: worst lag.
	var f: Dictionary = cam.follow
	var speed := float(deck.stand_in.speed_m_s)
	var dt := 1.0 / 60.0
	for preset in cam.presets:
		for k in 8:
			var a := TAU * k / 8.0
			var dir := Vector3(sin(a), 0, -cos(a))
			var player := Vector3.ZERO
			var focus := Vector3.UP * float(f.focus_height_m)
			for i in 180:
				player += dir * speed * dt
				var desired := player - dir * float(f.look_ahead_m) + Vector3.UP * float(f.focus_height_m)
				focus = CameraMath.follow_step(focus, desired, dt, float(f.smoothing_hz))
			_check_in_view(preset, focus, player, "running dir %d" % k)


func test_real_camera3d_agrees() -> void:
	# Cross-check the math against Godot's own Camera3D frustum.
	var tree := Engine.get_main_loop() as SceneTree
	var c := Camera3D.new()
	tree.root.add_child(c)
	for preset in cam.presets:
		if CameraMath.is_ortho(preset):
			c.projection = Camera3D.PROJECTION_ORTHOGONAL
			c.size = float(preset.ortho_size_m)
		else:
			c.projection = Camera3D.PROJECTION_PERSPECTIVE
			c.fov = float(preset.fov_deg)
		c.far = float(cam.far_m)
		var focus := Vector3(1, 0.9, 1)
		c.global_transform = CameraMath.camera_transform(focus, preset)
		var player := focus - Vector3.UP * 0.9
		check(c.is_position_in_frustum(player), "%s: Camera3D sees the player" % preset.name)
		check(c.is_position_in_frustum(player + Vector3.UP * _model_height()), "%s: Camera3D sees the head" % preset.name)
		check(not c.is_position_in_frustum(focus + Vector3(200, 0, 0)), "%s: far point is outside" % preset.name)
	c.free()


func test_concept_preset_operator_size() -> void:
	# Lead's measurement: the operator is about 8% of view height in the concept.
	var preset: Dictionary = cam.presets[int(cam.default_preset)]
	var xf := CameraMath.camera_transform(Vector3.UP * float(cam.follow.focus_height_m), preset)
	var frac := CameraMath.screen_height_fraction(xf, preset, Vector3.ZERO, float(deck.stand_in.height_m), 16.0 / 9.0)
	check(frac > 0.065 and frac < 0.095, "concept preset: operator %.1f%% of view height (aim ~8%%)" % (frac * 100.0))


func test_follow_step_converges_and_is_frame_rate_independent() -> void:
	var a := Vector3.ZERO
	var b := Vector3.ZERO
	var goal := Vector3(10, 0, 0)
	for i in 60:
		a = CameraMath.follow_step(a, goal, 1.0 / 60.0, 5.0)
	for i in 120:
		b = CameraMath.follow_step(b, goal, 1.0 / 120.0, 5.0)
	check(a.distance_to(b) < 1e-3, "same result at 60 and 120 fps")
	check(a.x > 9.9, "converges within a second (%.3f)" % a.x)


func test_cut_zone() -> void:
	var to_cam := Vector2(0, 1)  # camera due south
	var player := Vector2(0, 0)
	var c: Dictionary = cam.cutaway
	var hw := float(c.half_width_m)
	var depth := float(c.depth_m)
	var behind := float(c.behind_m)
	check(CameraMath.in_cut_zone(Rect2(-2, 2, 4, 0.5), player, to_cam, hw, depth, behind), "wall just south of the player is cut")
	check(not CameraMath.in_cut_zone(Rect2(-2, -3, 4, 0.5), player, to_cam, hw, depth, behind), "wall north of the player stays")
	check(not CameraMath.in_cut_zone(Rect2(-2, depth + 1, 4, 0.5), player, to_cam, hw, depth, behind), "wall beyond depth stays")
	check(not CameraMath.in_cut_zone(Rect2(hw + 1, 1, 0.5, 2), player, to_cam, hw, depth, behind), "wall off to the side stays")
	var yawed := Vector2(1, 1).normalized()
	check(CameraMath.in_cut_zone(Rect2(2, 2, 0.5, 0.5), player, yawed, hw, depth, behind), "yawed camera cuts along its own direction")
	check(not CameraMath.in_cut_zone(Rect2(-4, 3, 0.5, 0.5), player, yawed, 1.0, depth, behind), "yawed zone is narrow sideways")
