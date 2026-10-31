extends "res://tools/t007_bots.gd"
## Q001: tools/t007_bots.gd with every random source that moves its numbers fixed. The original seeds
## the pirates in _report, but _bot then calls squad.reset(), which builds new brains with random
## seeds, and it never seeds the player's rifle. _in_sight is the first call after that reset, so the
## seeds go in there. usage: godot --headless --path . --fixed-fps 60 -s tools/qa/t007_seeded.gd [runs]

const RIFLE_SEED := 3000

var _fights := 0
var _seed_pending := false


func _bot(stance: String, fires: bool) -> Dictionary:
	op.rifle.state.rng.seed = RIFLE_SEED + _fights
	_seed_pending = true
	var row: Dictionary = await super(stance, fires)
	_fights += 1
	return row


func _in_sight(at: Vector2, current: Node) -> Node:
	if _seed_pending:
		_seed_pending = false
		scene.squad._rng.seed = 4000 + _fights
		for j in scene.squad.pirates.size():
			var b: RefCounted = scene.squad.pirates[j].brain
			b.rng.seed = 1000 + _fights * 10 + j
			b.gun.rng.seed = 2000 + _fights * 10 + j
	return super(at, current)
