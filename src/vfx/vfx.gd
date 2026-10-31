extends Node
## The effect library. Autoloaded as `Vfx`. Every effect is a recipe in data/vfx.json: textures, counts,
## lifetimes, velocities, colours, light flashes, decals, sounds. Everything it draws is built here at start and
## reused: particle rings, decals, casings, magazines, lights, pools, emitters. Nothing is made per shot.
## See src/vfx/CONTRACT.md.
##
## Looks and sound only. No rule reads anything here, so its random numbers aren't the session's.

const ParticleField := preload("res://src/vfx/particle_field.gd")
const DecalRing := preload("res://src/vfx/decal_ring.gd")
const BrassField := preload("res://src/vfx/brass_field.gd")
const SurfaceMap := preload("res://src/vfx/surface_map.gd")
const SHADERS := {
	"add": preload("res://src/vfx/vfx_add.gdshader"),
	"blend": preload("res://src/vfx/vfx_blend.gdshader"),
	"lit": preload("res://src/vfx/vfx_lit.gdshader"),
}
const POOL_SHADER := preload("res://src/vfx/vfx_pool.gdshader")
## A decal goes on anything but layer 1: people, doors and beds move, and a hole wouldn't move with them.
const ALL_LAYERS := 0xFFFFF
const MOVING_LAYER := 1

signal played(recipe: String, at: Vector3)
signal decal_placed(sheet: String, frame: int, at: Vector3, normal: Vector3)

var cfg: Dictionary
var manifest: Dictionary
var surfaces: SurfaceMap
var rng := RandomNumberGenerator.new()
var now := 0.0
var fields := {}              # sheet -> ParticleField
var casings: BrassField
var magazines: BrassField
var decal_ring: DecalRing

var _meshes := {}             # sheet -> MultiMeshInstance3D
var _materials := {}          # sheet -> ShaderMaterial
var _decals: Array[Decal] = []
var _decal_tex := {}          # "<sheet>_<frame>" -> Texture2D
var _lights: Array[Dictionary] = []
var _emitters: Array[Dictionary] = []
var _pools: Array[Dictionary] = []
var _next_id := 1
var _casing_mm: MultiMesh
var _magazine_mm: MultiMesh
var _shake_m := 0.0
var _shake_full := 0.0
var _shake_recover := 1.0
var _bind := Callable()
var _warm_frames := 0


func _ready() -> void:
	cfg = Data.load_data("vfx")
	manifest = JSON.parse_string(FileAccess.get_file_as_string(String(cfg.manifest)))
	surfaces = SurfaceMap.new(cfg.surfaces, Data.load_data("kit"))
	rng.randomize()
	_warm_up()


## The whole budget, built once.
func _warm_up() -> void:
	var b: Dictionary = cfg.budgets
	var max_layers := 0
	for r: String in cfg.recipes:
		max_layers = maxi(max_layers, (cfg.recipes[r].layers as Array).size() if cfg.recipes[r].has("layers") else 0)
	for sheet: String in cfg.sheets:
		_make_sheet(sheet, int(float(b.max_particles) * float(cfg.sheets[sheet].share)))
	_load_decal_textures()
	_hold_decal_atlas()
	var d: Dictionary = cfg.decals
	decal_ring = DecalRing.new(int(b.max_decals), int(d.fade_band), float(d.fade_s))
	var decal_root := Node3D.new()
	decal_root.name = "Decals"
	add_child(decal_root)
	for i in int(b.max_decals):
		var n := Decal.new()
		n.name = "Decal%d" % i
		n.visible = false
		n.cull_mask = ALL_LAYERS & ~MOVING_LAYER
		n.normal_fade = float(d.normal_fade)
		n.upper_fade = float(d.edge_fade)
		n.lower_fade = float(d.edge_fade)
		decal_root.add_child(n)
		_decals.append(n)
	for i in int(b.max_lights):
		var l := OmniLight3D.new()
		l.name = "Light%d" % i
		l.shadow_enabled = false
		l.visible = false
		add_child(l)
		_lights.append({"node": l, "on": false, "left": 0.0, "life": 0.0, "energy": 0.0, "hz": 0.0, "depth": 0.0, "phase": 0.0})
	for i in int(b.max_emitters):
		var layers := PackedFloat32Array()
		layers.resize(max_layers)
		_emitters.append({"on": false, "id": 0, "recipe": {}, "name": "", "at": Vector3.ZERO, "facing": Vector3.UP, "box": Vector3.ZERO,
				"draft": Vector3.ZERO, "left": INF, "timers": layers, "light": -1, "pool": -1, "sound": "", "crackle": 0.0,
				"pulse_on": true, "pulse": 0.0, "cull": 0.0})
	for i in int(b.max_pools):
		_make_pool(i)
	casings = BrassField.new(cfg.casing, int(b.max_casings))
	magazines = BrassField.new(cfg.magazine, int(b.max_magazines))
	_casing_mm = _make_brass("Casings", cfg.casing, int(b.max_casings))
	_magazine_mm = _make_brass("Magazines", cfg.magazine, int(b.max_magazines))


