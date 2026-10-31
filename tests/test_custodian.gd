extends "res://tests/test_case.gd"
## T015: CUSTODIAN. The cutter's rule and tell, the drone's, waking, its voice, the paperwork, all on
## data's numbers, and on the real deck with the guns' real trace.

const CutterBrain := preload("res://src/custodian/cutter_brain.gd")
const DroneBrain := preload("res://src/custodian/drone_brain.gd")
const CustodianVoice := preload("res://src/custodian/custodian_voice.gd")
const Paperwork := preload("res://src/paperwork/paperwork.gd")
const RunLog := preload("res://src/run_log/run_log.gd")
const SuitOs := preload("res://src/hud/suit_os.gd")
const DT := 1.0 / 60.0
const P := 1

var _nodes: Array[Node] = []
var _clear := true


func after_each() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()
	Data.clear_cache()


func _cfg() -> Dictionary:
	return (Data.load_data("custodian") as Dictionary).duplicate(true)


func _trace(_from: Vector3, to: Vector3) -> Dictionary:
	return {"clear": _clear, "point": to}


func _players(at: Vector2, alive := true) -> Array:
	return [{"id": P, "pos": at, "body": Vector3(at.x, 1.3, at.y), "alive": alive}]


## A cutter at the origin looking at -z (yaw 0), awake.
func _cutter(cfg: Dictionary) -> CutterBrain:
	var c := CutterBrain.new(cfg.cutter, Vector2.ZERO, 0.0, 80.0)
	c.wake()
	return c


## Runs it until a state, or `limit` seconds. Returns the events on the way.
func _run_cutter(c: CutterBrain, players: Array, seconds: float) -> Array:
	var events: Array = []
	var t := 0.0
	while t < seconds:
		events.append_array(c.step(DT, players, _trace))
		t += DT
	return events


func _types(events: Array) -> Array:
	return events.map(func(e: Dictionary) -> String: return e.type)


func _scene() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	var scene: Node = (load("res://scenes/shift/shift_deck.tscn") as PackedScene).instantiate()
	tree.root.add_child(scene)
	_nodes.append(scene)
	scene.operator.input_enabled = false
	scene.aim_from_mouse = false
	scene.set_physics_process(false)
	scene.operator.set_physics_process(false)
	scene.run_log.enabled = false
	await tree.physics_frame
	await tree.physics_frame
	return scene


func _sim(scene: Node, seconds: float) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var t := 0.0
	while t < seconds:
		await tree.physics_frame
		scene.simulate_world(DT)
		scene.operator.simulate(DT)
		t += DT


func _place(scene: Node, at: Vector2) -> void:
	scene.operator.global_position = Vector3(at.x, 0.0, at.y)


## Quiet ship, so a stalker doesn't land in the middle of a test of something else.
func _no_stalkers(scene: Node) -> void:
	for s: Node in scene.pack.stalkers:
		s.brain.state = s.brain.State.DORMANT
		s.global_position = Vector3(scene.layout.bounds.end.x + 50.0, 0.0, scene.layout.bounds.end.y + 50.0)


func _player_at(scene: Node, at: Vector2, height: float) -> Dictionary:
	return {"id": P, "pos": at, "body": Vector3(at.x, height, at.y), "alive": true}


## Right behind the piece of cargo cover nearest the cargo cutter, on its far side.
func _behind(scene: Node, cutter: Node3D, kind: String) -> Vector2:
	var mount: Vector2 = cutter.floor_position()
	var best: Dictionary = {}
	var best_d := INF
	for p: Dictionary in scene.layout.props:
		if String(p.space) != "cargo" or String(p.cover) != kind:
			continue
		var to: Vector2 = (p.rect as Rect2).get_center() - mount
		if absf(angle_difference(cutter.brain.home_yaw, atan2(-to.x, -to.y))) > cutter.brain.arc_half * 0.5:
			continue
		var d: float = to.length()
		if d < best_d:
			best = p
			best_d = d
	var r: Rect2 = best.rect
	var c := r.get_center()
	return c + mount.direction_to(c) * (r.size.length() * 0.5 + 0.1)


