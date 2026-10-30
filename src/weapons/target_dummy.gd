extends StaticBody3D
## Grey-box target: takes hits, flinches away from the shot, falls over when out of health and
## resets. Numbers from data/weapons.json "targets".

signal hit_taken(damage: float)
signal went_down
signal was_reset

var cfg: Dictionary
var health := 0.0
var down := false

var _pivot: Node3D
var _mat: StandardMaterial3D
var _tilt_axis := Vector3.RIGHT
var _tilt := 0.0
var _flinch_left := 0.0
var _reset_left := 0.0
var _flash_left := 0.0


func _ready() -> void:
	cfg = Data.value("weapons", "targets", {})
	health = float(cfg.health)
	var radius := float(cfg.radius_m)
	var height := float(cfg.height_m)
	var shape := CapsuleShape3D.new()
	shape.radius = radius
	shape.height = height
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = height * 0.5
	add_child(cs)
	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	add_child(_pivot)
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(cfg.color)
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = radius
	body_mesh.height = height - float(cfg.head_radius_m) * 2.0
	body_mesh.material = _mat
	var body := MeshInstance3D.new()
	body.mesh = body_mesh
	body.position.y = body_mesh.height * 0.5
	_pivot.add_child(body)
	var head_mesh := SphereMesh.new()
	head_mesh.radius = float(cfg.head_radius_m)
	head_mesh.height = float(cfg.head_radius_m) * 2.0
	head_mesh.material = _mat
	var head := MeshInstance3D.new()
	head.mesh = head_mesh
	head.position.y = height - float(cfg.head_radius_m)
	_pivot.add_child(head)


## `hit` has "direction" (Vector3, the way the shot travels) and "damage".
func take_hit(hit: Dictionary) -> void:
	if down:
		return
	health -= float(hit.damage)
	var d: Vector3 = hit.direction
	_tilt_axis = Vector3.UP.cross(d).normalized()
	_flinch_left = float(cfg.flinch_s)
	_flash_left = float(cfg.hit_flash_s)
	hit_taken.emit(float(hit.damage))
	if health <= 0.0:
		down = true
		_reset_left = float(cfg.reset_s)
		went_down.emit()


func flinching() -> bool:
	return _flinch_left > 0.0


func tilt_deg() -> float:
	return rad_to_deg(_tilt)


func _process(delta: float) -> void:
	if down:
		_reset_left = maxf(_reset_left - delta, 0.0)
		var rate := deg_to_rad(float(cfg.down_deg)) / float(cfg.down_s)
		_tilt = move_toward(_tilt, deg_to_rad(float(cfg.down_deg)), rate * delta)
		if _reset_left == 0.0:
			_reset()
	else:
		_flinch_left = maxf(_flinch_left - delta, 0.0)
		_tilt = deg_to_rad(float(cfg.flinch_deg)) * _flinch_left / float(cfg.flinch_s)
	_flash_left = maxf(_flash_left - delta, 0.0)
	_pivot.basis = Basis(_tilt_axis, _tilt) if _tilt > 0.0 else Basis.IDENTITY
	var base := Color(cfg.down_color) if down else Color(cfg.color)
	_mat.albedo_color = base.lerp(Color(cfg.hit_color), _flash_left / float(cfg.hit_flash_s))


func _reset() -> void:
	down = false
	health = float(cfg.health)
	_tilt = 0.0
	_flinch_left = 0.0
	was_reset.emit()
