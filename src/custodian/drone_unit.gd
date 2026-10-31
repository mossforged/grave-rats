extends Node3D
## One patrol drone in the world: the rules (drone_brain.gd), a grey-box shell that hides unless seen, and
## its tell, the spotlight, roof bars and chirp. Shot dead it stays where it is, a dark wreck. While it's calling on you the cone and a set of bars over
## it show wherever it is. It has no collider: nothing walks into 0.65 m of drone yet. Rifle body contract:
## `shot_disc()`, `take_hit()`. data/custodian.json "drone".

const DroneBrain := preload("res://src/custodian/drone_brain.gd")
const Fx := preload("res://src/custodian/custodian_fx.gd")
const BeamFan := preload("res://src/sight/beam_fan.gd")
const Visibility := preload("res://src/sight/visibility.gd")
const BEAM_SHADER := preload("res://src/sight/beam.gdshader")
const SightTarget := preload("res://src/sight/sight_target.gd")
const PlaceholderSiren := preload("res://src/shift/placeholder_siren.gd")

var brain: DroneBrain
var cfg: Dictionary
var label := ""
var body: Node3D
var lens: MeshInstance3D
var spot: SpotLight3D
var fan: BeamFan
var beam: MeshInstance3D
var bars: Array = []
var tell_bars: Array = []

var _lens_cfg: Dictionary
var _mesh: ImmediateMesh
var _beam_mat: ShaderMaterial
var _chirp: AudioStreamPlayer3D
var _visible_mask: Texture2D
var _since_cast := INF
var _bar_lit: StandardMaterial3D
var _bar_dim: StandardMaterial3D
var _tell_plate: MeshInstance3D


func setup(all: Dictionary, spec: Dictionary, at: Vector2, route: Array, bind: Callable, mix_rate: int) -> void:
	cfg = all.drone
	_lens_cfg = all.lens
	label = "%s %s" % [String(cfg.label), String(spec.name).to_upper()]
	brain = DroneBrain.new(cfg, at, route)
	body = Node3D.new()
	body.name = "Body"
	add_child(body)
	var shell: Dictionary = all.shell
	var h := float(cfg.body_height_m)
	var size: Array = cfg.body_size_m
	Fx.box(body, size, Vector3(0.0, h, 0.0), String(shell.ivory), float(shell.roughness))
	Fx.box(body, cfg.skirt_size_m, Vector3(0.0, h * 0.5, 0.0), String(shell.teal), float(shell.roughness))
	lens = Fx.lens(body, _lens_cfg, Vector3(0.0, float(cfg.lens_up_m), 0.0), bind)
	var target := SightTarget.new()
	target.name = "SightTarget"
	body.add_child(target)
	_bar_lit = _bar_material(float(cfg.bar_lit_energy), Color(String(_lens_cfg.color)))
	_bar_dim = _bar_material(float(cfg.bar_dim_energy), Color(String(_lens_cfg.color)))
	var count := int(cfg.bars)
	var bar: Array = cfg.bar_size_m
	var pitch := float(bar[0]) + float(cfg.bar_gap_m)
	for i in count:
		var x := (float(i) - float(count - 1) * 0.5) * pitch
		var b := Fx.box(body, bar, Vector3(x, float(cfg.bar_up_m), 0.0), String(shell.dark), float(shell.roughness))
		b.material_override = _bar_dim
		bars.append(b)
	_make_tell(count)
	_make_spot()
	_chirp = AudioStreamPlayer3D.new()
	_chirp.stream = PlaceholderSiren.make(cfg.chirp, mix_rate, false)
	_chirp.volume_db = float(cfg.chirp.volume_db)
	_chirp.unit_size = float(cfg.unit_size_m)
	add_child(_chirp)
	_show()


