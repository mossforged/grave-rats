extends SceneTree
## Builds the legacy wrapper resources from the imported glbs. Re-run after reimporting them.
##   assets/game/legacy/anim/legacy_clips.tres  AnimationLibrary of the operator clips (saved by operator.glb.import)
##   assets/game/legacy/kit/<piece>.tscn        one scene per kit piece (meshes saved by kit.glb.import)
##   assets/game/legacy/robot.tscn              robot.glb + an AnimationPlayer with the operator clips
## Run: godot --headless --path . -s tools/godot/build_legacy_scenes.gd

const ROOT := "res://assets/game/legacy/"


func _init() -> void:
	var lib := AnimationLibrary.new()
	for f in DirAccess.get_files_at(ROOT + "anim"):
		if f.ends_with(".res"):
			lib.add_animation(f.get_basename(), load(ROOT + "anim/" + f))
	_save(lib, ROOT + "anim/legacy_clips.tres")
	lib = load(ROOT + "anim/legacy_clips.tres")

	for f in DirAccess.get_files_at(ROOT + "kit/meshes"):
		if not f.ends_with(".res"):
			continue
		var piece := f.get_basename()
		var root := Node3D.new()
		root.name = piece
		var mi := MeshInstance3D.new()
		mi.name = "Mesh"
		mi.mesh = load(ROOT + "kit/meshes/" + f)
		root.add_child(mi)
		mi.owner = root
		_pack(root, ROOT + "kit/" + piece + ".tscn")

	var robot := Node3D.new()
	robot.name = "robot"
	var model: Node3D = load(ROOT + "robot.glb").instantiate()
	model.name = "Model"
	robot.add_child(model)
	model.owner = robot
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	ap.add_animation_library("", lib)
	robot.add_child(ap)
	ap.owner = robot
	ap.root_node = NodePath("../Model")
	_pack(robot, ROOT + "robot.tscn")
	quit(0)


func _pack(root: Node, path: String) -> void:
	var ps := PackedScene.new()
	ps.pack(root)
	_save(ps, path)
	root.free()


func _save(res: Resource, path: String) -> void:
	var err := ResourceSaver.save(res, path)
	print("%s -> %s" % [path, error_string(err)])
	if err != OK:
		quit(1)
