extends "res://src/debug/t016_stand.gd"
## Root of scenes/dev/t021_stand.tscn: T021's capture stands. The overturned bed before and after its
## stripe from the game camera, and the wall-top repeat on one seed with the camera held still.
## tools/capture.sh scenes/dev/t021_stand.tscn docs/screens/T021 2

const REPEAT_SEED := 21021
const NUDGE_M := 0.001


func capture_shots() -> Array[Dictionary]:
	var aa: String = DisplayAA.modes()[0].id
	return [
		{"name": "t021_bed_before", "do": "bed", "stripe": false, "light": true},
		{"name": "t021_bed_after", "do": "bed", "stripe": true, "light": true},
		{"name": "t021_bed_dark_before", "do": "bed", "stripe": false, "light": false},
		{"name": "t021_bed_dark_after", "do": "bed", "stripe": true, "light": false},
		{"name": "t021_bed_room_before", "do": "bed_room", "stripe": false},
		{"name": "t021_bed_room_after", "do": "bed_room", "stripe": true},
		{"name": "t021_wall_repeat_a", "do": "aa", "mode": aa, "pinned": true},
		{"name": "t021_wall_repeat_b", "do": "aa", "mode": aa, "pinned": true},
		{"name": "t021_wall_nudged", "do": "aa", "mode": aa, "pinned": true, "nudge": NUDGE_M},
	]


func apply_shot(shot: Dictionary) -> void:
	rig.set_process(true)
	if shot.get("pinned", false):
		next_seed = REPEAT_SEED
	match String(shot.do):
		"bed":
			await super({"do": "none"})
			await _bed_view(bool(shot.stripe), "play", bool(shot.light))
		"bed_room":
			await super({"do": "none"})
			await _bed_view(bool(shot.stripe), "off", true)
		_:
			await super(shot)
	if shot.get("pinned", false):
		rig.set_process(false)
		var cam := get_viewport().get_camera_3d()
		cam.global_position = _pinned_at(cam.global_position) + Vector3.RIGHT * float(shot.get("nudge", 0.0))
	_report(String(shot.name))


## The camera's resting spot, the same to the bit whichever shot gets here first.
func _pinned_at(p: Vector3) -> Vector3:
	return p.snappedf(0.01)


## A step away from the room's overturned bed, on the door side, as you'd come in.
func _bed_view(stripe: bool, view: String, light: bool) -> void:
	Engine.time_scale = 1.0
	(beds[2] as TipBed).edge_stripe.visible = stripe
	await _open_medbay_door()
	var lying: Rect2 = beds[2].footprint()
	await _stand_at(_door("medbay", 0.7).opening.get_center(), lying.get_center())
	set_kit_view(view)
	flashlight.set_on(light)
	await _sim(0.25)
	Engine.time_scale = 0.0


## Where the overturned bed's top edge lands on screen, for measuring its contrast.
func _report(tag: String) -> void:
	var cam := get_viewport().get_camera_3d()
	var r: Rect2 = beds[2].footprint()
	var a := cam.unproject_position(Vector3(r.position.x, 0.9, r.position.y))
	var b := cam.unproject_position(Vector3(r.end.x, 0.9, r.end.y))
	print("T021 %s bed_top_px=%s..%s cam=%s seed=%d" % [tag, str(a), str(b), str(cam.global_position), session.seed_value])
