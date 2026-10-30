extends CanvasLayer
## The company-issue suit OS, in the A005-05 layout: the Remnant mark and one crew row top left, the
## oxygen ticker and the rental watermark bottom left, suit, ammo and salvage bottom right with the
## alarms and cover shields above them, states over the operator, the key help between the docks.
## Everything is drawn here, every size, colour and word from data/hud.json at `ref_height_px`
## scale, read live so the F1 panel works.

const SuitOs := preload("res://src/hud/suit_os.gd")

var cfg: Dictionary
var os_state: SuitOs
var operator: Node3D
var camera_rig: Node3D     # its `camera` places the states over the operator
var suit: RefCounted       # null in the decks without one: reads as a full suit
var mark: Node             # ProtectionMark: in_cover and the shooter lines; null when there's none
var in_acid := false
var light_off := false
var lock_state := ""       # "", "locked", "exposed"
var scene_help := ""
var help_on := true

var _canvas: Control
var _regular: Font
var _bold: Font
var _scale := 1.0


func _ready() -> void:
	cfg = Data.load_data("hud")
	layer = int(cfg.layer)
	os_state = SuitOs.new(cfg)
	help_on = bool(cfg.help.start_on)
	_regular = _font(String(cfg.font.regular))
	_bold = _font(String(cfg.font.bold))
	_canvas = Control.new()
	_canvas.name = "SuitOs"
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_hud)
	add_child(_canvas)


func _font(path: String) -> Font:
	if ResourceLoader.exists(path):
		return load(path)
	return ThemeDB.fallback_font


func reset() -> void:
	if os_state:
		os_state.reset()


func toggle_help() -> void:
	help_on = not help_on


func _process(delta: float) -> void:
	if os_state == null:
		return
	os_state.step(delta)
	_canvas.queue_redraw()


## What the suit's own state is right now, for the status row and for tests.
func status_now() -> Array:
	var s: RefCounted = operator.rifle.state
	var m: RefCounted = operator.model
	return os_state.status({
		"in_cover": mark != null and bool(mark.in_cover),
		"lock": lock_state,
		"crouched": float(m.crouch_amount) > 0.0,
		"sprinting": bool(m.sprinting),
		"reloading": bool(s.reloading()),
		"empty": int(s.mag) == 0,
		"light_off": light_off,
	})


func suit_fraction() -> float:
	return float(suit.fraction()) if suit else 1.0


func _draw_hud() -> void:
	if operator == null or operator.rifle == null or operator.rifle.state == null:
		return
	var view := _canvas.size
	_scale = view.y / float(cfg.ref_height_px)
	_draw_mark()
	_draw_crew()
	_draw_oxygen(view)
	_draw_watermark(view)
	var top := _draw_right_dock(view)
	top = _draw_alerts(view, top)
	_draw_shields(view, top)
	_draw_status()
	if help_on:
		_draw_help(view)


func _px(v: Variant) -> float:
	return float(v) * _scale


func _col(key: String) -> Color:
	return Color(String(cfg.colors[key]))


func _text(font: Font, at: Vector2, word: String, size: Variant, col: Color) -> void:
	_canvas.draw_string(font, at, word, HORIZONTAL_ALIGNMENT_LEFT, -1, int(_px(size)), col)


func _text_w(font: Font, word: String, size: Variant) -> float:
	return font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, int(_px(size))).x


## A dock's plate: dark glass with the corners cut, and a thin line round it.
func _plate(r: Rect2) -> void:
	var c := _px(cfg.dock.chamfer_px)
	var p := r.position
	var e := r.end
	var pts := PackedVector2Array([p + Vector2(c, 0), Vector2(e.x - c, p.y), Vector2(e.x, p.y + c),
			Vector2(e.x, e.y - c), Vector2(e.x - c, e.y), Vector2(p.x + c, e.y), Vector2(p.x, e.y - c), Vector2(p.x, p.y + c)])
	_canvas.draw_colored_polygon(pts, _col("plate"))
	var loop := pts.duplicate()
	loop.append(pts[0])
	_canvas.draw_polyline(loop, _col("line"), _px(cfg.dock.line_px), true)


## A bar: `fill` of it in `col`, the rest in the track colour.
func _bar(r: Rect2, fill: float, col: Color) -> void:
	_canvas.draw_rect(r, _col("track"))
	_canvas.draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(fill, 0.0, 1.0), r.size.y)), col)


