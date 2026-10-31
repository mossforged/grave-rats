extends CanvasLayer
## FPS and frame-time overlay. Autoloaded as `DebugOverlay`; F3 toggles it.
## Starts visible when data/debug.json "fps_overlay" is true. Hidden in headless runs.
## Being the first thing up, it also applies the saved anti-aliasing mode.

const DisplayAA := preload("res://src/debug/display_aa.gd")

var _label: Label
var _accum := 0.0
var _frames := 0
var _worst := 0.0
var _refresh := 0.25


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayAA.apply(get_tree().root, DisplayAA.starting_mode())
	_label = Label.new()
	_label.position = Vector2(12, 8)
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 4)
	add_child(_label)
	var headless := DisplayServer.get_name() == "headless"
	_refresh = float(Data.value("debug", "fps_overlay_refresh_s", 0.25))
	visible = bool(Data.value("debug", "fps_overlay", true)) and not headless
	set_process(not headless)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		visible = not visible
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_accum += delta
	_frames += 1
	_worst = maxf(_worst, delta)
	if _accum < _refresh:
		return
	var avg_ms := _accum / _frames * 1000.0
	_label.text = "%d fps  %.2f ms avg  %.2f ms worst\n%s  %dx%d" % [
		Engine.get_frames_per_second(), avg_ms, _worst * 1000.0,
		RenderingServer.get_video_adapter_name(),
		get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y]
	_accum = 0.0
	_frames = 0
	_worst = 0.0
