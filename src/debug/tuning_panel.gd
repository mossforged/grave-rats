extends CanvasLayer
## F1 tuning panel (dev only). One slider per entry in data/debug.json "tuning". A slider writes
## straight into the loaded data dictionary, which the game reads live; Save writes the changed
## files back to data/, so John's tuning persists as a data change.

const FILE_DIR := "res://data"

var save_dir := FILE_DIR
var sliders: Dictionary = {}      # "file:path" -> HSlider
var dirty: Dictionary = {}        # file name -> true

var _status: Label
var _root: Control


func _ready() -> void:
	layer = 60
	visible = false
	_build()


func toggle() -> void:
	visible = not visible


## The dictionary and last key of a dotted path like "turn.standing_deg_s".
static func resolve(file: String, path: String) -> Array:
	var node: Variant = Data.load_data(file)
	var parts := path.split(".")
	for i in parts.size() - 1:
		if not (node is Dictionary and node.has(parts[i])):
			return []
		node = node[parts[i]]
	if not (node is Dictionary and node.has(parts[-1])):
		return []
	return [node, parts[-1]]


func set_value(file: String, path: String, value: float) -> void:
	var r := resolve(file, path)
	if r.is_empty():
		push_error("TuningPanel: no %s in data/%s.json" % [path, file])
		return
	r[0][r[1]] = value
	dirty[file] = true


## Writes every changed file to save_dir. Returns the list of files written.
func save() -> PackedStringArray:
	var written: PackedStringArray = []
	for file: String in dirty.keys():
		var path := save_dir.path_join(file + ".json")
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f == null:
			push_error("TuningPanel: can't write %s: %s" % [path, error_string(FileAccess.get_open_error())])
			continue
		f.store_string(JSON.stringify(Data.load_data(file), "  ", false) + "\n")
		f.close()
		written.append(file)
	for file in written:
		dirty.erase(file)
	if _status:
		_status.text = "saved: %s" % ", ".join(written) if written.size() > 0 else "nothing changed"
	return written


func _build() -> void:
	var panel := PanelContainer.new()
	panel.anchor_bottom = 1.0
	panel.offset_right = 520
	add_child(panel)
	_root = panel
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	var save_row := HBoxContainer.new()
	box.add_child(save_row)
	var save_btn := Button.new()
	save_btn.name = "Save"
	save_btn.text = "Save to data/"
	save_btn.focus_mode = Control.FOCUS_NONE
	save_btn.pressed.connect(func() -> void: save())
	save_row.add_child(save_btn)
	_status = Label.new()
	save_row.add_child(_status)
	for entry: Dictionary in Data.value("debug", "tuning", []):
		if entry.has("section"):
			var head := Label.new()
			head.text = String(entry.section)
			head.add_theme_color_override("font_color", Color.GOLD)
			box.add_child(head)
			continue
		_add_slider(box, entry)


func _add_slider(box: VBoxContainer, e: Dictionary) -> void:
	var file := String(e.file)
	var path := String(e.path)
	var r := resolve(file, path)
	if r.is_empty():
		push_error("TuningPanel: no %s in data/%s.json" % [path, file])
		return
	var row := HBoxContainer.new()
	box.add_child(row)
	var name_label := Label.new()
	name_label.text = String(e.label)
	name_label.custom_minimum_size.x = 230
	row.add_child(name_label)
	var slider := HSlider.new()
	slider.min_value = float(e.min)
	slider.max_value = float(e.max)
	slider.step = float(e.step)
	slider.value = float(r[0][r[1]])
	slider.focus_mode = Control.FOCUS_NONE
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var value_label := Label.new()
	value_label.custom_minimum_size.x = 60
	value_label.text = str(slider.value)
	row.add_child(value_label)
	slider.value_changed.connect(func(v: float) -> void:
		set_value(file, path, v)
		value_label.text = str(v))
	sliders["%s:%s" % [file, path]] = slider