# --- the cutter ---

func test_cutter_is_dormant_until_woken_and_wakes_once() -> void:
	var cfg := _cfg()
	var c := CutterBrain.new(cfg.cutter, Vector2.ZERO, 0.0, 80.0)
	check_eq(_run_cutter(c, _players(Vector2(0, -4)), 2.0), [], "asleep it does nothing")
	check(not c.line_on(), "no line asleep")
	check(c.wake(), "wakes")
	check(not c.wake(), "only once")


func test_warmup_time_comes_from_data() -> void:
	var cfg := _cfg()
	for warmup: float in [0.6, 2.0]:
		cfg.cutter.warmup_s = warmup
		var c := _cutter(cfg)
		var players := _players(Vector2(0, -4))
		var fired_after := -1.0
		var started := -1.0
		var t := 0.0
		while t < warmup + 2.0 and fired_after < 0.0:
			var ev: Array = c.step(DT, players, _trace)
			if started < 0.0 and c.warm > 0.0:
				started = t
			if _types(ev).has(CutterBrain.EV_BURN):
				fired_after = t
			t += DT
		check(fired_after > 0.0, "it fired on a warm-up of %.1f" % warmup)
		check(absf(fired_after - started - warmup) < DT * 2.0, "warm-up %.1f took %.3f" % [warmup, fired_after - started])


func test_never_fires_without_a_line_and_always_shows_one_while_aiming() -> void:
	var cfg := _cfg()
	var c := _cutter(cfg)
	var players := _players(Vector2(0, -4))
	var fired := 0
	var aimed := 0
	for i in roundi(30.0 / DT):
		# The line comes and goes on a schedule that catches every state.
		_clear = i % 97 < 80
		for ev: Dictionary in c.step(DT, players, _trace):
			if ev.type == CutterBrain.EV_BURN or ev.type == CutterBrain.EV_HIT:
				check(_clear, "it fired with no line, step %d" % i)
				fired += 1
		if c.aiming():
			aimed += 1
			check(c.line_on(), "aiming with its line off, step %d" % i)
	_clear = true
	check(aimed > 0, "it aimed")
	check(fired > 0, "and fired when it could")
	_clear = false
	var c2 := _cutter(cfg)
	check_eq(_run_cutter(c2, players, 20.0), [], "no line at all: not one event in 20 s")
	_clear = true


func test_breaking_the_line_cancels_the_warmup_at_once() -> void:
	var cfg := _cfg()
	var c := _cutter(cfg)
	var players := _players(Vector2(0, -4))
	while c.warm_share() < 0.5:
		c.step(DT, players, _trace)
	_clear = false
	var ev: Array = c.step(DT, players, _trace)
	_clear = true
	check_eq(_types(ev), [CutterBrain.EV_CANCEL], "cancelled that step")
	check_eq(c.warm_share(), 0.0, "the ring is empty")
	check_eq(c.state, CutterBrain.State.SWEEP, "back to sweeping")


func test_burn_lands_once_and_a_dead_or_out_of_range_player_is_safe() -> void:
	var cfg := _cfg()
	var c := _cutter(cfg)
	var hits := _run_cutter(c, _players(Vector2(0, -4)), float(cfg.cutter.warmup_s) + float(cfg.cutter.burn_s) + 0.5)
	var dealt := hits.filter(func(e: Dictionary) -> bool: return e.type == CutterBrain.EV_HIT)
	check_eq(dealt.size(), 1, "one burn, one hit")
	check_eq(float(dealt[0].amount), float(cfg.cutter.damage), "for the data's damage")
	check_eq(int(dealt[0].player_id), P, "carrying the player's ID")
	var far := _cutter(cfg)
	check_eq(_run_cutter(far, _players(Vector2(0, -float(cfg.cutter.range_m) - 1.0)), 5.0), [], "out of range")
	var dead := _cutter(cfg)
	check_eq(_run_cutter(dead, _players(Vector2(0, -4), false), 5.0), [], "a dead player isn't a target")