func _make_sheet(sheet: String, capacity: int) -> void:
	var c: Dictionary = cfg.sheets[sheet]
	var tex_name := String(c.get("texture", sheet))
	var m: Dictionary = manifest[tex_name]
	var cols := float(m.cols)
	var rows := ceilf(float(m.frames) / cols)
	var mat := ShaderMaterial.new()
	mat.shader = SHADERS[String(c.look)]
	mat.render_priority = int(c.priority)
	mat.set_shader_parameter("sheet", load(texture_path(tex_name)))
	mat.set_shader_parameter("grid", Vector2(cols, rows))
	mat.set_shader_parameter("aspect", (float(m.size_px[0]) / cols) / (float(m.size_px[1]) / rows))
	mat.set_shader_parameter("floor_y", float(cfg.floor_y_m))
	mat.set_shader_parameter("align_velocity", bool(c.get("align_velocity", false)))
	mat.set_shader_parameter("spin", deg_to_rad(float(c.spin_deg_s)))
	mat.set_shader_parameter("fade_power", float(c.fade_power))
	mat.set_shader_parameter("fade_in", float(c.fade_in))
	mat.set_shader_parameter("soft_m", float(c.soft_m))
	mat.set_shader_parameter("emit_share", float(c.get("emit_share", 0.0)))
	mat.set_shader_parameter("scatter", float(c.get("scatter", 0.0)))
	mat.set_shader_parameter("alpha_from_luma", bool(c.get("alpha_from_luma", false)))
	mat.set_shader_parameter("cone_only", bool(c.get("cone_only", false)))
	var quad := QuadMesh.new()
	quad.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = quad
	mm.instance_count = capacity
	mm.custom_aabb = _world_aabb()
	var mi := MultiMeshInstance3D.new()
	mi.name = sheet.to_pascal_case()
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	add_child(mi)
	fields[sheet] = ParticleField.new(capacity, float(cfg.floor_y_m))
	_meshes[sheet] = mi
	_materials[sheet] = mat


func _world_aabb() -> AABB:
	var half := float(cfg.world_half_m)
	return AABB(Vector3(-half, -half, -half), Vector3(half, half, half) * 2.0)


func _load_decal_textures() -> void:
	for name: String in manifest:
		if name.begins_with("decal_"):
			for f in int(manifest[name].frames):
				_decal_tex["%s_%d" % [name, f]] = load("%s/%s_%d.png" % [cfg.texture_dir, name, f])


## The engine packs every texture a Decal holds into one atlas and rebuilds it when the set changes, a long frame
## on a first shot. A hidden Decal per texture keeps the set the same for good.
func _hold_decal_atlas() -> void:
	var root := Node3D.new()
	root.name = "DecalAtlasHolders"
	add_child(root)
	for key: String in _decal_tex:
		var n := Decal.new()
		n.texture_albedo = _decal_tex[key]
		n.visible = false
		root.add_child(n)


## Draws everything once, the frame a deck comes up, so no pipeline is first compiled on the first shot.
func warm_pipelines() -> void:
	_warm_frames = int(cfg.warm_frames)
	_casing_mm.visible_instance_count = maxi(_casing_mm.visible_instance_count, 1)
	_magazine_mm.visible_instance_count = maxi(_magazine_mm.visible_instance_count, 1)


func _make_pool(i: int) -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	var mat := ShaderMaterial.new()
	mat.shader = POOL_SHADER
	mat.render_priority = 1
	plane.material = mat
	var mi := MeshInstance3D.new()
	mi.name = "Pool%d" % i
	mi.mesh = plane
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	add_child(mi)
	_pools.append({"node": mi, "mat": mat, "on": false})


func _make_brass(node_name: String, c: Dictionary, count: int) -> MultiMesh:
	var mesh := _first_mesh(load(String(c.mesh)) as PackedScene)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(c.color)
	mat.metallic = float(c.metallic)
	mat.roughness = float(c.roughness)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = count
	mm.visible_instance_count = 0
	mm.custom_aabb = _world_aabb()
	var mi := MultiMeshInstance3D.new()
	mi.name = node_name
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mm


