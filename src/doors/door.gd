extends Node3D
## One sliding bulkhead door in a doorway from DeckLayout. The panel's collision and its sight
## rect both follow the panel, so a half-open door leaves a real half-size gap.
## Sight contract (src/sight): group "sight_occluder", sight_rect(), blocks_sight().

const DoorState := preload("res://src/doors/door_state.gd")
const CUTAWAY_GROUP := &"camera_cutaway"  # the camera rig's contract
const OCCLUDER_GROUP := &"sight_occluder"  # src/sight's contract

signal state_changed(door: Node3D)

var door_state: DoorState
var cfg: Dictionary
var opening: Rect2
var along_x := true
var slide := 1.0
var space := ""
var side := ""

var _pivot: Node3D
var _frame_rect: Rect2
var _panel: MeshInstance3D
var _body: StaticBody3D
var _lamp_mat: StandardMaterial3D
var _height := 0.0
var _last_state := -1
var _panel_mat: StandardMaterial3D
var _dents: Array = []
var _shake_left := 0.0
var _shake_t := 0.0
var _fall_sign := 1.0


## `door` is one entry of DeckLayout.doors, `spec` the matching entry of data/deck.json "doors".
func setup(door: Dictionary, spec: Dictionary, config: Dictionary, wall_height: float) -> void:
	cfg = config
	opening = door.rect
	along_x = door.along_x
	space = String(door.space)
	side = String(door.side)
	slide = float(spec.get("slide", 1))
	_height = wall_height
	_frame_rect = door.frames[0]
	door_state = DoorState.new(cfg, String(spec.get("state", "closed")))
	name = "Door_%s_%s" % [space, side]
	add_to_group(OCCLUDER_GROUP)
	var c := opening.get_center()
	position = Vector3(c.x, 0, c.y)
	_build()
	_apply()


func _build() -> void:
	var t := float(cfg.panel_thickness_m)
	var colors: Dictionary = cfg.colors
	# A hair under the wall top: slid away, the panel lies inside the wall and must not z-fight it.
	var h := _height - float(cfg.panel_top_gap_m)
	var size := Vector3(opening.size.x, h, t) if along_x else Vector3(t, h, opening.size.y)
	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	add_child(_pivot)
	# Only a door facing the camera can hide anything: side doors stay tall, so they read as shut.
	if along_x:
		_join_cutaway(_pivot, opening)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(colors.panel_locked if door_state.is_locked() else colors.panel)
	mat.roughness = float(cfg.panel_roughness)
	_panel_mat = mat
	var mesh := BoxMesh.new()
	mesh.size = size
	_panel = MeshInstance3D.new()
	_panel.name = "Panel"
	_panel.mesh = mesh
	_panel.material_override = mat
	_pivot.add_child(_panel)
	_make_dents(size)
	_body = StaticBody3D.new()
	_body.name = "PanelBody"
	var box := BoxShape3D.new()
	box.size = size
	var cs := CollisionShape3D.new()
	cs.shape = box
	_body.add_child(cs)
	add_child(_body)
	_lamp_mat = StandardMaterial3D.new()
	_lamp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_lamp_mat.emission_enabled = true
	_lamp_mat.emission_energy_multiplier = float(cfg.lamp_energy)
	# The lamp is on the frame post, so it follows the post when the cut-away drops it.
	var lamp_mesh := BoxMesh.new()
	var ls: Array = cfg.lamp_size_m
	lamp_mesh.size = Vector3(float(ls[0]), float(ls[1]), float(ls[2])) if along_x \
			else Vector3(float(ls[2]), float(ls[1]), float(ls[0]))
	var lamp := MeshInstance3D.new()
	lamp.name = "Lamp"
	lamp.mesh = lamp_mesh
	lamp.material_override = _lamp_mat
	lamp.position.y = float(cfg.lamp_height_m)
	lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var post := Node3D.new()
	post.name = "LampPost"
	var off := _frame_rect.get_center() - opening.get_center()
	post.position = Vector3(off.x, 0, off.y)
	_join_cutaway(post, _frame_rect)
	add_child(post)
	post.add_child(lamp)


## Dark dents on both faces of the panel, shown one by one as a stalker works on it.
func _make_dents(panel_size: Vector3) -> void:
	var b: Dictionary = cfg.bash
	var s: Array = b.dent_size_m
	var rng := RandomNumberGenerator.new()
	rng.seed = int(b.dent_seed) + hash(name)
	var mesh := BoxMesh.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(cfg.colors.panel_dented)
	mat.roughness = float(cfg.panel_roughness)
	mesh.material = mat
	mesh.size = Vector3(float(s[0]), float(s[1]), panel_size.z + float(s[2])) if along_x \
			else Vector3(panel_size.x + float(s[2]), float(s[1]), float(s[0]))
	for i in int(b.dent_count):
		var dent := MeshInstance3D.new()
		dent.name = "Dent%d" % i
		dent.mesh = mesh
		var along := rng.randf_range(-0.5, 0.5) * (panel_size.x if along_x else panel_size.z) * (1.0 - float(s[0]))
		var up := rng.randf_range(-0.5, 0.5) * panel_size.y * (1.0 - float(s[1]))
		dent.position = Vector3(along, up, 0.0) if along_x else Vector3(0.0, up, along)
		dent.visible = false
		_panel.add_child(dent)
		_dents.append(dent)