func test_tall_cover_blocks_the_cutter_and_low_cover_does_not() -> void:
	var scene: Node = await _scene()
	var cutter: Node3D = scene.custodian.cutters[0]
	var trace: Callable = scene._custodian_trace.line
	var low_h := float(scene._cover_cfg.low_height_m)
	var aim_floor := float(cutter.cfg.aim_floor_m)
	check(aim_floor > low_h, "the aim point is over low cover")
	check(float(cutter.cfg.mount_height_m) > aim_floor, "and it fires from above")
	for p: Dictionary in scene.layout.props:
		if String(p.cover) == "low":
			check(float(p.size.y) < aim_floor, "low %s stays under the line" % String(p.type))
	var torso := {"standing": float(scene._cover_cfg.standing_torso_m), "crouched": float(scene._cover_cfg.crouched_torso_m)}
	for stance: String in torso:
		var h: float = torso[stance]
		var at_tall := _behind(scene, cutter, "tall")
		check(not cutter.brain.can_see(_player_at(scene, at_tall, h), trace), "tall cover blocks it, %s" % stance)
		var at_low := _behind(scene, cutter, "low")
		check(cutter.brain.can_see(_player_at(scene, at_low, h), trace), "low cover doesn't, %s" % stance)


func test_shots_and_cutter_agree_on_walls_and_the_line_stops_there() -> void:
	var scene: Node = await _scene()
	var cutter: Node3D = scene.custodian.cutters[0]
	var trace: Callable = scene._custodian_trace.line
	# The junction's on the far side of the cargo's west wall, with its doors shut.
	var through: Vector2 = scene.layout.point_in("junction", [0.5, 0.3])
	var to := Vector3(through.x, 1.3, through.y)
	var result: Dictionary = trace.call(cutter.brain.mount, to)
	check(not bool(result.clear), "a wall stops it")
	var wall_x: float = scene.layout.space_rect("cargo").position.x
	check((result.point as Vector3).x >= wall_x - float(scene.deck_data.wall_thickness_m) - 0.01, "at the wall: %s" % str(result.point))
	# A stalker in the way hides nobody.
	var scene_mid: Vector2 = scene.layout.point_in("cargo", [0.5, 0.2])
	var s: Node = scene.pack.stalkers[0]
	s.global_position = Vector3(scene_mid.x, 0.0, scene_mid.y)
	await (Engine.get_main_loop() as SceneTree).physics_frame
	await (Engine.get_main_loop() as SceneTree).physics_frame
	var open: Dictionary = trace.call(cutter.brain.mount, Vector3(scene_mid.x, 1.3, scene_mid.y + 2.0))
	check(bool(open.clear), "a stalker doesn't block the line")


func test_on_the_deck_the_line_shows_stopped_by_tall_cover_and_the_beam_hurts() -> void:
	var scene: Node = await _scene()
	_no_stalkers(scene)
	var cutter: Node3D = scene.custodian.cutters[0]
	var other: Node3D = scene.custodian.cutters[1]
	var at_tall := _behind(scene, cutter, "tall")
	_place(scene, at_tall)
	scene.custodian.wake("tier")
	other.brain.state = other.brain.State.COOL
	other.brain._cool = INF
	# Hold the line on the player: it's stopped at the crate, short of them, and never warms up.
	var hurt_before: float = scene.suit.integrity
	await _sim(scene, 3.0)
	check_eq(scene.suit.integrity, hurt_before, "no harm behind tall cover")
	check(cutter.line_mesh.visible, "its line is up")
	var open: Vector2 = scene.layout.point_in("cargo", [0.6, 0.3])
	_place(scene, open)
	var left := 3.0
	while left > 0.0 and not cutter.brain.aiming():
		await _sim(scene, DT)
		left -= DT
	check(cutter.brain.aiming(), "in the open it aims")
	while cutter.brain.aiming():
		check(cutter.line_mesh.visible, "line up the whole warm-up")
		check(cutter.target_ring.visible and cutter.mount_ring.visible, "and the ring, on the mount and under you")
		await _sim(scene, DT)
	await _sim(scene, DT * 2.0)
	check_eq(scene.suit.integrity, hurt_before - float(cutter.cfg.damage), "the burn lands")
	check_eq(int(scene.run_log.custodian_hits), 1, "logged as CUSTODIAN's")
	check(float(scene.run_log.damage_by_source.cutter) > 0.0, "under its own source")