func _first_mesh(scene: PackedScene) -> Mesh:
	var root := scene.instantiate()
	var found := root.find_children("*", "MeshInstance3D", true, false)
	var mesh: Mesh = (found[0] as MeshInstance3D).mesh if not found.is_empty() else (root as MeshInstance3D).mesh
	root.free()
	return mesh


func texture_path(name: String) -> String:
	return "%s/%s" % [cfg.texture_dir, manifest[name].file]


# --- the deck ---

## Where walls and rooms are, for the surfaces and the casings' floor.
func set_layout(layout: RefCounted) -> void:
	surfaces = SurfaceMap.new(cfg.surfaces, Data.load_data("kit"))  # the ship may have changed
	surfaces.layout = layout
	warm_pipelines()


## Everything drawn here obeys the sight mask from now on. `bind` is SightMask.bind.
func use_mask(bind: Callable) -> void:
	_bind = bind
	for sheet: String in _materials:
		bind.call(_materials[sheet])
		(_materials[sheet] as ShaderMaterial).set_shader_parameter("masked", true)
	for p: Dictionary in _pools:
		bind.call(p.mat)
		(p.mat as ShaderMaterial).set_shader_parameter("masked", true)


## The local player's light: motes only show inside it.
func set_beam(origin: Vector3, dir: Vector2, half_angle_rad: float, range_m: float, on: bool) -> void:
	for sheet: String in cfg.sheets:
		if bool(cfg.sheets[sheet].get("cone_only", false)):
			var m: ShaderMaterial = _materials[sheet]
			m.set_shader_parameter("beam_origin", origin)
			m.set_shader_parameter("beam_dir", dir)
			m.set_shader_parameter("beam_cos", cos(half_angle_rad))
			m.set_shader_parameter("beam_range", range_m)
			m.set_shader_parameter("beam_on", 1.0 if on else 0.0)


## The deck's list: data "effects" [{recipe, space, at [fx, fz], y_m, facing [x, y, z], box_m}]. An entry for a
## room this deck doesn't have is skipped. `layer_of` is (space) -> render layers its light may touch.
func place_effects(entries: Array, layout: RefCounted, layer_of: Callable) -> void:
	for e: Dictionary in entries:
		var space := String(e.space)
		if not layout.spaces.has(space):
			continue
		var p: Vector2 = layout.point_in(space, e.at)
		var f: Array = e.get("facing", [0.0, 1.0, 0.0])
		var opts := {"light_layers": int(layer_of.call(space)) | MOVING_LAYER, "space": space}
		if e.has("box_m"):
			opts.box = Vector3(float(e.box_m[0]), float(e.box_m[1]), float(e.box_m[2]))
		start(String(e.recipe), Vector3(p.x, float(e.get("y_m", 0.0)), p.y), Vector3(float(f[0]), float(f[1]), float(f[2])), opts)


## The new ship: holes, brass and one-shots go. Placed effects keep running.
func clear_debris() -> void:
	decal_ring.clear()
	for d: Decal in _decals:
		d.visible = false
	casings.clear()
	magazines.clear()
	for l: Dictionary in _lights:
		if l.on and float(l.life) < INF:
			l.on = false
			(l.node as OmniLight3D).visible = false
	_casing_mm.visible_instance_count = 0
	_magazine_mm.visible_instance_count = 0
	for sheet: String in fields:
		fields[sheet].forget()
	_shake_m = 0.0


## The deck's gone.
func clear() -> void:
	for e: Dictionary in _emitters:
		if e.on:
			_end_emitter(e)
	clear_debris()
	surfaces.layout = null
	if _bind.is_valid():
		_bind = Callable()
	for sheet: String in _materials:
		_unmask(_materials[sheet])
	for p: Dictionary in _pools:
		_unmask(p.mat)


func _unmask(m: ShaderMaterial) -> void:
	m.set_shader_parameter("masked", false)
	m.set_shader_parameter("visible_mask", null)
	m.set_shader_parameter("memory_mask", null)


# --- one-shots ---

## Plays a one-shot recipe. `normal` is the way the surface faces. opts: `dir` (the shot's way, for the
## ricochet), `scale` (counts), `light_layers`, `quiet`. False if there's no such recipe.
func play(name: String, at: Vector3, normal := Vector3.UP, opts := {}) -> bool:
	if not cfg.recipes.has(name):
		push_error("Vfx: no recipe %s" % name)
		return false
	var r: Dictionary = cfg.recipes[name]
	if bool(r.get("loop", false)):
		return start(name, at, normal, opts) != 0
	var scale_by := float(opts.get("scale", 1.0))
	var layers: Array = r.get("layers", [])
	for layer: Dictionary in layers:
		var n := roundi(rng.randi_range(int(layer.count[0]), int(layer.count[1])) * scale_by)
		_spawn(layer, at, normal, n, Vector3.ZERO, Vector3.ZERO)
	if r.has("light"):
		_flash(r.light, at, int(opts.get("light_layers", ALL_LAYERS)))
	if r.has("decal"):
		var d: Dictionary = r.decal
		if bool(d.get("floor", false)):
			place_decal(d, Vector3(at.x, surfaces.floor_at(at), at.z), Vector3.UP)
		else:
			place_decal(d, at, normal)
	if not bool(opts.get("quiet", false)):
		_recipe_sound(r, at, normal, opts)
	if r.has("shake"):
		_shake(r.shake, at)
	played.emit(name, at)
	return true


