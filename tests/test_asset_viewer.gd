extends "res://tests/test_case.gd"
## scenes/dev/asset_viewer.tscn builds headless: lights, camera, actors and the layered run tree.

var _scene: Node


func after_each() -> void:
	if is_instance_valid(_scene):
		_scene.free()


func test_viewer_builds() -> void:
	var ps: PackedScene = load("res://scenes/dev/asset_viewer.tscn")
	if not check(ps != null, "asset_viewer.tscn loads"):
		return
	_scene = ps.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(_scene)
	var spot: SpotLight3D = _scene.get_node("Operator1/Flashlight")
	check(spot.shadow_enabled, "flashlight casts shadows")
	check_eq(spot.spot_range, float(Data.value("viewer", "flashlight").range), "flashlight range comes from data/viewer.json")
	check(_scene.get_node("Operator1").global_basis.z.dot(-spot.global_basis.z) < -0.9,
		"flashlight points where the operator faces (-Z forward)")
	var env: Environment = _scene.get_node("WorldEnvironment").environment
	check(env.glow_enabled and env.ssao_enabled and env.volumetric_fog_enabled, "glow, SSAO and volumetric fog on")
	var tree: AnimationTree = _scene.get_node("Operator1").find_child("AnimationTree", true, false)
	check(tree != null and tree.active, "running operator has an active layered AnimationTree")
	check_eq(_scene.capture_shots().size(), (Data.value("viewer", "shots") as Array).size(), "capture shots exposed")
	_scene.apply_shot(_scene.capture_shots()[0])
	_scene.release_shot()
