extends Node3D
## The sealed panel that fills a DeckLayout breach: looks like wall, stops bodies and sight until
## it bursts, then it's gone and debris (plain cubes) flies out. Numbers: data/enemies.json "ambush".
## Sight contract (src/sight): group "sight_occluder", sight_rect(), blocks_sight().

const KitPieces := preload("res://src/kit/kit_pieces.gd")
const KitMaterials := preload("res://src/kit/kit_materials.gd")
const BEACON := preload("res://src/sight/beacon.gdshader")
const CUTAWAY_GROUP := &"camera_cutaway"
const OCCLUDER_GROUP := &"sight_occluder"

signal burst

var cfg: Dictionary
var rect := Rect2()
var out_dir := Vector2.ZERO
var sealed := true

var _tell: MeshInstance3D
var _tell_mat: ShaderMaterial
var _pivot: Node3D
var _body: StaticBody3D
var _shape: CollisionShape3D
var _debris: Array = []  # {node, vel, spin}
var _mats: Array[StandardMaterial3D] = []
var _rng := RandomNumberGenerator.new()


## `breach` is one entry of DeckLayout.breaches; debris flies toward the open side (out of `space`).
func setup(breach: Dictionary, config: Dictionary, wall_height: float) -> void:
	cfg = config
	rect = breach.rect
	name = "Bulkhead"
	match String(breach.side):
		"east": out_dir = Vector2.RIGHT
		"west": out_dir = Vector2.LEFT
		"north": out_dir = Vector2.UP
		_: out_dir = Vector2.DOWN
	add_to_group(OCCLUDER_GROUP)
	var c := rect.get_center()
	_pivot = Node3D.new()
	_pivot.name = "Panel"
	_pivot.set_meta("cutaway_rect", rect)
	_pivot.set_meta("cutaway_height", wall_height)
	_pivot.add_to_group(CUTAWAY_GROUP)
	add_child(_pivot)
	_pivot.global_position = Vector3(c.x, 0.0, c.y)
	# The kit's own wall, so only the tell gives the ambush away.
	var long_x := rect.size.x >= rect.size.y
	var length := rect.size.x if long_x else rect.size.y
	var depth := rect.size.y if long_x else rect.size.x
	var post := float(KitMaterials.cfg().dims.bulkhead_post_m)
	var mi := MeshInstance3D.new()
	mi.mesh = KitPieces.wall(length, depth, wall_height, "corridor", "corridor", post, post, 0)
	if not long_x:
		mi.rotation.y = -PI * 0.5
	_pivot.add_child(mi)
	_make_tell(c, long_x, length, depth)
	_body = StaticBody3D.new()
	_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(rect.size.x, wall_height, rect.size.y)
	_shape.shape = box
	_body.add_child(_shape)
	add_child(_body)
	_body.global_position = Vector3(c.x, wall_height * 0.5, c.y)
	var d: Dictionary = cfg.debris
	for hex: String in [String(d.color), String(d.hot_color)]:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(hex)
		_mats.append(m)


## A hairline of warm light along the panel's foot on the open side (T011, the fairness rule): a seam that
## isn't quite shut, for the player who remembers seeing it. A look, not a rule.
func _make_tell(c: Vector2, long_x: bool, length: float, depth: float) -> void:
	var t: Dictionary = cfg.tell
	_tell_mat = ShaderMaterial.new()
	_tell_mat.shader = BEACON
	_tell_mat.set_shader_parameter("beacon_color", Color(String(t.color)))
	_tell_mat.set_shader_parameter("energy", float(t.energy))
	var box := BoxMesh.new()
	var along := length * float(t.length_frac)
	box.size = Vector3(along, float(t.height_m), float(t.width_m)) if long_x else Vector3(float(t.width_m), float(t.height_m), along)
	_tell = MeshInstance3D.new()
	_tell.name = "Tell"
	_tell.mesh = box
	_tell.material_override = _tell_mat
	_tell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_tell)
	var at := c + out_dir * (depth * 0.5 + float(t.out_m))
	_tell.global_position = Vector3(at.x, float(t.height_m) * 0.5, at.y)


## `bind` is SightMask.bind: the tell shows only once the player's seen this stretch of wall.
func use_mask(bind: Callable) -> void:
	bind.call(_tell_mat)
	_tell_mat.set_shader_parameter("masked", true)


func tell_visible() -> bool:
	return _tell.visible


func blocks_sight() -> bool:
	return sealed


func sight_rect() -> Rect2:
	return rect


func panel_center() -> Vector2:
	return rect.get_center()


## Blows it out. Does nothing the second time.
func blow() -> void:
	if not sealed:
		return
	sealed = false
	_pivot.visible = false
	_tell.visible = false
	_shape.set_deferred("disabled", true)
	_spawn_debris()
	burst.emit()


func reset() -> void:
	if _pivot == null:  # a ship with no ambush: never set up, nothing to put back
		return
	sealed = true
	_pivot.visible = true
	_tell.visible = true
	_shape.set_deferred("disabled", false)
	for e: Dictionary in _debris:
		(e.node as Node).queue_free()
	_debris.clear()


func debris_count() -> int:
	return _debris.size()


func _spawn_debris() -> void:
	var d: Dictionary = cfg.debris
	var c := rect.get_center()
	var spread := deg_to_rad(float(d.spread_deg))
	for i in int(d.count):
		var mi := MeshInstance3D.new()
		mi.name = "Debris"
		var box := BoxMesh.new()
		var s := _rng.randf_range(float(d.size_min_m), float(d.size_max_m))
		box.size = Vector3(s, s, s)
		box.material = _mats[1] if _rng.randf() < float(d.hot_share) else _mats[0]
		mi.mesh = box
		add_child(mi)
		var along := Vector2(-out_dir.y, out_dir.x) * _rng.randf_range(-rect.size.length() * 0.5, rect.size.length() * 0.5)
		mi.global_position = Vector3(c.x + along.x, _rng.randf_range(s, float(Data.value("deck", "wall_height_m"))), c.y + along.y)
		var dir := out_dir.rotated(_rng.randf_range(-spread, spread)) * _rng.randf_range(float(d.speed_min_m_s), float(d.speed_max_m_s))
		var spin := float(d.spin_deg_s)
		_debris.append({"node": mi, "vel": Vector3(dir.x, _rng.randf() * float(d.lift_m_s), dir.y), "half": s * 0.5,
				"spin": Vector3(_rng.randf_range(-spin, spin), _rng.randf_range(-spin, spin), _rng.randf_range(-spin, spin))})


func tick(delta: float) -> void:
	if _pivot == null:
		return
	var d: Dictionary = cfg.debris
	for e: Dictionary in _debris:
		var v: Vector3 = e.vel
		if v == Vector3.ZERO:
			continue
		v.y -= float(d.gravity_m_s2) * delta
		var n: Node3D = e.node
		n.global_position += v * delta
		n.rotation_degrees += (e.spin as Vector3) * delta
		if n.global_position.y <= float(e.half):
			n.global_position.y = float(e.half)
			v = Vector3(v.x * float(d.friction), -v.y * float(d.bounce), v.z * float(d.friction))
			if v.length() < float(d.friction):
				v = Vector3.ZERO
		e.vel = v
