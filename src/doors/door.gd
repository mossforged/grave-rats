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
var _panel: MeshInstance3D
var _body: StaticBody3D
var _lamp_mat: StandardMaterial3D
var _height := 0.0
var _last_state := -1


## `door` is one entry of DeckLayout.doors, `spec` the matching entry of data/deck.json "doors".
func setup(door: Dictionary, spec: Dictionary, config: Dictionary, wall_height: float) -> void:
	cfg = config
	opening = door.rect
	along_x = door.along_x
	space = String(door.space)
	side = String(door.side)
	slide = float(spec.get("slide", 1))
	_height = wall_height
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
	_pivot.set_meta("cutaway_rect", opening)
	_pivot.set_meta("cutaway_height", _height)
	_pivot.add_to_group(CUTAWAY_GROUP)
	add_child(_pivot)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(colors.panel_locked if door_state.is_locked() else colors.panel)
	mat.roughness = float(cfg.panel_roughness)
	var mesh := BoxMesh.new()
	mesh.size = size
	_panel = MeshInstance3D.new()
	_panel.name = "Panel"
	_panel.mesh = mesh
	_panel.material_override = mat
	_pivot.add_child(_panel)
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
	_pivot.add_child(lamp)


func tick(delta: float, actors: Array) -> void:
	door_state.step(delta, doorway_clear(actors))
	_apply()


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
	var local := Vector3(off.x, (_height - float(cfg.panel_top_gap_m)) * 0.5, off.y)
	_panel.position = local
	_body.position = local
	var s := int(door_state.state)
	if s == _last_state:
		return
	_last_state = s
	var colors: Dictionary = cfg.colors
	var hex: String = colors.lamp_locked if door_state.is_locked() else (
			colors.lamp_closed if door_state.blocks() else colors.lamp_open)
	_lamp_mat.albedo_color = Color(hex)
	_lamp_mat.emission = Color(hex)
	state_changed.emit(self)