func _join_cutaway(node: Node3D, rect: Rect2) -> void:
	node.set_meta("cutaway_rect", rect)
	node.set_meta("cutaway_height", _height)
	node.add_to_group(CUTAWAY_GROUP)


func tick(delta: float, actors: Array) -> void:
	door_state.step(delta, doorway_clear(actors))
	_shake_left = maxf(_shake_left - delta, 0.0)
	_shake_t += delta
	_apply()


## Back to how the level starts it, dents and all.
func reset(start: String) -> void:
	door_state = DoorState.new(cfg, start)
	_shake_left = 0.0
	_last_state = -1
	_apply()


## A stalker worked on it for `delta`, from where it stands.
func bash(delta: float, from: Vector2) -> void:
	var c := opening.get_center()
	_fall_sign = -signf((from - c).y if along_x else (from - c).x)
	if door_state.bash(delta):
		_shake_left = 0.0
	_apply()


## One blow: the panel jumps and a dent may show. The time to break it is counted in bash().
func bang() -> void:
	_shake_left = float(cfg.bash.shake_s)


## Where a body of `radius` stands to work on this door, on the side of `from`.
func front_point(from: Vector2, radius: float) -> Vector2:
	var c := opening.get_center()
	if along_x:
		return Vector2(c.x, c.y + signf(from.y - c.y) * (opening.size.y * 0.5 + radius + float(cfg.bash.reach_m) * 0.5))
	return Vector2(c.x + signf(from.x - c.x) * (opening.size.x * 0.5 + radius + float(cfg.bash.reach_m) * 0.5), c.y)


func within_reach(p: Vector2, radius: float) -> bool:
	var q := Vector2(clampf(p.x, opening.position.x, opening.end.x), clampf(p.y, opening.position.y, opening.end.y))
	return q.distance_to(p) <= radius + float(cfg.bash.reach_m)


## E pressed by someone. Returns the door's answer (see DoorState.interact).
func interact(actors: Array) -> String:
	var answer := door_state.interact(doorway_clear(actors))
	_apply()
	return answer


## `actors` are {position: Vector2, radius: float}.
func doorway_clear(actors: Array) -> bool:
	for a: Dictionary in actors:
		var p: Vector2 = a.position
		var r := float(a.radius)
		var q := Vector2(clampf(p.x, opening.position.x, opening.end.x), clampf(p.y, opening.position.y, opening.end.y))
		if q.distance_squared_to(p) < r * r:
			return false
	return true


func blocks_sight() -> bool:
	return door_state.blocks()


## The panel's footprint right now (world XZ).
func sight_rect() -> Rect2:
	var t := float(cfg.panel_thickness_m)
	var c := opening.get_center()
	var off := door_state.progress * slide
	if along_x:
		return Rect2(c.x - opening.size.x * 0.5 + off * opening.size.x, c.y - t * 0.5, opening.size.x, t)
	return Rect2(c.x - t * 0.5, c.y - opening.size.y * 0.5 + off * opening.size.y, t, opening.size.y)


func _apply() -> void:
	var c := opening.get_center()
	var off := sight_rect().get_center() - c
	var half_h := (_height - float(cfg.panel_top_gap_m)) * 0.5
	var local := Vector3(off.x, half_h, off.y)
	_body.position = local
	_show_panel(local, half_h)
	var s := int(door_state.state)
	if s == _last_state:
		return
	_last_state = s
	var colors: Dictionary = cfg.colors
	var hex: String = colors.lamp_broken if door_state.is_broken() else (colors.lamp_locked if door_state.is_locked() else (
			colors.lamp_closed if door_state.blocks() else colors.lamp_open))
	_lamp_mat.albedo_color = Color(hex)
	_lamp_mat.emission = Color(hex)
	state_changed.emit(self)


## The panel you see: shaking under blows, showing its dents, flat on the floor once broken. Fully
## slid away it lies inside the wall and is hidden: there it fought the door post's surfaces.
func _show_panel(local: Vector3, half_h: float) -> void:
	var b: Dictionary = cfg.bash
	var broken := door_state.is_broken()
	var colors: Dictionary = cfg.colors
	_panel.visible = broken or door_state.progress < 1.0 - float(cfg.open_tolerance)
	var dented := door_state.bash_progress
	if not door_state.is_locked():
		_panel_mat.albedo_color = Color(colors.panel_broken) if broken else Color(colors.panel).lerp(Color(colors.panel_dented), dented)
	var shown := ceili(dented * _dents.size())
	for i in _dents.size():
		_dents[i].visible = i < shown
	if broken:
		var lean := deg_to_rad(float(b.broken_lean_deg)) * _fall_sign
		var out := sin(lean) * half_h
		var y := cos(lean) * half_h
		_panel.position = Vector3(0, y, out) if along_x else Vector3(out, y, 0)
		_panel.rotation = Vector3(lean, 0, 0) if along_x else Vector3(0, 0, -lean)
		return
	_panel.rotation = Vector3.ZERO
	var shake := 0.0
	if _shake_left > 0.0:
		shake = sin(_shake_t * TAU * float(b.shake_hz)) * float(b.shake_m) * _shake_left / float(b.shake_s)
	_panel.position = local + (Vector3(0, 0, shake) if along_x else Vector3(shake, 0, 0))
