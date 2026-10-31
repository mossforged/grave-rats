extends SceneTree
## T012: a greedy bot against a cautious one on the real shift_deck, no window. Not a test: numbers
## for the handoff. Greedy grabs everything, prize included, and stays until nothing's left or the air
## is nearly gone. Cautious takes small and medium, and goes home the moment tier 1 lands.
## usage: godot --headless --path . --fixed-fps 60 -s tools/t012_bots.gd [seeds] [out.json]

const DT := 1.0 / 30.0
const AIM_LAG_S := 0.2
const FIRE_WITHIN_DEG := 12.0
const FIGHT_M := 9.0
const DROP_HEAVY_M := 6.0
const HOME_MARGIN_S := 35.0
const STUCK_S := 12.0
const GREEDY := "greedy"
const CAUTIOUS := "cautious"

var scene: Node
var op: Node3D
var _seen := {}
var _skipped := {}
var _stuck_left := 0.0
var _last_goal := Vector2.INF


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
	for bot: String in [GREEDY, CAUTIOUS]:
		var rows: Array = []
		for i in seeds:
			rows.append(await _shift(bot, 1000 + i))
			print("OUT %s seed %d: %s" % [bot, 1000 + i, JSON.stringify(rows[-1])])
		all[bot] = rows
		_report(bot, rows)
	if args.size() > 1:
		var f := FileAccess.open(args[1], FileAccess.WRITE)
		f.store_string(JSON.stringify(all, "  ") + "\n")
		f.close()
	quit()


func _report(bot: String, rows: Array) -> void:
	var survived := rows.filter(func(r: Dictionary) -> bool: return String(r.outcome) == "extracted")
	print("OUT == %s, %d seeds" % [bot, rows.size()])
	print("OUT    survived %d of %d (%.0f%%)" % [survived.size(), rows.size(), 100.0 * survived.size() / rows.size()])
	for key: String in ["banked", "deposited", "items", "tier", "time_s", "prize"]:
		var vals: Array = rows.map(func(r: Dictionary) -> float: return float(r[key]))
		vals.sort()
		var total := 0.0
		for v: float in vals:
			total += v
		print("OUT    %-10s mean %8.1f  median %8.1f  min %8.1f  max %8.1f" % [key, total / vals.size(), vals[vals.size() / 2], vals[0], vals[-1]])
	var deaths := {}
	for r: Dictionary in rows:
		if r.cause != null:
			deaths[r.cause] = int(deaths.get(r.cause, 0)) + 1
	print("OUT    deaths by %s" % JSON.stringify(deaths))


func _shift(bot: String, seed_value: int) -> Dictionary:
	scene.next_seed = seed_value
	scene.respawn()
	seed(seed_value)
	var k := 0
	for s: Node in scene.pack.stalkers:
		k += 1
		s.brain.rng.seed = seed_value * 31 + k
	op.rifle.state.rng.seed = seed_value * 7
	_seen = {}
	_skipped = {}
	_stuck_left = STUCK_S
	_last_goal = Vector2.INF
	var t := 0.0
	var cap := float(scene.shift.cfg.oxygen_s) + 60.0
	while not scene.shift.ended() and t < cap:
		_decide(bot)
		await physics_frame
		scene.simulate_world(DT)
		op.simulate(DT)
		t += DT
	var rep: Dictionary = scene.shift.report()
	return {"seed": seed_value, "outcome": rep.shift_outcome, "banked": rep.banked_value, "deposited": rep.deposited_value,
		"items": rep.deposited_items, "lost": rep.items_lost, "tier": rep.tier_reached, "prize": 1 if rep.prize_taken else 0,
		"time_s": t, "oxygen_left_s": rep.oxygen_at_exit_s, "cause": scene.run_log.to_dict("x").cause_of_death}


