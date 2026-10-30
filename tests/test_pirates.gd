extends "res://tests/test_case.gd"
## T007: pirates that obey your weight, cover that matters both ways, the suppress-and-flank, the
## lock-to-cover prototype, the firefight deck and the new run log fields.

const PirateBrain := preload("res://src/pirates/pirate_brain.gd")
const Tactics := preload("res://src/pirates/squad_tactics.gd")
const HitTally := preload("res://src/pirates/hit_tally.gd")
const CoverField := preload("res://src/cover/cover_field.gd")
const CoverLock := preload("res://src/cover/cover_lock.gd")
const RunLog := preload("res://src/run_log/run_log.gd")
const OperatorModel := preload("res://src/player/operator_model.gd")
const DT := 1.0 / 60.0
const TEST_DIR := "user://test_runs_t007"

var _nodes: Array[Node] = []


func after_each() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()
	Data.clear_cache()
	Engine.time_scale = 1.0
	var d := DirAccess.open(TEST_DIR)
	if d:
		for f in d.get_files():
			d.remove(f)


func _cfg() -> Dictionary:
	return (Data.load_data("pirates") as Dictionary).duplicate(true)


func _senses(pos: Vector2, aim: Vector2, engage := false) -> Dictionary:
	return {"pos": pos, "next_point": pos, "aim": aim, "sees": engage, "can_engage": engage}


func _brain(cfg := {}) -> PirateBrain:
	return PirateBrain.new(_cfg() if cfg.is_empty() else cfg, [Vector2(0, 0)])


func _scene() -> Node:
	var scene: Node = (load("res://scenes/pirates/pirate_deck.tscn") as PackedScene).instantiate()
	_nodes.append(scene)
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	await tree.process_frame
	scene.aim_from_mouse = false
	scene.operator.input_enabled = false
	scene.set_physics_process(false)
	scene.operator.set_physics_process(false)
	scene.run_log.enabled = false
	scene.squad.reset()
	for i in scene.squad.pirates.size():
		scene.squad.pirates[i].brain.rng.seed = 700 + i
		scene.squad.pirates[i].brain.gun.rng.seed = 800 + i
	return scene


func _run(scene: Node, seconds: float, each := Callable()) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	for i in roundi(seconds / DT):
		await tree.physics_frame
		scene.simulate_world(DT)
		scene.operator.simulate(DT)
		if each.is_valid():
			each.call()


func _at(scene: Node, p: Vector2, look: Vector2) -> void:
	scene.operator.global_position = Vector3(p.x, 0, p.y)
	scene.operator.model.reset_motion()
	scene.operator.face_now(Vector3(look.x, 1.2, look.y))


## The long crate on the south side of the hold, with open floor to its west.
func _low_rect(scene: Node) -> Rect2:
	return scene.layout.props[11].rect


func _park_others(scene: Node, keep: Node) -> void:
	for q: Node in scene.squad.pirates:
		if q != keep:
			q.brain.take_hit(INF)


# --- weight ---

func test_their_numbers_come_from_data_and_start_equal_to_yours() -> void:
	var c := _cfg()
	var player: Dictionary = Data.load_data("player")
	var rifle: Dictionary = Data.value("weapons", "rifle", {})
	for section: String in ["move", "turn", "crouch"]:
		check_eq(c.weight[section], player[section], "weight.%s matches the player's" % section)
	for key: String in ["magazine", "reserve", "fire_interval_s", "reload_s", "cone", "recoil", "range_m"]:
		check_eq(c.rifle[key], rifle[key], "rifle.%s matches the player's" % key)
	var b := _brain(c)
	check(b.model.cfg == c.weight, "its body reads pirates.json")
	check(b.gun.cfg == c.rifle, "its gun reads pirates.json")
	check(b.cone.cfg == c.rifle.cone, "its cone reads pirates.json")
	var slow := _cfg()
	slow.weight.turn.standing_deg_s = 60.0
	check_eq(_brain(slow).model.current_turn_rate_deg(), 60.0, "and changing the data changes it")


func test_it_turns_at_your_cap_however_much_it_wants_to() -> void:
	var c := _cfg()
	var b := _brain(c)
	var pos := Vector2(0, 0)
	var behind := pos + Vector2(0, 10)
	b.model.face_now(0.0)
	b.stand_down()
	b.spot = {"hide": pos, "fire": pos, "kind": "low", "id": 1}
	b.state = PirateBrain.State.MOVE
	var was := b.model.torso_yaw
	b.step(DT, _senses(pos, behind))
	var turned := rad_to_deg(absf(angle_difference(was, b.model.torso_yaw)))
	check(turned <= float(c.weight.turn.standing_deg_s) * DT + 0.001, "standing cap (%.2f°)" % turned)
	b.state = PirateBrain.State.DOWN
	b.model.crouch_amount = 1.0
	was = b.model.torso_yaw
	b.step(DT, _senses(pos, behind))
	turned = rad_to_deg(absf(angle_difference(was, b.model.torso_yaw)))
	check(turned <= float(c.weight.turn.crouched_deg_s) * DT + 0.001, "crouched cap (%.2f°)" % turned)