## A round landed on something that isn't a body playing its own hit. `target` is null when cover stopped it.
func land(target: Object, point: Vector3, normal: Vector3, dir: Vector3, damage: float) -> String:
	var surface := surfaces.surface_of(target, point, normal)
	play(surfaces.recipe_for(surface), point, normal, {"dir": dir})
	if target == null:
		var chew: String = surfaces.recipe_for("chew")
		play(chew, point, normal, {"scale": damage / float(cfg.recipes[chew].scale_by_damage)})
	return surface


## A body's hit reaction: its spray back at the shooter, and its splat on what's behind it. `hit` is the rifle
## contract's dictionary. `body` isn't a surface for its own splat.
func body_hit(surface: String, hit: Dictionary, body: RID = RID()) -> void:
	if not hit.has("point"):
		return
	var dir: Vector3 = hit.direction
	var at: Vector3 = hit.point
	var name := surfaces.recipe_for(surface)
	play(name, at, -dir, {"dir": dir})
	var r: Dictionary = cfg.recipes[name]
	if r.has("splat"):
		_splat(r.splat, at, dir, body)


## On whatever is `reach_m` behind the hit, or else the floor under it.
func _splat(s: Dictionary, at: Vector3, dir: Vector3, body: RID) -> void:
	var reach := float(s.reach_m)
	if reach > 0.0:
		var q := PhysicsRayQueryParameters3D.create(at, at + dir * reach)
		if body.is_valid():
			q.exclude = [body]
		var hit: Dictionary = get_viewport().find_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty() and hit.collider is StaticBody3D:
			# A ray that starts inside a wall has no normal.
			place_decal(s, hit.position, hit.normal if hit.normal != Vector3.ZERO else -dir)
			return
	var floor_y := surfaces.floor_at(at)
	place_decal(s, Vector3(at.x, floor_y, at.z), Vector3.UP)


## One decal from a recipe's {sheet, frames [from, to], size_m [min, max], tint}. Projected, so it follows
## what's under it. Returns its slot.
func place_decal(d: Dictionary, at: Vector3, normal: Vector3) -> int:
	var slot := decal_ring.place()
	var n: Decal = _decals[slot]
	var frame := rng.randi_range(int(d.frames[0]), int(d.frames[1]))
	var size := rng.randf_range(float(d.size_m[0]), float(d.size_m[1]))
	n.texture_albedo = _decal_tex["%s_%d" % [d.sheet, frame]]
	n.modulate = Color(d.get("tint", "ffffff"))
	var depth := float(cfg.decals.depth_m)
	n.size = Vector3(size, depth, size)
	var up := normal.normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < float(cfg.decals.parallel_dot) else Vector3.RIGHT).normalized()
	var b := Basis(side, up, side.cross(up)).rotated(up, rng.randf_range(0.0, TAU))
	n.global_transform = Transform3D(b, at + up * float(cfg.decals.out_m))
	n.visible = true
	decal_placed.emit(String(d.sheet), frame, at, up)
	return slot


func _recipe_sound(r: Dictionary, at: Vector3, normal: Vector3, opts: Dictionary) -> void:
	var mix := {"muffle": true}
	if r.has("sound"):
		Audio.play(String(r.sound), at, mix)
	if r.has("voice"):
		Audio.play(String(r.voice), at, mix)
	if r.has("ricochet") and opts.has("dir"):
		var rc: Dictionary = r.ricochet
		if SurfaceMap.incidence_deg(opts.dir, normal) < float(rc.shallow_deg) and rng.randf() < float(rc.chance):
			Audio.play(String(rc.cue), at, mix)
	if r.has("sound_by_distance"):
		var s: Dictionary = r.sound_by_distance
		var near := Audio.listener_distance(at) <= float(s.near_m)
		Audio.play(String(s.near if near else s.far), at, mix)
	if bool(r.get("room_tail", false)):
		Audio.play(Audio.room_tail(_space_at(at)), at, mix)


