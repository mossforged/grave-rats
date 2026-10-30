extends Node3D
## The deck's stalkers and what they share: paths, senses from the sight and cover modules, noise,
## spits and puddles. The scene gives it `target` each step and wires its signals to the suit.

const Stalker := preload("res://src/enemies/stalker.gd")
const StalkerBrain := preload("res://src/enemies/stalker_brain.gd")
const StalkerNav := preload("res://src/enemies/stalker_nav.gd")
const SpitSystem := preload("res://src/enemies/spit_system.gd")
const SpitArc := preload("res://src/enemies/spit_arc.gd")
const PlaceholderSound := preload("res://src/enemies/placeholder_sound.gd")

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

var _sounds := {}


func setup(layout: RefCounted, cover_field: RefCounted, blocked: Callable, acid_dps: float) -> void:
	var all: Dictionary = Data.load_data("enemies")
	cfg = all.stalker
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
	var mix := int(all.sound.mix_rate)
	for key: String in ["bang", "spit", "lunge"]:
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
	for s: Node in stalkers:
		s.reset()


## A noise anyone may hear ("gunfire", "sprint").
func noise(kind: String, at: Vector2) -> void:
	for s: Node in stalkers:
		s.brain.hear(kind, at, s.floor_position())


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
	}


func next_stalk_point(s: Node) -> Vector2:
	var player: Vector2 = s.brain.last_known
	var hidden := func(p: Vector2) -> bool: return plan_blocked.call(player, p)
	return nav.stalk_point(s.floor_position(), player, s.side, hidden)


## One step of everything.
func tick(delta: float) -> void:
	var body := target_body()
	for s: Node in stalkers:
		for ev: String in s.simulate(delta, self):
			_handle(ev, s, body)
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
		StalkerBrain.EV_LUNGE_HIT:
			player_hit.emit("lunge", float(cfg.lunge.damage), s, in_cover_from(s))


func _on_glob_ended(result: String, shooter: Node3D, at: Vector3) -> void:
	if result == SpitArc.HIT:
		player_hit.emit("spit", float(cfg.spit.damage), shooter, in_cover_from(shooter))
	elif result == SpitArc.COVER and Vector2(at.x, at.z).distance_to(target.pos) <= float(cfg.lunge.range_m):
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