func test_its_aim_settles_and_recoil_kicks_as_yours_do() -> void:
	var c := _cfg()
	var b := _brain(c)
	var pos := Vector2(0, 0)
	var at := Vector2(0, -10)
	b.spot = {"hide": pos, "fire": pos, "kind": "low", "id": 1}
	b.state = PirateBrain.State.DOWN
	b.cone.spread_deg = float(c.rifle.cone.wide_deg)
	var settle := float(c.rifle.cone.settle_s)
	for i in roundi(settle * 0.5 / DT):
		b.step(DT, _senses(pos, at))
	check(b.cone.spread_deg > float(c.rifle.cone.tight_deg), "still wide halfway through the settle")
	for i in roundi(settle * 0.6 / DT):
		b.step(DT, _senses(pos, at))
	check_eq(b.cone.spread_deg, float(c.rifle.cone.tight_deg), "tight after settle_s")
	var shots := 0
	var peak := 0.0
	b._wait_left = 0.0
	for i in 60:
		var ev: Array = b.step(DT, _senses(pos, at, true))
		shots += ev.count(PirateBrain.EV_SHOT)
		peak = maxf(peak, absf(b.gun.recoil_deg))
	check(shots >= int(c.fight.burst_min), "it fired a burst (%d)" % shots)
	check(peak >= float(c.rifle.recoil.kick_deg) * 2.0 - 0.001, "recoil built up (%.2f°)" % peak)


func test_a_reload_is_a_commitment_for_it_too() -> void:
	var c := _cfg()
	var b := _brain(c)
	var pos := Vector2(0, 0)
	b.spot = {"hide": pos, "fire": pos, "kind": "low", "id": 1}
	b.state = PirateBrain.State.DOWN
	b.gun.mag = 1
	var ev: Array = b.step(DT, _senses(pos, Vector2(0, -8), true))
	check(ev.has(PirateBrain.EV_RELOAD), "low on rounds: it reloads and says so")
	check_eq(b.state, PirateBrain.State.RELOAD, "down behind its cover")
	check(b.model.crouch_amount > 0.0, "crouching")
	var t := DT
	var fired := 0
	while b.gun.reloading() and t < 10.0:
		fired += (b.step(DT, _senses(pos, Vector2(0, -8), true)) as Array).count(PirateBrain.EV_SHOT)
		t += DT
	check_eq(fired, 0, "no rounds during it")
	check(absf(t - float(c.rifle.reload_s)) < DT * 2.0, "it takes reload_s (%.2f)" % t)


func test_it_dies_in_four_or_five_rifle_hits_and_rounds_add_up_to_a_stagger() -> void:
	var c := _cfg()
	var rifle := float((Data.value("weapons", "rifle", {}) as Dictionary).damage)
	var b := _brain(c)
	var hits := 0
	while b.alive() and hits < 20:
		b.take_hit(rifle)
		hits += 1
	check(hits >= 4 and hits <= 5, "dead in %d hits" % hits)
	var s := _brain(c)
	s.take_hit(rifle)
	check(not s.suit.staggered(), "one round isn't a big hit")
	s.take_hit(rifle)
	check(s.suit.staggered(), "two together are")
	check(s.cone.spread_deg >= float(c.stagger.cone_deg), "the cone blows wide, as yours does")
	var pos := Vector2(0, 0)
	s.spot = {"hide": pos, "fire": pos, "kind": "low", "id": 1}
	s.state = PirateBrain.State.BURST
	var yaw := s.model.torso_yaw
	var mag := s.gun.mag
	s.step(DT, _senses(pos, Vector2(8, 8), true))
	check_eq(s.model.torso_yaw, yaw, "staggered: it can't turn")
	check_eq(s.gun.mag, mag, "or fire")
	var tally := HitTally.new(0.5, 25.0)
	check(not tally.add(12.0), "12")
	tally.step(0.6)
	check(not tally.add(12.0), "the old one aged out")
	check(not tally.add(12.0), "24")
	check(tally.add(12.0), "36: big")


# --- the picture ---