# --- the drone ---

func _drone(cfg: Dictionary) -> DroneBrain:
	var d := DroneBrain.new(cfg.drone, Vector2.ZERO, [Vector2(0, -20), Vector2(0, 20)])
	d.wake()
	return d


func test_drone_call_fills_three_bars_and_completes() -> void:
	var cfg := _cfg()
	var d := _drone(cfg)
	var players := _players(Vector2(0, -4))
	var bars: Array = []
	var done := {}
	var t := 0.0
	while t < float(cfg.drone.call_s) + 1.0 and done.is_empty():
		for ev: Dictionary in d.step(DT, players, _trace):
			if ev.type == DroneBrain.EV_BAR:
				bars.append(int(ev.bar))
			if ev.type == DroneBrain.EV_CALLED:
				done = ev
		t += DT
	check_eq(bars, [1, 2, 3], "the bars fill in sequence, each with a chirp")
	check_eq(int(done.get("player_id", -1)), P, "the call names who")
	check_eq(done.get("at"), Vector2(0, -4), "and where")
	check(t >= float(cfg.drone.call_s) - DT, "not before its time: %.2f" % t)


func test_breaking_the_drones_line_cancels_the_call() -> void:
	var cfg := _cfg()
	var d := _drone(cfg)
	var players := _players(Vector2(0, -4))
	while d.call_share() < 0.9:
		d.step(DT, players, _trace)
	check_eq(d.bars_lit(), int(cfg.drone.bars), "all lit by now")
	_clear = false
	var ev: Array = d.step(DT, players, _trace)
	_clear = true
	check(_types(ev).has(DroneBrain.EV_CALL_BROKEN), "line gone: the call's broken")
	check(not d.calling(), "it stops calling")
	check_eq(d.call_share(), 0.0, "and starts over from nothing")
	var moved := _drone(cfg)
	while moved.call_share() < 0.5:
		moved.step(DT, players, _trace)
	var gone := _players(Vector2(float(cfg.drone.spot_range_m), -4))
	check(_types(moved.step(DT, gone, _trace)).has(DroneBrain.EV_CALL_BROKEN), "out of the cone does it too")


func test_drone_is_fragile_never_attacks_and_needs_its_cone() -> void:
	var cfg := _cfg()
	var d := _drone(cfg)
	var rifle := float((Data.value("weapons", "rifle") as Dictionary).damage)
	var hits := 0
	while d.alive():
		d.take_hit(rifle)
		hits += 1
	check(hits >= 2 and hits <= 3, "2-3 rifle hits, took %d" % hits)
	var quiet := _drone(cfg)
	var all: Array = []
	for i in roundi(10.0 / DT):
		all.append_array(quiet.step(DT, _players(Vector2(0, -4)), _trace))
	for ev: Dictionary in all:
		check(not (ev as Dictionary).has("amount"), "nothing the drone does carries damage")
	var behind := _drone(cfg)
	behind.yaw = 0.0
	var ev2: Array = []
	for i in 5:
		ev2.append_array(behind.step(DT, _players(Vector2(0, 4)), _trace))
	check(not _types(ev2).has(DroneBrain.EV_CALL_START), "behind it, it doesn't see you")