func _space_at(at: Vector3) -> String:
	return surfaces.layout.space_at(Vector2(at.x, at.z)) if surfaces.layout != null else ""


func _shake(s: Dictionary, at: Vector3) -> void:
	var share := 1.0 - clampf(Audio.listener_distance(at) / float(s.reach_m), 0.0, 1.0)
	var m := float(s.kick_m) * share
	if m > _shake_m:
		_shake_m = m
		_shake_full = m
		_shake_recover = float(s.recover_s)


## This frame's camera offset from anything heavy (metres, screen x and y).
func camera_shake() -> Vector2:
	return Vector2.from_angle(rng.randf() * TAU) * _shake_m if _shake_m > 0.0 else Vector2.ZERO


func _spawn(layer: Dictionary, at: Vector3, normal: Vector3, count: int, box: Vector3, draft: Vector3) -> void:
	var sheet := String(layer.sheet)
	var field: ParticleField = fields[sheet]
	var c: Dictionary = cfg.sheets[sheet]
	var m: Dictionary = manifest[String(c.get("texture", sheet))]
	var axis: Vector3 = Vector3.UP if String(layer.axis) == "up" else normal.normalized()
	var spread := tan(deg_to_rad(minf(float(layer.spread_deg), float(cfg.max_spread_deg))))
	var color := Color(layer.color).srgb_to_linear()
	var energy := float(layer.get("energy", 1.0))
	color = Color(color.r * energy, color.g * energy, color.b * energy, float(layer.get("alpha", 1.0)))
	var offset := float(layer.get("offset_m", 0.0))
	var lift := float(layer.get("lift_m", 0.0))
	var play_how := String(layer.get("play", "hold"))
	var frames := float(m.frames)
	for i in count:
		var dir := axis
		if spread > 0.0:
			dir = (axis + _in_ball() * spread).normalized()
		var from := at + Vector3.UP * lift + _in_ball() * offset
		if box != Vector3.ZERO:
			from += Vector3(rng.randf_range(-0.5, 0.5) * box.x, rng.randf_range(-0.5, 0.5) * box.y, rng.randf_range(-0.5, 0.5) * box.z)
		var life := rng.randf_range(float(layer.life_s[0]), float(layer.life_s[1]))
		var vel := dir * rng.randf_range(float(layer.speed_m_s[0]), float(layer.speed_m_s[1])) + draft
		var fps := 0.0
		match play_how:
			"fit":
				fps = frames / life
			"manifest":
				fps = float(m.fps)
			"loop":
				fps = -float(layer.get("fps", m.fps))
		var frame := float(rng.randi_range(0, int(frames) - 1)) if fps == 0.0 and frames > 1.0 else 0.0
		field.spawn(now, from, vel, life, rng.randf_range(float(layer.size_m[0]), float(layer.size_m[1])),
				rng.randf_range(float(layer.size_end_m[0]), float(layer.size_end_m[1])), float(layer.get("gravity_m_s2", 0.0)),
				float(layer.get("drag_per_s", 0.0)), color, frame, frames, fps, float(layer.get("bounce", -1.0)))


## A point in the unit ball, near enough: cheap, and nobody can tell.
func _in_ball() -> Vector3:
	return Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * float(cfg.ball_share)


# --- running effects ---

## Starts a looping recipe. opts: `box` (Vector3, overrides the layers' box), `light_layers`, `space` (its draft).
## Returns an id for move() and stop(), 0 if every emitter is busy or there's no such recipe.
func start(name: String, at: Vector3, facing := Vector3.UP, opts := {}) -> int:
	if not cfg.recipes.has(name):
		push_error("Vfx: no recipe %s" % name)
		return 0
	var e: Dictionary = {}
	for slot: Dictionary in _emitters:
		if not slot.on:
			e = slot
			break
	if e.is_empty():
		return 0
	var r: Dictionary = cfg.recipes[name]
	e.on = true
	e.id = _next_id
	_next_id += 1
	e.recipe = r
	e.name = name
	e.at = at
	e.facing = facing.normalized()
	e.box = opts.get("box", Vector3.ZERO)
	e.left = float(r.get("life_s", INF))
	e.cull = float(r.get("cull_m", cfg.default_cull_m))
	e.draft = Vector3.ZERO
	if bool(r.get("draft", false)):
		var space := String(opts.get("space", _space_at(at)))
		var dr: Array = (cfg.room_draft as Dictionary).get(space, [0.0, 0.0])
		e.draft = Vector3(float(dr[0]), 0.0, float(dr[1]))
	var layers: Array = r.get("layers", [])
	for i in layers.size():
		e.timers[i] = 0.0
	e.light = -1
	if r.has("light"):
		e.light = _take_light(r.light, at, int(opts.get("light_layers", ALL_LAYERS)), INF)
	e.pool = -1
	if r.has("pool"):
		e.pool = _take_pool(r.pool, at)
	e.sound = ""
	if r.has("sound_loop"):
		e.sound = "vfx:%d" % e.id
		Audio.loop(String(e.sound), String(r.sound_loop), at)
	e.crackle = _roll(r.crackle.every_s) if r.has("crackle") else 0.0
	e.pulse_on = true
	e.pulse = _roll(r.pulse.on_s) if r.has("pulse") else 0.0
	played.emit(name, at)
	return int(e.id)


