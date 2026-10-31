extends SceneTree
## T015: what reading CUSTODIAN's tells is worth, on the real deck, no window, stalkers out of it. Not a
## test: numbers for the handoff. Every bot walks the cargo hold between random points.
##   cutter: `ignore` keeps walking; `cover` steps behind tall cover once the ring has been up REACT_S.
##   drone: `ignore` keeps walking; `break` sprints out of the light once the bars have been up REACT_S.
## usage: godot --headless --path . --fixed-fps 60 -s tools/t015_bots.gd -- [seeds] [out.json]

const DT := 1.0 / 30.0
const WINDOW_S := 90.0
const REACT_S := 0.3
const HIDE_S := 1.5
const IGNORE := "ignore"
const COVER := "cover"
const BREAK := "break"
const ARRIVE_M := 0.6
const SPOT_RINGS := [1.0, 1.5, 2.2, 3.0, 4.0]
const SPOT_ANGLES := 16

var scene: Node
var op: Node3D
var _goal := Vector2.ZERO
var _hide_left := 0.0
var _hiding := false
var _hide_at := Vector2.ZERO


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var seeds := int(args[0]) if args.size() > 0 else 12
	scene = (load("res://scenes/shift/shift_deck.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	scene.aim_from_mouse = false
	op = scene.operator
	op.input_enabled = false
	scene.set_physics_process(false)
	op.set_physics_process(false)
	scene.run_log.enabled = false
	var all := {}
	for bot: String in [IGNORE, COVER]:
		all["cutter_" + bot] = await _series("cutter", bot, seeds)
	for bot: String in [IGNORE, BREAK]:
		all["drone_" + bot] = await _series("drone", bot, seeds)
	for key: String in all:
		_report(key, all[key])
	if args.size() > 1 and args[1].ends_with(".json"):
		var f := FileAccess.open(args[1], FileAccess.WRITE)
		f.store_string(JSON.stringify(all, "  ") + "\n")
		f.close()
	quit()


func _series(unit: String, bot: String, seeds: int) -> Array:
	var rows: Array = []
	for i in seeds:
		rows.append(await _window(unit, bot, 3000 + i))
	return rows


func _report(key: String, rows: Array) -> void:
	var totals := {}
	for r: Dictionary in rows:
		for k: String in r:
			totals[k] = float(totals.get(k, 0.0)) + float(r[k])
	var line := "OUT %-14s" % key
	for k: String in totals:
		line += "  %s %.1f" % [k, float(totals[k]) / rows.size()]
	print(line)


func _window(unit: String, bot: String, seed_value: int) -> Dictionary:
	scene.next_seed = seed_value
	scene.respawn()
	seed(seed_value)
	_quiet()
	var cus: Node = scene.custodian
	cus.wake("tier")
	var watched: Node3D = cus.cutters[0] if unit == "cutter" else cus.drones[1]
	for c: Node3D in cus.cutters:
		if c != watched and c.brain.awake():
			c.brain.state = c.brain.State.COOL
			c.brain._cool = INF
	if unit == "drone":
		# Only the drone in the room; nothing may stack on its numbers. A call still counts, cutter or not.
		cus.drones[0].brain.take_hit(INF)
		_hold_cutters_down()
	else:
		for d: Node3D in cus.drones:
			d.brain.take_hit(INF)
	_goal = _next_goal()
	_place(_next_goal())
	_hiding = false
	var aims := 0
	var burns := 0
	var cancels := 0
	var was_aiming := false
	var was_burning := false
	var was_calling := false
	var calls := 0
	var aiming_for := 0.0
	var t := 0.0
	while t < WINDOW_S:
		var tell: bool = watched.brain.aiming() if unit == "cutter" else watched.brain.calling()
		aiming_for = aiming_for + DT if tell else 0.0
		_step_bot(bot, watched, aiming_for)
		await physics_frame
		scene.simulate_world(DT)
		op.simulate(DT)
		scene.suit.reset()
		scene.shift.oxygen_left = float(scene._cfg.oxygen_s)
		if unit == "cutter":
			if watched.brain.aiming() and not was_aiming:
				aims += 1
			if was_aiming and not watched.brain.aiming() and not watched.brain.burning():
				cancels += 1
			if watched.brain.burning() and not was_burning:
				burns += 1
			was_aiming = watched.brain.aiming()
			was_burning = watched.brain.burning()
		else:
			_hold_cutters_down()
			if watched.brain.calling() and not was_calling:
				calls += 1
			was_calling = watched.brain.calling()
		t += DT
	if unit == "cutter":
		return {"damage": float(scene.run_log.damage_by_source.cutter), "hits": scene.run_log.custodian_hits, "aims": aims, "burns": burns, "cancelled": cancels}
	return {"calls_started": calls, "completed": cus.calls_done, "broken": cus.calls_broken}


func _hold_cutters_down() -> void:
	for c: Node3D in scene.custodian.cutters:
		if c.brain.awake():
			c.brain.state = c.brain.State.COOL
			c.brain._cool = INF


func _quiet() -> void:
	scene.shift.tier_reached = (scene._cfg.tiers as Array).size()
	var bounds: Rect2 = scene.layout.bounds
	for s: Node in scene.pack.stalkers:
		s.brain.state = s.brain.State.DORMANT
		s.global_position = Vector3(bounds.end.x + 50.0, 0.0, bounds.end.y + 50.0)


func _place(p: Vector2) -> void:
	op.global_position = Vector3(p.x, 0.0, p.y)


func _next_goal() -> Vector2:
	var r: Rect2 = scene.layout.space_rect("cargo")
	while true:
		var p := r.position + r.size * Vector2(randf(), randf())
		if scene.pack.nav.is_free(p):
			return p
	return Vector2.ZERO


func _step_bot(bot: String, unit: Node3D, tell_for: float) -> void:
	var pos: Vector2 = scene._eye()
	if bot != IGNORE and tell_for >= REACT_S and not _hiding:
		var spot: Variant = _hidden_spot(pos, unit)
		if spot != null:
			_hiding = true
			_hide_at = spot
			_hide_left = HIDE_S
	var goal := _goal
	var sprint := false
	if _hiding:
		goal = _hide_at
		sprint = true
		if pos.distance_to(goal) <= ARRIVE_M:
			_hide_left -= DT
			if _hide_left <= 0.0:
				_hiding = false
	elif pos.distance_to(goal) <= ARRIVE_M:
		_goal = _next_goal()
		goal = _goal
	var keys := Vector2.ZERO
	if pos.distance_to(goal) > ARRIVE_M * 0.5:
		var path: Array = Array(scene.pack.nav.path(pos, goal))
		var next: Vector2 = goal
		for p: Vector2 in path:
			if pos.distance_to(p) > ARRIVE_M:
				next = p
				break
		keys = (next - pos).normalized()
	op.aim_point = op.global_position + Vector3(keys.x, 0.0, keys.y) * 5.0 + Vector3.UP * 1.2
	op.scripted = {"keys": keys.rotated(deg_to_rad(float(op.move_yaw_deg))), "sprint": sprint}


## The nearest free place within reach that this unit's line can't reach.
func _hidden_spot(pos: Vector2, unit: Node3D) -> Variant:
	var trace: Callable = scene._custodian_trace.line
	var from: Vector3 = unit.brain.mount if "mount" in unit.brain else unit.brain.eye()
	var height: float = scene.body_height()
	var best: Variant = null
	var best_d := INF
	for r: float in SPOT_RINGS:
		for i in SPOT_ANGLES:
			var p: Vector2 = pos + Vector2.from_angle(TAU * i / SPOT_ANGLES) * r
			if scene.layout.space_at(p) != "cargo" or not scene.pack.nav.is_free(p) or r >= best_d:
				continue
			if not bool(trace.call(from, Vector3(p.x, maxf(height, float(scene._custodian_cfg.cutter.aim_floor_m)), p.y)).clear):
				best = p
				best_d = r
	return best
