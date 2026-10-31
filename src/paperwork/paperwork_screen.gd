extends CanvasLayer
## The company's forms, on screen. Draws whichever document it's given from the operations listed for
## that screen in data/paperwork.json ("base" and "screens"), so layout and copy are both data. Everything
## is placed on the A012 1920x1080 sheet and scaled to the window as a layout, not as a picture.
## Enter presses the screen's primary button; the mouse presses any; wheel or arrows scroll a long ledger.

signal pressed(button: String)

var cfg: Dictionary
var doc := {}
var screen_name := ""

var _canvas: Control
var _regular: Font
var _bold: Font
var _scale := 1.0
var _origin := Vector2.ZERO
var _scroll := 0
var _scroll_max := 0
var _hover := ""
var _lock_left := 0.0


func _ready() -> void:
	cfg = Data.load_data("paperwork")
	layer = int(cfg.screen.layer)
	_regular = _font(String(cfg.screen.font_regular))
	_bold = _font(String(cfg.screen.font_bold))
	_canvas = Control.new()
	_canvas.name = "Form"
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_form)
	add_child(_canvas)
	close()


func _font(path: String) -> Font:
	if ResourceLoader.exists(path):
		return load(path)
	return ThemeDB.fallback_font


func open(screen: String, document: Dictionary) -> void:
	screen_name = screen
	doc = document
	_scroll = 0
	_hover = ""
	_lock_left = float(cfg.screen.input_lock_s)
	visible = true
	set_process(true)
	set_process_input(true)
	_canvas.queue_redraw()


## Same form, changed fields: the lock doesn't start over.
func update(document: Dictionary) -> void:
	doc = document
	_canvas.queue_redraw()


func close() -> void:
	screen_name = ""
	doc = {}
	visible = false
	set_process(false)
	set_process_input(false)


func is_open() -> bool:
	return screen_name != ""


## Presses a button if this form is showing it. False if not.
func press(button: String) -> bool:
	for b: Dictionary in buttons():
		if b.name == button:
			pressed.emit(button)
			return true
	return false


## The buttons showing now: {name, rect (on the sheet), primary}.
func buttons() -> Array:
	var out: Array = []
	if not is_open():
		return out
	for op: Dictionary in cfg.screens[screen_name]:
		if op.has("button") and _showing(op):
			var r: Array = op.rect
			out.append({"name": String(op.button), "rect": Rect2(r[0], r[1], float(r[2]) - float(r[0]), float(r[-1]) - float(r[1])), "primary": bool(op.get("primary", false))})
	return out


func _process(delta: float) -> void:
	_lock_left = maxf(_lock_left - delta, 0.0)


func _input(event: InputEvent) -> void:
	if not is_open():
		return
	if event is InputEventMouseMotion:
		var over := _button_at((event as InputEventMouseMotion).position)
		if over != _hover:
			_hover = over
			_canvas.queue_redraw()
	elif event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll_by(-1)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll_by(1)
		elif mb.button_index == MOUSE_BUTTON_LEFT and _lock_left <= 0.0:
			var at := _button_at(mb.position)
			if at != "":
				press(at)
	elif event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).physical_keycode
		if k == KEY_UP:
			_scroll_by(-1)
		elif k == KEY_DOWN:
			_scroll_by(1)
		elif (k == KEY_ENTER or k == KEY_KP_ENTER) and _lock_left <= 0.0:
			for b: Dictionary in buttons():
				if b.primary:
					press(String(b.name))
					break
	get_viewport().set_input_as_handled()


func _scroll_by(rows: int) -> void:
	_scroll = clampi(_scroll + rows, 0, _scroll_max)
	_canvas.queue_redraw()


func _button_at(pos: Vector2) -> String:
	var sheet := (pos - _origin) / _scale if _scale > 0.0 else pos
	for b: Dictionary in buttons():
		if (b.rect as Rect2).has_point(sheet):
			return String(b.name)
	return ""


# --- drawing ---

func _draw_form() -> void:
	if not is_open():
		return
	var view := _canvas.get_viewport_rect().size
	var sheet: Array = cfg.screen.sheet
	_scale = minf(view.x / float(sheet[0]), view.y / float(sheet[1]))
	_origin = (view - Vector2(float(sheet[0]), float(sheet[1])) * _scale) * 0.5
	_canvas.draw_rect(Rect2(Vector2.ZERO, view), _col("bg"))
	if _scale <= 0.0:
		return
	for op: Dictionary in cfg.base:
		_draw_op(op, doc)
	for op: Dictionary in cfg.screens[screen_name]:
		_draw_op(op, doc)


func _showing(op: Dictionary, fields := doc) -> bool:
	if op.has("if") and not fields.get(String(op["if"]), false):
		return false
	if op.has("unless") and fields.get(String(op.unless), false):
		return false
	return true


func _draw_op(op: Dictionary, fields: Dictionary) -> void:
	if not _showing(op, fields):
		return
	if op.has("text"):
		_draw_text(op, fields)
	elif op.has("panel"):
		_draw_panel(op.panel, _col(String(op.get("color", "paper"))))
	elif op.has("rule"):
		var r: Array = op.rule
		_canvas.draw_line(_at(r[0], r[1]), _at(r[2], r[1]), _col("line"), maxf(float(cfg.screen.rule_px) * _scale, 1.0))
	elif op.has("stripe"):
		_draw_stripe(op.stripe)
	elif op.has("bar"):
		_draw_bar(op, fields)
	elif op.has("button"):
		_draw_button(op)
	elif op.has("list"):
		_draw_list(op)


func _at(x: Variant, y: Variant) -> Vector2:
	return _origin + Vector2(float(x), float(y)) * _scale


