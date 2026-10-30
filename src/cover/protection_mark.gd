extends CanvasLayer
## The HUD's shield marks: one per stalker hunting you, solid when cover stops what it would throw
## at you right now, a hollow red outline when its line is open. Numbers: data/cover.json "mark".

var cfg: Dictionary
var lines: Array = []  # bools, per shooter: true = blocked

var _canvas: Control


func _ready() -> void:
	cfg = (Data.load_data("cover") as Dictionary).mark
	layer = int(cfg.layer)
	_canvas = Control.new()
	_canvas.name = "Marks"
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_marks)
	add_child(_canvas)


func set_lines(new_lines: Array) -> void:
	if new_lines == lines:
		return
	lines = new_lines
	_canvas.queue_redraw()


func protected_count() -> int:
	return lines.count(true)


func _draw_marks() -> void:
	var size := float(cfg.size_px)
	var gap := float(cfg.gap_px)
	var total := lines.size() * size + maxi(lines.size() - 1, 0) * gap
	var view := _canvas.size
	var x := (view.x - total) * 0.5
	var y := view.y - float(cfg.from_bottom_px)
	var font := ThemeDB.fallback_font
	for blocked: bool in lines:
		var col := Color(String(cfg.protected_color if blocked else cfg.exposed_color))
		var pts := _shield(Vector2(x, y), size)
		if blocked:
			_canvas.draw_colored_polygon(pts, col)
		var loop := pts.duplicate()
		loop.append(pts[0])
		_canvas.draw_polyline(loop, col, float(cfg.line_px), true)
		var word := String(cfg.word_protected if blocked else cfg.word_exposed)
		var w := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, int(cfg.font_size)).x
		_canvas.draw_string(font, Vector2(x + (size - w) * 0.5, y + size + float(cfg.word_gap_px)), word,
				HORIZONTAL_ALIGNMENT_LEFT, -1, int(cfg.font_size), col)
		x += size + gap


func _shield(at: Vector2, s: float) -> PackedVector2Array:
	var h := s * 0.5
	return PackedVector2Array([at, at + Vector2(s, 0), at + Vector2(s, h), at + Vector2(h, s), at + Vector2(0, h)])
