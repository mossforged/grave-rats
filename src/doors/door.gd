extends Node3D
## One sliding bulkhead door in a doorway from DeckLayout. The panel's collision and its sight
## rect both follow the panel, so a half-open door leaves a real half-size gap.
## Sight contract (src/sight): group "sight_occluder", sight_rect(), blocks_sight().

const DoorState := preload("res://src/doors/door_state.gd")
const KitPieces := preload("res://src/kit/kit_pieces.gd")
const KitMaterials := preload("res://src/kit/kit_materials.gd")
const BEACON := preload("res://src/sight/beacon.gdshader")
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
var _lamp_mat: ShaderMaterial
var _state_hex := ""
var _height := 0.0
## () -> bool: may this machine change this door? Empty: yes.
var authority := Callable()
var _last_state := -1
var _panel_mat: StandardMaterial3D
var _seam: MeshInstance3D
var _seam_mat: StandardMaterial3D
var _leak: OmniLight3D
var _look: Dictionary
var _leaf_h := 0.0
var _leaf_t := 0.0
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
	var kit: Dictionary = KitMaterials.cfg()
	_look = kit.door_look
	_leaf_h = float(kit.dims.door_aperture_h_m)
	_leaf_t = float(kit.dims.door_leaf_t_m)
	# Collision keeps the T006 box; what you see is A006's thinner, lower leaf inside it.
	var h := _height - float(cfg.panel_top_gap_m)
	var size := Vector3(opening.size.x, h, t) if along_x else Vector3(t, h, opening.size.y)
	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	add_child(_pivot)
	# Only a door facing the camera can hide anything: side doors stay tall, so they read as shut.
	if along_x:
		_join_cutaway(_pivot, opening)
	_panel = MeshInstance3D.new()
	_panel.name = "Panel"
	_panel.mesh = KitPieces.door_leaf(opening.size.x if along_x else opening.size.y, _leaf_h, _leaf_t)
	_panel.set_meta("kit_piece", "door_leaf")
	# Its own copy of the paint: each leaf darkens by its own damage.
	_panel_mat = KitMaterials.material("leaf").duplicate()
	_panel.set_surface_override_material(0, _panel_mat)
	_pivot.add_child(_panel)
	_make_seam()
	_body = StaticBody3D.new()
	_body.name = "PanelBody"
	var box := BoxShape3D.new()
	box.size = size
	var cs := CollisionShape3D.new()
	cs.shape = box
	_body.add_child(cs)
	add_child(_body)
	# One light in three places. It draws after the sight mask, so a door you've seen stays readable
	# outside the cone (T011, the study's fairness rule).
	_lamp_mat = ShaderMaterial.new()
	_lamp_mat.shader = BEACON
	_lamp_mat.set_shader_parameter("energy", float(cfg.lamp_energy))
	_lamp_mat.set_shader_parameter("unknown_share", float(_look.floor_strip.unknown_share))
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
	post.add_child(_make_state_strip(off))
	for side_sign: float in [-1.0, 1.0]:
		add_child(_make_floor_strip(side_sign), true)


## The same state light on top of the header: from above, a side door's jambs hide the lamp's faces.
func _make_state_strip(post_offset: Vector2) -> MeshInstance3D:
	var s: Array = _look.strip_size_m
	var mesh := BoxMesh.new()
	mesh.size = Vector3(float(s[0]), float(s[1]), float(s[2])) if along_x else Vector3(float(s[2]), float(s[1]), float(s[0]))
	var strip := MeshInstance3D.new()
	strip.name = "StateStrip"
	strip.mesh = mesh
	strip.material_override = _lamp_mat
	strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var rail := float(KitMaterials.cfg().dims.header_rail_m) * 0.5
	var across := float(opening.size.y if along_x else opening.size.x) * 0.5 - rail
	strip.position = Vector3(-post_offset.x, _height + float(s[1]) * 0.5, -post_offset.y + across) if along_x \
			else Vector3(-post_offset.x + across, _height + float(s[1]) * 0.5, -post_offset.y)
	return strip


## The state along the threshold, on the floor just outside the wall: nothing hides it from above,
## however the door faces. `side_sign` picks which side of the wall.
func _make_floor_strip(side_sign: float) -> MeshInstance3D:
	var f: Dictionary = _look.floor_strip
	var length := float(opening.size.x if along_x else opening.size.y) * float(f.length_frac)
	var w := float(f.width_m)
	var h := float(f.height_m)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(length, h, w) if along_x else Vector3(w, h, length)
	var strip := MeshInstance3D.new()
	strip.name = "FloorStrip"
	strip.mesh = mesh
	strip.material_override = _lamp_mat
	strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var out := float(opening.size.y if along_x else opening.size.x) * 0.5 + float(f.out_m)
	strip.position = Vector3(0.0, h * 0.5, side_sign * out) if along_x else Vector3(side_sign * out, h * 0.5, 0.0)
	return strip


