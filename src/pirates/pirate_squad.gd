extends Node3D
## The squad and what it shares: where it thinks you are, who does what, paths, the shot trace,
## barks. The scene gives it `target` each step and wires its signals to the suit and the run log.

const Pirate := preload("res://src/pirates/pirate.gd")
const PirateBrain := preload("res://src/pirates/pirate_brain.gd")
const Tactics := preload("res://src/pirates/squad_tactics.gd")
const CoverSpots := preload("res://src/pirates/cover_spots.gd")
const PlayerTarget := preload("res://src/pirates/player_target.gd")
const StalkerNav := preload("res://src/enemies/stalker_nav.gd")
const StalkerBrain := preload("res://src/enemies/stalker_brain.gd")
const ShotTracer := preload("res://src/cover/shot_tracer.gd")
const PlaceholderSound := preload("res://src/enemies/placeholder_sound.gd")

## Someone in the squad said something. Tests and the log listen; the labels are its own.
signal barked(pirate: Node3D, key: String, line: String)

var cfg: Dictionary
var nav: StalkerNav
var cover: RefCounted
var spots: CoverSpots
var pirates: Array = []
var doors: Array = []
var tracer: ShotTracer
var player_body := PlayerTarget.new()
## {pos: Vector2, height: float, alive: bool}: the player, set by the scene before each tick.
var target := {"pos": Vector2.ZERO, "height": 0.0, "alive": true}
var plan_blocked := Callable()
var light_on := func(_p: Vector2) -> bool: return false
var visibility: RefCounted
var mask_texture: Texture2D
var mask_bounds := Rect2()

var alerted := false
var last_known := Vector2.ZERO
var contact_age := INF         # seconds since anyone actually saw the player
var shots_fired_at_cover := 0  # rounds a suppressor let go while it couldn't see the player

var _roles := {}
var _trail: Array = []
var _retask_left := 0.0
var _sprint_left := 0.0
var _bark_ready := {}
var _labels := {}
var _bark_left := {}
var _rng := RandomNumberGenerator.new()
var _shot_sound: AudioStreamPlayer3D
var _reflank_left := {}
var _covering_fire := false    # the suppressor has opened up; the flanker goes on that
var _flank_wait_left := 0.0


func setup(layout: RefCounted, cover_field: RefCounted, blocked: Callable, sight_visibility: RefCounted,
		door_nodes: Array, world: World3D, character_scale: float) -> void:
	cfg = Data.load_data("pirates")
	cover = cover_field
	plan_blocked = blocked
	visibility = sight_visibility
	doors = door_nodes
	_rng.randomize()
	var radius := float(cfg.radius_m) * character_scale
	var nav_cfg := {"radius_m": radius, "nav": cfg.nav, "stalk": cfg.stalk}
	nav = StalkerNav.new(nav_cfg, layout)
	for d: Node in doors:
		if d.door_state.is_locked():
			nav.set_blocker(d, d.opening)
	var free := func(p: Vector2) -> bool: return nav.is_free(p)
	spots = CoverSpots.new(cfg.spots, cover, layout.props, radius, float(cfg.aim_height_m), free, blocked, nav.path)
	for entry: Dictionary in cfg.squad:
		var p := Pirate.new()
		p.name = "Pirate%d" % (pirates.size() + 1)
		add_child(p)
		var loot: Array = []
		for at: Array in entry.loot:
			loot.append(layout.point_in(String(entry.space), at))
		p.setup(cfg, entry, layout.point_in(String(entry.space), entry.at), loot, character_scale)
		p.was_shot.connect(_on_pirate_shot)
		pirates.append(p)
		var l := Label3D.new()
		l.name = "Bark%d" % pirates.size()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.pixel_size = float(cfg.barks.pixel_size)
		l.font_size = int(cfg.barks.font_size)
		l.outline_size = int(cfg.barks.outline_px)
		l.modulate = Color(String(cfg.barks.color))
		l.visible = false
		add_child(l)
		_labels[p] = l
		_bark_left[p] = 0.0
	# They shoulder past each other: one dug in on a lane must not stop a flanker dead.
	for p: Node in pirates:
		for q: Node in pirates:
			if p != q:
				p.add_collision_exception_with(q)
	tracer = ShotTracer.new(cover, world)
	tracer.bodies = [player_body]
	_shot_sound = AudioStreamPlayer3D.new()
	_shot_sound.name = "ShotSound"
	_shot_sound.stream = PlaceholderSound.make(cfg.sound.shot, int(cfg.sound.mix_rate))
	_shot_sound.volume_db = float(cfg.sound.shot.volume_db)
	_shot_sound.unit_size = float(cfg.sound.unit_size_m)
	_shot_sound.max_polyphony = pirates.size() * 2
	add_child(_shot_sound)