func test_the_rival_paint_is_a_data_swap_with_no_orange_left() -> void:
	var scene: Node = await _scene()
	var model: Node = scene.squad.pirates[0].get_node("Model")
	var specs: Dictionary = _cfg().body.materials
	var swapped := 0
	for m: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for i in m.mesh.get_surface_count():
			var source := m.mesh.surface_get_material(i) as BaseMaterial3D
			if source == null or not specs.has(source.resource_name):
				continue
			var worn := m.get_surface_override_material(i) as BaseMaterial3D
			check(worn != null, "%s has an override" % source.resource_name)
			check_eq(worn.albedo_color.to_html(false), Color(String(specs[source.resource_name].color)).to_html(false), "colour from data")
			if source.resource_name == "paint_orange":
				check(worn.albedo_texture == null, "the orange texture is gone, or a tint couldn't hide it")
				check(worn.albedo_color.h > 0.3, "and it isn't orange")
				swapped += 1
			check_eq(source.albedo_color, Color.WHITE if source.albedo_texture else source.albedo_color, "the source material is untouched")
	check(swapped >= 2, "body and rifle both (%d)" % swapped)
	check(model.find_child("Rifle", true, false) != null, "same rifle model")
	var mine: Node = scene.operator.get_node("Model")
	var op_mesh: MeshInstance3D = mine.find_children("*", "MeshInstance3D", true, false)[0]
	check(op_mesh.get_surface_override_material(1) == null, "the operator keeps his orange")


func test_they_carry_lights_and_a_dead_ones_goes_out() -> void:
	var scene: Node = await _scene()
	var p: Node = scene.squad.pirates[0]
	check(p.light.spot.visible, "light on")
	check_eq(p.light.spot.light_color.to_html(false), Color(String(_cfg().flashlight.color)).to_html(false), "its colour from data")
	await _run(scene, 0.2)
	check(p.light.global_position.distance_to(p.muzzle_position()) < 0.3, "at the muzzle")
	p.take_hit({"damage": INF})
	check(not p.light.spot.visible, "out when dead")


# --- senses ---

func test_walls_doors_and_low_cover_stop_their_eyes_and_gunfire_doesnt() -> void:
	var scene: Node = await _scene()
	var door: Node = scene._door("cargo", 0.6)
	var c: Vector2 = door.opening.get_center()
	var s: Node = scene.squad
	var p: Node = s.pirates[0]
	_park_others(scene, p)
	var inside := c + Vector2(4.0, 0)
	p.global_position = Vector3(inside.x, 0, inside.y)
	p.brain.model.face_now(OperatorModel.yaw_to(p.global_position, Vector3(c.x - 3.0, 0, c.y)))
	_at(scene, c + Vector2(-3.0, 0), inside)
	check(door.door_state.blocks(), "shut")
	await _run(scene, 0.2)
	check(not s.alerted, "a shut door hides you")
	door.interact([])
	await _run(scene, float(door.cfg.open_s) + 0.2)
	check(s.alerted, "open, it sees you")
	s.reset()
	door.reset("closed")
	s.pirates[1].brain.take_hit(INF)
	s.pirates[2].brain.take_hit(INF)
	await _run(scene, 0.1)
	check(not s.alerted, "shut again")
	s.noise("gunfire", c + Vector2(-3.0, 0))
	check(s.alerted, "but it hears gunfire through it")
	check_eq(s.last_known, c + Vector2(-3.0, 0), "and knows where from")


func test_your_light_gives_you_away() -> void:
	var scene: Node = await _scene()
	var s: Node = scene.squad
	s.light_on = func(_p: Vector2) -> bool: return true
	await _run(scene, 0.1)
	check(s.alerted, "caught in your beam, it knows")


# --- cover, both ways ---

func test_crouched_behind_low_cover_is_protected_and_braced_is_exposed() -> void:
	var scene: Node = await _scene()
	var r := _low_rect(scene)
	var p: Node = scene.squad.pirates[0]
	_park_others(scene, p)
	var hide := Vector2(r.end.x + 0.6, r.get_center().y)
	var shooter := Vector2(r.position.x - 3.5, r.get_center().y)
	p.global_position = Vector3(hide.x, 0, hide.y)
	p.brain.spot = {"hide": hide, "fire": hide, "kind": "low", "id": 0}
	p.brain.state = p.brain.State.DOWN
	p.brain.model.crouch_amount = 1.0
	p.brain.brace = 0.0
	p.torso_height = scene.squad._torso(p)
	check_eq(p.torso_height, float(scene._cover_cfg.crouched_torso_m), "crouched torso")
	var origin := Vector3(shooter.x, 1.2, shooter.y)
	var dir := Vector3(hide.x - shooter.x, 0, hide.y - shooter.y).normalized()
	var stopped: Array = []
	scene.tracer.cover_stopped.connect(func(b: Object) -> void: stopped.append(b))
	var hit: Dictionary = scene.tracer.trace(origin, dir, 40.0)
	check(not hit.is_empty() and hit.collider == null, "the round stops at the cover")
	check_eq(stopped, [p], "and it counts as stopped")
	check_eq(hit.position.x <= r.end.x + 0.001, true, "at the cover itself")
	p.brain.brace = 1.0
	p.torso_height = scene.squad._torso(p)
	check_eq(p.torso_height, float(scene._cover_cfg.braced_torso_m), "braced torso")
	hit = scene.tracer.trace(origin, dir, 40.0)
	check(not hit.is_empty() and hit.collider == p, "braced, the round finds it")
	p.take_hit({"damage": 18.0, "origin": origin})
	check_eq(p.brain.suit.integrity, float(_cfg().health) - 18.0, "and it hurts")


