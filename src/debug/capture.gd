extends Node
## Windowed capture driver. Autoloaded as `Capture`; idle unless the run has --capture-out.
## tools/capture.sh <scene> <out-dir> [seconds] starts it. It:
##   1. sizes the framebuffer to --capture-size (default 1920x1080) and turns vsync off,
##   2. warms up, then records wall-clock frame times (vsync off) for --capture-seconds,
##      (the Metal driver returns 0 for viewport GPU timers, so there is no separate GPU number),
##   3. saves <scene>.png (and <scene>_overlay.png with the FPS overlay),
##   4. if the scene root has capture_shots()/apply_shot(), saves one PNG per shot,
##   5. writes frametime.json and quits.

var _out := ""
var _seconds := 10.0
var _warmup := 2.0
var _size := Vector2i(1920, 1080)
var _cpu_ms: PackedFloat64Array = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-out="):
			_out = arg.get_slice("=", 1)
		elif arg.begins_with("--capture-seconds="):
			_seconds = float(arg.get_slice("=", 1))
		elif arg.begins_with("--capture-warmup="):
			_warmup = float(arg.get_slice("=", 1))
		elif arg.begins_with("--capture-size="):
			var wh := arg.get_slice("=", 1).split("x")
			_size = Vector2i(int(wh[0]), int(wh[1]))
	if _out == "":
		set_process(false)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	var tree := get_tree()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await _fit_framebuffer()
	await _wait(_warmup)
	var t_end := Time.get_ticks_usec() + int(_seconds * 1e6)
	var last := Time.get_ticks_usec()
	while Time.get_ticks_usec() < t_end:
		await tree.process_frame
		var now := Time.get_ticks_usec()
		_cpu_ms.append((now - last) / 1000.0)
		last = now
	var scene := tree.current_scene
	var base := scene.scene_file_path.get_file().get_basename() if scene else "capture"
	var overlay := tree.root.get_node_or_null("DebugOverlay")
	if overlay:
		overlay.visible = false
	await _shoot(base)
	if overlay:
		overlay.visible = true
		await _shoot(base + "_overlay")
		overlay.visible = false
	if scene and scene.has_method("capture_shots") and scene.has_method("apply_shot"):
		# Env CAPTURE_ONLY: comma-separated shot names, or "none" for frame time alone.
		var only := OS.get_environment("CAPTURE_ONLY").split(",", false)
		for shot in scene.capture_shots():
			if not only.is_empty() and not only.has(shot.name):
				continue
			await scene.apply_shot(shot)
			await _shoot(String(shot.name))
		if scene.has_method("release_shot"):
			scene.release_shot()
	_write_report(base)
	tree.quit(0)


## Window sizes are in points on a HiDPI Mac; resize until the framebuffer is _size pixels.
func _fit_framebuffer() -> void:
	DisplayServer.window_set_size(_size)
	for i in 3:
		await _frames(3)
		var got := Vector2i(get_viewport().get_texture().get_size())
		if got == _size:
			break
		var win := DisplayServer.window_get_size()
		DisplayServer.window_set_size(Vector2i(Vector2(win) * Vector2(_size) / Vector2(got)))
	var screen := DisplayServer.window_get_current_screen()
	var origin := DisplayServer.screen_get_position(screen)
	DisplayServer.window_set_position(origin + Vector2i(40, 40))
	await _frames(3)


## Waits enough frames for temporal effects (volumetric fog reprojection, SSAO) to settle.
func _shoot(png_name: String) -> void:
	await _frames(20)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := _out.path_join(png_name + ".png")
	var err := img.save_png(path)
	print("capture: %s %dx%d %s" % [path, img.get_width(), img.get_height(), error_string(err)])


func _write_report(base: String) -> void:
	var cpu := _sorted(_cpu_ms)
	var tex_size := get_viewport().get_texture().get_size()
	var report := {
		"scene": base,
		"seconds": _seconds,
		"warmup_seconds": _warmup,
		"frames": cpu.size(),
		"frame_ms_avg": _avg(cpu),
		"frame_ms_p95": _pct(cpu, 0.95),
		"frame_ms_p99": _pct(cpu, 0.99),
		"frame_ms_max": cpu[-1] if cpu.size() else 0.0,
		"fps_avg": 1000.0 / _avg(cpu) if cpu.size() else 0.0,
		"resolution": "%dx%d" % [tex_size.x, tex_size.y],
		"window_size": "%dx%d" % [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y],
		"screen_scale": DisplayServer.screen_get_scale(),
		"renderer": ProjectSettings.get_setting("rendering/renderer/rendering_method"),
		"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"msaa_3d": ["off", "2x", "4x", "8x"][get_viewport().msaa_3d],
		"vsync": "disabled",
		"godot": Engine.get_version_info().string,
		"date": Time.get_datetime_string_from_system(),
	}
	var f := FileAccess.open(_out.path_join("frametime.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "  ") + "\n")
	print("capture: frame %.2f ms avg, %.2f ms p95 at %s" % [report.frame_ms_avg, report.frame_ms_p95, report.resolution])


func _wait(seconds: float) -> void:
	var t_end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < t_end:
		await get_tree().process_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _sorted(a: PackedFloat64Array) -> PackedFloat64Array:
	var s := a.duplicate()
	s.sort()
	return s


func _avg(a: PackedFloat64Array) -> float:
	if a.is_empty():
		return 0.0
	var t := 0.0
	for v in a:
		t += v
	return t / a.size()


func _pct(sorted: PackedFloat64Array, p: float) -> float:
	if sorted.is_empty():
		return 0.0
	return sorted[mini(sorted.size() - 1, int(ceil(p * sorted.size())) - 1)]