func _bar_material(energy: float, color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	return mat


## The same three bars, floating on a dark plate, over everything: the call is never only audible, and
## never hidden. All three show from the start, so you can read how far it's got.
func _make_tell(count: int) -> void:
	var size: Array = cfg.tell_size_m
	var pitch := float(size[0]) + float(cfg.tell_gap_m)
	var pad := float(cfg.tell_pad_m) * 2.0
	_tell_plate = _tell_quad(Vector2(pitch * float(count) - float(cfg.tell_gap_m) + pad, float(size[1]) + pad), 0.0, String(cfg.tell_plate), 0)
	for i in count:
		var x := (float(i) - float(count - 1) * 0.5) * pitch
		tell_bars.append(_tell_quad(Vector2(float(size[0]), float(size[1])), x, String(cfg.tell_dim), 1))


func _tell_quad(size: Vector2, x: float, hex: String, priority: int) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.render_priority = priority
	mat.albedo_color = Color(hex)
	var quad := QuadMesh.new()
	quad.size = size
	quad.center_offset = Vector3(x, 0.0, 0.0)
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(0.0, float(cfg.tell_up_m), 0.0)
	mi.visible = false
	add_child(mi)
	return mi


func _make_spot() -> void:
	var c: Dictionary = cfg.spot
	spot = SpotLight3D.new()
	spot.name = "Spot"
	spot.light_color = Color(String(c.color))
	spot.light_energy = float(c.energy)
	spot.spot_range = float(cfg.spot_range_m)
	spot.spot_angle = float(cfg.spot_half_deg)
	spot.spot_attenuation = float(c.attenuation)
	spot.spot_angle_attenuation = float(c.angle_attenuation)
	spot.shadow_enabled = false
	add_child(spot)
	_mesh = ImmediateMesh.new()
	_beam_mat = ShaderMaterial.new()
	_beam_mat.shader = BEAM_SHADER
	_beam_mat.set_shader_parameter("beam_color", Color(String(c.color)))
	_beam_mat.set_shader_parameter("strength", float(c.beam_strength))
	_beam_mat.set_shader_parameter("fade_power", float(c.fade_power))
	_beam_mat.set_shader_parameter("edge_power", float(c.edge_power))
	_beam_mat.set_shader_parameter("tan_half", tan(deg_to_rad(float(cfg.spot_half_deg))))
	beam = Fx.ribbon(self, "Beam", _mesh, _beam_mat, float(cfg.spot_range_m))
	fan = BeamFan.new(int(c.rays))
	fan.configure(deg_to_rad(float(cfg.spot_half_deg)), float(cfg.spot_range_m), float(c.reach_rate_m_s), float(c.snap_m))


## The sheet shows only where the player has sight, unless it's calling on them.
func set_mask(texture: Texture2D, bounds: Rect2) -> void:
	_visible_mask = texture
	_beam_mat.set_shader_parameter("visible_mask", texture)
	_beam_mat.set_shader_parameter("mask_origin", bounds.position)
	_beam_mat.set_shader_parameter("mask_size", bounds.size)


func reset() -> void:
	brain.reset()
	fan.restart()
	_since_cast = INF
	_place()
	_show()


func wake() -> bool:
	var woke := brain.wake()
	if woke:
		fan.restart()
		_show()
	return woke


func floor_position() -> Vector2:
	return brain.pos


func shot_disc() -> Dictionary:
	if not brain.alive():
		return {}
	return {"center": brain.pos, "radius": float(cfg.hit_radius_m), "height": float(cfg.shot_height_m)}


func take_hit(hit: Dictionary) -> void:
	brain.take_hit(float(hit.damage))
	if not brain.alive():
		_show()


## One step: the rules, then what they look like. `visibility` knows the walls, for the cone.
func tick(delta: float, players: Array, trace: Callable, visibility: RefCounted) -> Array:
	var events: Array = brain.step(delta, players, trace)
	for ev: Dictionary in events:
		if String(ev.type) == DroneBrain.EV_BAR:
			_chirp.pitch_scale = 1.0 + float(cfg.chirp.pitch_step) * float(int(ev.bar) - 1)
			_chirp.play()
	_place()
	_show()
	if brain.awake():
		_draw_cone(delta, visibility)
	return events


func _place() -> void:
	global_position = Vector3(brain.pos.x, 0.0, brain.pos.y)
	body.rotation.y = brain.yaw


func _draw_cone(delta: float, visibility: RefCounted) -> void:
	var c: Dictionary = cfg.spot
	var eye := brain.eye()
	var at := brain.pos
	_since_cast += delta
	if _since_cast >= 1.0 / float(c.hz):
		_since_cast = 0.0
		fan.cast(visibility, at, at, brain.yaw)
	fan.step(delta, at, brain.yaw)
	fan.fill(_mesh, eye, deg_to_rad(float(c.pitch_deg)), float(c.floor_m))
	# Out in front: from inside the shell it would only light the shell.
	var front := Visibility.yaw_dir2(brain.yaw) * float(c.ahead_m)
	spot.global_transform = Transform3D(Basis.from_euler(Vector3(deg_to_rad(float(c.pitch_deg)), brain.yaw, 0.0)), eye + Vector3(front.x, 0.0, front.y))


func _show() -> void:
	var on := brain.awake()
	beam.visible = on
	spot.visible = on
	var calling := brain.calling()
	_beam_mat.set_shader_parameter("visible_mask", null if calling else _visible_mask)
	_beam_mat.set_shader_parameter("strength", float(cfg.spot.call_strength if calling else cfg.spot.beam_strength))
	var lit := brain.bars_lit()
	for i in bars.size():
		(bars[i] as MeshInstance3D).material_override = _bar_lit if i < lit else _bar_dim
		var tell: MeshInstance3D = tell_bars[i]
		tell.visible = calling
		(tell.material_override as StandardMaterial3D).albedo_color = Color(String(_lens_cfg.color if i < lit else cfg.tell_dim))
	_tell_plate.visible = calling
	Fx.lens_set_bright(lens, _lens_cfg, on)
	body.rotation.z = 0.0 if brain.alive() else deg_to_rad(float(cfg.wreck_tilt_deg))
