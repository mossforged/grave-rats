extends Node3D
## Root of scenes/study/scale_deck.tscn: the T002 camera and scale study.
## Builds the grey-box deck from data/deck.json, spawns the stand-in, follows it with the
## camera rig (src/camera), and offers live keys:
##   1-5 camera presets, 6/7/8 room scale, 9/0 character scale, C cut-away mode,
##   WASD move, mouse aim, F3 frame time.
## Capture hooks (capture_shots/apply_shot) feed tools/capture.sh.

const DeckLayout := preload("res://src/study/deck_layout.gd")
const DeckBuilder := preload("res://src/study/deck_builder.gd")
const CameraRig := preload("res://src/camera/camera_rig.gd")
const StandIn := preload("res://src/study/stand_in.gd")
const CameraMath := preload("res://src/camera/camera_math.gd")

var deck_data: Dictionary
var layout: DeckLayout
var room_scale := 1.0
var rig: Node3D
var stand_in: CharacterBody3D
var aim_from_mouse := true

var _deck: Node3D
var _hud: Label
var _aim_height := 1.2


func _ready() -> void:
	deck_data = Data.load_data("deck")
	_aim_height = float(deck_data.stand_in.aim_height_m)
	_make_lighting()
	stand_in = StandIn.new()
	stand_in.name = "StandIn"
	add_child(stand_in)
	rig = CameraRig.new()
	rig.name = "CameraRig"
	add_child(rig)
	rig.target = stand_in
	_make_hud()
	rig.preset_changed.connect(func(_i: int, _p: Dictionary) -> void: _update_hud())
	rig.cutaway_mode_changed.connect(func(_m: String) -> void: _update_hud())
	# Captures hold a fixed pose instead of following the mouse wherever the window opens.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-out="):
			aim_from_mouse = false
			stand_in.input_enabled = false
	set_room_scale(float(deck_data.room_scale))
	respawn()


## Rebuilds the deck at room scale `s`; the stand-in keeps its relative spot in its space.
func set_room_scale(s: float) -> void:
	var where := ""
	var frac := Vector2.ZERO
	if layout and stand_in.is_inside_tree():
		var p := Vector2(stand_in.global_position.x, stand_in.global_position.z)
		where = layout.space_at(p)
		if where != "":
			var r := layout.space_rect(where)
			frac = (p - r.position) / r.size
	room_scale = s
	layout = DeckLayout.new(deck_data, s)
	if _deck:
		remove_child(_deck)
		_deck.queue_free()
	_deck = DeckBuilder.build(layout)
	add_child(_deck)
	if where != "":
		var q := layout.point_in(where, [frac.x, frac.y])
		if layout.is_free(q, stand_in.radius()):
			stand_in.global_position = Vector3(q.x, 0, q.y)
		else:
			respawn()
	_update_hud()


func set_character_scale(s: float) -> void:
	stand_in.set_character_scale(s)
	_update_hud()


## Puts the stand-in at data "spawn" and aims it at spawn.aim_deg (0 = screen-up / north, 90 = east).
func respawn() -> void:
	var sp: Dictionary = deck_data.spawn
	var p := layout.point_in(String(sp.space), sp.at)
	stand_in.global_position = Vector3(p.x, 0, p.y)
	var a := deg_to_rad(float(sp.aim_deg))
	var aim := Vector3(p.x + sin(a) * 5.0, _aim_height, p.y - cos(a) * 5.0)
	stand_in.face_now(aim)
	rig.aim_dir = stand_in.aim_dir()
	rig.snap()


func _process(_delta: float) -> void:
	if aim_from_mouse:
		var cam: Camera3D = rig.camera
		var mp := get_viewport().get_mouse_position()
		var hit: Variant = Plane(Vector3.UP, _aim_height).intersects_ray(
				cam.project_ray_origin(mp), cam.project_ray_normal(mp))
		if hit != null:
			stand_in.aim_point = hit
	stand_in.move_yaw_deg = float(rig.preset().yaw_deg)
	rig.aim_dir = stand_in.aim_dir()
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var k := (event as InputEventKey).physical_keycode
	var rooms: Array = deck_data.room_scale_options
	var chars: Array = deck_data.character_scale_options
	if k >= KEY_1 and k <= KEY_5 and k - KEY_1 < rig.presets.size():
		rig.set_preset(k - KEY_1)
	elif k >= KEY_6 and k <= KEY_8 and k - KEY_6 < rooms.size():
		set_room_scale(float(rooms[k - KEY_6]))
	elif k == KEY_9 and chars.size() > 0:
		set_character_scale(float(chars[0]))
	elif k == KEY_0 and chars.size() > 1:
		set_character_scale(float(chars[1]))
	elif k == KEY_C:
		rig.cycle_cutaway_mode()
	elif k == KEY_R:
		respawn()
	else:
		return
	get_viewport().set_input_as_handled()


