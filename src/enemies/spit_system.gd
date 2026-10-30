extends Node3D
## Globs in flight and the puddles they leave. SpitArc and PuddleField do the rules; this draws
## them, in opaque materials only, so the sight mask hides them like anything else on the floor.

const SpitArc := preload("res://src/enemies/spit_arc.gd")
const PuddleField := preload("res://src/health/puddle_field.gd")

signal glob_ended(result: String, shooter: Node3D, at: Vector3)

var cfg: Dictionary  # data/enemies.json "stalker"
var puddles: PuddleField
var cover: RefCounted
var plan_blocked: Callable

var _globs: Array = []    # {arc, shooter, mesh}
var _discs: Dictionary = {}  # puddle Dictionary -> MeshInstance3D
var _glob_mesh: SphereMesh
var _disc_mesh: CylinderMesh


func setup(config: Dictionary, dps: float, cover_field: RefCounted, blocked: Callable) -> void:
	cfg = config
	cover = cover_field
	plan_blocked = blocked
	puddles = PuddleField.new(dps)
	var s: Dictionary = cfg.spit
	_glob_mesh = SphereMesh.new()
	_glob_mesh.radius = float(s.glob_radius_m)
	_glob_mesh.height = float(s.glob_radius_m) * 2.0
	_glob_mesh.material = _glowing(String(s.glob_color), float(s.glob_energy))
	var p: Dictionary = cfg.puddle
	_disc_mesh = CylinderMesh.new()
	_disc_mesh.top_radius = float(p.radius_m)
	_disc_mesh.bottom_radius = float(p.radius_m)
	_disc_mesh.height = float(p.height_m)
	_disc_mesh.material = _glowing(String(p.color), float(p.energy))


func _glowing(hex: String, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(hex)
	m.emission_enabled = true
	m.emission = Color(hex)
	m.emission_energy_multiplier = energy
	return m


func spit(shooter: Node3D, target: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Glob"
	mi.mesh = _glob_mesh
	add_child(mi)
	var arc := SpitArc.new(cfg.spit, shooter.mouth(), target)
	mi.global_position = arc.position
	_globs.append({"arc": arc, "shooter": shooter, "mesh": mi})


func tick(delta: float, body: Vector3) -> void:
	var still: Array = []
	for g: Dictionary in _globs:
		var result: String = g.arc.step(delta, cover, plan_blocked, body)
		(g.mesh as Node3D).global_position = g.arc.position
		if result == SpitArc.FLYING:
			still.append(g)
			continue
		(g.mesh as Node).queue_free()
		_end_glob(g, result)
	_globs = still
	puddles.step(delta)
	_sync_discs()


func _end_glob(g: Dictionary, result: String) -> void:
	var arc: SpitArc = g.arc
	var at := Vector2(arc.position.x, arc.position.z)
	var p: Dictionary = cfg.puddle
	if result == SpitArc.COVER or result == SpitArc.WALL:
		# The splash stays on the thrower's side of what stopped it.
		var back := Vector2(arc.from.x, arc.from.z) - at
		at += back.normalized() * float(p.blocked_back_m)
	add_puddle(at, String(g.shooter.label))
	glob_ended.emit(result, g.shooter, arc.position)


func add_puddle(at: Vector2, owner_name: String) -> void:
	var p: Dictionary = cfg.puddle
	puddles.add(at, float(p.radius_m), float(p.life_s), owner_name, int(p.max_count))
	_sync_discs()


func _sync_discs() -> void:
	var live := {}
	var from := float(cfg.puddle.shrink_from)
	for q: Dictionary in puddles.puddles:
		live[q] = true
		if not _discs.has(q):
			var mi := MeshInstance3D.new()
			mi.name = "Puddle"
			mi.mesh = _disc_mesh
			add_child(mi)
			var at: Vector2 = q.at
			mi.global_position = Vector3(at.x, float(cfg.puddle.height_m) * 0.5, at.y)
			_discs[q] = mi
		var left := float(q.left) / float(q.life)
		var f := clampf(left / from, 0.0, 1.0)
		(_discs[q] as Node3D).scale = Vector3(f, 1.0, f)
	for q: Dictionary in _discs.keys():
		if not live.has(q):
			(_discs[q] as Node).queue_free()
			_discs.erase(q)


func clear() -> void:
	for g: Dictionary in _globs:
		(g.mesh as Node).queue_free()
	_globs.clear()
	puddles.clear()
	_sync_discs()


func glob_count() -> int:
	return _globs.size()
