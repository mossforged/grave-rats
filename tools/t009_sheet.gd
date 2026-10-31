extends Node3D
## T009: a row of bodies in a plain room, for looking at the hauler state by state. Saves PNGs to the
## given folder and quits. Run windowed, for the real GPU:
##   godot --path . scenes/dev/t009_sheet.tscn -- --out=docs/screens/T009

const OperatorBody := preload("res://src/player/operator_body.gd")

const STATES := ["idle", "walk_fwd", "walk_back", "walk_left", "walk_right", "run_fwd", "sprint_fwd", "crouch_idle",
	"crouch_walk_fwd", "crouch_aim", "aim", "low", "reload", "roll", "hit_front", "death", "turn_left"]

var _out := "docs/screens/T009"
var _cam: Camera3D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(_out)
	get_window().size = Vector2i(1800, 1000)
	_room()
	_cam = Camera3D.new()
	add_child(_cam)
	await _clip_sheet()
	get_tree().quit(0)


func _room() -> void:
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	floor_mesh.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.32, 0.33, 0.35)
	floor_mesh.material_override = mat
	add_child(floor_mesh)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 30, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.12, 0.13, 0.15)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.7, 0.75)
	e.ambient_light_energy = 0.6
	env.environment = e
	add_child(env)


## One hauler per clip, frozen a little way into it, playing the raw clip with no tree or twist, with
## its rifle. Bones are posed by the AnimationPlayer, so this shows the clips, not the mix.
func _clip_sheet() -> void:
	var holder := Node3D.new()
	add_child(holder)
	var columns := 6
	var i := 0
	var labels: Array[Label3D] = []
	for state: String in STATES:
		var slot := Node3D.new()
		holder.add_child(slot)
		slot.position = Vector3((i % columns) * 2.2, 0, (i / columns) * 2.8)
		var body := OperatorBody.build(slot, "hauler", _anim_cfg(), "weapon")
		body.anim.tree.active = false
		body.anim.twist.active = false
		var player: AnimationPlayer = body.visual.find_children("*", "AnimationPlayer", true, false)[0]
		var at: float = 0.6 if state == "death" else 0.3
		player.play("hauler/" + state)
		player.seek(player.current_animation_length * at, true)
		player.pause()
		var label := Label3D.new()
		label.text = state
		label.pixel_size = 0.006
		label.font_size = 42
		label.outline_size = 12
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = Vector3(0, 2.25, 0)
		slot.add_child(label)
		labels.append(label)
		i += 1
	var rows: int = ceili(float(STATES.size()) / columns)
	var center := Vector3((columns - 1) * 1.1, 0.9, (rows - 1) * 1.4)
	for view: Array in [["front", Vector3(0, 7.5, 13.5)], ["back", Vector3(0, 7.5, -13.5)], ["top", Vector3(5, 15, 7)]]:
		_cam.position = center + (view[1] as Vector3)
		_cam.look_at(center)
		_cam.fov = 42
		await _shot("clips_%s" % view[0])
	holder.queue_free()


func _anim_cfg() -> Dictionary:
	var weight: Dictionary = Data.load_data("player")
	return OperatorBody.weight_for("hauler", weight).anim


func _shot(shot_name: String) -> void:
	for f in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [_out, shot_name]
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)
