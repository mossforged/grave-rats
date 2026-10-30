extends "res://tests/test_case.gd"
## src/core/data.gd: good file, missing file, bad JSON, and the real data/ files.

const DataScript := preload("res://src/core/data.gd")

var data: Node


func before_each() -> void:
	data = DataScript.new()
	data.base_dir = "res://tests/fixtures/data"


func after_each() -> void:
	data.free()


func test_good_file_loads() -> void:
	var d: Variant = data.load_data("good")
	check(d is Dictionary, "good.json parses to a Dictionary")
	check_eq(data.last_error, "", "no error on a good file")
	check_eq(data.value("good", "speed"), 4.8, "number read back")
	check_eq(data.value("good", "name"), "rat", "string read back")


func test_missing_file_fails_loudly() -> void:
	check(data.load_data("does_not_exist") == null, "missing file returns null")
	check(data.last_error.contains("missing"), "missing file sets last_error: " + data.last_error)


func test_bad_json_fails_loudly() -> void:
	check(data.load_data("bad") == null, "bad JSON returns null")
	check(data.last_error.contains("bad JSON"), "bad JSON sets last_error: " + data.last_error)


func test_missing_key_returns_fallback() -> void:
	check_eq(data.value("good", "nope", 7), 7, "fallback on missing key")
	check(data.last_error.contains("nope"), "missing key sets last_error")


func test_project_data_files_all_parse() -> void:
	data.base_dir = "res://data"
	var files := Array(DirAccess.get_files_at("res://data")).filter(func(f: String) -> bool: return f.ends_with(".json"))
	check(files.size() > 0, "data/ has json files")
	for f in files:
		check(data.load_data(f.get_basename()) is Dictionary, "data/%s parses" % f)
	check(data.value("debug", "fps_overlay") is bool, "debug.json has the fps_overlay toggle")


func test_autoload_present() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	check(tree.root.has_node("Data"), "Data autoload in the tree")