func test_their_rounds_use_the_same_trace_and_your_cover_stops_them() -> void:
	var scene: Node = await _scene()
	var r := _low_rect(scene)
	var p: Node = scene.squad.pirates[0]
	_park_others(scene, p)
	var me := Vector2(r.end.x + 0.6, r.get_center().y)
	var from := Vector2(r.position.x - 3.5, r.get_center().y)
	_at(scene, me, from)
	scene.operator.scripted = {"crouch": true}
	await _run(scene, 0.4)
	p.global_position = Vector3(from.x, 0, from.y)
	var aim := Vector3(me.x - from.x, 0, me.y - from.y).normalized()
	scene.squad.player_body.center = me
	scene.squad.player_body.height = scene.body_height()
	var hit: Dictionary = scene.squad.tracer.trace(p.shot_origin(), aim, 40.0)
	check(not hit.is_empty() and hit.collider == null, "cover stops a round at your crouched body")
	check_eq(scene.run_log.shots_blocked_for_you, 1, "the log counts it")
	scene.squad.player_body.height = float(scene._cover_cfg.standing_torso_m)
	hit = scene.squad.tracer.trace(p.shot_origin(), aim, 40.0)
	check(not hit.is_empty() and hit.collider == scene.squad.player_body, "standing, it reaches you")


# --- the squad ---

func test_roles_one_suppresses_one_flanks_and_they_hand_over() -> void:
	var a := {"id": "a", "pos": Vector2(5, 0), "reloading": false, "hurt": false}
	var b := {"id": "b", "pos": Vector2(9, 0), "reloading": false, "hurt": false}
	var c := {"id": "c", "pos": Vector2(7, 0), "reloading": false, "hurt": false}
	var r: Dictionary = Tactics.assign([a, b, c], Vector2.ZERO, {})
	check_eq(r.a, Tactics.Role.SUPPRESS, "nearest suppresses")
	check_eq(r.b, Tactics.Role.FLANK, "furthest flanks")
	check_eq(r.c, Tactics.Role.SUPPORT, "the other supports")
	var a2 := a.duplicate()
	a2.reloading = true
	var r2: Dictionary = Tactics.assign([a2, b, c], Vector2.ZERO, r)
	check_eq(r2.c, Tactics.Role.SUPPRESS, "support takes over while it reloads")
	check_eq(r2.b, Tactics.Role.FLANK, "flanker keeps flanking")
	var b2 := b.duplicate()
	b2.hurt = true
	var r3: Dictionary = Tactics.assign([a, b2, c], Vector2.ZERO, r)
	check(r3.b != Tactics.Role.FLANK, "a hurt one doesn't flank")
	check_eq(Tactics.assign([a], Vector2.ZERO, {}).a, Tactics.Role.SUPPORT, "alone, it just holds")


func test_the_suppressor_fires_at_your_cover_while_the_flanker_gets_an_open_line() -> void:
	var scene: Node = await _scene()
	scene._open_all_doors()
	var s: Node = scene.squad
	var bark_keys: Array = []
	s.barked.connect(func(_p: Node, key: String, _l: String) -> void: bark_keys.append(key))
	var r := _low_rect(scene)
	var me := Vector2(r.position.x - 0.6, r.get_center().y)
	_at(scene, me, Vector2(14.0, r.get_center().y))
	scene.operator.scripted = {"crouch": true}
	await _run(scene, 0.4)
	s.alert(me)
	var crouched := float(scene._cover_cfg.crouched_torso_m)
	var fired_while_flanking := 0
	var flanker: Node = null
	var flanker_home := Vector2.ZERO
	var arrived := false
	var t := 0.0
	while t < 20.0 and not arrived:
		await _run(scene, DT)
		t += DT
		s.alert(me)
		scene.suit.reset()
		scene.operator.release_control()
		var f: Node = s.with_role(Tactics.Role.FLANK)
		var sup: Node = s.with_role(Tactics.Role.SUPPRESS)
		if f and flanker == null:
			flanker = f
			flanker_home = f.floor_position()
		if f and sup and sup.brain.state == PirateBrain.State.BURST:
			fired_while_flanking += 1
		if f and f.brain.dug_in() and s.spots.open_line(f.floor_position(), me, crouched):
			arrived = true
	check(flanker != null, "somebody flanks")
	check(arrived, "the flanker reaches a spot with an open line on a crouched body (%.1f s)" % t)
	check(fired_while_flanking > 0, "while the suppressor is up firing")
	check(scene.run_log.shots_blocked_for_you > 0, "and its rounds hit your cover (%d)" % scene.run_log.shots_blocked_for_you)
	check(flanker.floor_position().distance_to(flanker_home) > 2.0, "it actually went somewhere")
	check(bark_keys.has("flank"), "they call it out")
	check(bark_keys.has("suppress"), "both of them")
	var was: float = scene.suit.integrity
	t = 0.0
	while t < 6.0 and scene.suit.integrity >= was:
		await _run(scene, DT)
		t += DT
		s.alert(me)
	check(scene.suit.integrity < was, "and the open line gets you, cover and all (%.1f s)" % t)