## An icon from data: filled polygons and circles in a unit box.
func _icon(key: String, at: Vector2, size: float, col: Color) -> void:
	for shape: Dictionary in cfg.icons[key]:
		if shape.has("circle"):
			var c: Array = shape.circle
			var center := at + Vector2(float(c[0]), float(c[1])) * size
			if shape.has("line"):
				_canvas.draw_arc(center, float(c[2]) * size, 0.0, TAU, int(cfg.mark.arc_points), col, float(shape.line) * size, true)
			else:
				_canvas.draw_circle(center, float(c[2]) * size, col, true, -1.0, true)
		else:
			var pts := PackedVector2Array()
			for q: Array in shape.poly:
				pts.append(at + Vector2(float(q[0]), float(q[1])) * size)
			_canvas.draw_colored_polygon(pts, col)


func _draw_mark() -> void:
	var m: Dictionary = cfg.mark
	var c := Vector2(_px(m.x_px), _px(m.y_px))
	var r := _px(m.radius_px)
	var col := _col("text_dim")
	var arcs := int(m.arcs)
	var gap := deg_to_rad(float(m.arc_gap_deg))
	for i in arcs:
		var a := TAU * float(i) / float(arcs) + gap * 0.5 + deg_to_rad(float(m.arc_start_deg))
		_canvas.draw_arc(c, r, a, a + TAU / float(arcs) - gap, int(m.arc_points), col, _px(m.line_px), true)
	var sides := int(m.hex_sides)
	for at: Array in m.hexes:
		var center := c + Vector2(float(at[0]), float(at[1])) * r
		var pts := PackedVector2Array()
		for k in sides:
			var a := TAU * float(k) / float(sides) + deg_to_rad(float(m.hex_start_deg))
			pts.append(center + Vector2.from_angle(a) * r * float(m.hex_radius))
		_canvas.draw_colored_polygon(pts, col)
	var x := c.x + r + _px(m.text_gap_px)
	_text(_regular, Vector2(x, c.y - _px(m.text_line_px) * 0.5 + _px(m.text_drop_px)), String(m.line_1), m.font_px, col)
	_text(_regular, Vector2(x, c.y + _px(m.text_line_px) * 0.5 + _px(m.text_drop_px)), String(m.line_2), m.font_px, col)


func _draw_crew() -> void:
	var w: Dictionary = cfg.crew
	var at := Vector2(_px(w.x_px), _px(w.y_px))
	var size := _px(w.icon_px)
	_icon("helmet", at, size, _col("text_dim"))
	var x := at.x + size + _px(w.gap_px)
	_canvas.draw_rect(Rect2(x, at.y, _px(w.tag_w_px), size), Color(String(w.color)))
	x += _px(w.tag_w_px) + _px(w.gap_px)
	_text(_regular, Vector2(x, at.y + _px(w.font_px)), String(w.name), w.font_px, _col("text"))
	_bar(Rect2(x, at.y + size - _px(w.bar_h_px), _px(w.bar_w_px), _px(w.bar_h_px)), suit_fraction(), _col("bar"))


func _draw_oxygen(view: Vector2) -> void:
	var d: Dictionary = cfg.oxygen
	var r := Rect2(_px(d.x_px), view.y - _px(d.from_bottom_px), _px(d.w_px), _px(d.h_px))
	_plate(r)
	var pad := _px(cfg.dock.pad_px)
	var x := r.position.x + pad
	var y := r.position.y + pad
	_text(_regular, Vector2(x, y + _px(d.big_px)), String(d.word), d.big_px, _col("text"))
	var o2_w := _text_w(_regular, String(d.word), d.big_px)
	_text(_regular, Vector2(x + o2_w, y + _px(d.big_px)), String(d.sub), d.sub_px, _col("text"))
	var tx := x + o2_w + _text_w(_regular, String(d.sub), d.sub_px) + _px(d.gap_px)
	_text(_bold, Vector2(tx, y + _px(d.big_px)), os_state.oxygen_text(), d.big_px, _col("text"))
	_text(_regular, Vector2(tx, y + _px(d.big_px) + _px(d.label_px) + _px(d.label_gap_px)), String(d.label), d.label_px, _col("text_dim"))
	var bh := _px(d.bar_h_px)
	var f: float = os_state.oxygen_fraction()
	var bar := Rect2(x, r.end.y - pad - bh, r.size.x - pad * 2.0, bh)
	_bar(bar, f, _col("bar"))
	_canvas.draw_rect(Rect2(bar.position, Vector2(bar.size.x * minf(f, float(d.accent)), bh)), _col("accent"))


