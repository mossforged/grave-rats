extends "res://tests/test_case.gd"
## T003 rifle and cone: settle, moving minimum, reload commitment, recoil, hitscan, targets,
## materials that can't black-box, and "every number comes from data".

const AimCone := preload("res://src/weapons/aim_cone.gd")
const RifleState := preload("res://src/weapons/rifle_state.gd")
const RifleFx := preload("res://src/weapons/rifle_fx.gd")
const Rifle := preload("res://src/weapons/rifle.gd")
const TargetDummy := preload("res://src/weapons/target_dummy.gd")
const DeckLayout := preload("res://src/study/deck_layout.gd")
const DT := 1.0 / 60.0
const NUMBER_FREE := ["res://src/player/operator_model.gd", "res://src/player/operator.gd",
	"res://src/player/aim_visuals.gd", "res://src/player/spine_twist.gd",
	"res://src/weapons/aim_cone.gd", "res://src/weapons/rifle_state.gd", "res://src/weapons/rifle.gd",
	"res://src/weapons/rifle_fx.gd", "res://src/weapons/target_dummy.gd", "res://src/cover/cover_lock.gd",
	"res://src/pirates/squad_tactics.gd", "res://src/pirates/hit_tally.gd",
	"res://src/hud/noise_state.gd", "res://src/hud/noise_ring.gd", "res://src/hud/suit_os.gd", "res://src/hud/suit_os_hud.gd",
	"res://src/sight/beam_fan.gd",
	"res://src/salvage/salvage_item.gd", "res://src/salvage/salvage_rules.gd", "res://src/salvage/carry_state.gd",
	"res://src/salvage/hold.gd", "res://src/salvage/salvage_field.gd", "res://src/enemies/spawn_picker.gd",
	"res://src/shift/shift_state.gd", "res://src/shift/section_lights.gd", "res://src/shift/alarm_marker.gd",
	"res://src/shift/airlock.gd", "res://src/shift/quota_state.gd", "res://src/paperwork/paperwork.gd",
	"res://src/paperwork/line_book.gd", "res://src/paperwork/paperwork_screen.gd",
	"res://src/custodian/cutter_brain.gd", "res://src/custodian/drone_brain.gd", "res://src/custodian/custodian_voice.gd",
	"res://src/custodian/custodian_trace.gd", "res://src/custodian/custodian_fx.gd", "res://src/custodian/cutter_unit.gd",
	"res://src/custodian/drone_unit.gd", "res://src/custodian/custodian.gd"]

var _nodes: Array[Node] = []


func after_each() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()


func _rifle_cfg() -> Dictionary:
	return (Data.value("weapons", "rifle") as Dictionary).duplicate(true)


func test_cone_closes_over_the_settle_time() -> void:
	var cfg := _rifle_cfg().cone as Dictionary
	var c := AimCone.new(cfg)
	c.spread_deg = float(cfg.wide_deg)
	var settle := float(cfg.settle_s)
	var mid := (float(cfg.wide_deg) + float(cfg.tight_deg)) * 0.5
	var n := roundi(settle / DT)
	for i in n / 2:
		c.step(DT, 0.0, false, false, 0.0)
	var close_per_frame := (float(cfg.wide_deg) - float(cfg.tight_deg)) / n
	check(absf(c.spread_deg - mid) <= close_per_frame * 1.5, "halfway through settle it is half closed (%.2f)" % c.spread_deg)
	check(c.spread_deg > float(cfg.tight_deg), "not settled early")
	for i in n - n / 2 + 1:
		c.step(DT, 0.0, false, false, 0.0)
	check(is_equal_approx(c.spread_deg, float(cfg.tight_deg)), "tight after settle_s (%.2f)" % c.spread_deg)


func test_moving_keeps_the_minimum() -> void:
	var cfg := _rifle_cfg().cone as Dictionary
	var c := AimCone.new(cfg)
	c.step(DT, 0.01, true, false, 0.0)
	check(c.spread_deg >= float(cfg.moving_min_deg), "the first moving step already holds the minimum (%.2f)" % c.spread_deg)
	for fraction: float in [0.05, 0.4, 1.0]:
		for i in 120:
			c.step(DT, fraction, true, false, 0.0)
			check(c.spread_deg >= float(cfg.moving_min_deg), "never under the minimum at fraction %.2f" % fraction)
	check(is_equal_approx(c.spread_deg, float(cfg.wide_deg)), "full walk ends at wide (%.2f)" % c.spread_deg)


func test_sprint_widens_past_wide() -> void:
	var cfg := _rifle_cfg().cone as Dictionary
	var c := AimCone.new(cfg)
	for i in 120:
		c.step(DT, 1.5, true, true, 0.0)
	check(is_equal_approx(c.spread_deg, float(cfg.sprint_deg)), "sprint spread (%.2f)" % c.spread_deg)
	check(float(cfg.sprint_deg) > float(cfg.wide_deg), "sprint is wider than wide")