func move(id: int, at: Vector3, facing := Vector3.ZERO) -> void:
	for e: Dictionary in _emitters:
		if e.on and int(e.id) == id:
			e.at = at
			if facing != Vector3.ZERO:
				e.facing = facing.normalized()
			return


func stop(id: int) -> void:
	for e: Dictionary in _emitters:
		if e.on and int(e.id) == id:
			_end_emitter(e)
			return


func running(id: int) -> bool:
	for e: Dictionary in _emitters:
		if e.on and int(e.id) == id:
			return true
	return false


func running_count() -> int:
	var n := 0
	for e: Dictionary in _emitters:
		if e.on:
			n += 1
	return n


func _end_emitter(e: Dictionary) -> void:
	e.on = false
	if int(e.light) >= 0:
		_lights[int(e.light)].on = false
		(_lights[int(e.light)].node as OmniLight3D).visible = false
	if int(e.pool) >= 0:
		_pools[int(e.pool)].on = false
		(_pools[int(e.pool)].node as MeshInstance3D).visible = false
	if String(e.sound) != "":
		Audio.stop_loop(String(e.sound))


func _roll(range_s: Array) -> float:
	return rng.randf_range(float(range_s[0]), float(range_s[1]))


func _step_emitters(delta: float) -> void:
	var near_to: Variant = Audio.listener_position()
	for e: Dictionary in _emitters:
		if not e.on:
			continue
		e.left = float(e.left) - delta
		if float(e.left) <= 0.0:
			_end_emitter(e)
			continue
		if near_to != null and (e.at as Vector3).distance_to(near_to) > float(e.cull):
			continue
		var r: Dictionary = e.recipe
		if r.has("pulse"):
			_step_pulse(e, r.pulse, delta)
		if r.has("crackle"):
			e.crackle = float(e.crackle) - delta
			if float(e.crackle) <= 0.0:
				e.crackle = _roll(r.crackle.every_s)
				Audio.play(String(r.crackle.cue), e.at, {"muffle": true})
		if not bool(e.pulse_on):
			continue
		var layers: Array = r.layers
		var timers: PackedFloat32Array = e.timers
		for i in layers.size():
			var layer: Dictionary = layers[i]
			var n := 0
			if layer.has("burst_every_s"):
				timers[i] -= delta
				if timers[i] <= 0.0:
					timers[i] = _roll(layer.burst_every_s)
					n = rng.randi_range(int(layer.count[0]), int(layer.count[1]))
			else:
				timers[i] += delta * float(layer.rate_per_s)
				n = int(timers[i])
				timers[i] -= n
			if n > 0:
				var box: Vector3 = e.box
				if box == Vector3.ZERO and layer.has("box_m"):
					box = Vector3(float(layer.box_m[0]), float(layer.box_m[1]), float(layer.box_m[2]))
				_spawn(layer, e.at, e.facing, n, box, e.draft)
		e.timers = timers


func _step_pulse(e: Dictionary, p: Dictionary, delta: float) -> void:
	e.pulse = float(e.pulse) - delta
	if float(e.pulse) > 0.0:
		return
	e.pulse_on = not bool(e.pulse_on)
	e.pulse = _roll(p.on_s if e.pulse_on else p.off_s)
	if String(e.sound) != "":
		Audio.set_loop_volume(String(e.sound), 0.0 if e.pulse_on else float(p.quiet_db))


# --- lights and pools ---

func _flash(l: Dictionary, at: Vector3, layers: int) -> void:
	_take_light(l, at, layers, float(l.life_s))


func _take_light(l: Dictionary, at: Vector3, layers: int, life: float) -> int:
	for i in _lights.size():
		var slot: Dictionary = _lights[i]
		if slot.on:
			continue
		var n: OmniLight3D = slot.node
		n.light_color = Color(l.color)
		n.omni_range = float(l.range_m)
		n.light_cull_mask = layers
		n.global_position = at + Vector3.UP * float(l.get("height_m", 0.0))
		n.light_energy = float(l.energy)
		n.visible = true
		slot.on = true
		slot.left = life
		slot.life = life
		slot.energy = float(l.energy)
		slot.hz = float(l.get("flicker_hz", 0.0))
		slot.depth = float(l.get("flicker_depth", 0.0))
		slot.phase = rng.randf() * TAU
		return i
	return -1


