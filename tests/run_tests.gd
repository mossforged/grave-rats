extends SceneTree
## Headless test runner: godot --headless --path . -s tests/run_tests.gd
## Runs every test_* method in tests/test_*.gd. Exits non-zero on any failed test, any script
## error raised while a test runs, or any test file that fails to load or parse.

const DIR := "res://tests"


class ErrorCatcher extends Logger:
	var script_errors: PackedStringArray = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _backtraces: Array) -> void:
		if error_type == ERROR_TYPE_SCRIPT:
			script_errors.append("%s:%d %s %s" % [file, line, function, rationale if rationale else code])

	func _log_message(_message: String, _error: bool) -> void:
		pass


func _init() -> void:
	# Run after the first frame so autoloads are in the tree.
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var catcher := ErrorCatcher.new()
	OS.add_logger(catcher)
	var passed := 0
	var failed := 0
	var load_errors := 0
	var files := Array(DirAccess.get_files_at(DIR)).filter(
		func(f: String) -> bool: return f.begins_with("test_") and f.ends_with(".gd"))
	files.sort()
	if files.is_empty():
		print("no test files found")
		load_errors += 1
	for f in files:
		var path: String = DIR.path_join(f)
		var script: Script = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if script == null or not script.can_instantiate():
			print("LOAD ERROR  %s" % path)
			load_errors += 1
			continue
		var methods: Array = script.get_script_method_list().map(func(m: Dictionary) -> String: return m.name)
		methods = methods.filter(func(m: String) -> bool: return m.begins_with("test_"))
		for m in methods:
			var tc: Object = script.new()
			if not tc.has_method("check"):
				print("LOAD ERROR  %s does not extend TestCase" % path)
				load_errors += 1
				break
			catcher.script_errors.clear()
			if tc.has_method("before_each"):
				await tc.before_each()
			await tc.call(m)
			var problems: PackedStringArray = tc.failures.duplicate()
			problems.append_array(catcher.script_errors)
			if tc.has_method("after_each"):
				tc.after_each()
			if problems.is_empty():
				passed += 1
				print("ok    %s::%s" % [f, m])
			else:
				failed += 1
				print("FAIL  %s::%s" % [f, m])
				for p in problems:
					print("        " + p)
	OS.remove_logger(catcher)
	print("TESTS: %d passed, %d failed, %d load errors" % [passed, failed, load_errors])
	quit(1 if failed > 0 or load_errors > 0 else 0)
