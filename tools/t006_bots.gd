extends SceneTree
## T006: how long do bots live, and does the ambush bite? Runs the real stalker_deck with scripted
## players, no window. Not a test: numbers for the handoff. Works on the T005 commit too, for the
## "before" column. usage: godot --headless --path . --fixed-fps 60 -s tools/t006_bots.gd [runs]

const DT := 1.0 / 60.0
const MAX_S := 90.0
const REACT_S := 0.45  # how long a person takes to act on a bang behind them
const FIRE_WITHIN_DEG := 15.0
const HAND_LAG_S := 0.2

var scene: Node
var op: Node3D


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var runs := int(args[0]) if args.size() > 0 else 12
	scene = (load("res://scenes/enemies/stalker_deck.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	scene.aim_from_mouse = false
	op = scene.operator
	op.input_enabled = false
	scene.set_physics_process(false)
	op.set_physics_process(false)
	scene.run_log.enabled = false
	await _report("standing still, after the burst", runs, _standing)
	await _report("crouched behind the overturned bed, stalker 6 m off through the door", runs, _in_cover)
	await _report("ambush: walks on, reacts to the bang after %.2f s" % REACT_S, runs, _ambush.bind(REACT_S))
	await _report("ambush: turns at once on the bang", runs, _ambush.bind(0.0))
	await _report("standing, tracks the stalker perfectly and fires", runs, _tracker.bind(0.0))
	await _report("standing, tracks where it was %.2f s ago (a person's eye and hand) and fires" % HAND_LAG_S, runs, _tracker.bind(HAND_LAG_S))
	quit()


func _report(title: String, runs: int, bot: Callable) -> void:
	var rows: Array = []
	for i in runs:
		scene.respawn()
		for s: Node in scene.pack.stalkers:
			if "rng" in s.brain:
				s.brain.rng.seed = 1000 + i
		rows.append(await bot.call())
	print("OUT ", title)
	for key: String in rows[0]:
		var vals: Array = rows.map(func(r: Dictionary) -> float: return float(r[key]))
		vals.sort()
		var known: Array = vals.filter(func(v: float) -> bool: return v >= 0.0)
		var line := "OUT    %-18s" % key
		if known.is_empty():
			line += " never in %d runs" % runs
		else:
			var total := 0.0
			for v: float in known:
				total += v
			line += " mean %6.2f  min %6.2f  max %6.2f  (%d of %d runs)" % [total / known.size(), known[0], known[-1], known.size(), runs]
		print(line)


func _step() -> void:
	await physics_frame
	scene.simulate_world(DT)
	op.simulate(DT)


func _hurt_at(t: float, was: float, first: float) -> float:
	if first < 0.0 and float(scene.suit.integrity) < was:
		return t
	return first


## How far the gun is from the aim point right now, whatever the model read last step.
func _off_target_deg() -> float:
	var to: float = op.model.yaw_to(op.global_position, op.aim_point)
	return absf(rad_to_deg(angle_difference(op.model.torso_yaw, to)))


func _awake_stalker() -> Node:
	for s: Node in scene.pack.stalkers:
		if s.brain.alive() and s.brain.hunting():
			return s
	return scene.pack.stalkers[1]


func _standing() -> Dictionary:
	op.scripted = {}
	scene.fire_ambush()
	scene.ambush.fired = true
	var was: float = scene.suit.integrity
	var first := -1.0
	var t := 0.0
	while t < MAX_S and not scene.suit.dead:
		await _step()
		t += DT
		first = _hurt_at(t, was, first)
	return {"died_s": t if scene.suit.dead else -1.0, "first_hit_s": first}


func _in_cover() -> Dictionary:
	scene._open_medbay_door()
	var bed: Node = scene.beds[2]
	var r: Rect2 = bed.footprint()
	var behind := Vector2(r.position.x - 0.6, r.get_center().y)
	var far := Vector2(r.end.x + 6.0, r.get_center().y)
	op.global_position = Vector3(behind.x, 0, behind.y)
	op.face_now(Vector3(far.x, 1.2, far.y))
	op.scripted = {"crouch": true}
	for i in 30:
		await _step()
	scene.pack.stalkers[0].place_hunting(far, behind)
	var was: float = scene.suit.integrity
	var first := -1.0
	var t := 0.0
	while t < MAX_S and not scene.suit.dead:
		await _step()
		t += DT
		first = _hurt_at(t, was, first)
	return {"died_s": t if scene.suit.dead else -1.0, "first_hit_s": first}


## From the real spawn, walking north past the panel. On the bang it waits `react_s`, still walking,
## then turns toward the stalker and fires once it's roughly on it.
func _ambush(react_s: float) -> Dictionary:
	op.scripted = {"keys": Vector2(0, -1)}
	var guard := 0.0
	while not scene.ambush.fired and guard < 20.0:
		op.aim_point = op.global_position + Vector3(0, 1.2, -5)
		await _step()
		guard += DT
	var was: float = scene.suit.integrity
	var t := 0.0
	var first_hit := -1.0
	var first_shot := -1.0
	var mag: int = op.rifle.state.mag
	while t < 8.0 and not scene.suit.dead:
		var s: Node = scene.pack.stalkers[1]
		var at: Vector2 = s.floor_position()
		if t >= react_s:
			op.aim_point = Vector3(at.x, 1.2, at.y)
			op.scripted = {"fire": _off_target_deg() <= FIRE_WITHIN_DEG}
		else:
			op.aim_point = op.global_position + Vector3(0, 1.2, -5)
		await _step()
		t += DT
		first_hit = _hurt_at(t, was, first_hit)
		if first_shot < 0.0 and int(op.rifle.state.mag) < mag:
			first_shot = t
	return {"first_hit_s": first_hit, "first_shot_s": first_shot,
		"shot_before_hit": 1.0 if first_shot >= 0.0 and (first_hit < 0.0 or first_shot < first_hit) else -1.0,
		"suit_after_8s": float(scene.suit.integrity), "died_s": t if scene.suit.dead else -1.0}


## The fairest fight there is: it always knows where the stalker is and turns at the real rate.
func _tracker(lag_s: float) -> Dictionary:
	scene.fire_ambush()
	scene.ambush.fired = true
	var s: Node = scene.pack.stalkers[1]
	var t := 0.0
	var seen: Array = []
	var was_shots := int(scene.run_log.shots_fired)
	var was_hits := int(scene.run_log.shots_hit)
	while t < MAX_S and not scene.suit.dead and s.brain.alive():
		seen.append(s.floor_position())
		var at: Vector2 = seen[maxi(seen.size() - 1 - roundi(lag_s / DT), 0)]
		op.aim_point = Vector3(at.x, 1.2, at.y)
		op.scripted = {"fire": s.brain.state != s.brain.State.DORMANT and _off_target_deg() < FIRE_WITHIN_DEG}
		if op.rifle.state.mag == 0:
			op.request_reload()
		await _step()
		t += DT
	var shots := int(scene.run_log.shots_fired) - was_shots
	var hits := int(scene.run_log.shots_hit) - was_hits
	return {"killed_it_s": t if not s.brain.alive() else -1.0, "died_s": t if scene.suit.dead else -1.0,
		"hit_percent": 100.0 * hits / maxi(shots, 1), "suit_left": float(scene.suit.integrity)}