func test_a_hurt_pirate_falls_back_to_further_cover() -> void:
	var scene: Node = await _scene()
	scene._open_all_doors()
	var s: Node = scene.squad
	var keys: Array = []
	s.barked.connect(func(_p: Node, key: String, _l: String) -> void: keys.append(key))
	var r := _low_rect(scene)
	var me := Vector2(r.position.x - 0.6, r.get_center().y)
	_at(scene, me, Vector2(14.0, r.get_center().y))
	s.alert(me)
	var p: Node = s.pirates[0]
	await _run(scene, 1.0, func() -> void: scene.suit.reset(); scene.operator.release_control())
	var before: Vector2 = p.brain.spot.hide if not p.brain.spot.is_empty() else p.floor_position()
	p.take_hit({"damage": float(_cfg().health) * (1.0 - float(_cfg().fight.fall_back_below)) + 1.0, "origin": Vector3(me.x, 1.2, me.y)})
	check(p.brain.alive() and p.brain.wants_fall_back(), "hurt enough")
	await _run(scene, 0.8, func() -> void: scene.suit.reset(); scene.operator.release_control(); s.alert(me))
	check(p.brain.fell_back, "it fell back")
	check(keys.has("hurt"), "and said so")
	check((p.brain.spot.hide as Vector2).distance_to(me) >= before.distance_to(me) - 0.5, "away, not closer")


func test_they_stand_down_when_you_die_or_vanish() -> void:
	var scene: Node = await _scene()
	var s: Node = scene.squad
	var keys: Array = []
	s.barked.connect(func(_p: Node, key: String, _l: String) -> void: keys.append(key))
	s.alert(Vector2(8, 5))
	_at(scene, Vector2(2.5, 15), Vector2(2.5, 10))
	await _run(scene, 0.1)
	check(s.alerted, "alerted")
	s.contact_age = float(_cfg().senses.stand_down_s) + 1.0
	await _run(scene, 0.1)
	check(not s.alerted, "gave up after stand_down_s")
	check(keys.has("lost"), "and said so")
	s.alert(Vector2(8, 5))
	scene._hurt("rifle", 999.0, "Hale", false)
	await _run(scene, 0.1)
	check(not s.alerted, "you died: back to work")
	check(keys.has("clear"), "nothing personal")
	check_eq(s.pirates[0].brain.state, PirateBrain.State.LOOT, "looting")


# --- lock-to-cover ---

func _lock_field() -> CoverField:
	var f := CoverField.new(Data.load_data("cover"))
	f.set_piece("low", Rect2(0, 0, 2, 1), CoverField.LOW)
	f.set_piece("tall", Rect2(10, 0, 2, 1), CoverField.TALL)
	return f


func _free(_p: Vector2, _r: float) -> bool:
	return true


func _lock() -> CoverLock:
	return CoverLock.new((Data.load_data("cover") as Dictionary).lock)


func test_lock_snaps_only_next_to_low_cover() -> void:
	var f := _lock_field()
	var l := _lock()
	var reach := float(l.cfg.reach_m)
	check(not l.try_lock(f, Vector2(1, -reach - 0.3), 0.46, _free), "too far")
	check(not l.locked(), "still free")
	check(not l.try_lock(f, Vector2(11, -0.5), 0.46, _free), "tall isn't low")
	check(not l.try_lock(f, Vector2(1, -0.5), 0.46, func(_p: Vector2, _r: float) -> bool: return false), "nowhere to stand")
	check(l.try_lock(f, Vector2(1.3, -reach + 0.1), 0.46, _free), "near low cover")
	check_eq(l.state, CoverLock.State.SNAPPING, "snapping")
	check_eq(l.normal, Vector2(0, -1), "out of the cover, towards you")
	var want := 0.0 - 0.46 - float(l.cfg.gap_m)
	check(is_equal_approx(l.slot.y, want), "slot right against the edge (%.2f)" % l.slot.y)
	check(is_equal_approx(l.slot.x, 1.3), "where you already were along it")
	for i in roundi(float(l.cfg.snap_s) * 0.5 / DT):
		l.step(DT, Vector2.ZERO, false)
	var mid := l.hold_position(Vector2.ZERO)
	check(mid.y < want, "partway there after half snap_s (%.2f)" % mid.y)
	for i in roundi(float(l.cfg.snap_s) * 0.6 / DT):
		l.step(DT, Vector2.ZERO, false)
	check_eq(l.state, CoverLock.State.LOCKED, "locked after snap_s")