func _col(key: String) -> Color:
	return Color(String(cfg.screen.colors[key]))


func _face(op: Dictionary) -> Font:
	return _bold if String(op.get("font", "regular")) == "bold" else _regular


func _draw_text(op: Dictionary, fields: Dictionary) -> void:
	var line := String(op.text).format(fields)
	if line == "":
		return
	var font := _face(op)
	var size := maxi(roundi(float(op.size) * _scale), 1)
	var a: Array = op.at
	var pos := _at(a[0], a[1]) + Vector2(0.0, font.get_ascent(size))
	var col := _col(String(op.get("color", "ink")))
	if op.has("wrap"):
		_canvas.draw_multiline_string(font, pos, line, HORIZONTAL_ALIGNMENT_LEFT, float(op.wrap) * _scale, size, -1, col)
		return
	var w := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	match String(op.get("align", "left")):
		"right":
			pos.x -= w
		"center":
			pos.x -= w * 0.5
	_canvas.draw_string(font, pos, line, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _draw_panel(r: Array, col: Color) -> void:
	var c := float(cfg.screen.clip_px)
	var x := float(r[0])
	var y := float(r[1])
	var e := float(r[2])
	var b := float(r[-1])
	var pts := PackedVector2Array([_at(x + c, y), _at(e - c, y), _at(e, y + c), _at(e, b - c), _at(e - c, b), _at(x + c, b), _at(x, b - c), _at(x, y + c)])
	_canvas.draw_colored_polygon(pts, col)


func _draw_stripe(r: Array) -> void:
	var s: Dictionary = cfg.screen.stripe
	var x := float(r[0])
	var y := float(r[1])
	var b := float(r[-1])
	_canvas.draw_rect(Rect2(_at(x, y), Vector2(float(r[2]) - x, b - y) * _scale), _col("yellow"))
	var dark := _col("bg")
	while x < float(r[2]):
		var pts := PackedVector2Array([_at(x, y), _at(x + float(s.gap_px), y), _at(x + float(s.gap_px) - float(s.lean_px), b), _at(x - float(s.lean_px), b)])
		_canvas.draw_colored_polygon(pts, dark)
		x += float(s.pitch_px)


func _draw_bar(op: Dictionary, fields: Dictionary) -> void:
	var r: Array = op.bar
	var size := Vector2(float(r[2]), float(r[-1])) * _scale
	var share := clampf(float(fields.get(String(op.value), 0.0)), 0.0, 1.0)
	_canvas.draw_rect(Rect2(_at(r[0], r[1]), size), _col(String(op.get("track", "track"))))
	_canvas.draw_rect(Rect2(_at(r[0], r[1]), Vector2(size.x * share, size.y)), _col(String(op.get("color", "yellow"))))


func _draw_button(op: Dictionary) -> void:
	var r: Array = op.rect
	var primary := bool(op.get("primary", false))
	var hot := _hover == String(op.button)
	if primary:
		_draw_panel(r, _col("yellow_hot") if hot else _col("yellow"))
	else:
		var box := Rect2(_at(r[0], r[1]), Vector2(float(r[2]) - float(r[0]), float(r[-1]) - float(r[1])) * _scale)
		if hot:
			_canvas.draw_rect(box, _col("track"))
		_canvas.draw_rect(box, _col("muted"), false, maxf(float(cfg.screen.frame_px) * _scale, 1.0))
	var font := _bold
	var size := maxi(roundi(float(op.get("size", cfg.screen.button_font_px)) * _scale), 1)
	var w := font.get_string_size(String(op.label), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var mid := (_at(r[0], r[1]) + _at(r[2], r[-1])) * 0.5
	var pos := mid + Vector2(-w * 0.5, (font.get_ascent(size) - font.get_descent(size)) * 0.5)
	_canvas.draw_string(font, pos, String(op.label), HORIZONTAL_ALIGNMENT_LEFT, -1, size, _col("ink") if primary else _col("paper"))


## Rows of `doc[list]` from `top` to `bottom`, each row's look by its `style`. A long list tightens to
## `min_fit`, then scrolls by whole rows, and says so. Nothing is ever drawn cut off.
func _draw_list(op: Dictionary) -> void:
	var rows: Array = doc.get(String(op.list), [])
	var styles: Dictionary = op.styles
	var natural := 0.0
	for row: Dictionary in rows:
		natural += float(styles[String(row.get("style", "row"))].pitch)
	var top := float(op.top)
	var bottom := float(op.bottom)
	var window := bottom - top
	var fit := clampf(window / natural, float(op.get("min_fit", 1.0)), 1.0) if natural > 0.0 else 1.0
	_scroll_max = _rows_to_hide(rows, styles, fit, window)
	_scroll = mini(_scroll, _scroll_max)
	var y := top
	for i in range(_scroll, rows.size()):
		var row: Dictionary = rows[i]
		var style: Dictionary = styles[String(row.get("style", "row"))]
		var step := float(style.pitch) * fit
		if y + step > bottom + float(cfg.screen.row_slack_px):
			break
		for cell: Dictionary in style.cells:
			var placed := cell.duplicate()
			placed.at = [cell.x, y + float(cell.get("dy", 0.0))]
			_draw_text(placed, row)
		y += step
	if _scroll_max > 0 and op.has("more"):
		_draw_text(op.more, {})


## How many leading rows have to scroll away for the rest to fit.
func _rows_to_hide(rows: Array, styles: Dictionary, fit: float, window: float) -> int:
	var used := 0.0
	var i := rows.size() - 1
	while i >= 0:
		used += float(styles[String(rows[i].get("style", "row"))].pitch) * fit
		if used > window + float(cfg.screen.row_slack_px):
			return i + 1
		i -= 1
	return 0