func test_turning_opens_the_cone() -> void:
	var cfg := _rifle_cfg().cone as Dictionary
	var c := AimCone.new(cfg)
	for i in 60:
		c.step(DT, 0.0, false, false, 240.0 * DT)
	check(c.spread_deg > float(cfg.tight_deg) + 1.0, "a hard turn opens the cone (%.2f)" % c.spread_deg)
	check(c.spread_deg <= float(cfg.wide_deg), "turning alone stops at wide")


func test_reload_is_not_cancelled_by_firing() -> void:
	var cfg := _rifle_cfg()
	var r := RifleState.new(cfg)
	r.mag = 5
	check(r.start_reload(false), "reload starts")
	check(r.reloading(), "and is running the same step")
	var t := 0.0
	var outcome := ""
	while outcome == "" and t < 10.0:
		check_eq(r.try_fire(false), RifleState.BLOCKED_RELOAD, "fire is refused during the reload")
		outcome = r.step(DT, false)
		t += DT
	check_eq(outcome, "finished", "the reload finished")
	check(absf(t - float(cfg.reload_s)) <= DT * 1.01, "and took its full time (%.3f s)" % t)
	check_eq(r.mag, int(cfg.magazine), "full magazine")
	check_eq(r.reserve, int(cfg.reserve) + 5 - int(cfg.magazine), "old rounds back, new magazine out")


func test_reload_is_cancelled_by_sprinting_and_loses_the_magazine() -> void:
	var cfg := _rifle_cfg()
	var r := RifleState.new(cfg)
	r.mag = 5
	r.start_reload(false)
	r.step(0.5, false)
	check(r.reloading(), "still reloading")
	check_eq(r.step(DT, true), "cancelled", "sprint cancels")
	check(not r.reloading(), "not reloading any more")
	check_eq(r.mag, 0, "gun is empty")
	check_eq(r.reserve, int(cfg.reserve) + 5 - int(cfg.magazine), "new magazine is gone")


func test_sprinting_blocks_firing_and_starting_a_reload() -> void:
	var r := RifleState.new(_rifle_cfg())
	check_eq(r.try_fire(true), RifleState.BLOCKED_SPRINT, "no fire while sprinting")
	r.mag = 3
	check(not r.start_reload(true), "no reload start while sprinting")


func test_reload_refused_when_full_or_nothing_left() -> void:
	var r := RifleState.new(_rifle_cfg())
	check(not r.start_reload(false), "full magazine")
	r.mag = 0
	r.reserve = 0
	check(not r.start_reload(false), "no rounds left")
	r.reserve = 7
	check(r.start_reload(false), "partial reserve")
	r.step(float(r.cfg.reload_s) + 1.0, false)
	check_eq(r.mag, 7, "partial magazine")
	check_eq(r.reserve, 0, "reserve spent")


func test_fire_interval_and_empty() -> void:
	var cfg := _rifle_cfg()
	var r := RifleState.new(cfg)
	r.mag = 2
	check_eq(r.try_fire(false), RifleState.FIRED, "first shot the same step")
	check_eq(r.try_fire(false), RifleState.BLOCKED_COOLDOWN, "interval holds")
	r.step(float(cfg.fire_interval_s) + DT, false)
	check_eq(r.try_fire(false), RifleState.FIRED, "second shot after the interval")
	r.step(float(cfg.fire_interval_s) + DT, false)
	check_eq(r.try_fire(false), RifleState.BLOCKED_EMPTY, "empty")


func test_recoil_kicks_waits_and_recovers() -> void:
	var cfg := _rifle_cfg()
	var r := RifleState.new(cfg)
	r.rng.seed = 7
	r.try_fire(false)
	var kick := float(cfg.recoil.kick_deg)
	check(is_equal_approx(absf(r.recoil_deg), kick), "one kick (%.2f)" % r.recoil_deg)
	check(is_equal_approx(r.camera_kick_m, float(cfg.camera_kick.kick_m)), "camera kick")
	r.step(float(cfg.recoil.recover_delay_s) * 0.5, false)
	check(is_equal_approx(absf(r.recoil_deg), kick), "holds during the recover delay")
	r.step(float(cfg.recoil.recover_delay_s) * 0.5, false)
	r.step(kick / float(cfg.recoil.recover_deg_s) + DT, false)
	check_eq(r.recoil_deg, 0.0, "recovered at the data rate")
	check_eq(r.camera_kick_m, 0.0, "camera recovered")


func test_shots_land_inside_the_cone() -> void:
	var r := RifleState.new(_rifle_cfg())
	r.rng.seed = 11
	var lo := INF
	var hi := -INF
	for i in 2000:
		var y := r.shot_yaw(0.5, 10.0)
		lo = minf(lo, y)
		hi = maxf(hi, y)
	check(lo >= 0.5 - deg_to_rad(5.0) and hi <= 0.5 + deg_to_rad(5.0), "inside ±half the spread")
	check(hi - lo > deg_to_rad(9.5), "fills the cone (%.2f°)" % rad_to_deg(hi - lo))


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _keep(n: Node) -> Node:
	_tree().root.add_child(n)
	_nodes.append(n)
	return n


