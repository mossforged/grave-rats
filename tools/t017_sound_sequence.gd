extends Node
## T017: one scripted sequence on the real shift deck, for Movie Maker to record picture and sound (silently,
## and exactly: it mixes off the real clock). Spit wind-up, cutter warm-up and burn, the alarm, then the worst
## pile-up the packet names: three stalkers, CUSTODIAN and the alarm all going, the rifle firing.
## Run by tools/t017_sound_capture.sh, which also measures it. Writes the segment times beside the movie.

const SEGMENTS := [
	{"name": "room_tone", "from": 0.0, "to": 2.0},
	{"name": "spit_windup", "from": 2.0, "to": 4.5},
	{"name": "cutter_warmup_burn", "from": 4.5, "to": 8.0},
	{"name": "alarm", "from": 8.0, "to": 12.0},
	{"name": "everything", "from": 12.0, "to": 20.0},
]
const END_S := 20.0

var deck: Node
var t := 0.0
var _done := {}
var _stalker: Node
var _cutter: Node
var _cues: Array = []


func _ready() -> void:
	if OS.get_environment("T017_NO_LIMITER") == "1":
		for i in range(AudioServer.get_bus_effect_count(0) - 1, -1, -1):
			AudioServer.remove_bus_effect(0, i)
	# How much the limiter holds back: every bus driven this much over its mix.
	var hot := float(OS.get_environment("T017_HOT_DB")) if OS.has_environment("T017_HOT_DB") else 0.0
	if hot != 0.0:
		for bus: String in Audio.cfg.buses:
			Audio.cfg.buses[bus].volume_db = float(Audio.cfg.buses[bus].volume_db) + hot
	Audio.played.connect(func(cue: String, _at: Vector3, _pitch: float) -> void: _cues.append([snappedf(t, 0.01), cue]))
	Audio.loop_started.connect(func(key: String, cue: String) -> void: _cues.append([snappedf(t, 0.01), "loop on: %s (%s)" % [cue, key]]))
	Audio.loop_stopped.connect(func(key: String) -> void: _cues.append([snappedf(t, 0.01), "loop off: %s" % key]))
	deck = (load("res://scenes/shift/shift_deck.tscn") as PackedScene).instantiate()
	add_child(deck)
	deck.operator.input_enabled = false
	deck.aim_from_mouse = false
	deck.run_log.enabled = false
	for s: Node in deck.pack.stalkers:
		s.brain.state = s.brain.State.DORMANT
	_cutter = deck.custodian.cutters[0]
	var p: Vector2 = deck.layout.point_in("cargo", [0.5, 0.5])
	deck.operator.global_position = Vector3(p.x, 0.0, p.y)
	var out := OS.get_environment("T017_SEGMENTS")
	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE)
		f.store_string(JSON.stringify(SEGMENTS, "  "))
		f.close()


func _once(key: String, at: float) -> bool:
	if t < at or _done.has(key):
		return false
	_done[key] = true
	return true


func _open_spot(from: Vector2, reach: float, turn: int) -> Vector2:
	for i in 16:
		var q := from + Vector2.from_angle(TAU * float(i + turn) / 16.0) * reach
		if deck.layout.space_at(q) != "" and not deck.pack.plan_blocked.call(q, from):
			return q
	return from


func _physics_process(delta: float) -> void:
	t += delta
	deck.suit.integrity = float(deck.suit.cfg.suit.max)
	var eye: Vector2 = deck._eye()
	if _once("spit", 2.0):
		_stalker = deck.pack.stalkers[0]
		_stalker.reset()
		_stalker.place_hunting(_open_spot(eye, 5.0, 0), eye)
		_stalker.brain.force_spit()
		deck.operator.face_now(_stalker.global_position)
	if _once("quiet", 3.5):
		_stalker.brain.state = _stalker.brain.State.DORMANT
	if _once("cutter", 4.5):
		_cutter.wake()
		var q: Vector2 = _cutter.floor_position() + Vector2(-sin(_cutter.brain.yaw), -cos(_cutter.brain.yaw)) * 4.0
		deck.operator.global_position = Vector3(q.x, 0.0, q.y)
		deck.custodian.awake = true
	if _once("alarm", 8.0):
		_cutter.brain.reset()
		deck._trip_alarm()
	if _once("everything", 12.0):
		deck.custodian.wake("tier")
		var turn := 0
		for s: Node in deck.pack.stalkers.slice(0, 3):
			s.reset()
			s.place_hunting(_open_spot(deck._eye(), 5.0, turn), deck._eye())
			s.brain.force_spit()
			turn += 5
		for d: Node in deck.custodian.drones:
			d.wake()
		deck.operator.scripted = {"fire": true}
	if t >= 12.0:
		deck.operator.rifle.state.mag = maxi(deck.operator.rifle.state.mag, 5)
	if t >= END_S:
		var out := OS.get_environment("T017_CUES")
		if out != "":
			var f := FileAccess.open(out, FileAccess.WRITE)
			f.store_string(JSON.stringify(_cues))
			f.close()
		get_tree().quit()
