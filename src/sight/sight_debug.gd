extends MeshInstance3D
## F2: the sight polygon and the grid's areas outlined by state, drawn on the floor over everything.

const SightSystem := preload("res://src/sight/sight_system.gd")
const SightGrid := preload("res://src/sight/sight_grid.gd")

var sight: SightSystem

var _mesh: ImmediateMesh
var _since := INF


func setup(system: SightSystem) -> void:
	sight = system
	_mesh = ImmediateMesh.new()
	mesh = _mesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = sight.bounds.size.length()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.no_depth_test = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.render_priority = Material.RENDER_PRIORITY_MAX
	material_override = mat
	visible = false


func toggle() -> void:
	visible = not visible
	_since = INF
	if not visible:
		_mesh.clear_surfaces()


## Redraws the outlines at `debug.outline_hz`: walking a whole grid is only worth it in debug.
func _process(delta: float) -> void:
	if not visible:
		return
	_since += delta
	if _since < 1.0 / float(sight.cfg.debug.outline_hz) and delta > 0.0:
		return
	_since = 0.0
	redraw()


func redraw() -> void:
	var d: Dictionary = sight.cfg.debug
	var y := float(d.floor_y_m)
	_mesh.clear_surfaces()
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	_segments(sight.grid.boundary(SightGrid.UNKNOWN), Color(d.unknown_color), y)
	_segments(sight.grid.boundary(SightGrid.REMEMBERED), Color(d.remembered_color), y)
	_segments(sight.grid.boundary(SightGrid.VISIBLE), Color(d.visible_color), y)
	var p := sight.polygon
	var ring := PackedVector2Array()
	for i in p.size():
		ring.append(p[i])
		ring.append(p[(i + 1) % p.size()])
	_segments(ring, Color(d.polygon_color), y)
	_mesh.surface_end()


func _segments(points: PackedVector2Array, color: Color, y: float) -> void:
	_mesh.surface_set_color(color)
	for q in points:
		_mesh.surface_add_vertex(Vector3(q.x, y, q.y))
