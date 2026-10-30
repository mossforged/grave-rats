extends Node
## The cover readout's state: whether you're IN COVER, and one line per shooter hunting you, true
## when cover stops what it would throw at you right now. The suit OS (src/hud) draws them.

var lines: Array = []  # bools, per shooter: true = blocked
var in_cover := false


func set_lines(new_lines: Array) -> void:
	lines = new_lines


func set_in_cover(now: bool) -> void:
	in_cover = now


func protected_count() -> int:
	return lines.count(true)
