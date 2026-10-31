extends Node
## The debug gallery, in the F1 panel's "Effects" section. Pick any recipe and spawn it at the cursor (P). Or
## stand a wall of each surface in front of the operator and play the shot on it (O), so John can judge by eye.
## Dev only; nothing here is part of the game.

const KitMaterials := preload("res://src/kit/kit_materials.gd")
const KitPieces := preload("res://src/kit/kit_pieces.gd")

var deck: Node
var picker: OptionButton
var walls: Array[StaticBody3D] = []

var _running: Array[int] = []
var _cfg: Dictionary
var _sequence_on := false


func build(box: VBoxContainer, owner_deck: Node) -> void:
	deck = owner_deck
	_cfg = Data.value("vfx", "gallery")
	var head := Label.new()
	head.text = String(_cfg.section)
	head.add_theme_color_override("font_color", Color.GOLD)
	box.add_child(head)
	picker = OptionButton.new()
	picker.name = "RecipePicker"
	picker.focus_mode = Control.FOCUS_NONE
	var names: Array = (Data.value("vfx", "recipes") as Dictionary).keys()
	names.sort()
	for n: String in names:
		picker.add_item(n)
	box.add_child(picker)
	_button(box, String(_cfg.spawn_label), spawn_selected)
	_button(box, String(_cfg.sequence_label), run_sequence)
	_button(box, String(_cfg.all_label), spawn_environment)
	_button(box, String(_cfg.clear_label), clear)


func _button(box: VBoxContainer, label: String, what: Callable) -> void:
	var b := Button.new()
	b.text = label
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func() -> void: what.call())
	box.add_child(b)


func _unhandled_key_input(event: InputEvent) -> void:
	if not (get_parent() as CanvasLayer).visible or not event.is_pressed() or event.is_echo():
		return
	match (event as InputEventKey).physical_keycode:
		KEY_P:
			spawn_selected()
		KEY_O:
			run_sequence()
		_:
			return
	get_viewport().set_input_as_handled()


func _has_operator() -> bool:
	return deck != null and "operator" in deck and deck.operator != null


func spawn_selected() -> void:
	if _has_operator():
		spawn(picker.get_item_text(picker.selected), deck.operator.aim_point)


## Any recipe at this point: on the floor if it belongs there, else in the air.
func spawn(recipe: String, cursor: Vector3) -> void:
	var on_floor: bool = (_cfg.floor_recipes as Array).has(recipe)
	var at := Vector3(cursor.x, 0.0 if on_floor else float(_cfg.spawn_height_m), cursor.z)
	var facing := Vector3.UP
	if (_cfg.sideways as Array).has(recipe) and _has_operator():
		facing = deck.operator.aim_dir()
	var r: Dictionary = (Data.value("vfx", "recipes") as Dictionary)[recipe]
	if bool(r.get("loop", false)):
		var id := Vfx.start(recipe, at, facing)
		if id != 0:
			_running.append(id)
	else:
		Vfx.play(recipe, at, facing)


## Every environment effect in a row across the operator's view.
func spawn_environment() -> void:
	if not _has_operator():
		return
	var op: Node3D = deck.operator
	var dir: Vector3 = deck.operator.aim_dir()
	var side := dir.cross(Vector3.UP).normalized()
	var list: Array = _cfg.environment
	var step := float(_cfg.row_step_m)
	for i in list.size():
		var off := (float(i) - float(list.size() - 1) * 0.5) * step
		spawn(String(list[i]), op.global_position + dir * float(_cfg.row_back_m) + side * off)


## A wall of each surface in a row in front of the operator, each taking a short burst through the real rifle.
func run_sequence() -> void:
	if not _has_operator() or _sequence_on:
		return
	_sequence_on = true
	stand_walls()
	var op: Node3D = deck.operator
	var rifle: Node = deck.operator.rifle
	for wall: StaticBody3D in walls:
		var at: Vector3 = wall.global_position
		var origin: Vector3 = op.global_position + Vector3.UP * float(Data.value("player", "aim_height_m"))
		deck.operator.face_now(Vector3(at.x, origin.y, at.z))
		for i in int(_cfg.sequence_rounds):
			if not is_instance_valid(wall):
				_sequence_on = false
				return
			var yaw := atan2(-(at.x - origin.x), -(at.z - origin.z))
			rifle.play_round(origin, yaw, deck.operator.muzzle_position())
			await get_tree().create_timer(float(_cfg.sequence_gap_s)).timeout
		await get_tree().create_timer(float(_cfg.wall_gap_s)).timeout
	_sequence_on = false


func stand_walls() -> void:
	_clear_walls()
	var op: Node3D = deck.operator
	var dir: Vector3 = deck.operator.aim_dir()
	var side := dir.cross(Vector3.UP).normalized()
	var list: Array = _cfg.walls
	var size := Vector3(float(_cfg.wall_size_m[0]), float(_cfg.wall_size_m[1]), float(_cfg.wall_size_m[2]))
	var step := float(_cfg.wall_step_m)
	var layers := 1
	if "layout" in deck and deck.layout != null:
		for n: String in deck.layout.space_order:
			layers |= KitPieces.space_layer(deck.layout, n)
	for i in list.size():
		var material := String(list[i].material)
		var body := StaticBody3D.new()
		body.name = "GalleryWall_%s" % material
		body.set_meta("kit_material", material)
		var shape := BoxShape3D.new()
		shape.size = size
		var cs := CollisionShape3D.new()
		cs.shape = shape
		body.add_child(cs)
		var box := BoxMesh.new()
		box.size = size
		box.material = KitMaterials.material(material)
		var mi := MeshInstance3D.new()
		mi.mesh = box
		mi.layers = layers
		body.add_child(mi)
		deck.add_child(body)
		var off := (float(i) - float(list.size() - 1) * 0.5) * step
		var c: Vector3 = op.global_position + dir * float(_cfg.wall_distance_m) + side * off
		body.global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP), Vector3(c.x, size.y * 0.5, c.z))
		walls.append(body)


func _clear_walls() -> void:
	for w: StaticBody3D in walls:
		if is_instance_valid(w):
			w.queue_free()
	walls.clear()


func clear() -> void:
	for id: int in _running:
		Vfx.stop(id)
	_running.clear()
	_clear_walls()


func _exit_tree() -> void:
	clear()