func test_hitscan_hits_a_target_and_it_flinches_and_resets() -> void:
	var rifle: Rifle = _keep(Rifle.new())
	rifle.state.rng.seed = 3
	var dummy: TargetDummy = _keep(TargetDummy.new())
	dummy.global_position = Vector3(0, 0, -5)
	await _tree().physics_frame
	await _tree().physics_frame
	var got := {"n": 0, "hit": null}
	rifle.fired.connect(func(_f: Vector3, _t: Vector3, _d: Vector3, h: Object) -> void:
		got.n += 1
		got.hit = h)
	rifle.trigger_held = true
	check(rifle.tick(DT, false, Vector3(0, 1.2, 0), 0.0, Vector3(0, 1.2, -0.5)), "a shot went off")
	rifle.trigger_held = false
	check_eq(got.n, 1, "one fired signal")
	check(got.hit == dummy, "the dummy was hit")
	var cfg: Dictionary = dummy.cfg
	check_eq(dummy.health, float(cfg.health) - float(rifle.state.cfg.damage), "took the data damage")
	check(dummy.flinching(), "flinches")
	dummy._process(float(cfg.flinch_s) * 0.5)
	check(dummy.tilt_deg() > 0.0, "tilted away")
	dummy._process(float(cfg.flinch_s))
	check_eq(dummy.tilt_deg(), 0.0, "flinch recovers")
	dummy.take_hit({"direction": Vector3.FORWARD, "damage": float(cfg.health)})
	check(dummy.down, "falls when out of health")
	var health := dummy.health
	dummy.take_hit({"direction": Vector3.FORWARD, "damage": 1.0})
	check_eq(dummy.health, health, "ignores hits while down")
	dummy._process(float(cfg.reset_s) + DT)
	check(not dummy.down, "resets")
	check_eq(dummy.health, float(cfg.health), "with full health")


func test_recoil_and_cone_steer_the_shot_off_the_target() -> void:
	var rifle: Rifle = _keep(Rifle.new())
	var dummy: TargetDummy = _keep(TargetDummy.new())
	dummy.global_position = Vector3(0, 0, -5)
	await _tree().physics_frame
	await _tree().physics_frame
	rifle.trigger_held = true
	var ok := rifle.tick(DT, false, Vector3(0, 1.2, 0), deg_to_rad(60.0), Vector3(0, 1.2, -0.5))
	check(ok, "fired")
	check_eq(dummy.health, float(dummy.cfg.health), "a shot 60° off misses")


func test_sprint_blocks_the_rifle_node() -> void:
	var rifle: Rifle = _keep(Rifle.new())
	await _tree().physics_frame
	rifle.trigger_held = true
	var mag: int = rifle.state.mag
	check(not rifle.tick(DT, true, Vector3.ZERO, 0.0, Vector3.ZERO), "no shot while sprinting")
	check_eq(rifle.state.mag, mag, "no round spent")


func test_fx_materials_can_only_add_light() -> void:
	var fx: RifleFx = _keep(RifleFx.new())
	await _tree().process_frame
	var count := 0
	for n in fx.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var mat: BaseMaterial3D = mi.mesh.surface_get_material(0)
		check_eq(mat.blend_mode, BaseMaterial3D.BLEND_MODE_ADD, "%s is additive" % mi.name)
		check_eq(mat.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED, "%s is unshaded" % mi.name)
		check_eq(mi.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "%s casts no shadow" % mi.name)
		count += 1
	check(count >= 3, "flash, tracers and impacts are all there (%d)" % count)


func test_six_targets_are_placed_clear_of_the_props_and_doors() -> void:
	var deck: Dictionary = Data.load_data("deck")
	var targets: Dictionary = Data.value("weapons", "targets")
	check_eq(targets.placements.size(), 6, "six targets")
	var layout := DeckLayout.new(deck, float(deck.room_scale))
	var player_r := float(Data.value("player", "radius_m"))
	var r := float(targets.radius_m)
	for p: Dictionary in targets.placements:
		var at := layout.point_in(String(p.space), p.at)
		check(layout.is_free(at, r + player_r), "%s %s leaves room to walk around it" % [p.space, str(p.at)])
		for door: Dictionary in layout.doors:
			check(not (door.rect as Rect2).grow(r + player_r * 2.0).has_point(at), "%s %s clear of a door" % [p.space, str(p.at)])


## No number a designer might tune in the gameplay scripts: only 0, 1, 2 and small indices.
func test_gameplay_scripts_have_no_tunable_literals() -> void:
	var rx := RegEx.create_from_string("(?<![\\w.\"#%])(\\d+\\.\\d+|\\d+)(?![\\w\"])")
	var allowed := ["0", "1", "2", "0.0", "1.0", "2.0", "0.5"]
	for path: String in NUMBER_FREE:
		var text := FileAccess.get_file_as_string(path)
		var n := 0
		for raw in text.split("\n"):
			n += 1
			var line: String = raw.get_slice("#", 0)
			var strip := RegEx.create_from_string("\"[^\"]*\"")
			line = strip.sub(line, "\"\"", true)
			for m in rx.search_all(line):
				if not allowed.has(m.get_string(1)):
					check(false, "%s:%d has the literal %s" % [path, n, m.get_string(1)])