func reset() -> void:
	alerted = false
	last_known = Vector2.ZERO
	contact_age = INF
	shots_fired_at_cover = 0
	_roles = {}
	_trail = []
	_retask_left = 0.0
	_bark_ready = {}
	_reflank_left = {}
	_covering_fire = false
	_flank_wait_left = 0.0
	for p: Node in pirates:
		p.reset()
		p.remove_meta("flanking")
		_labels[p].visible = false
		_bark_left[p] = 0.0


func set_mask(texture: Texture2D, bounds: Rect2) -> void:
	for p: Node in pirates:
		p.light.set_mask(texture, bounds)


func living() -> Array:
	return pirates.filter(func(p: Node) -> bool: return p.brain.alive())


func with_role(role: int) -> Node:
	for p: Node in living():
		if p.brain.role == role:
			return p
	return null


## Everyone knows where you are, right now.
func alert(at: Vector2) -> void:
	last_known = at
	contact_age = 0.0
	if not alerted:
		_start_fight()


func _start_fight() -> void:
	alerted = true
	_retask_left = 0.0
	_covering_fire = false
	_flank_wait_left = float(cfg.fight.flank_wait_s)


## A noise anyone may hear ("gunfire", "sprint"). It tells them where to look, not that they saw you.
func noise(kind: String, at: Vector2) -> void:
	for p: Node in living():
		if p.floor_position().distance_to(at) <= float(cfg.senses[kind + "_m"]):
			if not alerted:
				say(p, "noise")
			last_known = at
			contact_age = 0.0
			if not alerted:
				_start_fight()
			return


## A round went by close enough to notice, or hit someone.
func shot_at(from: Vector2, to: Vector2) -> void:
	var near := float(cfg.senses.shot_line_m)
	for p: Node in living():
		var at: Vector2 = p.floor_position()
		if at.distance_to(Geometry2D.get_closest_point_to_segment(at, from, to)) <= near:
			alert(from)
			return


func _on_pirate_shot(pirate: Node3D, _damage: float, from: Vector2) -> void:
	alert(from)
	if not pirate.brain.alive():
		for p: Node in living():
			say(p, "down")
			break


## What one pirate knows right now.
func senses_for(p: Node) -> Dictionary:
	var pos: Vector2 = p.floor_position()
	var player: Vector2 = target.pos
	var sees := _sees(p, pos, player)
	var aim := _aim_point(p, pos, player, sees)
	return {
		"pos": pos,
		"next_point": pos,
		"aim": aim,
		"sees": sees,
		"can_engage": alerted and bool(target.alive) and _can_engage(p, aim),
	}


func _torso(p: Node) -> float:
	return cover.torso_height(p.brain.model.crouch_amount, p.brain.exposed())


func _sees(p: Node, pos: Vector2, player: Vector2) -> bool:
	if not bool(target.alive):
		return false
	var blocked: bool = plan_blocked.call(pos, player)
	var eye := Vector3(pos.x, _torso(p), pos.y)
	var body := Vector3(player.x, float(target.height), player.y)
	return StalkerBrain.perceives(cfg, pos, p.brain.model.torso_yaw, player, blocked, cover.line_blocked(eye, body))


## Eyes and hands lag a moment behind where you are; it never knows better than it could see.
func _aim_point(p: Node, pos: Vector2, player: Vector2, sees: bool) -> Vector2:
	if not alerted:
		return pos
	if sees and not _trail.is_empty():
		var t: Array = _trail[0]
		return t[1]
	if last_known == Vector2.ZERO:
		return player
	return last_known


func _can_engage(p: Node, aim: Vector2) -> bool:
	var spot: Dictionary = p.brain.spot
	if spot.is_empty():
		return false
	var fire: Vector2 = spot.fire
	if _friend_on_line(p, fire, aim):
		return false
	match p.brain.role:
		Tactics.Role.SUPPRESS:
			return contact_age <= float(cfg.fight.suppress_memory_s) and not plan_blocked.call(fire, aim)
		_:
			return spots.open_line(fire, target.pos, float(target.height))


