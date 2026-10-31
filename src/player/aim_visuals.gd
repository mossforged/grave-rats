extends MeshInstance3D
## Floor drawings that explain the gun: the aim-settle cone, the arc from the gun's current facing
## to the cursor while turning, and a ring under the aim point. Rebuilt each step in world space.
## In a scene with sight (`use_mask`) the cone and arc obey the mask; the ring never does, since you
## have to be able to aim into the dark. Numbers from data/player.json "aim_visuals".

const OperatorModel := preload("res://src/player/operator_model.gd")
const AIM_FLOOR := preload("res://src/sight/aim_floor.gdshader")

var arc_showing := false

var _cfg: Dictionary
var _mesh: ImmediateMesh
var _plain: StandardMaterial3D
var _under_sight: Material


func _ready() -> void:
	_cfg = Data.value("player", "aim_visuals", {})
	top_level = true
	global_transform = Transform3D.IDENTITY
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh = ImmediateMesh.new()
	mesh = _mesh
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_plain = m
	_under_sight = m


## `bind` is SightMask.bind: from here on the cone and arc draw through the mask.
func use_mask(bind: Callable) -> void:
	var m := ShaderMaterial.new()
	m.shader = AIM_FLOOR
	m.set_shader_parameter("remembered_share", float(_cfg.remembered_share))
	bind.call(m)
	_under_sight = m


func under_sight_material() -> Material:
	return _under_sight


## `gun_yaw` includes recoil; `aim_yaw` is the cursor's yaw; `aim_point` the cursor in the world.
## `reach` (yaw -> metres) is how far a shot along that yaw flies, so the cone stops where shots do.
func draw(from: Vector3, gun_yaw: float, spread_deg: float, aim_yaw: float, aim_point: Vector3, reach: Callable) -> void:
	_mesh.clear_surfaces()
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _under_sight)
	var y := float(_cfg.floor_y_m)
	var c := Vector3(from.x, y, from.z)
	_draw_cone(c, gun_yaw, deg_to_rad(spread_deg), reach)
	var err := wrapf(aim_yaw - gun_yaw, -PI, PI)
	arc_showing = absf(err) > deg_to_rad(float(_cfg.arc_min_deg))
	if arc_showing:
		_draw_arc(c, gun_yaw, err)
	_mesh.surface_end()
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _plain)
	_draw_ring(Vector3(aim_point.x, y, aim_point.z))
	_mesh.surface_end()


func _draw_cone(c: Vector3, yaw: float, spread: float, reach: Callable) -> void:
	var fill := Color(String(_cfg.cone_fill_color))
	var edge := Color(String(_cfg.cone_edge_color))
	var segs := int(_cfg.cone_segments)
	var half := spread * 0.5
	var ends: Array[Vector3] = []
	for i in segs + 1:
		var a := yaw - half + spread * i / segs
		ends.append(c + OperatorModel.yaw_dir(a) * minf(float(_cfg.cone_length_m), reach.call(a)))
	for i in segs:
		_tri(c, ends[i], ends[i + 1], fill)
	var w := float(_cfg.cone_edge_width_m)
	_line(c, ends[0], w, edge)
	_line(c, ends[segs], w, edge)


func _draw_arc(c: Vector3, yaw: float, err: float) -> void:
	var color := Color(String(_cfg.arc_color))
	var r := float(_cfg.arc_radius_m)
	var w := float(_cfg.arc_width_m)
	var steps := maxi(ceili(rad_to_deg(absf(err)) / float(_cfg.arc_step_deg)), 1)
	for i in steps:
		var a := yaw + err * i / steps
		var b := yaw + err * (i + 1) / steps
		_line(c + OperatorModel.yaw_dir(a) * r, c + OperatorModel.yaw_dir(b) * r, w, color)


func _draw_ring(c: Vector3) -> void:
	var color := Color(String(_cfg.marker_color))
	var r := float(_cfg.marker_radius_m)
	var w := float(_cfg.marker_width_m)
	var segs := int(_cfg.marker_segments)
	for i in segs:
		var a := TAU * i / segs
		var b := TAU * (i + 1) / segs
		_line(c + OperatorModel.yaw_dir(a) * r, c + OperatorModel.yaw_dir(b) * r, w, color)


func _line(a: Vector3, b: Vector3, width: float, color: Color) -> void:
	var side := (b - a).cross(Vector3.UP).normalized() * width * 0.5
	_tri(a - side, a + side, b + side, color)
	_tri(a - side, b + side, b - side, color)


func _tri(a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	for v: Vector3 in [a, b, c]:
		_mesh.surface_set_color(color)
		_mesh.surface_add_vertex(v)
