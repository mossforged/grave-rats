extends Node3D
## The airlock: the extraction point and the hold. A marked stretch of the deck for now, an outline
## of light that always reads, and a sign. Knows only where it is. data/shift.json "airlock".

const BEACON := preload("res://src/sight/beacon.gdshader")

var rect := Rect2()


func setup(c: Dictionary, layout: RefCounted, bind: Callable) -> void:
	var a: Vector2 = layout.point_in(String(c.space), c.from)
	var b: Vector2 = layout.point_in(String(c.space), c.to)
	rect = Rect2(a, b - a).abs()
	var mat := ShaderMaterial.new()
	mat.shader = BEACON
	mat.set_shader_parameter("beacon_color", Color(String(c.color)))
	mat.set_shader_parameter("energy", float(c.energy))
	mat.set_shader_parameter("unknown_share", float(c.unknown_share))
	bind.call(mat)
	mat.set_shader_parameter("masked", true)
	var w := float(c.strip_m)
	var h := float(c.strip_height_m)
	var e := rect.end
	var p := rect.position
	for strip: Rect2 in [Rect2(p.x, p.y, rect.size.x, w), Rect2(p.x, e.y - w, rect.size.x, w),
			Rect2(p.x, p.y, w, rect.size.y), Rect2(e.x - w, p.y, w, rect.size.y)]:
		var box := BoxMesh.new()
		box.size = Vector3(strip.size.x, h, strip.size.y)
		var mi := MeshInstance3D.new()
		mi.mesh = box
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		mi.global_position = Vector3(strip.get_center().x, h * 0.5, strip.get_center().y)
	var sign_label := Label3D.new()
	sign_label.name = "Sign"
	sign_label.text = String(c.sign)
	sign_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign_label.no_depth_test = true
	sign_label.pixel_size = float(c.sign_pixel_size)
	sign_label.font_size = int(c.sign_font_size)
	sign_label.modulate = Color(String(c.sign_color))
	add_child(sign_label)
	# On the threshold, so it doesn't sit on whoever's standing inside.
	sign_label.global_position = Vector3(rect.get_center().x, float(c.sign_height_m), rect.position.y)


func has_point(p: Vector2) -> bool:
	return rect.has_point(p)