func _friend_on_line(p: Node, from: Vector2, to: Vector2) -> bool:
	var clear := float(cfg.fight.friend_clear_m)
	for q: Node in living():
		if q == p:
			continue
		var at: Vector2 = q.floor_position()
		if at.distance_to(Geometry2D.get_closest_point_to_segment(at, from, to)) < clear:
			return true
	return false


## One step of everything.
func tick(delta: float) -> void:
	_track(delta)
	player_body.center = target.pos
	player_body.height = float(target.height)
	player_body.alive = bool(target.alive)
	if not bool(target.alive) and alerted:
		_stand_down("clear")
	var lost_for := contact_age
	if alerted and lost_for > float(cfg.senses.stand_down_s):
		_stand_down("lost")
	if alerted:
		_retask(delta)
	for p: Node in pirates:
		p.torso_height = _torso(p)
		for ev: String in p.simulate(delta, self):
			_handle(ev, p)
		_open_door_for(p)
		_step_light(delta, p)
	_step_barks(delta)


func _track(delta: float) -> void:
	contact_age += delta
	_sprint_left -= delta
	_trail.append([0.0, target.pos])
	for t: Array in _trail:
		t[0] += delta
	var keep := float(cfg.senses.reaction_s)
	while _trail.size() > 1 and _trail[1][0] >= keep:
		_trail.pop_front()
	if not bool(target.alive):
		return
	for p: Node in living():
		if p.brain.alive() and (_sees(p, p.floor_position(), target.pos) or light_on.call(p.floor_position())):
			if not alerted:
				say(p, "contact")
			alert(target.pos)
			return


func _stand_down(line: String) -> void:
	alerted = false
	var first := true
	for p: Node in living():
		if first:
			say(p, line)
			first = false
		p.brain.stand_down()
		p.remove_meta("flanking")
	_roles = {}


## Who does what, and where. Slots are only looked for now and then: they cost.
func _retask(delta: float) -> void:
	_retask_left -= delta
	if _retask_left > 0.0:
		return
	_flank_wait_left -= float(cfg.fight.retask_s)
	_retask_left = float(cfg.fight.retask_s)
	var members: Array = []
	for p: Node in living():
		var b: PirateBrain = p.brain
		members.append({"id": p, "pos": p.floor_position(), "reloading": b.gun.reloading(), "hurt": b.hurt()})
	var was := _roles
	_roles = Tactics.assign(members, last_known, was)
	var crouched := float(cover.cfg.crouched_torso_m)
	for p: Node in living():
		var b: PirateBrain = p.brain
		var role: int = _roles[p]
		if role == Tactics.Role.SUPPRESS and was.get(p, Tactics.Role.NONE) != role:
			say(p, "suppress")
		var taken := _taken_by_others(p)
		if b.wants_fall_back():
			var back := spots.best_cover(last_known, crouched, p.floor_position(), taken, true)
			b.fell_back = true
			say(p, "hurt")
			b.order(role, back)
			continue
		if role == Tactics.Role.FLANK and (_covering_fire or _flank_wait_left <= 0.0):
			_task_flanker(p, was, taken, crouched)
		elif b.spot.is_empty() or (b.dug_in() and not spots.hides(b.spot, last_known, crouched)):
			var slot := spots.best_cover(last_known, crouched, p.floor_position(), taken)
			if slot.is_empty():
				slot = spots.fire_spot(last_known, p.floor_position(), taken)
			b.order(role, slot)
		else:
			b.order(role, {})


func _task_flanker(p: Node, was: Dictionary, taken: Array, crouched: float) -> void:
	var b: PirateBrain = p.brain
	var fresh: bool = was.get(p, Tactics.Role.NONE) != Tactics.Role.FLANK or not p.has_meta("flanking")
	p.set_meta("flanking", true)
	var left: float = float(_reflank_left.get(p, 0.0)) - float(cfg.fight.retask_s)
	_reflank_left[p] = left
	var closed: bool = b.dug_in() and not b.spot.is_empty() and not spots.open_line(b.spot.fire, last_known, crouched)
	if not fresh and not b.spot.is_empty() and not (closed and left <= 0.0):
		b.order(Tactics.Role.FLANK, {})
		return
	var anchor := last_known + Vector2.RIGHT
	var sup := _member_with(Tactics.Role.SUPPRESS)
	if sup:
		anchor = sup.floor_position()
	var spot := spots.flank_spot(last_known, crouched, p.floor_position(), anchor, taken)
	_reflank_left[p] = float(cfg.fight.reflank_s)
	if spot.is_empty():
		spot = spots.fire_spot(last_known, p.floor_position(), taken)
	else:
		say(p, "flank")
	b.order(Tactics.Role.FLANK, spot)


