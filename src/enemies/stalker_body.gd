extends Node3D
## The stalker's grey-box body, built from data/enemies.json "stalker.body": low, wide, too many
## legs. Shows the wind-up glow and lean, the charge stretch, the recover slump, flinch and death.

var cfg: Dictionary
var height_m := 0.0

var _pose: Node3D
var _mat: StandardMaterial3D
var _glow: MeshInstance3D
var _glow_mat: StandardMaterial3D
var _lean := 0.0
var _stretch := 1.0
var _squash := 1.0
var _tilt := 0.0


func setup(config: Dictionary) -> void:
	cfg = config.body
	height_m = float(config.height_m)
	_pose = Node3D.new()
	_pose.name = "Pose"
	add_child(_pose)
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(String(cfg.color))
	for part: Dictionary in cfg.parts:
		_pose.add_child(_part(part))
	_glow_mat = StandardMaterial3D.new()
	_glow_mat.albedo_color = Color(String(cfg.glow_color))
	_glow_mat.emission_enabled = true
	_glow_mat.emission = Color(String(cfg.glow_color))
	_glow_mat.emission_energy_multiplier = float(cfg.glow_energy)
	var sphere := SphereMesh.new()
	sphere.radius = float(cfg.glow_radius_m)
	sphere.height = float(cfg.glow_radius_m) * 2.0
	sphere.material = _glow_mat
	_glow = MeshInstance3D.new()
	_glow.name = "Glow"
	_glow.mesh = sphere
	_glow.position = _vec(cfg.glow_at)
	_glow.visible = false
	_pose.add_child(_glow)


func _part(part: Dictionary) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if part.has("capsule"):
		var c := CapsuleMesh.new()
		c.radius = float(part.capsule[0])
		c.height = float(part.capsule[1])
		c.material = _mat
		mi.mesh = c
	else:
		var b := BoxMesh.new()
		b.size = _vec(part.box)
		b.material = _mat
		mi.mesh = b
	mi.position = _vec(part.at)
	if part.has("rot"):
		mi.rotation_degrees = _vec(part.rot)
	return mi


func _vec(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


## Called every step with the brain.
func show_state(delta: float, brain: RefCounted) -> void:
	var State: Dictionary = brain.State
	var dead: bool = brain.state == State.DEAD
	var recovering: bool = brain.state == State.RECOVER
	var rate := float(cfg.visual_rate_per_s) * delta
	_glow.visible = brain.windup > 0.0 and brain.state == State.SPIT
	if _glow.visible:
		_glow.scale = Vector3.ONE * maxf(float(brain.windup), float(cfg.glow_min_scale))
	var lean: float = brain.windup * float(cfg.windup_lean_deg)
	if brain.flinch_left > 0.0:
		lean = -float(brain.cfg.flinch.pitch_deg)
	_lean = lerpf(_lean, lean, minf(rate, 1.0))
	var stretch := float(cfg.charge_stretch) if brain.charging else (float(cfg.dash_stretch) if brain.velocity.length() > 0.0 and brain.state != State.PROWL and brain.state != State.INVESTIGATE else 1.0)
	_stretch = lerpf(_stretch, stretch, minf(rate, 1.0))
	_squash = lerpf(_squash, float(cfg.recover_squash) if recovering else 1.0, minf(rate, 1.0))
	_tilt = lerpf(_tilt, float(cfg.dead_tilt_deg) if dead else 0.0, minf(rate, 1.0))
	_pose.rotation_degrees = Vector3(_lean, 0.0, _tilt)
	_pose.scale = Vector3(1.0, _squash, _stretch)
	var col := String(cfg.color)
	if dead:
		col = String(cfg.dead_color)
	elif brain.flash_left > 0.0:
		col = String(cfg.hit_color)
	elif recovering:
		col = String(cfg.recover_color)
	_mat.albedo_color = Color(col)
