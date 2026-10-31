extends "res://src/player/weight_deck.gd"
## Root of scenes/sight/sight_deck.tscn: the weight deck in the dark, with sight, the flashlight
## and doors. F flashlight, E door, F2 sight debug, plus everything weight_deck has.
## Env SIGHT_FLASHLIGHT=on|off fixes the light for a frame-time capture.

const SightSystem := preload("res://src/sight/sight_system.gd")
const SightMask := preload("res://src/sight/sight_mask.gd")
const SightTarget := preload("res://src/sight/sight_target.gd")
const SightDebug := preload("res://src/sight/sight_debug.gd")
const Flashlight := preload("res://src/sight/flashlight.gd")
const DoorSystem := preload("res://src/doors/door_system.gd")
const DeckLighting := preload("res://src/kit/deck_lighting.gd")

var sight: SightSystem
var mask: SightMask
var flashlight: Flashlight
var doors: DoorSystem
var sight_debug: SightDebug
var deck_lighting: DeckLighting

var _env_light := ""


func _ready() -> void:
	super()
	deck_lighting = DeckLighting.new()
	add_child(deck_lighting)
	deck_lighting.setup(layout, _plain_env, get_node("Deck"))
	doors = DoorSystem.new()
	doors.name = "Doors"
	add_child(doors)
	doors.setup(layout)
	sight = SightSystem.new()
	sight.name = "Sight"
	add_child(sight)
	sight.setup(layout)
	sight.refresh_occluders()
	mask = SightMask.new()
	mask.name = "SightMask"
	add_child(mask)
	mask.setup(sight)
	flashlight = Flashlight.new()
	flashlight.name = "Flashlight"
	add_child(flashlight)
	flashlight.setup(sight.cfg)
	flashlight.spot.light_volumetric_fog_energy = float(deck_lighting.cfg.fog.flashlight_energy)
	flashlight.set_mask(mask.visible_texture(), sight.bounds)
	sight_debug = SightDebug.new()
	sight_debug.name = "SightDebug"
	add_child(sight_debug)
	sight_debug.setup(sight)
	for t in targets:
		var st := SightTarget.new()
		st.name = "SightTarget"
		t.add_child(st)
	hud.scene_help = _help_text()
	_env_light = OS.get_environment("SIGHT_FLASHLIGHT")
	if _env_light != "":
		flashlight.set_on(_env_light == "on")
	sight.forget()
	_update_sight(0.0, true)


func _help_text() -> String:
	return String(sight.cfg.help.text)


## Sight's own darker numbers on top of the deck's, in a copy so nothing else sees them.
func _make_lighting() -> void:
	deck_data = deck_data.duplicate(true)
	deck_data.lighting.merge(Data.value("sight", "lighting", {}), true)
	super()


## Back to the spawn and forget the deck: a respawn is a new run.
func respawn() -> void:
	super()
	if sight:
		sight.forget()
		_update_sight(0.0, true)


func _process(delta: float) -> void:
	super(delta)
	doors.actors = [{"position": _eye(), "radius": operator.body_radius()}]
	doors.show_prompt(_eye())
	if panel and panel.visible:
		mask.apply_cfg()
		flashlight.apply_cfg()
	hud.light_off = not flashlight.on
	_update_sight(delta, false)


func _eye() -> Vector2:
	return Vector2(operator.global_position.x, operator.global_position.z)


func _update_sight(delta: float, force_memory: bool) -> void:
	var yaw := operator.gun_yaw()
	sight.update_sight(_eye(), yaw, flashlight.on, delta, force_memory)
	var muzzle := operator.muzzle_position()
	flashlight.follow(muzzle, yaw)
	flashlight.draw_beam(sight.visibility, _eye(), yaw, muzzle, delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).physical_keycode:
			KEY_F:
				flashlight.toggle()
			KEY_E:
				doors.interact(_eye())
			KEY_F2:
				sight_debug.toggle()
			_:
				super(event)
				return
		get_viewport().set_input_as_handled()
		return
	super(event)


## Captures: how much the mask hides. "off" no mask (the art alone), "known" everything already seen
## (the paint-overs show rooms you know), "play" as it is.
func set_kit_view(view: String) -> void:
	mask.visible = view != "off"
	if view == "known":
		mask.reveal_all()


# --- capture hooks (src/debug/capture.gd) ---

func capture_shots() -> Array[Dictionary]:
	return [
		{"name": "enter_medbay_three_states", "do": "enter"},
		{"name": "flashlight_on", "do": "light", "on": true},
		{"name": "flashlight_off", "do": "light", "on": false},
		{"name": "door_closed", "do": "door", "open": false},
		{"name": "door_open", "do": "door", "open": true},
		{"name": "door_locked_prompt", "do": "locked"},
		{"name": "target_hidden", "do": "target", "seen": false},
		{"name": "target_seen", "do": "target", "seen": true},
		{"name": "debug_f2", "do": "debug"},
		{"name": "camera_ortho", "do": "preset", "index": 3},
		{"name": "postfx_glow_ssao_fog", "do": "postfx"},
	]


