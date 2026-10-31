extends Node3D
## The deck's stalkers and what they share: paths, senses from the sight and cover modules, noise,
## spits and puddles. The scene gives it `target` each step and wires its signals to the suit.

const Stalker := preload("res://src/enemies/stalker.gd")
const StalkerBrain := preload("res://src/enemies/stalker_brain.gd")
const StalkerNav := preload("res://src/enemies/stalker_nav.gd")
const SpitSystem := preload("res://src/enemies/spit_system.gd")
const SpitArc := preload("res://src/enemies/spit_arc.gd")
const PlaceholderSound := preload("res://src/enemies/placeholder_sound.gd")
const SpawnPicker := preload("res://src/enemies/spawn_picker.gd")

## Something reached the player. `in_cover`: cover stood on the straight line from the thrower.
signal player_hit(source: String, amount: float, stalker: Node3D, in_cover: bool)
## Cover stopped a glob aimed at the player.
signal player_protected(stalker: Node3D)

var cfg: Dictionary        # data/enemies.json "stalker"
var nav: StalkerNav
var cover: RefCounted
var stalkers: Array = []
var spits: SpitSystem
## {pos: Vector2, height: float, alive: bool}: the player, set by the scene before each tick.
var target := {"pos": Vector2.ZERO, "height": 0.0, "alive": true}
## (a: Vector2, b: Vector2) -> bool: walls, shut doors and tall cover on the floor plan.
var plan_blocked := Callable()
## (p: Vector2) -> bool: the player's light is on this point. The scene sets it.
var light_on := func(_p: Vector2) -> bool: return false

var _sounds := {}
var _layout: RefCounted
var _spawn_points: Array = []
var _spawn_specs: Array = []
var _spawn_used: Array = []
var _spawn_cfg: Dictionary
var _base_count := 0


func setup(layout: RefCounted, cover_field: RefCounted, blocked: Callable, acid_dps: float) -> void:
	var all: Dictionary = Data.load_data("enemies")
	cfg = all.stalker
	_layout = layout
	_spawn_cfg = all.spawning
	_spawn_specs = all.spawn_points
	for spec: Dictionary in _spawn_specs:
		_spawn_points.append(layout.point_in(String(spec.space), spec.at))
	cover = cover_field
	plan_blocked = blocked
	nav = StalkerNav.new(cfg, layout)
	spits = SpitSystem.new()
	spits.name = "Spits"
	add_child(spits)
	spits.setup(cfg, acid_dps, cover, blocked)
	spits.glob_ended.connect(_on_glob_ended)
	var side := 1.0
	for entry: Dictionary in all.pack:
		var s := Stalker.new()
		s.name = "Stalker%d" % (stalkers.size() + 1)
		add_child(s)
		var patrol: Array = []
		for at: Array in entry.patrol:
			patrol.append(layout.point_in(String(entry.space), at))
		s.setup(cfg, entry, layout.point_in(String(entry.space), entry.at), patrol, side)
		side = -side
		stalkers.append(s)
	_base_count = stalkers.size()
	var mix := int(all.sound.mix_rate)
	for key: String in ["bang", "spit", "lunge", "bash"]:
		var p := AudioStreamPlayer3D.new()
		p.name = key.capitalize()
		p.stream = PlaceholderSound.make(all.sound[key], mix)
		p.volume_db = float(all.sound[key].volume_db)
		p.unit_size = float(all.sound.unit_size_m)
		add_child(p)
		_sounds[key] = p


func play_sound(key: String, at: Vector3) -> void:
	var p: AudioStreamPlayer3D = _sounds[key]
	p.global_position = at
	p.play()


func reset() -> void:
	spits.clear()
	# In place: the shot tracer holds this same array.
	while stalkers.size() > _base_count:
		var extra: Node = stalkers.pop_back()
		remove_child(extra)
		extra.queue_free()
	_spawn_used = []
	for s: Node in stalkers:
		s.reset()


## Another one wakes, at a spawn point (`spawn_points` in data) nobody can see: `viewers` holds one
## (p: Vector2) -> bool per player, `players` where they are. Null when nowhere will do yet; ask
## again after `spawning.retry_s`.
func spawn_out_of_view(viewers: Array, players: Array, rng: RandomNumberGenerator) -> Node3D:
	var i := SpawnPicker.pick(_spawn_points, viewers, players, _spawn_used, float(_spawn_cfg.min_player_m), rng)
	if i < 0:
		return null
	_spawn_used.append(i)
	var entry: Dictionary = _spawn_specs[i]
	var s := Stalker.new()
	s.name = "Stalker%d" % (stalkers.size() + 1)
	add_child(s)
	var patrol: Array = []
	for at: Array in entry.patrol:
		patrol.append(_layout.point_in(String(entry.space), at))
	s.setup(cfg, entry, _spawn_points[i], patrol, 1.0 if stalkers.size() % 2 == 0 else -1.0)
	s.brain.rng.seed = rng.randi()
	stalkers.append(s)
	return s


func spawn_points() -> Array:
	return _spawn_points


## Everyone's told where you are: the prize alarm.
func alert(at: Vector2) -> void:
	for s: Node in stalkers:
		s.brain.alert(at)


