extends RefCounted
## The small pieces every CUSTODIAN unit is drawn with. Grey box: boxes until the Meshy models come.

const LENS := preload("res://src/custodian/custodian_lens.gdshader")
const RING := preload("res://src/custodian/custodian_ring.gdshader")
const LINE := preload("res://src/custodian/custodian_line.gdshader")


static func box(parent: Node3D, size: Array, at: Vector3, hex: String, roughness: float) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(float(size[0]), float(size[1]), float(size[2]))
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(hex)
	mat.roughness = roughness
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	parent.add_child(mi)
	return mi


## The mark. `lens_set_bright` switches it.
static func lens(parent: Node3D, cfg: Dictionary, at: Vector3, bind: Callable) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * float(cfg.size_m)
	var mat := ShaderMaterial.new()
	mat.shader = LENS
	mat.set_shader_parameter("lens_color", Color(String(cfg.color)))
	mat.set_shader_parameter("energy", float(cfg.dim_energy))
	mat.set_shader_parameter("unknown_share", float(cfg.unknown_share))
	bind.call(mat)
	mat.set_shader_parameter("masked", true)
	var mi := MeshInstance3D.new()
	mi.name = "Lens"
	mi.mesh = quad
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = at
	parent.add_child(mi)
	return mi


static func lens_set_bright(mi: MeshInstance3D, cfg: Dictionary, bright: bool) -> void:
	(mi.material_override as ShaderMaterial).set_shader_parameter("energy", float(cfg.bright_energy if bright else cfg.dim_energy))


static func ring(parent: Node3D, cfg: Dictionary, radius: float) -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * radius * 2.0
	var mat := ShaderMaterial.new()
	mat.shader = RING
	mat.set_shader_parameter("ring_color", Color(String(cfg.color)))
	mat.set_shader_parameter("energy", float(cfg.energy))
	mat.set_shader_parameter("segments", float(cfg.segments))
	mat.set_shader_parameter("gap", float(cfg.gap))
	mat.set_shader_parameter("inner", float(cfg.inner))
	mat.set_shader_parameter("track_alpha", float(cfg.track_alpha))
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.top_level = true
	mi.visible = false
	parent.add_child(mi)
	return mi


static func ribbon(parent: Node3D, node_name: String, mesh: ImmediateMesh, mat: Material, cull_margin: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.top_level = true
	mi.extra_cull_margin = cull_margin
	mi.visible = false
	parent.add_child(mi)
	return mi


static func line_material(color: String, energy: float, dash_m: float, gap_m: float, unknown_share: float, bind: Callable) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = LINE
	mat.set_shader_parameter("line_color", Color(color))
	mat.set_shader_parameter("energy", energy)
	mat.set_shader_parameter("dash_m", dash_m)
	mat.set_shader_parameter("gap_m", gap_m)
	mat.set_shader_parameter("unknown_share", unknown_share)
	bind.call(mat)
	mat.set_shader_parameter("masked", true)
	return mat


## A flat ribbon from a to b, `width` across, UV.x in metres along it. It lies flat because the camera's above.
static func fill_ribbon(mesh: ImmediateMesh, a: Vector3, b: Vector3, width: float) -> void:
	mesh.clear_surfaces()
	var along := b - a
	var side := along.cross(Vector3.UP)
	if side.length_squared() == 0.0:
		return
	side = side.normalized() * width * 0.5
	var length := along.length()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	mesh.surface_set_uv(Vector2(0.0, 0.0))
	mesh.surface_add_vertex(a + side)
	mesh.surface_set_uv(Vector2(0.0, 1.0))
	mesh.surface_add_vertex(a - side)
	mesh.surface_set_uv(Vector2(length, 0.0))
	mesh.surface_add_vertex(b + side)
	mesh.surface_set_uv(Vector2(length, 1.0))
	mesh.surface_add_vertex(b - side)
	mesh.surface_end()
