extends "res://src/shift/shift_deck.gd"
## Root of scenes/dev/t023_stand.tscn: T023's stands on the survey vessel, from the game camera, and the
## frame-time stands for both ships. Env T023_SHIP = a deck file (default deck_survey). Env T023_AT =
## "space,fx,fz" stands the player there for the frame-time window.
## tools/capture.sh scenes/dev/t023_stand.tscn docs/screens/T023 2

const STANDS := [
	{"name": "bridge", "space": "bridge", "at": [0.42, 0.72], "aim": [0.6, 0.1], "view": "off"},
	{"name": "bridge_black_box", "space": "bridge", "at": [0.5, 0.82], "aim": [0.57, 0.42], "view": "off"},
	{"name": "bridge_black_box_play", "space": "bridge", "at": [0.46, 0.8], "aim": [0.57, 0.42], "view": "play"},
	{"name": "bio_lab", "space": "bio_lab", "at": [0.42, 0.55], "aim": [0.42, 0.1], "view": "off"},
	{"name": "bio_lab_tanks_play", "space": "bio_lab", "at": [0.42, 0.5], "aim": [0.42, 0.1], "view": "play"},
	{"name": "bio_lab_seal_trolley", "space": "east_spine", "at": [0.5, 0.42], "aim": [0.1, 0.29], "view": "off"},
	{"name": "bio_lab_seal_play", "space": "east_spine", "at": [0.5, 0.45], "aim": [0.1, 0.29], "view": "play"},
	{"name": "mess", "space": "mess", "at": [0.5, 0.6], "aim": [0.5, 0.1], "view": "off"},
	{"name": "quarters", "space": "quarters", "at": [0.45, 0.45], "aim": [0.45, 0.05], "view": "off"},
	{"name": "engineering_dead_end", "space": "engineering", "at": [0.3, 0.55], "aim": [0.6, 0.2], "view": "off"},
	{"name": "engineering_door_play", "space": "engineering", "at": [0.18, 0.5], "aim": [0.7, 0.65], "view": "play"},
	{"name": "airlock_hold", "space": "airlock", "at": [0.55, 0.55], "aim": [0.5, 0.1], "view": "off"},
	{"name": "west_spine_north", "space": "west_spine", "at": [0.5, 0.45], "aim": [0.5, 0.1], "view": "off"},
	{"name": "west_spine_south", "space": "west_spine", "at": [0.5, 0.6], "aim": [0.5, 0.95], "view": "off"},
	{"name": "west_spine_play", "space": "west_spine", "at": [0.5, 0.4], "aim": [0.5, 0.1], "view": "play"},
	{"name": "east_spine_north", "space": "east_spine", "at": [0.5, 0.5], "aim": [0.5, 0.1], "view": "off"},
	{"name": "east_spine_south", "space": "east_spine", "at": [0.5, 0.6], "aim": [0.5, 0.95], "view": "off"},
	{"name": "east_spine_grim", "space": "east_spine", "at": [0.45, 0.2], "aim": [0.85, 0.08], "view": "off"},
	{"name": "east_spine_play", "space": "east_spine", "at": [0.5, 0.4], "aim": [0.5, 0.1], "view": "play"},
]


func _ready() -> void:
	var ship := OS.get_environment("T023_SHIP")
	Data.use_ship("deck_survey" if ship == "" else ship)
	super()
	var at := OS.get_environment("T023_AT").split(",")
	if at.size() == 3:
		var p := layout.point_in(at[0], [float(at[1]), float(at[2])])
		_demo_t = -1.0
		ambush.fired = true
		operator.global_position = Vector3(p.x, 0.0, p.y)
		flashlight.set_on(true)
		_quiet_stalkers()
		rig.snap()


## Both ships stand still for the frame-time window: the deck's own demo walks the first ship's rooms.
func _demo_step(_delta: float) -> void:
	pass


func _exit_tree() -> void:
	super()
	Data.reset_ship()


func capture_shots() -> Array[Dictionary]:
	var shots: Array[Dictionary] = []
	for s: Dictionary in STANDS:
		var shot: Dictionary = s.duplicate()
		shot.name = "t023_%s" % s.name
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
	_quiet_stalkers()
	set_kit_view(String(shot.view))
	await _stand_at(layout.point_in(String(shot.space), shot.at), layout.point_in(String(shot.space), shot.aim))
	await _sim(0.25)
	Engine.time_scale = 0.0


func release_shot() -> void:
	Engine.time_scale = 1.0
