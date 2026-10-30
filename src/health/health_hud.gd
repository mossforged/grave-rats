extends CanvasLayer
## Suit integrity bar, hit flash, acid warning, the death screen. Numbers: data/health.json "hud".

var suit: RefCounted
var cfg: Dictionary

var _word: Label
var _back: ColorRect
var _bar: ColorRect
var _flash: ColorRect
var _death: ColorRect
var _death_word: Label
var _detail: Label
var _flash_left := 0.0
var in_acid := false


func _ready() -> void:
	cfg = (Data.load_data("health") as Dictionary).hud
	layer = int(cfg.layer)
	var m := float(cfg.margin_px)
	var w := float(cfg.bar_width_px)
	var h := float(cfg.bar_height_px)
	_flash = _rect("Flash", Color(String(cfg.flash_color)))
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.visible = false
	_back = _rect("Back", Color.BLACK)
	_back.position = Vector2(m, m)
	_back.size = Vector2(w, h)
	_bar = _rect("Bar", Color(String(cfg.bar_color)))
	_bar.position = Vector2(m, m)
	_bar.size = Vector2(w, h)
	_word = _label(int(cfg.label_font_size))
	_word.position = Vector2(m, m + h)
	_death = _rect("Death", Color(String(cfg.death_color)))
	_death.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_death.visible = false
	_death_word = _label(int(cfg.death_font_size))
	_death_word.text = String(cfg.death_word)
	_death_word.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_death_word.anchor_top = 0.5
	_death_word.anchor_bottom = 0.5
	_death_word.offset_top = -float(cfg.death_font_size)
	_death_word.offset_bottom = 0.0
	_death_word.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_death_word.visible = false
	_detail = _label(int(cfg.detail_font_size))
	_detail.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_detail.anchor_top = 0.5
	_detail.anchor_bottom = 0.5
	_detail.offset_top = float(cfg.death_font_size)
	_detail.offset_bottom = float(cfg.death_font_size)
	_detail.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_detail.grow_vertical = Control.GROW_DIRECTION_END
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail.visible = false


func _process(delta: float) -> void:
	if suit == null:
		return
	var f: float = suit.fraction()
	_bar.size.x = float(cfg.bar_width_px) * f
	_bar.color = Color(String(cfg.low_color if f <= float(cfg.low_fraction) else cfg.bar_color))
	_word.text = "SUIT %d" % ceili(suit.integrity) if not in_acid else "SUIT %d   ACID" % ceili(suit.integrity)
	_word.modulate = Color(String(cfg.acid_color)) if in_acid else Color.WHITE
	_flash_left = maxf(_flash_left - delta, 0.0)
	_flash.visible = _flash_left > 0.0
	if _flash.visible:
		_flash.modulate.a = _flash_left / float(cfg.flash_s)


func flash() -> void:
	_flash_left = float(cfg.flash_s)


## `line` says what killed you; empty hides the screen.
func show_death(line: String) -> void:
	var on := line != ""
	_death.visible = on
	_death_word.visible = on
	_detail.visible = on
	_detail.text = "%s\n%s" % [line, String(cfg.restart_word)]


func _rect(node_name: String, col: Color) -> ColorRect:
	var r := ColorRect.new()
	r.name = node_name
	r.color = col
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r


func _label(size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", int(cfg.outline_px))
	add_child(l)
	return l
