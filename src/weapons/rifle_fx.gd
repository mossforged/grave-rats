extends Node3D
## Muzzle flash and tracer, per gun. The flash is the sheet's: a random side cone along the barrel and a small
## front star at the tip, random roll and scale, on screen for `flash_frames` frames and no more, with the muzzle
## light dying over `flash_life_s`. Everything is unshaded additive, so with any post-processing the worst a dark
## pixel can do is add nothing: no black boxes. Where a round lands is src/vfx's.
## tests/test_weapons.gd checks the materials; tools/t003_blackbox.py checks captured frames.
## Numbers from data/weapons.json "fx".

var _cfg: Dictionary
var _flash: MeshInstance3D
var _flash_mat: StandardMaterial3D
var _star: MeshInstance3D
var _star_mat: StandardMaterial3D
var _light: OmniLight3D
var _flash_left := 0.0
var _sprite_frames := 0
var _tracers: Array[Dictionary] = []
var _next_tracer := 0


func _ready() -> void:
	_cfg = Data.value("weapons", "fx", {})
	top_level = true
	global_transform = Transform3D.IDENTITY
	var sheet: Texture2D = load(String(_cfg.flash_sheet))
	var flash_color := Color(_cfg.flash_color)
	_flash_mat = additive_material(flash_color, float(_cfg.flash_energy), sheet)
	_flash = _quad(Vector2(float(_cfg.flash_cone_length_m), float(_cfg.flash_cone_width_m)), _flash_mat)
	_flash.name = "Flash"
	add_child(_flash)
	_star_mat = additive_material(flash_color, float(_cfg.flash_energy), sheet)
	_star = _quad(Vector2.ONE * float(_cfg.flash_star_size_m), _star_mat)
	_star.name = "FlashStar"
	add_child(_star)
	var cell := Vector3(1.0 / float(_cfg.flash_cols), 1.0 / float(_cfg.flash_rows), 1.0)
	_flash_mat.uv1_scale = cell
	_star_mat.uv1_scale = cell
	_light = OmniLight3D.new()
	_light.name = "FlashLight"
	_light.light_color = flash_color
	_light.omni_range = float(_cfg.flash_light_range_m)
	_light.shadow_enabled = false
	_light.visible = false
	add_child(_light)
	for i in int(_cfg.pool_size):
		var tm := additive_material(Color(_cfg.tracer_color), float(_cfg.tracer_energy), null)
		var box := BoxMesh.new()
		box.material = tm
		var t := MeshInstance3D.new()
		t.name = "Tracer%d" % i
		t.mesh = box
		t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		t.visible = false
		add_child(t)
		_tracers.append({"node": t, "mat": tm, "left": 0.0})


## A material that can only add light. `tex` is multiplied in, so its black adds nothing.
static func additive_material(color: Color, energy: float, tex: Texture2D) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(color.r * energy, color.g * energy, color.b * energy, 1.0)
	m.albedo_texture = tex
	return m


func shot(muzzle: Vector3, to: Vector3) -> void:
	_place_flash(muzzle, (to - muzzle).normalized())
	_light.global_position = muzzle
	_light.visible = true
	_flash_left = float(_cfg.flash_life_s)
	_light.light_energy = float(_cfg.flash_light_energy)
	var t: Dictionary = _tracers[_next_tracer]
	_next_tracer = (_next_tracer + 1) % _tracers.size()
	var node: MeshInstance3D = t.node
	var length := muzzle.distance_to(to)
	(node.mesh as BoxMesh).size = Vector3(float(_cfg.tracer_width_m), float(_cfg.tracer_width_m), length)
	node.global_transform = Transform3D(Basis.looking_at(to - muzzle, Vector3.UP), (muzzle + to) * 0.5)
	node.visible = true
	t.left = float(_cfg.tracer_life_s)
	t.mat.albedo_color.a = 1.0


## The cone lies along the barrel, turned to the camera as far as that allows; the star faces the camera. Both pick
## a frame, a roll and a size, so no two shots match.
func _place_flash(muzzle: Vector3, dir: Vector3) -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var to_cam := (cam.global_position - muzzle).normalized() if cam != null else Vector3.UP
	var jitter := float(_cfg.flash_scale_jitter)
	var size := Vfx.rng.randf_range(1.0 - jitter, 1.0 + jitter)
	var side := to_cam.cross(dir).normalized() * (1.0 if Vfx.rng.randf() < 0.5 else -1.0)
	var front := dir.cross(side).normalized()
	var length := float(_cfg.flash_cone_length_m) * size
	_flash.global_transform = Transform3D(Basis(dir, side, front).scaled_local(Vector3.ONE * size), muzzle + dir * length * 0.5)
	_set_frame(_flash_mat, _cfg.flash_cone_frames)
	var right := Vector3.UP.cross(to_cam).normalized() if absf(to_cam.y) < 1.0 else Vector3.RIGHT
	var star_basis := Basis(right, to_cam.cross(right), to_cam).rotated(to_cam, Vfx.rng.randf_range(0.0, TAU))
	_star.global_transform = Transform3D(star_basis.scaled_local(Vector3.ONE * size), muzzle)
	_set_frame(_star_mat, _cfg.flash_star_frames)
	_flash.visible = true
	_star.visible = true
	_sprite_frames = int(_cfg.flash_frames)


func _set_frame(mat: StandardMaterial3D, frames: Array) -> void:
	var f := Vfx.rng.randi_range(int(frames[0]), int(frames[1]))
	var cols := int(_cfg.flash_cols)
	mat.uv1_offset = Vector3(float(f % cols) / float(cols), float(f / cols) / float(_cfg.flash_rows), 0.0)


func _process(delta: float) -> void:
	# Counted in frames, however fast they come. A frozen capture holds it.
	if _sprite_frames > 0 and delta > 0.0:
		_sprite_frames -= 1
		if _sprite_frames == 0:
			_flash.visible = false
			_star.visible = false
	if _flash_left > 0.0:
		_flash_left = maxf(_flash_left - delta, 0.0)
		_light.light_energy = float(_cfg.flash_light_energy) * _flash_left / float(_cfg.flash_life_s)
		if _flash_left == 0.0:
			_light.visible = false
	_fade(_tracers, float(_cfg.tracer_life_s), delta)


func _fade(pool: Array[Dictionary], life: float, delta: float) -> void:
	for p in pool:
		if p.left > 0.0:
			p.left = maxf(p.left - delta, 0.0)
			p.mat.albedo_color.a = p.left / life
			if p.left == 0.0:
				p.node.visible = false


func _quad(size: Vector2, mat: Material) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = size
	q.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	return mi