## `bind` is SightMask.bind.
func use_mask(bind: Callable) -> void:
	bind.call(_lamp_mat)
	_lamp_mat.set_shader_parameter("masked", true)


## The colour every state light on this door shows right now.
func state_color() -> Color:
	return Color(_state_hex)


## The warm seam (and the spill it casts) that A006-03c shows once a leaf is pushed out of true.
func _make_seam() -> void:
	_seam = MeshInstance3D.new()
	_seam.name = "Seam"
	_seam.mesh = KitPieces.door_seam(opening.size.x if along_x else opening.size.y, _leaf_h)
	_seam_mat = KitMaterials.material("leak").duplicate()
	_seam.set_surface_override_material(0, _seam_mat)
	_seam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_seam.visible = false
	_pivot.add_child(_seam)
	if not along_x:
		_seam.rotation.y = -PI * 0.5
	_seam.position.y = _leaf_h * 0.5
	_leak = OmniLight3D.new()
	_leak.name = "Leak"
	_leak.light_color = Color(String(_look.leak_color))
	_leak.omni_range = float(_look.leak_light_range_m)
	_leak.visible = false
	add_child(_leak)


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
	if authority.is_valid() and not authority.call():
		return
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
	if authority.is_valid() and not authority.call():
		return ""
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
	var colors: Dictionary = cfg.colors
	var hex: String = colors.lamp_broken if door_state.is_broken() else (colors.lamp_locked if door_state.is_locked() else (
			colors.lamp_open if not door_state.blocks() else (colors.lamp_bashed if door_state.bash_progress > 0.0 else colors.lamp_closed)))
	if hex != _state_hex:
		_state_hex = hex
		_lamp_mat.set_shader_parameter("beacon_color", Color(hex))
	var s := int(door_state.state)
	if s == _last_state:
		return
	_last_state = s
	state_changed.emit(self)


## The panel you see: shaking under blows, its mesh dented by the damage so far, flat on the floor
## once broken. Fully slid away it lies inside the wall and is hidden: there it fought the door post's
## surfaces.
func _show_panel(local: Vector3, _half_h: float) -> void:
	var b: Dictionary = cfg.bash
	var broken := door_state.is_broken()
	var colors: Dictionary = cfg.colors
	var half := _leaf_h * 0.5
	var base := Vector3(local.x, half, local.z)
	_panel.visible = broken or door_state.progress < 1.0 - float(cfg.open_tolerance)
	var dented := door_state.bash_progress
	var tint: Color
	if broken:
		tint = Color(colors.panel_broken)
	elif door_state.is_locked():
		tint = Color(colors.panel_locked)
	else:
		tint = Color(colors.panel).lerp(Color(colors.panel_dented), dented)
	_panel_mat.albedo_color = tint
	_set_dent(dented, _fall_sign)
	var seen := dented > 0.0 and not broken and _panel.visible
	_seam.visible = seen
	_seam.position = Vector3(local.x, half, local.z)
	_seam_mat.emission_energy_multiplier = dented * float(_look.seam_energy)
	_leak.visible = seen
	if seen:
		_leak.light_energy = dented * float(_look.leak_light_energy)
		var o := float(_look.leak_light_out_m) * _fall_sign
		_leak.position = Vector3(0, float(_look.leak_light_y_m), o) if along_x else Vector3(o, float(_look.leak_light_y_m), 0)
	var turn := 0.0 if along_x else -PI * 0.5
	if broken:
		var lean := deg_to_rad(float(b.broken_lean_deg)) * _fall_sign
		var out := sin(lean) * half
		var y := cos(lean) * half + _leaf_t * 0.5
		_panel.position = Vector3(0, y, out) if along_x else Vector3(out, y, 0)
		_panel.rotation = Vector3(lean, turn, 0) if along_x else Vector3(-lean, turn, 0)
		return
	_panel.rotation = Vector3(0, turn, 0)
	var shake := 0.0
	if _shake_left > 0.0:
		shake = sin(_shake_t * TAU * float(b.shake_hz)) * float(b.shake_m) * _shake_left / float(b.shake_s)
	_panel.position = base + (Vector3(0, 0, shake) if along_x else Vector3(shake, 0, 0))


## The damage so far on the leaf's mesh, bulging the way the blows push. A side door's leaf is turned a
## quarter, so its +Z points west: the blend shape that goes east is "dent_back".
func _set_dent(amount: float, push: float) -> void:
	var toward_front := push > 0.0 if along_x else push < 0.0
	_panel.set_blend_shape_value(0, amount if toward_front else 0.0)
	_panel.set_blend_shape_value(1, 0.0 if toward_front else amount)
