extends Node3D
## Placeholder muzzle flash, tracer and impact. Everything is unshaded additive, so with any
## post-processing the worst a dark pixel can do is add nothing: no black boxes.
## tests/test_weapons.gd checks the materials; tools/t003_blackbox.py checks captured frames.
## Numbers from data/weapons.json "fx".

var _cfg: Dictionary
var _flash: MeshInstance3D
var _flash_mat: StandardMaterial3D
var _light: OmniLight3D
var _flash_left := 0.0
var _tracers: Array[Dictionary] = []
var _impacts: Array[Dictionary] = []
var _next_tracer := 0
var _next_impact := 0


func _ready() -> void:
	_cfg = Data.value("weapons", "fx", {})
	top_level = true
	global_transform = Transform3D.IDENTITY
	var glow := _radial_texture()
	var flash_color := Color(_cfg.flash_color)
	_flash_mat = additive_material(flash_color, float(_cfg.flash_energy), glow)
	_flash = _quad(float(_cfg.flash_size_m), _flash_mat)
	_flash.name = "Flash"
	add_child(_flash)
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
		var im := additive_material(Color(_cfg.impact_color), float(_cfg.impact_energy), glow)
		var q := _quad(float(_cfg.impact_size_m), im)
		q.name = "Impact%d" % i
		add_child(q)
		_impacts.append({"node": q, "mat": im, "left": 0.0})


## A material that can only add light. `tex` is multiplied in, so its black adds nothing.
static func additive_material(color: Color, energy: float, tex: Texture2D) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED if tex else BaseMaterial3D.BILLBOARD_DISABLED
	m.albedo_color = Color(color.r * energy, color.g * energy, color.b * energy, 1.0)
	m.albedo_texture = tex
	return m


func shot(muzzle: Vector3, to: Vector3) -> void:
	_flash.global_position = muzzle
	_flash.visible = true
	_light.global_position = muzzle
	_light.visible = true
	_flash_left = float(_cfg.flash_life_s)
	_set_flash(1.0)
	var t: Dictionary = _tracers[_next_tracer]
	_next_tracer = (_next_tracer + 1) % _tracers.size()
	var node: MeshInstance3D = t.node
	var length := muzzle.distance_to(to)
	(node.mesh as BoxMesh).size = Vector3(float(_cfg.tracer_width_m), float(_cfg.tracer_width_m), length)
	node.global_transform = Transform3D(Basis.looking_at(to - muzzle, Vector3.UP), (muzzle + to) * 0.5)
	node.visible = true
	t.left = float(_cfg.tracer_life_s)
	t.mat.albedo_color.a = 1.0


func impact(at: Vector3) -> void:
	var i: Dictionary = _impacts[_next_impact]
	_next_impact = (_next_impact + 1) % _impacts.size()
	var node: MeshInstance3D = i.node
	node.global_position = at
	node.visible = true
	i.left = float(_cfg.impact_life_s)
	i.mat.albedo_color.a = 1.0


func _process(delta: float) -> void:
	if _flash_left > 0.0:
		_flash_left = maxf(_flash_left - delta, 0.0)
		_set_flash(_flash_left / float(_cfg.flash_life_s))
		if _flash_left == 0.0:
			_flash.visible = false
			_light.visible = false
	_fade(_tracers, float(_cfg.tracer_life_s), delta)
	_fade(_impacts, float(_cfg.impact_life_s), delta)


func _set_flash(amount: float) -> void:
	_flash_mat.albedo_color.a = amount
	_light.light_energy = float(_cfg.flash_light_energy) * amount


func _fade(pool: Array[Dictionary], life: float, delta: float) -> void:
	for p in pool:
		if p.left > 0.0:
			p.left = maxf(p.left - delta, 0.0)
			p.mat.albedo_color.a = p.left / life
			if p.left == 0.0:
				p.node.visible = false


func _quad(size: float, mat: Material) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	return mi


func _radial_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color.WHITE)
	g.set_color(1, Color.BLACK)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	return t
