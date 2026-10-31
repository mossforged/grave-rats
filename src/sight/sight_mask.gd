extends Node3D
## Draws the mask: the sight polygon into two deck-wide SubViewports (one cleared each frame, the
## visible area; one never, the memory), and a fullscreen quad (sight_mask.gdshader) applying both.

const SHADER := preload("res://src/sight/sight_mask.gdshader")
const SightSystem := preload("res://src/sight/sight_system.gd")


## Draws a triangle fan (first point is the eye) and any revealed rects, in world XZ.
class PolyCanvas extends Node2D:
	var points := PackedVector2Array()
	var rects: Array = []

	func _draw() -> void:
		var n := points.size()
		if n >= 3:
			var idx := PackedInt32Array()
			idx.resize((n - 2) * 3)
			for i in n - 2:
				idx[i * 3] = 0
				idx[i * 3 + 1] = i + 1
				idx[i * 3 + 2] = i + 2
			var colors := PackedColorArray()
			colors.resize(n)
			colors.fill(Color.WHITE)
			RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), idx, points, colors)
		for r: Rect2 in rects:
			draw_rect(r, Color.WHITE)


var sight: SightSystem
var material: ShaderMaterial

var _visible_vp: SubViewport
var _memory_vp: SubViewport
var _visible_canvas: PolyCanvas
var _memory_canvas: PolyCanvas
var _reveal_all_next := false


func setup(system: SightSystem) -> void:
	sight = system
	var ppm := float(sight.cfg.mask.px_per_m)
	_visible_vp = _make_viewport("VisibleMask", ppm)
	_visible_vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	_visible_vp.msaa_2d = Viewport.MSAA_4X
	_visible_canvas = _make_canvas(_visible_vp, ppm)
	# Memory is never cleared: every frame's sight paints over the last, so what was seen stays.
	# No MSAA here: an uncleared multisampled target comes back as garbage on Metal.
	_memory_vp = _make_viewport("MemoryMask", ppm)
	_memory_vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
	_memory_canvas = _make_canvas(_memory_vp, ppm)
	material = ShaderMaterial.new()
	material.shader = SHADER
	material.render_priority = Material.RENDER_PRIORITY_MIN
	material.set_shader_parameter("visible_mask", _visible_vp.get_texture())
	material.set_shader_parameter("memory_mask", _memory_vp.get_texture())
	material.set_shader_parameter("mask_origin", sight.bounds.position)
	material.set_shader_parameter("mask_size", sight.bounds.size)
	apply_cfg()
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	var mi := MeshInstance3D.new()
	mi.name = "Quad"
	mi.mesh = quad
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	mi.ignore_occlusion_culling = true
	mi.extra_cull_margin = 16384.0
	add_child(mi)
	sight.sight_updated.connect(_on_sight)
	sight.forgotten.connect(_on_forgotten)


func _make_viewport(vp_name: String, ppm: float) -> SubViewport:
	var vp := SubViewport.new()
	vp.name = vp_name
	vp.size = Vector2i((sight.bounds.size * ppm).ceil())
	vp.disable_3d = true
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	return vp


func _make_canvas(vp: SubViewport, ppm: float) -> PolyCanvas:
	var c := PolyCanvas.new()
	c.name = "Polygon"
	c.transform = Transform2D(0.0, Vector2.ONE * ppm, 0.0, -sight.bounds.position * ppm)
	vp.add_child(c)
	return c


func visible_texture() -> Texture2D:
	return _visible_vp.get_texture()


## Data to shader. Called at setup, and while the tuning panel is open.
func apply_cfg() -> void:
	var m: Dictionary = sight.cfg.mask
	material.set_shader_parameter("dilate_m", float(m.dilate_m))
	material.set_shader_parameter("edge_low", float(m.edge_low))
	material.set_shader_parameter("edge_high", float(m.edge_high))
	material.set_shader_parameter("remembered_brightness", float(m.remembered_brightness))
	material.set_shader_parameter("remembered_saturation", float(m.remembered_saturation))
	var tint := Color(m.remembered_tint)
	material.set_shader_parameter("remembered_tint", Vector3(tint.r, tint.g, tint.b))
	material.set_shader_parameter("unknown_brightness", float(m.unknown_brightness))
	material.set_shader_parameter("unknown_saturation", float(m.unknown_saturation))


func _on_sight(polygon: PackedVector2Array, reveal: Array) -> void:
	# The eye first, then the star's ring closed back on itself: a fan that covers it exactly.
	var fan := PackedVector2Array([sight.eye])
	fan.append_array(polygon)
	if not polygon.is_empty():
		fan.append(polygon[0])
	# The shader spreads every shape by dilate_m, so what's revealed whole is drawn that much
	# smaller, down to a sliver: a door panel must not spill into the room behind it.
	var dilate := float(sight.cfg.mask.dilate_m)
	var sliver := dilate * 0.5
	var rects: Array = []
	for r: Rect2 in reveal:
		var w := maxf(r.size.x - dilate * 2.0, sliver)
		var h := maxf(r.size.y - dilate * 2.0, sliver)
		rects.append(Rect2(r.get_center() - Vector2(w, h) * 0.5, Vector2(w, h)))
	for c: PolyCanvas in [_visible_canvas, _memory_canvas]:
		c.points = fan
		c.rects = rects
		c.queue_redraw()
	if _reveal_all_next:
		_reveal_all_next = false
		_memory_canvas.rects = rects + [sight.bounds]


## Captures only: paints the whole deck into memory, as if every corner had been walked.
func reveal_all() -> void:
	_reveal_all_next = true


func _on_forgotten() -> void:
	_memory_vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
