extends CanvasLayer
## F1 tuning panel (dev only). One slider per entry in data/debug.json "tuning". A slider writes
## straight into the loaded data dictionary, which the game reads live; Save writes the changed
## files back to data/, so John's tuning persists as a data change. Its Display section switches
## anti-aliasing live and saves that choice at once, with the frame time beside it. Vsync is off while
## the panel is open, so that number is the real cost and not the display's refresh.

const DisplayAA := preload("res://src/debug/display_aa.gd")
const VfxGallery := preload("res://src/vfx/vfx_gallery.gd")
const FILE_DIR := "res://data"

var save_dir := FILE_DIR
var sliders: Dictionary = {}      # "file:path" -> HSlider
var dirty: Dictionary = {}        # file name -> true
var aa_picker: OptionButton
var ship_picker: OptionButton
var frame_label: Label
var gallery: VfxGallery

var _status: Label
var _root: Control
var _vsync_before := -1
var _last_usec := 0
var _frame_usec := 0
var _worst_usec := 0
var _frames := 0


func _ready() -> void:
	layer = 60
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visibility_changed.connect(_on_visibility_changed)


func toggle() -> void:
	visible = not visible


func _on_visibility_changed() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if visible:
		_vsync_before = DisplayServer.window_get_vsync_mode()
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	elif _vsync_before >= 0:
		DisplayServer.window_set_vsync_mode(_vsync_before)
		_vsync_before = -1
	_last_usec = 0


## Wall-clock, since delta follows Engine.time_scale and the capture driver freezes that.
func _process(_delta: float) -> void:
	if not visible:
		return
	var now := Time.get_ticks_usec()
	if _last_usec > 0:
		var took := now - _last_usec
		_frame_usec += took
		_worst_usec = maxi(_worst_usec, took)
		_frames += 1
	_last_usec = now
	if _frame_usec >= int(float(Data.value("display", "readout_s")) * 1e6):
		show_frame_time(_frame_usec / 1000.0 / _frames, _worst_usec / 1000.0)
		_frame_usec = 0
		_worst_usec = 0
		_frames = 0


func show_frame_time(avg_ms: float, worst_ms: float) -> void:
	frame_label.text = String(Data.value("display", "readout")) % [avg_ms, worst_ms]


## Switches the live viewport and writes the choice to data/display.json. False if there's no such
## mode. An env DISPLAY_AA only sets the start, so this always saves what's picked.
func pick_aa(id: String) -> bool:
	if not DisplayAA.apply(get_tree().root, id):
		return false
	Data.load_data("display").aa_mode = id
	_select_aa(id)
	var written := _write(DisplayAA.FILE)
	if _status:
		_status.text = "saved: %s" % DisplayAA.FILE if written else "couldn't save %s" % DisplayAA.FILE
	return written


func _select_aa(id: String) -> void:
	for i in aa_picker.item_count:
		if String(aa_picker.get_item_metadata(i)) == id:
			aa_picker.select(i)


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
		if _write(file):
			written.append(file)
	for file in written:
		dirty.erase(file)
	if _status:
		_status.text = "saved: %s" % ", ".join(written) if written.size() > 0 else "nothing changed"
	return written


func _write(file: String) -> bool:
	if Data.ship != Data.BASE_SHIP:
		push_warning("TuningPanel: not saving %s: on %s it holds that ship's overrides too" % [file, Data.ship])
		return false
	var path := save_dir.path_join(file + ".json")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("TuningPanel: can't write %s: %s" % [path, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(JSON.stringify(Data.load_data(file), "  ", false) + "\n")
	f.close()
	return true


## F1 > Shift: which ship. Only on a deck that can change ship; picking one restarts the scene on it.
func _add_ship_picker(box: VBoxContainer) -> void:
	var deck := get_parent()
	if deck == null or not deck.has_method("pick_ship"):
		return
	var head := Label.new()
	head.text = String(Data.value("shift", "ship_section"))
	head.add_theme_color_override("font_color", Color.GOLD)
	box.add_child(head)
	ship_picker = OptionButton.new()
	ship_picker.name = "ShipPicker"
	ship_picker.focus_mode = Control.FOCUS_NONE
	var ships: Array = Data.value("shift", "ships", [])
	for i in ships.size():
		ship_picker.add_item(String(ships[i]))
		if String(ships[i]) == Data.ship:
			ship_picker.select(i)
	ship_picker.item_selected.connect(func(i: int) -> void: deck.pick_ship(String(ships[i])))
	box.add_child(ship_picker)


func _add_display(box: VBoxContainer) -> void:
	var head := Label.new()
	head.text = String(Data.value("display", "section"))
	head.add_theme_color_override("font_color", Color.GOLD)
	box.add_child(head)
	var row := HBoxContainer.new()
	box.add_child(row)
	aa_picker = OptionButton.new()
	aa_picker.name = "AaPicker"
	aa_picker.focus_mode = Control.FOCUS_NONE
	for mode: Dictionary in DisplayAA.modes():
		aa_picker.add_item(String(mode.label))
		aa_picker.set_item_metadata(aa_picker.item_count - 1, String(mode.id))
	_select_aa(DisplayAA.mode_of(get_tree().root))
	aa_picker.item_selected.connect(func(i: int) -> void: pick_aa(String(aa_picker.get_item_metadata(i))))
	row.add_child(aa_picker)
	frame_label = Label.new()
	frame_label.name = "FrameTime"
	row.add_child(frame_label)


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
	_add_display(box)
	_add_ship_picker(box)
	gallery = VfxGallery.new()
	gallery.name = "Gallery"
	add_child(gallery)
	gallery.build(box, get_parent())
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
