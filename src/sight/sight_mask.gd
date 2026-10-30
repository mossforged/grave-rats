extends Node3D
## Draws the mask: the sight polygon into a deck-wide SubViewport (visible channel), the grid's
## memory into a texture, and a fullscreen quad (sight_mask.gdshader) that applies both.

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

var _viewport: SubViewport
var _canvas: PolyCanvas
var _memory_image: Image
var _memory_tex: ImageTexture


func setup(system: SightSystem) -> void:
	sight = system
	var cfg: Dictionary = sight.cfg
	var ppm := float(cfg.mask.px_per_m)
	_viewport = SubViewport.new()
	_viewport.name = "VisibleMask"
	_viewport.size = Vector2i((sight.bounds.size * ppm).ceil())
	_viewport.disable_3d = true
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	add_child(_viewport)
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.size = Vector2(_viewport.size)
	_viewport.add_child(bg)
	_canvas = PolyCanvas.new()
	_canvas.name = "Polygon"
	_canvas.transform = Transform2D(0.0, Vector2.ONE * ppm, 0.0, -sight.bounds.position * ppm)
	_viewport.add_child(_canvas)
	var grid = sight.grid
	_memory_image = Image.create_from_data(grid.nx, grid.nz, false, Image.FORMAT_L8, grid.memory)
	_memory_tex = ImageTexture.create_from_image(_memory_image)
	material = ShaderMaterial.new()
	material.shader = SHADER
	material.render_priority = Material.RENDER_PRIORITY_MIN
	material.set_shader_parameter("visible_mask", _viewport.get_texture())
	material.set_shader_parameter("memory_mask", _memory_tex)
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


func visible_texture() -> Texture2D:
	return _viewport.get_texture()


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
	_canvas.points = fan
	_canvas.rects = reveal.duplicate()
	_canvas.queue_redraw()
	if sight.grid.memory_dirty:
		sight.grid.memory_dirty = false
		_memory_image.set_data(sight.grid.nx, sight.grid.nz, false, Image.FORMAT_L8, sight.grid.memory)
		_memory_tex.update(_memory_image)