func test_lock_raises_and_lowers_on_data_times_and_slides_and_releases() -> void:
	var f := _lock_field()
	var l := _lock()
	l.try_lock(f, Vector2(1, -0.7), 0.46, _free)
	for i in roundi(float(l.cfg.snap_s) / DT) + 1:
		l.step(DT, Vector2.ZERO, false)
	check(not l.exposed() and not l.can_fire(), "down: protected, can't fire")
	var t := 0.0
	while l.raise < 1.0 and t < 2.0:
		l.step(DT, Vector2.ZERO, true)
		t += DT
	check(absf(t - float(l.cfg.raise_s)) < DT * 2.0, "up in raise_s (%.2f)" % t)
	check(l.exposed() and l.can_fire(), "up: exposed, can fire")
	check_eq(l.step(DT, Vector2(1, 0), true), Vector2.ZERO, "committed while up: no sliding")
	t = 0.0
	while l.raise > 0.0 and t < 2.0:
		l.step(DT, Vector2.ZERO, false)
		t += DT
	check(absf(t - float(l.cfg.lower_s)) < DT * 2.0, "down in lower_s (%.2f)" % t)
	check_eq(l.step(DT, Vector2(1, 0), false), Vector2(1, 0), "slides along the edge")
	var far := l.hold_position(Vector2(2.3, l.slot.y))
	check(far.x <= 2.0, "not past its end (%.2f)" % far.x)
	check_eq(l.step(DT, Vector2(1, 0), false), Vector2.ZERO, "and stops there")
	check(l.locked(), "still locked")
	check_eq(l.step(DT, Vector2(0, 1), false), Vector2.ZERO, "pushing into it does nothing")
	check(l.locked(), "still locked")
	check_eq(l.step(DT, Vector2(0, -1), false), Vector2(0, -1), "moving away walks off")
	check(not l.locked(), "and lets go")


func test_locked_in_the_scene_is_protected_then_exposed_then_released() -> void:
	var scene: Node = await _scene()
	var r := _low_rect(scene)
	var op: Node = scene.operator
	var from := Vector2(r.position.x - 3.5, r.get_center().y)
	# Nobody's shooting: this is about the geometry. Rounds are traced by hand from `from`.
	_park_others(scene, null)
	var muzzle := Vector3(from.x, 1.2, from.y)
	var start := Vector2(r.end.x + 0.7, r.get_center().y)
	_at(scene, start, from)
	check(scene.driver.press(), "the key locks")
	await _run(scene, float(scene._cover_cfg.lock.snap_s) + 0.3)
	check(scene.driver.lock.state == CoverLock.State.LOCKED, "locked")
	check(op.model.crouch_amount >= 1.0, "crouched")
	var at: Vector2 = scene._eye()
	check(absf(at.x - (r.end.x + op.body_radius() + float(scene._cover_cfg.lock.gap_m))) < 0.01, "snapped to the edge (%.2f)" % at.x)
	check(absf(wrapf(op.model.torso_yaw - op.model.yaw_to(op.global_position, Vector3(from.x, 0, from.y)), -PI, PI)) < 0.2, "facing it")
	check(scene.in_cover_now(), "IN COVER")
	var aim := Vector3(at.x - from.x, 0, at.y - from.y).normalized()
	scene.squad.player_body.center = at
	scene.squad.player_body.height = scene.body_height()
	var hit: Dictionary = scene.squad.tracer.trace(muzzle, aim, 40.0)
	check(not hit.is_empty() and hit.collider == null, "locked and down: protected")
	scene.driver.scripted = {"aim": true}
	await _run(scene, float(scene._cover_cfg.lock.raise_s) + 0.05)
	check(scene.driver.lock.exposed(), "aiming over")
	check_eq(scene.body_height(), float(scene._cover_cfg.braced_torso_m), "braced torso")
	check(not scene.in_cover_now(), "not IN COVER up there")
	scene.squad.player_body.height = scene.body_height()
	hit = scene.squad.tracer.trace(muzzle, aim, 40.0)
	check(not hit.is_empty() and hit.collider == scene.squad.player_body, "exposed: a round finds you")
	var mag: int = op.rifle.state.mag
	scene.driver.scripted = {"fire": true}
	await _run(scene, 0.2)
	check(op.rifle.state.mag < mag, "you can fire over it")
	check(scene.run_log.time_locked_s > 0.0, "the log counts the time")
	scene.driver.scripted = {}
	await _run(scene, float(scene._cover_cfg.lock.aim_hold_s) + float(scene._cover_cfg.lock.lower_s) + 0.1)
	check(not scene.driver.lock.exposed(), "lowers again")
	scene.driver.scripted = {"keys": Vector2(1, 0)}
	await _run(scene, 0.05)
	check(not scene.driver.lock.locked(), "moving away lets go")
	check(op.scripted.is_empty(), "and hands the controls back")
	check(scene.driver.press(), "locks again")
	check(scene.driver.press(), "the key lets go too")
	check(not scene.driver.lock.locked(), "free")