func test_completed_call_wakes_a_cutter_or_alerts_the_nearest_stalker() -> void:
	var scene: Node = await _scene()
	var cus: Node = scene.custodian
	var reserve: Node3D = null
	for c: Node3D in cus.cutters:
		if not bool(c.get_meta("on_wake")):
			reserve = c
	check(reserve != null, "data holds a cutter back")
	cus.wake("tier")
	check(not reserve.brain.awake(), "the reserve sleeps through waking")
	var drone: Node3D = cus.drones[1]
	var at: Vector2 = drone.floor_position() + Vector2(0, -3)
	cus._on_drone_event(drone, {"type": DroneBrain.EV_CALLED, "player_id": P, "at": at})
	check(reserve.brain.awake(), "a completed call woke it")
	check_eq(int(scene.run_log.custodian_calls), 1, "logged")
	# All cutters up: now it's the nearest stalker, and only that one.
	var far: Node = scene.pack.stalkers[0]
	var near: Node = scene.pack.stalkers[1]
	for s: Node in [far, near]:
		s.brain.state = s.brain.State.PROWL
		s.brain.knows = false
	near.global_position = Vector3(drone.floor_position().x + 1.0, 0.0, drone.floor_position().y)
	far.global_position = Vector3(drone.floor_position().x + 15.0, 0.0, drone.floor_position().y)
	cus._on_drone_event(drone, {"type": DroneBrain.EV_CALLED, "player_id": P, "at": at})
	check_eq(near.brain.last_known, at, "the nearest stalker got your position")
	check(near.brain.hunting(), "and hunts")
	check(not far.brain.hunting(), "the other one didn't")


func test_drone_routes_are_clear_of_props_and_it_can_be_shot() -> void:
	var scene: Node = await _scene()
	for d: Node3D in scene.custodian.drones:
		var route: Array = d.brain.route
		for i in route.size():
			check(scene.pack.nav.line_free(route[i], route[(i + 1) % route.size()]), "%s leg %d is clear" % [d.label, i])
	var drone: Node3D = scene.custodian.drones[0]
	_no_stalkers(scene)
	var at: Vector2 = drone.floor_position()
	var shot: Dictionary = scene._trace_shot(Vector3(at.x, 1.2, at.y + 4.0), Vector3(0, 0, -1), 10.0)
	check(shot.get("collider") == drone, "a round on its line hits it: %s" % str(shot))


# --- waking ---

func test_tier_2_and_the_prize_wake_it_once_each_shift() -> void:
	var scene: Node = await _scene()
	_no_stalkers(scene)
	var cus: Node = scene.custodian
	var woke: Array = []
	var said: Array = []
	cus.woke.connect(func(r: String) -> void: woke.append(r))
	cus.spoke.connect(func(l: String) -> void: said.append(l))
	var cfg: Dictionary = cus.cfg
	check(not cus.awake, "asleep to begin")
	for c: Node3D in cus.cutters:
		check(not c.brain.awake(), "its cutters too")
	var shift_cfg: Dictionary = scene._cfg
	scene._step_clock_to(float(shift_cfg.tiers[0].at_oxygen))
	check(not cus.awake, "tier 1 doesn't wake it")
	scene._step_clock_to(float(shift_cfg.tiers[1].at_oxygen))
	check(cus.awake, "tier 2 does")
	check_eq(woke, ["tier"], "once")
	check_eq(said, [String(cfg.voice.lines.wake_tier.text)], "with its line")
	scene._trip_alarm()
	check_eq(woke, ["tier"], "the prize later doesn't wake it again")
	check(said.has(String(cfg.voice.lines.wake_prize.text)), "but gets its line")
	scene.respawn()
	check(not cus.awake, "a new shift, asleep again")
	woke.clear()
	said.clear()
	scene._trip_alarm()
	check_eq(woke, ["prize"], "the prize wakes it early")
	check_eq(said, [String(cfg.voice.lines.wake_prize.text)], "\"Asset tamper confirmed.\"")
	check_eq(String(cfg.voice.lines.wake_prize.text), "Asset tamper confirmed.", "the packet's words")
	scene.shift.oxygen_left = 0.0
	scene._step_clock_to(0.0)
	check_eq(woke, ["prize"], "tier 2 after the prize doesn't wake it again")
	check(scene.run_log.threats_seen.has("custodian"), "on file for the next briefing")