## A round went from `from` to `to`: whoever it passed close to tries to get out of the line.
func shot_at(from: Vector2, to: Vector2) -> void:
	var near := float(cfg.dodge.shot_line_m)
	for s: Node in stalkers:
		var at: Vector2 = s.floor_position()
		# With no open way to whoever fired, the round stopped on the far side of a shut door.
		if at.distance_to(Geometry2D.get_closest_point_to_segment(at, from, to)) <= near and not nav.path(at, from).is_empty():
			s.brain.notice_shot(from)


## A noise anyone may hear ("gunfire", "sprint", "walk", "crouch"). With no open way to it, it's
## coming through a shut door, and carries less.
func noise(kind: String, at: Vector2) -> void:
	for s: Node in stalkers:
		var pos: Vector2 = s.floor_position()
		if pos.distance_to(at) <= StalkerBrain.hearing_radius(cfg, kind):
			s.brain.hear(kind, at, pos, nav.path(pos, at).is_empty())


func target_body() -> Vector3:
	var p: Vector2 = target.pos
	return Vector3(p.x, float(target.height), p.y)


## What one stalker knows right now.
func senses_for(s: Node) -> Dictionary:
	var pos: Vector2 = s.floor_position()
	var player: Vector2 = target.pos
	var body := target_body()
	var blocked_to_player: bool = plan_blocked.call(pos, player)
	var sees := StalkerBrain.perceives(cfg, pos, s.brain.yaw, player, blocked_to_player,
			cover.line_blocked(s.mouth(), body))
	var probe := float(cfg.lunge.probe_height_m)
	var ground_clear: bool = not blocked_to_player and not cover.line_blocked(
			Vector3(pos.x, probe, pos.y), Vector3(player.x, probe, player.y))
	return {
		"pos": pos,
		"player": player,
		"alive": bool(target.alive),
		"sees": sees,
		"clear": not plan_blocked.call(pos, s.brain.last_known),
		"ground_clear": ground_clear,
		"next_point": pos,
		"stalk_point": pos,
		"lit": s.brain.state != StalkerBrain.State.DORMANT and light_on.call(pos),
		"dodge_point": pos,
		"door_ahead": false,
		"door_at": pos,
		"door_face": pos,
		"at_door": false,
	}


func next_stalk_point(s: Node) -> Vector2:
	var player: Vector2 = s.brain.last_known
	var hidden := func(p: Vector2) -> bool: return plan_blocked.call(player, p)
	return nav.stalk_point(s.floor_position(), player, s.side, hidden, s.brain.backing_off())


func next_dodge_point(s: Node) -> Vector2:
	var player: Vector2 = s.brain.last_known
	var hidden := func(p: Vector2) -> bool: return plan_blocked.call(player, p)
	return nav.dodge_point(s.floor_position(), player, s.side, hidden)


## The shut door that's all that stands between this stalker and where it thinks you are, or null.
func door_towards(s: Node) -> Node3D:
	var pos: Vector2 = s.floor_position()
	if not nav.path(pos, s.brain.last_known).is_empty():
		return null
	return nav.door_on_way(pos, s.brain.last_known)


## One step of everything.
func tick(delta: float) -> void:
	var body := target_body()
	var worked_on := {}
	for s: Node in stalkers:
		for ev: String in s.simulate(delta, self):
			_handle(ev, s, body)
		if s.brain.bashing and s.door != null:
			worked_on[s.door] = s
	# Two on one door don't break it any sooner.
	for d: Node3D in worked_on:
		d.bash(delta, worked_on[d].floor_position())
	spits.tick(delta, body)


func _handle(ev: String, s: Node, body: Vector3) -> void:
	match ev:
		StalkerBrain.EV_SPIT:
			var at: Vector2 = s.brain.last_known
			var height := body.y if at.distance_to(target.pos) <= float(cfg.spit.hit_radius_m) else float(cfg.torso_m)
			spits.spit(s, Vector3(at.x, height, at.y))
			play_sound("spit", s.mouth())
		StalkerBrain.EV_LUNGE_START:
			play_sound("lunge", s.global_position)
		StalkerBrain.EV_BANG:
			if s.door != null:
				s.door.bang()
				play_sound("bash", s.door.global_position)
		StalkerBrain.EV_LUNGE_HIT:
			player_hit.emit("lunge", float(cfg.lunge.damage), s, in_cover_from(s))


func _on_glob_ended(result: String, shooter: Node3D, aimed_at: Vector3) -> void:
	if result == SpitArc.HIT:
		player_hit.emit("spit", float(cfg.spit.damage), shooter, in_cover_from(shooter))
	elif result == SpitArc.COVER and Vector2(aimed_at.x, aimed_at.z).distance_to(target.pos) <= float(cfg.spit.protect_radius_m):
		player_protected.emit(shooter)


## Cover on the straight line from this thrower to the player's torso.
func in_cover_from(s: Node) -> bool:
	return cover.line_blocked(s.mouth(), target_body())


## Per stalker hunting the player with nothing tall between them: true when cover stops its arc.
func shooter_lines() -> Array:
	var out: Array = []
	var body := target_body()
	for s: Node in stalkers:
		if not s.brain.hunting() or plan_blocked.call(s.floor_position(), target.pos):
			continue
		out.append(SpitArc.blocked_by_cover(cfg.spit, cover, s.mouth(), body))
	return out