func _draw_watermark(view: Vector2) -> void:
	var w: Dictionary = cfg.watermark
	_text(_regular, Vector2(_px(w.x_px), view.y - _px(w.from_bottom_px)), String(w.text), w.font_px, _col("watermark"))


## Suit, ammo, salvage. Returns the y of its top edge.
func _draw_right_dock(view: Vector2) -> float:
	var d: Dictionary = cfg.dock
	var r := Rect2(view.x - _px(d.from_right_px) - _px(d.w_px), view.y - _px(d.from_bottom_px), _px(d.w_px), _px(d.h_px))
	_plate(r)
	var cell := r.size.x / float(d.cells)
	var s: RefCounted = operator.rifle.state
	var frac := suit_fraction()
	var low_suit: bool = os_state.suit_low(frac)
	var low_ammo: bool = os_state.ammo_low(int(s.mag))
	var suit_col := _col("danger") if low_suit else _col("text")
	_cell(r, 0, cell, "suit", String(cfg.suit.word), "%d%s" % [ceili(frac * float(cfg.suit.percent)), String(cfg.suit.unit)], "",
			suit_col, frac, _col("danger") if low_suit else _col("accent"))
	var ammo_fill := float(s.mag) / float(s.cfg.magazine)
	var ammo_bar := _col("warn") if low_ammo else _col("bar")
	if s.reloading():
		ammo_fill = float(s.reload_progress())
		ammo_bar = _col("accent")
	var ammo_digits := int(cfg.ammo.digits)
	_cell(r, 1, cell, "ammo", String(cfg.ammo.word), String.num_int64(int(s.mag)).pad_zeros(ammo_digits), " / %d" % int(s.reserve),
			_col("danger") if low_ammo else _col("text"), ammo_fill, ammo_bar)
	_cell(r, 2, cell, "salvage", String(cfg.salvage.word), os_state.credits_text(int(cfg.salvage.credits)), " %s" % String(cfg.salvage.unit),
			_col("text"), float(cfg.salvage.fill), _col("bar"))
	for i in int(d.cells) - 1:
		var x := r.position.x + cell * float(i + 1)
		_canvas.draw_line(Vector2(x, r.position.y + _px(d.pad_px)), Vector2(x, r.end.y - _px(d.pad_px)), _col("line"), _px(d.line_px))
	return r.position.y


func _cell(r: Rect2, i: int, cell: float, icon: String, label: String, big: String, small: String, big_col: Color, fill: float, bar_col: Color) -> void:
	var d: Dictionary = cfg.dock
	var pad := _px(d.pad_px)
	var x := r.position.x + cell * float(i) + pad
	var y := r.position.y + pad
	var size := _px(d.icon_px)
	_icon(icon, Vector2(x, y), size, _col("text"))
	var tx := x + size + _px(d.icon_gap_px)
	_text(_regular, Vector2(tx, y + _px(d.label_px)), label, d.label_px, _col("text_dim"))
	var base := y + _px(d.label_px) + _px(d.value_px) + _px(d.value_gap_px)
	_text(_bold, Vector2(tx, base), big, d.value_px, big_col)
	if small != "":
		_text(_regular, Vector2(tx + _text_w(_bold, big, d.value_px), base), small, d.small_px, _col("text_dim"))
	var bh := _px(d.bar_h_px)
	_bar(Rect2(x, r.end.y - pad - bh, cell - pad * 2.0, bh), fill, bar_col)