func _step_lights(delta: float) -> void:
	for slot: Dictionary in _lights:
		if not slot.on:
			continue
		var n: OmniLight3D = slot.node
		if float(slot.life) < INF:
			slot.left = float(slot.left) - delta
			if float(slot.left) <= 0.0:
				slot.on = false
				n.visible = false
				continue
			n.light_energy = float(slot.energy) * float(slot.left) / float(slot.life)
		elif float(slot.hz) > 0.0:
			# Two beating sines: a fault, not a metronome.
			var t := now * float(slot.hz) * TAU + float(slot.phase)
			var wobble := 0.5 + 0.5 * sin(t) * sin(t * float(cfg.flicker_beat))
			n.light_energy = float(slot.energy) * (1.0 - float(slot.depth) * wobble)


func _take_pool(p: Dictionary, at: Vector3) -> int:
	for i in _pools.size():
		var slot: Dictionary = _pools[i]
		if slot.on:
			continue
		var m: ShaderMaterial = slot.mat
		m.set_shader_parameter("puddle", _decal_tex[String(p.mask)])
		m.set_shader_parameter("noise", load(texture_path("liquid_noise")))
		m.set_shader_parameter("pool_color", Color(p.color))
		m.set_shader_parameter("edge_color", Color(p.edge_color))
		m.set_shader_parameter("edge_energy", float(p.edge_energy))
		m.set_shader_parameter("scroll_a", Vector2(float(p.scroll_a[0]), float(p.scroll_a[1])))
		m.set_shader_parameter("scroll_b", Vector2(float(p.scroll_b[0]), float(p.scroll_b[1])))
		m.set_shader_parameter("noise_scale_m", float(p.noise_scale_m))
		var n: MeshInstance3D = slot.node
		n.scale = Vector3(float(p.size_m), 1.0, float(p.size_m))
		n.global_position = Vector3(at.x, float(cfg.floor_y_m), at.z)
		n.visible = true
		slot.on = true
		return i
	return -1


# --- brass ---

## One casing from the ejection port, thrown right and up off a gun firing along `dir`.
func eject_casing(port: Vector3, dir: Vector3) -> void:
	_throw(casings, cfg.casing, port, dir)


## The old magazine, out of the bottom of the gun.
func drop_magazine(port: Vector3, dir: Vector3) -> void:
	_throw(magazines, cfg.magazine, port + Vector3.DOWN * float(cfg.magazine.drop_below_m), dir)


func _throw(field: BrassField, c: Dictionary, from: Vector3, dir: Vector3) -> void:
	var right := dir.cross(Vector3.UP).normalized()
	var vel: Vector3 = right * _roll(c.speed_right_m_s) + Vector3.UP * _roll(c.speed_up_m_s) - dir * _roll(c.speed_back_m_s)
	var wall_at := Vector3.ZERO
	var wall_normal := Vector3.ZERO
	var flat := Vector3(vel.x, 0.0, vel.z)
	if flat != Vector3.ZERO:
		var q := PhysicsRayQueryParameters3D.create(from, from + flat.normalized() * float(c.wall_reach_m))
		var hit: Dictionary = get_viewport().find_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty() and hit.collider is StaticBody3D:
			wall_at = hit.position
			wall_normal = hit.normal
	var g := float(c.gravity_m_s2)
	var airtime := (vel.y + sqrt(maxf(vel.y * vel.y + 2.0 * g * from.y, 0.0))) / g
	var floor_y := surfaces.floor_at(from + flat * airtime)
	var slot := field.throw(from, vel, floor_y, wall_at, wall_normal, rng)
	_place_brass(field, field == casings, slot)
	var mm: MultiMesh = _casing_mm if field == casings else _magazine_mm
	mm.visible_instance_count = field.count


func _place_brass(field: BrassField, is_casing: bool, slot: int) -> void:
	var s: Dictionary = field.slots[slot]
	var mm: MultiMesh = _casing_mm if is_casing else _magazine_mm
	mm.set_instance_transform(slot, Transform3D((s.basis as Basis).scaled(Vector3.ONE * float(field.cfg.scale)), s.pos))


