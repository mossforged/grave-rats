extends "res://tools/t006_bots.gd"
## Q001: tools/t006_bots.gd with every random source that moves its numbers fixed. The original seeds
## the stalkers but not the player's rifle, so the bots that fire differ from run to run.
## usage: godot --headless --path . --fixed-fps 60 -s tools/qa/t006_seeded.gd [runs]

const RIFLE_SEED := 3000

var _fights := 0


func _ambush(react_s: float) -> Dictionary:
	_seed_rifle()
	return await super(react_s)


func _tracker(lag_s: float) -> Dictionary:
	_seed_rifle()
	return await super(lag_s)


func _seed_rifle() -> void:
	op.rifle.state.rng.seed = RIFLE_SEED + _fights
	_fights += 1
