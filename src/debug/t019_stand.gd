extends "res://src/shift/shift_deck.gd"
## Root of scenes/dev/t019_stand.tscn: T019's stands on the real shift deck, from the game camera. Run
## once with KIT_CORRIDORS=off for the "before" of the same shots.
## tools/capture.sh scenes/dev/t019_stand.tscn docs/screens/T019 2

const CorridorDressing := preload("res://src/kit/corridor_dressing.gd")

const STANDS := [
	{"name": "long_corridor_north", "space": "junction", "at": [0.5, 0.3], "aim": [0.5, 0.0], "view": "off"},
	{"name": "long_corridor_south", "space": "junction", "at": [0.5, 0.72], "aim": [0.5, 1.0], "view": "off"},
	{"name": "side_corridor", "space": "side_corridor", "at": [0.5, 0.5], "aim": [1.0, 0.5], "view": "off"},
	{"name": "door_jambs_lintel", "space": "side_corridor", "at": [0.8, 0.7], "aim": [0.8, 0.0], "view": "off"},
	{"name": "door_side", "space": "junction", "at": [0.55, 0.27], "aim": [1.0, 0.27], "view": "off"},
	{"name": "inner_corner", "space": "side_corridor", "at": [0.88, 0.6], "aim": [1.0, 0.0], "view": "off"},
	{"name": "grimmest", "space": "side_corridor", "at": [0.2, 0.75], "aim": [0.2, 0.0], "view": "off"},
	{"name": "grimmest_play", "space": "side_corridor", "at": [0.2, 0.75], "aim": [0.2, 0.0], "view": "play"},
	{"name": "long_corridor_play", "space": "junction", "at": [0.5, 0.45], "aim": [0.5, 0.1], "view": "play"},
]


func capture_shots() -> Array[Dictionary]:
	var tag := "before" if OS.get_environment("KIT_CORRIDORS") == "off" else "after"
	var shots: Array[Dictionary] = []
	for s: Dictionary in STANDS:
		var shot: Dictionary = s.duplicate()
		shot.stand = s.name
		shot.name = "t019_%s_%s" % [s.name, tag]
		shots.append(shot)
	return shots


func apply_shot(shot: Dictionary) -> void:
	_demo_t = -1.0
	Engine.time_scale = 1.0
	panel.visible = false
	sight_debug.visible = false
	_close_form()
	session_live = false
	respawn()
	rig.set_preset(int(Data.value("camera", "default_preset")))
	flashlight.set_on(true)
	ambush.fired = true
	set_kit_view(String(shot.view))
	await _stand_at(layout.point_in(String(shot.space), shot.at), layout.point_in(String(shot.space), shot.aim))
	await _sim(0.25)
	Engine.time_scale = 0.0