func _step_brass(field: BrassField, is_casing: bool, delta: float, sounds: Dictionary) -> void:
	if field.moving_count() == 0:
		return
	field.step(delta)
	for slot: int in field.moved:
		_place_brass(field, is_casing, slot)
	var steps: Dictionary = Data.value("audio", "footsteps")
	for slot: int in field.bounced:
		var at: Vector3 = field.slots[slot].pos
		Audio.play(String(sounds[surfaces.ground_at(at, steps)]), at, {"muffle": true})


# --- the frame ---

func _process(delta: float) -> void:
	advance(delta)


## Time passes. Public so tests can step it.
func advance(delta: float) -> void:
	now += delta
	_step_emitters(delta)
	_step_lights(delta)
	_step_decals(delta)
	_step_brass(casings, true, delta, Data.value("audio", "tinks"))
	_step_brass(magazines, false, delta, Data.value("audio", "clatter"))
	if _shake_m > 0.0:
		_shake_m = maxf(_shake_m - _shake_full / _shake_recover * delta, 0.0)
	for p: Dictionary in _pools:
		if p.on:
			(p.mat as ShaderMaterial).set_shader_parameter("now", now)
	for sheet: String in fields:
		_draw_sheet(sheet)
	if _warm_frames > 0:
		_warm_frames -= 1
		if _warm_frames == 0:
			_casing_mm.visible_instance_count = casings.count
			_magazine_mm.visible_instance_count = magazines.count


func _draw_sheet(sheet: String) -> void:
	var f: ParticleField = fields[sheet]
	var mi: MultiMeshInstance3D = _meshes[sheet]
	var live := f.active(now) or _warm_frames > 0
	if mi.visible != live:
		mi.visible = live
	if not live:
		return
	(_materials[sheet] as ShaderMaterial).set_shader_parameter("now", now)
	if f.dirty:
		f.dirty = false
		RenderingServer.multimesh_set_buffer(mi.multimesh.get_rid(), f.buffer)


func _step_decals(delta: float) -> void:
	for slot: int in decal_ring.step(delta):
		_decals[slot].visible = false
	for i in _decals.size():
		if decal_ring.fading(i):
			_decals[i].albedo_mix = decal_ring.strength(i)
		elif _decals[i].albedo_mix != 1.0:
			_decals[i].albedo_mix = 1.0


# --- for tests and the readout ---

func live_particles() -> int:
	var n := 0
	for sheet: String in fields:
		n += fields[sheet].alive_count(now)
	return n


func capacity() -> int:
	var n := 0
	for sheet: String in fields:
		n += fields[sheet].capacity
	return n


func visible_decals() -> int:
	var n := 0
	for d: Decal in _decals:
		if d.visible:
			n += 1
	return n


## What the pools hold. It must not change after warm-up.
func pool_counts() -> Dictionary:
	return {"nodes": _count_nodes(self), "particles": capacity(), "decals": _decals.size(), "lights": _lights.size(),
			"emitters": _emitters.size(), "pools": _pools.size(), "casings": casings.slots.size(), "magazines": magazines.slots.size()}


func _count_nodes(n: Node) -> int:
	var c := 1
	for k: Node in n.get_children():
		c += _count_nodes(k)
	return c


## Everything the recipes ask for, or what's wrong with it. An empty list is a clean book.
func problems() -> PackedStringArray:
	var out := PackedStringArray()
	for sheet: String in cfg.sheets:
		var c: Dictionary = cfg.sheets[sheet]
		var t := String(c.get("texture", sheet))
		if not manifest.has(t):
			out.append("sheet %s: no %s in the manifest" % [sheet, t])
		elif not ResourceLoader.exists(texture_path(t)):
			out.append("sheet %s: no file %s" % [sheet, texture_path(t)])
	for name: String in cfg.recipes:
		var r: Dictionary = cfg.recipes[name]
		for layer: Dictionary in r.get("layers", []):
			if not cfg.sheets.has(String(layer.get("sheet", ""))):
				out.append("%s: no sheet %s" % [name, layer.get("sheet", "")])
		for key: String in ["decal", "splat"]:
			if r.has(key):
				for f in range(int(r[key].frames[0]), int(r[key].frames[1]) + 1):
					if not _decal_tex.has("%s_%d" % [r[key].sheet, f]) or _decal_tex["%s_%d" % [r[key].sheet, f]] == null:
						out.append("%s: no decal %s_%d" % [name, r[key].sheet, f])
		if r.has("pool") and not _decal_tex.has(String(r.pool.mask)):
			out.append("%s: no pool mask %s" % [name, r.pool.mask])
		for key: String in ["sound", "voice", "sound_loop"]:
			if r.has(key) and not Audio.bank.has(String(r[key])) and not Audio.bank.is_group(String(r[key])):
				out.append("%s: no sound %s" % [name, r[key]])
	return out
