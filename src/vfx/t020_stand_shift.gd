extends "res://src/shift/shift_deck.gd"
## Root of scenes/dev/t020_stand_shift.tscn: T020's capture on the real shift deck, not a game scene.

const Stage := preload("res://src/vfx/t020_stage.gd")

var stage: Stage


func _ready() -> void:
	super()
	stage = Stage.new(self)
	if OS.has_environment("T020_MOVIE"):
		_movie.call_deferred()


func simulate_world(_delta: float) -> void:
	pass


func capture_shots() -> Array[Dictionary]:
	return stage.shots(true)


func apply_shot(shot: Dictionary) -> void:
	session_live = false
	_close_form()
	_demo_t = -1.0
	ambush.fired = true
	await stage.apply(shot)


func release_shot() -> void:
	Engine.time_scale = 1.0


## For the screen recording: a full magazine into a metal wall, then the reload, from an empty one.
func _movie() -> void:
	_close_form()
	session_live = false
	ambush.fired = true
	operator.input_enabled = false
	aim_from_mouse = false
	await stage._to_wall("junction", "metal")
	await _sim(0.6)
	operator.scripted = {"fire": true}
	while operator.rifle.state.mag > 0:
		await get_tree().process_frame
	await _sim(0.5)
	operator.scripted = {}
	await _sim(0.5)
	operator.request_reload()
	await _sim(3.0)
	get_tree().quit()