func apply_shot(shot: Dictionary) -> void:
	_demo_t = -1.0
	Engine.time_scale = 1.0
	if panel:
		panel.visible = false
	sight_debug.visible = false
	flashlight.set_on(_captured_light())
	match String(shot.do):
		"enter":
			await _walk_in_to_medbay()
		"light":
			await _walk_in_to_medbay()
			flashlight.set_on(bool(shot.on))
			await _sim(0.1)
		"door":
			await _at_medbay_door(bool(shot.open))
		"locked":
			await _stand(_door_side(_door("cargo", 0.2), -1.0), _door(("cargo"), 0.2).opening.get_center())
		"target":
			await _target_shot(bool(shot.seen))
		"debug":
			await _walk_in_to_medbay()
			sight_debug.toggle()
			sight_debug.redraw()
		"preset":
			rig.set_preset(int(shot.index))
			await _walk_in_to_medbay()
		"postfx":
			rig.set_preset(int(Data.value("camera", "default_preset")))
			_set_postfx(true)
			await _walk_in_to_medbay()
	await _sim(0.15)
	Engine.time_scale = 0.0


func release_shot() -> void:
	super()
	flashlight.set_on(_captured_light())
	sight_debug.visible = false


func _captured_light() -> bool:
	return _env_light != "off"


## The door of `space_name` at the data's `at` (cargo has two).
func _door(space_name: String, at: float) -> Node:
	var specs: Array = deck_data.doors
	for i in specs.size():
		if String(specs[i].space) == space_name and absf(float(specs[i].at) - at) < 0.001:
			return doors.doors[i]
	return null


## A point on one side of a door's opening; side -1 is toward smaller x (or z).
func _door_side(d: Node, side: float, dist := 1.6) -> Vector2:
	var c: Vector2 = d.opening.get_center()
	return c + (Vector2(0, side) if d.along_x else Vector2(side, 0)) * dist


func _stand(p: Vector2, look: Vector2) -> void:
	operator.scripted = {}
	operator.global_position = Vector3(p.x, 0, p.y)
	operator.model.reset_motion()
	operator.face_now(Vector3(look.x, _aim_height, look.y))
	rig.aim_dir = operator.aim_dir()
	rig.snap()
	await _sim(0.1)


func _set_door(d: Node, open: bool) -> void:
	if d.door_state.blocks() == open:
		doors.interact(d.opening.get_center())
	await _sim(float(doors.cfg.open_s) + 0.1)


## Look around the junction, open the medbay door, step into its mouth: the junction is
## remembered behind, the medbay lit ahead, cargo and the medbay's far side still unknown.
func _walk_in_to_medbay() -> void:
	super.respawn()
	sight.forget()
	var d := _door("medbay", 0.7)
	if d.door_state.blocks() == false:
		await _set_door(d, false)
	var c: Vector2 = d.opening.get_center()
	await _stand(Vector2(3.0, c.y - 4.0), Vector2(0.0, c.y))
	await _stand(Vector2(3.0, c.y), Vector2(0.0, c.y + 6.0))
	await _stand(_door_side(d, 1.0, 1.4), c)
	await _set_door(d, true)
	await _stand(_door_side(d, -1.0, 0.9), _door_side(d, -1.0, 6.0))


func _at_medbay_door(open: bool) -> void:
	super.respawn()
	sight.forget()
	var d := _door("medbay", 0.7)
	await _set_door(d, open)
	await _stand(_door_side(d, 1.0, 2.0), _door_side(d, -1.0, 4.0))


## A dummy in the medbay, from the junction: door shut, hidden; door open, seen.
func _target_shot(seen: bool) -> void:
	super.respawn()
	sight.forget()
	var d := _door("medbay", 0.7)
	await _set_door(d, seen)
	var t: Node3D = targets[2]
	var look := Vector2(t.global_position.x, t.global_position.z)
	await _stand(_door_side(d, 1.0, 2.0), look)


## Measuring window: pace the open medbay door and sweep the light through the room, no firing,
## so only the light differs between the on and off runs.
func _demo_step(delta: float) -> void:
	var d := _door("medbay", 0.7)
	if _demo_t == 0.0:
		if d.door_state.blocks():
			d.door_state.progress = 1.0
			d.door_state.state = d.door_state.State.OPEN
		var p := _door_side(d, 1.0, 1.0)
		operator.global_position = Vector3(p.x, 0, p.y)
		rig.snap()
	_demo_t += delta
	var phase := fmod(_demo_t, 4.0)
	operator.scripted = {"keys": Vector2(-1, 0) if phase < 1.0 else (Vector2(1, 0) if phase < 2.0 else Vector2.ZERO)}
	var a := -90.0 + sin(_demo_t * 1.5) * 50.0
	operator.aim_point = _ahead(a)