func test_lock_hands_the_players_own_controls_back() -> void:
	var scene: Node = await _scene()
	var r := _low_rect(scene)
	var op: Node = scene.operator
	op.input_enabled = true
	_at(scene, Vector2(r.position.x - 0.8, r.get_center().y), Vector2(14, 5))
	check(scene.driver.press(), "locks")
	check(not op.input_enabled, "the driver has the controls")
	scene.driver.press()
	check(op.input_enabled, "and gives them back")
	op.input_enabled = false


func test_with_the_toggle_off_the_key_does_nothing_and_crouch_is_the_plain_one() -> void:
	var scene: Node = await _scene()
	scene._cover_cfg.lock.enabled = 0.0
	var r := _low_rect(scene)
	var op: Node = scene.operator
	var at := Vector2(r.end.x + 0.8, r.get_center().y)
	_at(scene, at, Vector2(r.position.x - 3.0, r.get_center().y))
	check(not scene.driver.press(), "the key does nothing")
	check(not scene.driver.lock.locked(), "not locked")
	op.scripted = {"crouch": true}
	await _run(scene, float(op.model.cfg.crouch.down_s) + 0.05)
	check_eq(scene._eye(), at, "no snap")
	check_eq(scene.body_height(), float(scene._cover_cfg.crouched_torso_m), "crouched torso")
	check(scene.in_cover_now(), "IN COVER as before")
	op.scripted = {"crouch": true, "fire": true}
	await _run(scene, 0.05)
	check(op.rifle.state.mag < int(op.rifle.state.cfg.magazine), "fires from the crouch at once, as in T006")
	check_eq(scene.body_height(), float(scene._cover_cfg.braced_torso_m), "and the shot braces you, as in T006")
	op.scripted = {"crouch": true}
	await _run(scene, float(scene._cover_cfg.brace_hold_s) + 0.05)
	check_eq(scene.body_height(), float(scene._cover_cfg.crouched_torso_m), "for brace_hold_s, as in T006")
	check_eq(scene.run_log.time_locked_s, 0.0, "no locked time")
	scene._cover_cfg.lock.enabled = 1.0
	scene.driver.press()
	check(scene.driver.lock.locked(), "on again, it locks")
	scene._cover_cfg.lock.enabled = 0.0
	await _run(scene, 0.05)
	check(not scene.driver.lock.locked(), "turning it off mid-lock lets go")
	scene._cover_cfg.lock.enabled = 1.0


# --- the deck ---

func test_the_deck_has_cover_on_both_sides_and_everyone_can_get_around() -> void:
	var scene: Node = await _scene()
	var lay: RefCounted = scene.layout
	check_eq(Array(lay.space_order), ["junction", "cargo", "side_corridor"], "the hold and the junction")
	var counts := {"junction_low": 0, "junction_tall": 0, "west_low": 0, "west_tall": 0, "east_low": 0, "east_tall": 0}
	var mid: float = (lay.spaces.cargo.rect as Rect2).get_center().x
	for p: Dictionary in lay.props:
		var c: Vector2 = (p.rect as Rect2).get_center()
		var side: String = "junction" if p.space == "junction" else ("west" if c.x < mid else "east")
		if p.space != "side_corridor" and counts.has("%s_%s" % [side, p.cover]):
			counts["%s_%s" % [side, p.cover]] += 1
	for key: String in counts:
		check(counts[key] >= 1, "%s has some (%d)" % [key, counts[key]])
	var spawn: Vector2 = scene._eye()
	check(lay.space_at(spawn) == "junction", "you start in the junction")
	check(scene.layout.is_free(spawn, scene.operator.body_radius()), "clear of everything")
	var nav: RefCounted = scene.squad.nav
	var door: Node = scene._door("cargo", 0.6)
	check(door != null and door.door_state.blocks(), "the door you come through is shut")
	for p: Node in scene.squad.pirates:
		check_eq(lay.space_at(p.floor_position()), "cargo", "%s is in the hold" % p.label)
		check(nav.is_free(p.floor_position()), "%s starts clear" % p.label)
		check(not nav.path(p.floor_position(), spawn).is_empty(), "%s can reach you" % p.label)
		for q: Vector2 in p.loot:
			check(nav.is_free(q), "%s's crate at %s can be walked to" % [p.label, q])
	for i in lay.props.size():
		for k in range(i + 1, lay.props.size()):
			var o: Rect2 = (lay.props[i].rect as Rect2).intersection(lay.props[k].rect)
			check(o.size.x < 0.001 or o.size.y < 0.001, "props %d and %d overlap" % [i, k])
		for d: Dictionary in lay.doors:
			check(not (lay.props[i].rect as Rect2).intersects(d.rect), "prop %d is in a doorway" % i)