func _decide(bot: String) -> void:
	if scene.suit.dead or op.control_held():
		op.scripted = {}
		return
	var pos: Vector2 = scene._eye()
	var threat := _nearest_threat(pos)
	var carry: RefCounted = scene.shift.carry(scene.player_id)
	if threat != null and pos.distance_to(threat.floor_position()) <= DROP_HEAVY_M and not op.can_fire():
		scene.drop_item()
	var going_home := _should_go_home(bot, carry)
	var goal: Vector2 = scene.airlock.rect.get_center()
	var item: RefCounted = null
	if not going_home:
		item = _next_item(bot, carry, pos)
		if item != null:
			goal = item.at
		else:
			going_home = true
	var keys := _steer(pos, goal)
	var fire := false
	if threat != null and op.can_fire():
		var at: Vector2 = _lagged(threat)
		op.aim_point = Vector3(at.x, 1.2, at.y)
		fire = _off_target_deg() <= FIRE_WITHIN_DEG
		if int(op.rifle.state.mag) == 0:
			op.request_reload()
		# A cone that's opened up misses; stand still while there's something to shoot at, unless it's time to run.
		if not going_home or carry.carried().is_empty():
			keys = Vector2.ZERO
	else:
		op.aim_point = op.global_position + Vector3(keys.x, 0.0, keys.y) * 5.0 + Vector3.UP * 1.2
	var in_air: bool = scene.airlock.has_point(pos)
	op.scripted = {"keys": keys, "fire": fire, "leave": going_home and in_air}
	if item != null and pos.distance_to(item.at) <= float(scene._salvage_cfg.reach_m) * 0.7 and threat == null:
		op.scripted = {}
		scene.interact()


func _should_go_home(bot: String, carry: RefCounted) -> bool:
	if bot == CAUTIOUS and scene.shift.tier_reached >= 1:
		return true
	if float(scene.shift.oxygen_left) <= HOME_MARGIN_S:
		return true
	var full: bool = carry.pockets.size() >= int(scene._salvage_cfg.pocket_limit)
	return carry.in_hand != null or full


## The nearest thing this bot wants that it can carry, leaving out what it couldn't get to.
func _next_item(bot: String, carry: RefCounted, pos: Vector2) -> RefCounted:
	var best: RefCounted = null
	var best_d := INF
	for item: RefCounted in scene.field.on_floor():
		if _skipped.has(item.id) or carry.can_take(item) != "":
			continue
		if bot == CAUTIOUS and (item.prize or String(item.klass) == "heavy"):
			continue
		var d: float = pos.distance_to(item.at)
		if d < best_d:
			best = item
			best_d = d
	return best


## Toward the goal by the stalkers' own paths, opening whatever shut door's in the way.
func _steer(pos: Vector2, goal: Vector2) -> Vector2:
	if goal != _last_goal:
		_last_goal = goal
		_stuck_left = STUCK_S
	_stuck_left -= DT
	if _stuck_left <= 0.0:
		_stuck_left = STUCK_S
		for item: RefCounted in scene.field.items:
			if item.at == goal:
				_skipped[item.id] = true
	var nav: RefCounted = scene.pack.nav
	var path: PackedVector2Array = nav.path(pos, goal)
	if path.is_empty():
		var door: Variant = nav.door_on_way(pos, goal)
		if door == null:
			return Vector2.ZERO
		if scene.doors.door_in_reach(pos) == door:
			scene.doors.actors = [{"position": pos, "radius": op.body_radius()}]
			scene.doors.interact(pos)
			return Vector2.ZERO
		path = nav.path(pos, door.front_point(pos, op.body_radius()))
		if path.is_empty():
			return (door.opening.get_center() - pos).normalized()
	var next: Vector2 = path[mini(int(scene.pack.cfg.nav.lookahead_cells), path.size() - 1)]
	var d := next - pos
	return d.normalized() if d.length() > 0.05 else (goal - pos).normalized()


## The closest live stalker this player can really see, within fighting range.
func _nearest_threat(pos: Vector2) -> Node:
	var best: Node = null
	var best_d := FIGHT_M
	for s: Node in scene.pack.stalkers:
		if not s.brain.alive() or s.brain.state == s.brain.State.DORMANT:
			continue
		var at: Vector2 = s.floor_position()
		var d := pos.distance_to(at)
		if d < best_d and (d < float(scene.sight.cfg.awareness_radius_m) or not scene.sight.visibility.blocked(pos, at)):
			best = s
			best_d = d
	return best


## Where it was a moment ago: a person's eye and hand.
func _lagged(s: Node) -> Vector2:
	var trail: Array = _seen.get(s, [])
	trail.append(s.floor_position())
	var keep := roundi(AIM_LAG_S / DT) + 1
	if trail.size() > keep:
		trail.pop_front()
	_seen[s] = trail
	return trail[0]


func _off_target_deg() -> float:
	var to: float = op.model.yaw_to(op.global_position, op.aim_point)
	return absf(rad_to_deg(angle_difference(op.model.torso_yaw, to)))
