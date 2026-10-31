extends RefCounted
## The player as something a pirate's round can find (the ShotTracer body contract). Scene-free:
## the deck tells it where the body is and what to do when hit.

var center := Vector2.ZERO
var height := 0.0
var radius := 0.0
var alive := true
var on_hit := Callable()


func shot_disc() -> Dictionary:
	if not alive:
		return {}
	return {"center": center, "radius": radius, "height": height}


## A pirate's round in the player: the same red-brown spray (src/vfx).
func hit_surface() -> String:
	return "pirate"


func take_hit(hit: Dictionary) -> void:
	if on_hit.is_valid():
		on_hit.call(hit)
