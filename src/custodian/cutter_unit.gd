extends Node3D
## One cutter in the world: the rules (cutter_brain.gd) and its tell. Grey-box housing, the lens, the line
## stopped by whatever stops it, the ring on the mount and under you, the beam. data/custodian.json "cutter".

const CutterBrain := preload("res://src/custodian/cutter_brain.gd")
const Fx := preload("res://src/custodian/custodian_fx.gd")
const PlaceholderSiren := preload("res://src/shift/placeholder_siren.gd")

var brain: CutterBrain
var cfg: Dictionary
var label := ""
var line_mesh: MeshInstance3D
var beam_mesh: MeshInstance3D
var mount_ring: MeshInstance3D
var target_ring: MeshInstance3D
var lens: MeshInstance3D
## Where the line stopped on the last step.
var line_end := Vector3.ZERO

var _lens_cfg: Dictionary
var _line: ImmediateMesh
var _beam: ImmediateMesh
var _line_mat: ShaderMaterial
var _warm_sound: AudioStreamPlayer3D
var _burn_sound: AudioStreamPlayer3D


func setup(all: Dictionary, spec: Dictionary, at: Vector2, bind: Callable, mix_rate: int) -> void:
	cfg = all.cutter
	_lens_cfg = all.lens
	var shell: Dictionary = all.shell
	label = "%s %s" % [String(cfg.label), String(spec.name).to_upper()]
	brain = CutterBrain.new(cfg, at, float(spec.home_yaw_deg), float(spec.arc_half_deg))
	global_position = Vector3(at.x, 0.0, at.y)
	var up := float(cfg.mount_height_m)
	Fx.box(self, cfg.body_size_m, Vector3(0.0, up, 0.0), String(shell.ivory), float(shell.roughness))
	lens = Fx.lens(self, _lens_cfg, Vector3(0.0, up + float(cfg.lens_up_m), 0.0), bind)
	var ln: Dictionary = cfg.line
	_line = ImmediateMesh.new()
	_line_mat = Fx.line_material(String(ln.color), float(ln.energy), float(ln.dash_m), float(ln.gap_m), float(ln.unknown_share), bind)
	line_mesh = Fx.ribbon(self, "Line", _line, _line_mat, float(ln.cull_margin_m))
	var bm: Dictionary = cfg.beam
	_beam = ImmediateMesh.new()
	var beam_mat := Fx.line_material(String(bm.color), float(bm.energy), 0.0, 0.0, 0.0, bind)
	beam_mat.set_shader_parameter("reveal", 1.0)
	beam_mesh = Fx.ribbon(self, "Beam", _beam, beam_mat, float(ln.cull_margin_m))
	var r: Dictionary = cfg.ring
	mount_ring = Fx.ring(self, r, float(r.mount_radius_m))
	mount_ring.global_position = Vector3(at.x, up, at.y)
	target_ring = Fx.ring(self, r, float(r.target_radius_m))
	_warm_sound = _sound(cfg.warm_sound, mix_rate, all.drone)
	_burn_sound = _sound(cfg.burn_sound, mix_rate, all.drone)


func _sound(spec: Dictionary, mix_rate: int, drone_cfg: Dictionary) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = PlaceholderSiren.make(spec, mix_rate, false)
	p.volume_db = float(spec.volume_db)
	p.unit_size = float(drone_cfg.unit_size_m)
	add_child(p)
	return p


func reset() -> void:
	brain.reset()
	_warm_sound.stop()
	_show()


func wake() -> bool:
	var woke := brain.wake()
	if woke:
		Fx.lens_set_bright(lens, _lens_cfg, true)
	return woke


func floor_position() -> Vector2:
	return Vector2(global_position.x, global_position.z)


## One step: the rules, then what they look like. Returns the rules' events.
func tick(delta: float, players: Array, trace: Callable) -> Array:
	var events: Array = brain.step(delta, players, trace)
	for ev: Dictionary in events:
		match String(ev.type):
			CutterBrain.EV_AIM:
				_warm_sound.pitch_scale = 1.0
				_warm_sound.play()
			CutterBrain.EV_CANCEL:
				_warm_sound.stop()
			CutterBrain.EV_BURN:
				_warm_sound.stop()
				_burn_sound.play()
	if brain.line_on():
		line_end = trace.call(brain.mount, brain.far_point(brain.line_reach(players))).point
	_show(players)
	return events


func _show(players := []) -> void:
	line_mesh.visible = brain.line_on() and not brain.burning()
	beam_mesh.visible = brain.burning()
	var aiming := brain.aiming()
	mount_ring.visible = aiming
	target_ring.visible = aiming
	Fx.lens_set_bright(lens, _lens_cfg, brain.awake())
	if line_mesh.visible:
		var ln: Dictionary = cfg.line
		Fx.fill_ribbon(_line, brain.mount, line_end, float(ln.aim_width_m if aiming else ln.width_m))
		_line_mat.set_shader_parameter("reveal", 1.0 if aiming else 0.0)
		_line_mat.set_shader_parameter("energy", float(ln.aim_energy if aiming else ln.energy))
	if beam_mesh.visible:
		Fx.fill_ribbon(_beam, brain.mount, line_end, float(cfg.beam.width_m))
	if aiming:
		var share := brain.warm_share()
		(mount_ring.material_override as ShaderMaterial).set_shader_parameter("fill", share)
		(target_ring.material_override as ShaderMaterial).set_shader_parameter("fill", share)
		for p: Dictionary in players:
			if int(p.id) == brain.target_id:
				var at: Vector2 = p.pos
				target_ring.global_position = Vector3(at.x, float(cfg.ring.floor_m), at.y)
