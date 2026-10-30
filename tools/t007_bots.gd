extends SceneTree
## T007: how long do bots live against the squad, and does cover matter? Runs the real pirate_deck
## with scripted players, no window. Not a test: numbers for the handoff.
## usage: godot --headless --path . --fixed-fps 60 -s tools/t007_bots.gd [runs]

const DT := 1.0 / 60.0
const MAX_S := 60.0
const BURST_S := 0.45   # how long a firing bot keeps the trigger down
const DOWN_S := 1.1     # and how long it waits between
const REACT_S := 0.3    # a person's eye: how long something's been in sight before it fires at it
const HAND_LAG_S := 0.2 # a person's hand: it aims at where the target was this long ago
const SCAN_DEG := 50.0  # with nothing in sight it sweeps the light this far each side of the threat
const SCAN_HZ := 0.25

var scene: Node
var op: Node3D
var bark_keys := {}


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var runs := int(args[0]) if args.size() > 0 else 12
	scene = (load("res://scenes/pirates/pirate_deck.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	scene.aim_from_mouse = false
	op = scene.operator
	op.input_enabled = false
	scene.set_physics_process(false)
	op.set_physics_process(false)
	scene.run_log.enabled = false
	scene.squad.barked.connect(func(_p: Node, key: String, _l: String) -> void: bark_keys[key] = true)
	await _report("stands in the open, never fires", runs, _bot.bind("stand", false))
	await _report("crouches behind low cover, never fires", runs, _bot.bind("crouch", false))
	await _report("locked to the same cover, never fires", runs, _bot.bind("lock", false))
	await _report("stands in the open, fights like a person", runs, _bot.bind("stand", true))
	await _report("crouches behind low cover, fights like a person (rises as it shoots)", runs, _bot.bind("crouch", true))
	await _report("locked to the same cover, fights like a person (up to fire, down between bursts)", runs, _bot.bind("lock", true))
	quit()


func _report(title: String, runs: int, bot: Callable) -> void:
	var rows: Array = []
	for i in runs:
		scene.respawn()
		for j in scene.squad.pirates.size():
			var b: RefCounted = scene.squad.pirates[j].brain
			b.rng.seed = 1000 + i * 10 + j
			b.gun.rng.seed = 2000 + i * 10 + j
		rows.append(await bot.call())
	print("OUT ", title)
	for key: String in rows[0]:
		var vals: Array = rows.map(func(r: Dictionary) -> float: return float(r[key]))
		vals.sort()
		var known: Array = vals.filter(func(v: float) -> bool: return v >= 0.0)
		var line := "OUT    %-22s" % key
		if known.is_empty():
			line += " never in %d runs" % runs
		else:
			var total := 0.0
			for v: float in known:
				total += v
			line += " mean %6.2f  median %6.2f  min %6.2f  max %6.2f  (%d of %d runs)" % [total / known.size(), known[known.size() / 2], known[0], known[-1], known.size(), runs]
		print(line)


func _step() -> void:
	await physics_frame
	scene.simulate_world(DT)
	op.simulate(DT)


## The same place every time: east of the long crate on the hold's south side is open to them; the
## cover bots tuck in on its west side, with the crate between them and the squad.
func _bot(stance: String, fires: bool) -> Dictionary:
	var squad: Node = scene.squad
	var r: Rect2 = scene.layout.props[11].rect
	var body: float = op.body_radius()
	var tucked := Vector2(r.position.x - body - 0.1, r.get_center().y)
	var at: Vector2 = tucked if stance != "stand" else Vector2(r.position.x - 1.2, r.position.y - 2.0)
	op.global_position = Vector3(at.x, 0, at.y)
	var east := Vector3(14.0, 1.2, r.get_center().y)
	op.face_now(east)
	scene._open_all_doors()
	op.scripted = {"crouch": stance != "stand"}
	for i in 30:
		await _step()
	if stance == "lock":
		scene.driver.press()
		for i in 30:
			await _step()
	# The clock starts with the bot in place: nobody noticed the setting up.
	squad.reset()
	var was_logged: RefCounted = scene.run_log
	was_logged.begin()
	squad.alert(at)
	var t := 0.0
	var was: float = scene.suit.integrity
	var first := -1.0
	var phase := 0.0
	var kills_at := -1.0
	var seen_for := 0.0
	var mark: Node = null
	var trail: Array = []
	var ahead := Vector2(east.x, east.z) - at
	while t < MAX_S and not scene.suit.dead:
		phase = fmod(phase + DT, BURST_S + DOWN_S)
		var now := _in_sight(at, mark)
		if now != mark:
			mark = now
			seen_for = 0.0
			trail.clear()
		var fire := false
		if mark != null:
			seen_for += DT
			var q: Vector2 = mark.floor_position()
			trail.append(q)
			var lagged: Vector2 = trail[maxi(trail.size() - 1 - roundi(HAND_LAG_S / DT), 0)]
			op.aim_point = Vector3(lagged.x, 1.2, lagged.y)
			fire = fires and phase < BURST_S and seen_for >= REACT_S and _off_deg() < 8.0
		else:
			var sweep := deg_to_rad(SCAN_DEG) * sin(TAU * SCAN_HZ * t)
			var look: Vector2 = at + ahead.rotated(sweep)
			op.aim_point = Vector3(look.x, 1.2, look.y)
		if op.rifle.state.mag == 0:
			op.request_reload()
		if stance == "lock":
			scene.driver.scripted = {"fire": fire}
		else:
			op.scripted = {"crouch": stance == "crouch", "fire": fire}
		await _step()
		t += DT
		if first < 0.0 and float(scene.suit.integrity) < was:
			first = t
		if kills_at < 0.0 and squad.living().is_empty():
			kills_at = t
			break
	var l: RefCounted = scene.run_log
	return {
		"died_s": t if scene.suit.dead else -1.0,
		"first_hit_s": first,
		"cleared_squad_s": kills_at,
		"survived_60s": 1.0 if not scene.suit.dead and kills_at < 0.0 else -1.0,
		"pirates_killed": float(squad.pirates.size() - squad.living().size()),
		"rounds_blocked_for_you": float(l.shots_blocked_for_you),
		"your_rounds_blocked": float(l.your_shots_blocked),
		"hits_taken": float(l.hits_in_cover + l.hits_in_open),
		"your_hit_percent": 100.0 * l.shots_hit / maxi(l.shots_fired, 1),
	}


## What a person could see: the wedge and the circle. It sticks with what it's on while that lasts.
func _in_sight(at: Vector2, current: Node) -> Node:
	var sees := func(p: Node) -> bool: return scene.sight.visibility.can_see(at, op.gun_yaw(), true, p.floor_position())
	if current != null and current.brain.alive() and sees.call(current):
		return current
	var best: Node = null
	var best_d := INF
	for p: Node in scene.squad.living():
		var d: float = at.distance_to(p.floor_position())
		if d < best_d and sees.call(p):
			best_d = d
			best = p
	return best


func _off_deg() -> float:
	var to: float = op.model.yaw_to(op.global_position, op.aim_point)
	return absf(rad_to_deg(angle_difference(op.model.torso_yaw, to)))