func test_dormant_lens_is_dim_and_awake_bright() -> void:
	var scene: Node = await _scene()
	_no_stalkers(scene)
	var cus: Node = scene.custodian
	var lens_cfg: Dictionary = cus.cfg.lens
	check(float(lens_cfg.bright_energy) > float(lens_cfg.dim_energy) * 2.0, "they read apart")
	var units: Array = cus.cutters + cus.drones
	for u: Node3D in units:
		check_eq(float((u.lens.material_override as ShaderMaterial).get_shader_parameter("energy")), float(lens_cfg.dim_energy), "%s dim" % u.label)
	cus.wake("tier")
	for u: Node3D in cus.drones:
		check_eq(float((u.lens.material_override as ShaderMaterial).get_shader_parameter("energy")), float(lens_cfg.bright_energy), "%s bright" % u.label)
	await _sim(scene, DT)
	for c: Node3D in cus.cutters:
		var want: float = lens_cfg.bright_energy if bool(c.get_meta("on_wake")) else lens_cfg.dim_energy
		check_eq(float((c.lens.material_override as ShaderMaterial).get_shader_parameter("energy")), want, "%s by its own state" % c.label)
	check(cus.cutters.size() >= 2 and cus.cutters.size() <= 3, "2-3 cutters placed from data")
	check(cus.drones.size() >= 1 and cus.drones.size() <= 2, "1-2 drones, routes from data")


# --- voice ---

func test_announcement_cooldowns_hold() -> void:
	var cfg := _cfg()
	var v := CustodianVoice.new(cfg.voice)
	var event_rest := float(cfg.voice.lines.detect.cooldown_s)
	var shared := float(cfg.voice.global_cooldown_s)
	check(event_rest > shared, "the data's event rest is the longer of the two")
	check_eq(v.say("detect"), String(cfg.voice.lines.detect.text), "first time, it speaks")
	check_eq(v.say("detect"), "", "not again at once")
	check_eq(v.say("charged"), "", "nor anything else while the shared wait runs")
	v.step(shared + DT)
	check_eq(v.say("detect"), "", "that line still rests")
	check_eq(v.say("charged"), String(cfg.voice.lines.charged.text), "another may speak")
	v.step(event_rest + DT)
	check_eq(v.say("detect"), String(cfg.voice.lines.detect.text), "and after its rest, again")
	v.reset()
	v.say("detect")
	check_eq(v.say("wake_prize"), String(cfg.voice.lines.wake_prize.text), "waking doesn't wait")


func test_a_long_fight_doesnt_repeat_it_every_attack() -> void:
	var scene: Node = await _scene()
	_no_stalkers(scene)
	var said: Array = []
	scene.custodian.spoke.connect(func(l: String) -> void: said.append(l))
	scene.custodian.wake("tier")
	var open: Vector2 = scene.layout.point_in("cargo", [0.6, 0.3])
	_place(scene, open)
	var burns := 0
	var cutter: Node3D = scene.custodian.cutters[0]
	var was := false
	for i in roundi(24.0 / DT):
		await _sim(scene, DT)
		scene.suit.reset()
		if cutter.brain.burning() and not was:
			burns += 1
		was = cutter.brain.burning()
	check(burns >= 3, "several burns: %d" % burns)
	check(said.size() < burns + 1, "fewer lines than attacks: %d for %d burns" % [said.size(), burns])


func test_suit_keeps_custodians_line_apart_from_its_own() -> void:
	var os := SuitOs.new(Data.load_data("hud"))
	os.announce("SUIT")
	os.custodian_say("SHIP")
	check_eq(os.announcement(), "SUIT", "the suit's stays")
	check_eq(os.custodian_line(), "SHIP", "and the ship's beside it")
	os.step(float(os.cfg.custodian.life_s) + DT)
	check_eq(os.custodian_line(), "", "it fades out")


# --- paperwork and the log ---

func _paper_cfg() -> Dictionary:
	return (Data.load_data("paperwork") as Dictionary).duplicate(true)


func _contract(p: Paperwork) -> Dictionary:
	return p.contract(1, 1000, [], {"quota": 2400, "banked": 0, "shifts_left": 3, "share": 0.0, "verdict": "", "surplus": 0, "shortfall": 0, "cycle": 1})