## The alarm strip above the right dock. Returns the y of the top of what's now stacked there.
func _draw_alerts(view: Vector2, top: float) -> float:
	var list: Array = os_state.alerts(in_acid, int(operator.rifle.state.mag))
	if list.is_empty():
		return top
	var a: Dictionary = cfg.alert
	var h := _px(a.h_px)
	var w := _px(cfg.dock.w_px)
	var x := view.x - _px(cfg.dock.from_right_px) - w
	var y := top - h
	_canvas.draw_rect(Rect2(x, y, w, h), _col("plate"))
	var size := _px(a.icon_px)
	var at := Vector2(x + _px(a.pad_px), y + (h - size) * 0.5)
	_icon("warning", at, size, _col("danger"))
	var tx := at.x + size + _px(a.pad_px)
	for item: Dictionary in list:
		_text(_bold, Vector2(tx, y + (h + _px(a.font_px)) * 0.5 - _px(a.font_drop_px)), String(item.word), a.font_px, Color(String(item.color)))
		tx += _text_w(_bold, String(item.word), a.font_px) + _px(a.gap_px)
	return y


## One shield per stalker or pirate hunting you: solid when cover stops it, a hollow outline when not.
func _draw_shields(view: Vector2, top: float) -> void:
	if mark == null or mark.lines.is_empty():
		return
	var s: Dictionary = cfg.shields
	var size := _px(s.size_px)
	var gap := _px(s.gap_px)
	var x := view.x - _px(cfg.dock.from_right_px) - size
	var y := top - _px(s.above_px) - size - _px(s.font_px)
	for blocked: bool in mark.lines:
		var col := _col("good") if blocked else _col("danger")
		_shield(Vector2(x, y), size, col, blocked)
		var word := String(s.word_blocked if blocked else s.word_open)
		_text(_regular, Vector2(x + (size - _text_w(_regular, word, s.font_px)) * 0.5, y + size + _px(s.font_px)), word, s.font_px, col)
		x -= size + gap


func _shield(at: Vector2, size: float, col: Color, solid: bool) -> void:
	var h := size * 0.5
	var pts := PackedVector2Array([at, at + Vector2(size, 0), at + Vector2(size, h), at + Vector2(h, size), at + Vector2(0, h)])
	if solid:
		_canvas.draw_colored_polygon(pts, col)
	var loop := pts.duplicate()
	loop.append(pts[0])
	_canvas.draw_polyline(loop, col, _px(cfg.shields.line_px), true)


## The states, over the operator's head, as in A005-06b.
func _draw_status() -> void:
	var list := status_now()
	if list.is_empty() or camera_rig == null or camera_rig.camera == null:
		return
	var st: Dictionary = cfg.status
	var head := operator.global_position + Vector3.UP * float(st.above_m)
	if camera_rig.camera.is_position_behind(head):
		return
	var pad := _px(st.pad_px)
	var gap := _px(st.gap_px)
	var icon := _px(st.icon_px)
	var total := -gap
	var widths: Array = []
	for item: Dictionary in list:
		var w := _text_w(_bold, String(item.word), st.font_px) + pad * 2.0 + (icon + pad if item.has("shield") else 0.0)
		widths.append(w)
		total += w + gap
	var center: Vector2 = camera_rig.camera.unproject_position(head)
	var x := center.x - total * 0.5
	var h := _px(st.h_px)
	var y := center.y - h
	for i in list.size():
		var item: Dictionary = list[i]
		var col := Color(String(item.color))
		_canvas.draw_rect(Rect2(x, y, widths[i], h), _col("plate"))
		var tx := x + pad
		if item.has("shield"):
			_shield(Vector2(tx, y + (h - icon) * 0.5), icon, col, true)
			tx += icon + pad
		_text(_bold, Vector2(tx, y + (h + _px(st.font_px)) * 0.5 - _px(st.font_drop_px)), String(item.word), st.font_px, col)
		x += widths[i] + gap


func _draw_help(view: Vector2) -> void:
	var h: Dictionary = cfg.help
	var lines: Array = [scene_help, String(h.text)]
	var y := view.y - _px(h.from_bottom_px)
	var col := _col("text_dim")
	var widest := 0.0
	for line: String in lines:
		widest = maxf(widest, _text_w(_regular, line, h.font_px))
	var pad := _px(h.pad_px)
	# Its own dark strip, since the floor under it may be lit.
	_canvas.draw_rect(Rect2((view.x - widest) * 0.5 - pad, y - _px(h.font_px) - pad * 0.5, widest + pad * 2.0,
			_px(h.line_px) * float(lines.size()) + pad), _col("plate"))
	for line: String in lines:
		var w := _text_w(_regular, line, h.font_px)
		_text(_regular, Vector2((view.x - w) * 0.5, y), line, h.font_px, col)
		y += _px(h.line_px)