# --- capture hooks (src/debug/capture.gd) ---

## Every camera preset at default scale, then the concept preset at each room scale and with the
## bigger character.
func capture_shots() -> Array[Dictionary]:
	var shots: Array[Dictionary] = []
	for i in rig.presets.size():
		var n := String(rig.presets[i].name).to_snake_case().replace(":", "").replace("/", "").replace("__", "_")
		shots.append({"name": "preset_%d_%s" % [i + 1, n], "preset": i, "room": 1.0, "char": 1.0})
	for s in deck_data.room_scale_options:
		shots.append({"name": "concept_room_%03d" % roundi(float(s) * 100.0), "preset": 0, "room": float(s), "char": 1.0})
	var big := float(deck_data.character_scale_options[-1])
	shots.append({"name": "concept_room_100_char_%03d" % roundi(big * 100.0), "preset": 0, "room": 1.0, "char": big})
	shots.append({"name": "concept_room_100_fade", "preset": 0, "room": 1.0, "char": 1.0, "cutaway": "fade"})
	shots.append({"name": "concept_room_100_medbay", "preset": 0, "room": 1.0, "char": 1.0, "at": ["medbay", [0.55, 0.6]]})
	shots.append({"name": "concept_room_100_cargo", "preset": 0, "room": 1.0, "char": 1.0, "at": ["cargo", [0.3, 0.75]]})
	return shots


func apply_shot(shot: Dictionary) -> void:
	set_character_scale(float(shot.char))
	if not is_equal_approx(room_scale, float(shot.room)):
		set_room_scale(float(shot.room))
	rig.set_cutaway_mode(String(shot.get("cutaway", rig.cutaway.mode)))
	rig.set_preset(int(shot.preset))
	respawn()
	if shot.has("at"):
		var p := layout.point_in(String(shot.at[0]), shot.at[1])
		stand_in.global_position = Vector3(p.x, 0, p.y)
		rig.snap()


func release_shot() -> void:
	apply_shot({"preset": 0, "room": float(deck_data.room_scale), "char": float(deck_data.character_scale)})


# --- setup ---

func _make_lighting() -> void:
	var l: Dictionary = deck_data.lighting
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(l.background_color)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(l.ambient_color)
	env.ambient_light_energy = float(l.ambient_energy)
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(l.sun_color)
	sun.light_energy = float(l.sun_energy)
	sun.shadow_enabled = bool(l.sun_shadows)
	sun.directional_shadow_max_distance = float(l.sun_shadow_max_distance_m)
	sun.shadow_blur = float(l.sun_shadow_blur)
	sun.rotation_degrees = Vector3(float(l.sun_pitch_deg), float(l.sun_yaw_deg), 0)
	add_child(sun)


func _make_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	_hud = Label.new()
	_hud.add_theme_font_size_override("font_size", 20)
	_hud.add_theme_color_override("font_outline_color", Color.BLACK)
	_hud.add_theme_constant_override("outline_size", 5)
	_hud.anchor_top = 1.0
	_hud.anchor_bottom = 1.0
	_hud.offset_left = 16
	_hud.offset_top = -96
	_hud.grow_vertical = Control.GROW_DIRECTION_BEGIN
	layer.add_child(_hud)


func _update_hud() -> void:
	if _hud == null or rig == null or rig.camera == null:
		return
	var p: Dictionary = rig.preset()
	var lens := "ortho size %.0f m" % float(p.ortho_size_m) if CameraMath.is_ortho(p) \
			else "fov %.0f°  dist %.0f m" % [float(p.fov_deg), float(p.distance_m)]
	var vp := get_viewport().get_visible_rect().size
	var aspect := vp.x / maxf(vp.y, 1.0)
	var model_h: float = float(deck_data.stand_in.height_m) * stand_in.character_scale
	var frac := CameraMath.screen_height_fraction(rig.camera.global_transform, p,
			stand_in.global_position, model_h, aspect)
	_hud.text = "[%d] %s   pitch %.0f°  yaw %.0f°  %s\nroom ×%.2f   character ×%.2f   cut-away: %s   operator %.1f%% of view height\n1-5 camera   6/7/8 room 0.85/1.0/1.15   9/0 character 1.0/1.15   C cut-away   R respawn   WASD + mouse" % [
		rig.preset_index + 1, String(p.name).to_upper(), float(p.pitch_deg), float(p.yaw_deg), lens,
		room_scale, stand_in.character_scale, rig.cutaway_mode, frac * 100.0]