func test_death_bill_names_the_new_causes() -> void:
	var cfg := _paper_cfg()
	var p := Paperwork.new(cfg)
	p.reseed(5)
	var c := _contract(p)
	var log := RunLog.new("user://test_runs_custodian")
	log.enabled = false
	log.note_damage("cutter", 100.0, false)
	log.note_death("CUTTER UNIT CARGO NORTH", "cutter", "custodian_cutter")
	var doc: Dictionary = p.death_bill(log.to_dict("death"), c, {"quota": 2400, "banked": 0, "shifts_left": 2, "share": 0.0, "verdict": "", "surplus": 0, "shortfall": 0, "cycle": 1})
	check_eq(doc.cause, "Thermal cutting incident", "the cause")
	check_eq(doc.killer, "CUTTER UNIT CARGO NORTH", "the killer")
	var party: Array = cfg.causes.party.filter(func(l: Dictionary) -> bool: return l.id == "custodian")
	check_eq(party[0].text, "Property protection enforcement", "the party in the library")
	check_eq(doc.party_line, String(party[0].line), "on the bill")


func test_killer_is_custodian_cutter_on_the_deck() -> void:
	var scene: Node = await _scene()
	var cutter: Node3D = scene.custodian.cutters[0]
	scene._on_custodian_hit(P, String(cutter.cfg.source), 1000.0, cutter.floor_position(), cutter.label)
	var log: Dictionary = scene.run_log.to_dict("death")
	check(scene.suit.dead, "dead")
	check_eq(String(log.killed_by.custodian_cutter), String(cutter.label), "killed_by key and name")
	check_eq(String(log.cause_of_death), "cutter", "cause")


func test_payslip_line_appears_only_with_a_custodian_hit() -> void:
	var cfg := _paper_cfg()
	var p := Paperwork.new(cfg)
	p.reseed(5)
	var c := _contract(p)
	var log := RunLog.new("user://test_runs_custodian")
	log.enabled = false
	log.shift_report = func() -> Dictionary: return {"shift_outcome": "extracted", "airlock_cycles": 0, "salvage": []}
	log.note_time(60.0)
	var ids := func(doc: Dictionary) -> Array: return doc.deductions.map(func(d: Dictionary) -> String: return d.id)
	check(not ids.call(p.payslip(log.to_dict("left"), c)).has("custodian_charge"), "no hit, no line")
	log.note_custodian_call()
	check(not ids.call(p.payslip(log.to_dict("left"), c)).has("custodian_charge"), "a call isn't a hit")
	log.note_damage("spit", 10.0, false)
	check(not ids.call(p.payslip(log.to_dict("left"), c)).has("custodian_charge"), "a stalker's hit isn't CUSTODIAN's")
	log.note_damage("cutter", 40.0, false)
	var doc: Dictionary = p.payslip(log.to_dict("left"), c)
	check(ids.call(doc).has("custodian_charge"), "a hit, and there it is")
	var line: Dictionary = doc.deductions.filter(func(d: Dictionary) -> bool: return d.id == "custodian_charge")[0]
	check_eq(int(line.quantity), 1, "one hit")
	check_eq(line.note, "Your account has been charged.", "A011's words, short enough for the form")


func test_threats_seen_reaches_the_next_briefing() -> void:
	var cfg := _paper_cfg()
	var p := Paperwork.new(cfg)
	p.reseed(5)
	var kinds: Array = p.known_hazards([{"threats_seen": {"custodian": "ship"}}]).map(func(h: Dictionary) -> String: return h.kind)
	check_eq(kinds, ["custodian"], "CUSTODIAN makes the hazards once met")


func test_every_custodian_number_is_in_data() -> void:
	var cfg := _cfg()
	cfg.cutter.damage = 7.0
	cfg.drone.call_s = 1.0
	var c := _cutter(cfg)
	var hits := _run_cutter(c, _players(Vector2(0, -4)), 3.0).filter(func(e: Dictionary) -> bool: return e.type == CutterBrain.EV_HIT)
	check_eq(float(hits[0].amount), 7.0, "damage follows the data")
	var d := _drone(cfg)
	var t := 0.0
	var done := false
	while t < 2.0 and not done:
		done = _types(d.step(DT, _players(Vector2(0, -4)), _trace)).has(DroneBrain.EV_CALLED)
		t += DT
	check(done and t < 1.2, "the call follows the data: %.2f" % t)
