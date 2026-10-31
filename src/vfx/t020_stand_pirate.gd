extends "res://src/pirates/pirate_deck.gd"
## Root of scenes/dev/t020_stand_pirate.tscn: T020's capture on the real pirate deck, not a game scene.

const Stage := preload("res://src/vfx/t020_stage.gd")

var stage: Stage


func _ready() -> void:
	super()
	stage = Stage.new(self)


func simulate_world(_delta: float) -> void:
	pass


func capture_shots() -> Array[Dictionary]:
	return stage.shots(false)


func apply_shot(shot: Dictionary) -> void:
	_demo_t = -1.0
	_open_all_doors()
	await stage.apply(shot)


func release_shot() -> void:
	Engine.time_scale = 1.0


## The sight deck's capture helper, which this deck doesn't have.
func _stand_at(p: Vector2, look: Vector2) -> void:
	await _stand(p, look)
	rig.aim_dir = operator.aim_dir()