func _member_with(role: int) -> Node:
	for p: Node in _roles:
		if _roles[p] == role and is_instance_valid(p) and p.brain.alive():
			return p
	return null


func _taken_by_others(p: Node) -> Array:
	var out: Array = []
	for q: Node in living():
		if q != p:
			out.append(q.brain.spot.hide if not q.brain.spot.is_empty() else q.floor_position())
	return out


func _handle(ev: String, p: Node) -> void:
	match ev:
		PirateBrain.EV_SHOT:
			_fire(p)
		PirateBrain.EV_RELOAD:
			say(p, "reload")


## The real 3D trace, the same one the player's rounds use, inside the real cone.
func _fire(p: Node) -> void:
	var b: PirateBrain = p.brain
	if b.role == Tactics.Role.SUPPRESS:
		_covering_fire = true
	var yaw: float = b.gun.shot_yaw(b.gun_yaw(), b.cone.spread_deg)
	var dir := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var origin: Vector3 = p.shot_origin()
	var length := float(cfg.rifle.range_m)
	var hit: Dictionary = tracer.trace(origin, dir, length)
	var to: Vector3 = origin + dir * length
	if not hit.is_empty():
		to = hit.position
		var body: Object = hit.collider
		if body != null and body.has_method("take_hit"):
			body.take_hit({"point": to, "direction": dir, "damage": float(cfg.rifle.damage), "origin": origin, "shooter": p})
		p.fx.impact(to)
	p.fx.shot(p.muzzle_position(), to)
	if not _sees(p, p.floor_position(), target.pos):
		shots_fired_at_cover += 1
	_shot_sound.global_position = origin
	_shot_sound.play()


## Humans use doors. A shut, unlocked one on the way gets opened.
func _open_door_for(p: Node) -> void:
	if not p.brain.wants_move or p.path.is_empty():
		return
	var reach := float(cfg.fight.door_open_m)
	var pos: Vector2 = p.floor_position()
	for d: Node in doors:
		if not d.door_state.blocks() or d.door_state.is_locked():
			continue
		if pos.distance_to(d.opening.get_center()) > reach:
			continue
		var grown: Rect2 = d.opening.grow(float(cfg.nav.cell_m))
		for q: Vector2 in p.path:
			if grown.has_point(q):
				d.interact([])
				break


func _step_light(delta: float, p: Node) -> void:
	if not p.brain.alive():
		return
	var yaw: float = p.brain.gun_yaw()
	var muzzle: Vector3 = p.muzzle_position()
	p.light.follow(muzzle, yaw)
	p.light.draw_beam(delta, visibility, p.floor_position(), yaw, muzzle)


## Text over the head, placeholder for a voice. A voice carries, so it shows even when the one
## saying it can't be seen: being heard is the point of a bark, and the price of calling a flank.
func say(p: Node, key: String) -> void:
	var now := float(_bark_ready.get(key, 0.0))
	if now > 0.0:
		return
	_bark_ready[key] = float(cfg.barks.cooldown_s)
	var lines: Array = cfg.barks.lines[key]
	var line := String(lines[_rng.randi_range(0, lines.size() - 1)])
	var l: Label3D = _labels[p]
	l.text = line
	l.visible = true
	_bark_left[p] = float(cfg.barks.life_s)
	barked.emit(p, key, line)


func hide_barks() -> void:
	for p: Node in pirates:
		_labels[p].visible = false


func _step_barks(delta: float) -> void:
	for key: String in _bark_ready:
		_bark_ready[key] = float(_bark_ready[key]) - delta
	for p: Node in pirates:
		var l: Label3D = _labels[p]
		if not l.visible:
			continue
		_bark_left[p] = float(_bark_left[p]) - delta
		l.visible = float(_bark_left[p]) > 0.0
		l.global_position = p.global_position + Vector3.UP * float(cfg.barks.height_m)


## Per pirate that's after you with nothing tall between: true when cover stops what it would fire.
func shooter_lines() -> Array:
	var out: Array = []
	if not alerted:
		return out
	var body := Vector3(float(target.pos.x), float(target.height), float(target.pos.y))
	for p: Node in living():
		if plan_blocked.call(p.floor_position(), target.pos):
			continue
		out.append(cover.line_blocked(p.shot_origin(), body))
	return out
