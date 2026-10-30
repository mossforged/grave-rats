extends CanvasLayer
## Minimal HUD: magazine and reserve, reload bar, stance, key help.

var operator: Node

var _ammo: Label
var _state: Label
var _bar: ProgressBar
var _help: Label


func _ready() -> void:
	layer = 50
	_ammo = _label(44)
	_ammo.anchor_left = 1.0
	_ammo.anchor_right = 1.0
	_ammo.anchor_top = 1.0
	_ammo.anchor_bottom = 1.0
	_ammo.offset_left = -260
	_ammo.offset_right = -24
	_ammo.offset_top = -84
	_ammo.offset_bottom = -20
	_ammo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_state = _label(22)
	_state.anchor_left = 1.0
	_state.anchor_right = 1.0
	_state.anchor_top = 1.0
	_state.anchor_bottom = 1.0
	_state.offset_left = -420
	_state.offset_right = -24
	_state.offset_top = -148
	_state.offset_bottom = -116
	_state.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.max_value = 1.0
	_bar.anchor_left = 1.0
	_bar.anchor_right = 1.0
	_bar.anchor_top = 1.0
	_bar.anchor_bottom = 1.0
	_bar.offset_left = -260
	_bar.offset_right = -24
	_bar.offset_top = -108
	_bar.offset_bottom = -90
	add_child(_bar)
	_help = _label(18)
	_help.anchor_top = 1.0
	_help.anchor_bottom = 1.0
	_help.offset_left = 16
	_help.offset_top = -40
	_help.text = "WASD move   Shift sprint   C/Ctrl crouch   LMB fire   R reload   1-5 camera   V cut-away   Backspace respawn   F1 tuning   F3 frame time"


func _process(_delta: float) -> void:
	if operator == null or operator.rifle == null or operator.rifle.state == null:
		return
	var s = operator.rifle.state
	var m = operator.model
	_ammo.text = "%d / %d" % [s.mag, s.reserve]
	_bar.visible = s.reloading()
	_bar.value = s.reload_progress()
	var word := ""
	if s.reloading():
		word = "RELOADING"
	elif s.mag == 0:
		word = "EMPTY - R"
	elif m.sprinting:
		word = "SPRINT - CAN'T FIRE"
	elif m.crouch_amount > 0.0:
		word = "CROUCHED"
	_state.text = word


func _label(size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 5)
	add_child(l)
	return l