func test_a_pirate_opens_a_shut_door_on_its_way() -> void:
	var scene: Node = await _scene()
	var door: Node = scene._door("cargo", 0.6)
	var c: Vector2 = door.opening.get_center()
	var p: Node = scene.squad.pirates[0]
	_park_others(scene, p)
	_at(scene, Vector2(2.5, 18), Vector2(2.5, 21))
	var inside := c + Vector2(2.0, 0)
	p.global_position = Vector3(inside.x, 0, inside.y)
	var beyond := c + Vector2(-2.0, 0)
	p.brain.spot = {"hide": beyond, "fire": beyond, "kind": "none", "id": -1}
	p.brain.state = p.brain.State.MOVE
	scene.squad.alert(Vector2(2.5, 18))
	check(door.door_state.blocks(), "shut")
	await _run(scene, 3.0)
	check(not door.door_state.blocks(), "it opened it")
	check(p.floor_position().x < c.x + 0.5, "and came through (%.1f)" % p.global_position.x)


func test_respawn_resets_the_squad_the_lock_and_the_doors() -> void:
	var scene: Node = await _scene()
	var r := _low_rect(scene)
	_at(scene, Vector2(r.position.x - 0.8, r.get_center().y), Vector2(14, 5))
	scene.driver.press()
	scene.squad.alert(Vector2(5, 5))
	scene.squad.pirates[0].take_hit({"damage": INF})
	scene._door("cargo", 0.6).interact([])
	await _run(scene, 0.5)
	scene.respawn()
	check(not scene.driver.lock.locked(), "not locked")
	check(not scene.squad.alerted, "nobody's looking for you")
	check(scene.squad.pirates[0].brain.alive(), "the dead get up")
	check(scene._door("cargo", 0.6).door_state.blocks(), "doors shut")
	check_eq(scene.run_log.time_locked_s, 0.0, "a fresh log")


# --- the log ---

func test_the_run_log_has_the_new_fields_and_names_a_pirate() -> void:
	var l := RunLog.new(TEST_DIR)
	l.note_locked(0.5)
	l.note_locked(0.25)
	l.note_shot_blocked_for_you()
	l.note_your_shot_blocked()
	l.note_your_shot_blocked()
	l.note_damage("rifle", 12.0, false)
	l.note_death("Hale", "rifle", "pirate")
	var d := l.to_dict("death")
	check_eq(d.time_locked_s, 0.75, "time locked")
	check_eq(d.shots_blocked_for_you, 1, "their rounds your cover stopped")
	check_eq(d.your_shots_blocked, 2, "your rounds their cover stopped")
	check_eq(d.damage_by_source.rifle, 12.0, "rifle damage")
	check_eq(d.killed_by.pirate, "Hale", "which pirate")
	check_eq(d.killed_by.how, "rifle", "how")
	l.begin()
	check_eq(l.to_dict("respawn").time_locked_s, 0.0, "a new life starts clean")


func test_a_pirate_kill_lands_in_the_log() -> void:
	var scene: Node = await _scene()
	var p: Node = scene.squad.pirates[0]
	scene.squad.player_body.alive = true
	scene.squad.player_body.take_hit({"damage": 999.0, "shooter": p})
	check(scene.suit.dead, "dead")
	check_eq(scene.run_log.killed_by.pirate, p.label, "named")
	check_eq(scene.run_log.killed_by.how, "rifle", "how")
	check(scene.run_log.hits_in_open == 1, "in the open")


func test_every_pirate_slider_points_at_real_data() -> void:
	var seen := {}
	for e: Dictionary in Data.value("debug", "tuning", []):
		if e.has("file"):
			var node: Variant = Data.load_data(String(e.file))
			for part: String in String(e.path).split("."):
				check(node is Dictionary and node.has(part), "%s:%s" % [e.file, e.path])
				node = node[part] if node is Dictionary and node.has(part) else null
			seen[String(e.path)] = true
	for path: String in ["lock.enabled", "weight.turn.standing_deg_s", "rifle.cone.settle_s", "rifle.reload_s", "rifle.recoil.kick_deg", "rifle.damage", "fight.suppress_gap_s"]:
		check(seen.has(path), "%s is on F1" % path)
