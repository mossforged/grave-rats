extends Node3D
## The ship's maintenance AI: its units and its voice. Wakes once a shift, from tier 2 or the prize. The
## deck tells it where the players are each step and hears what happens through signals: no damage,
## stalker or HUD reaches in here. data/custodian.json. See src/custodian/CONTRACT.md.

const CutterBrain := preload("res://src/custodian/cutter_brain.gd")
const DroneBrain := preload("res://src/custodian/drone_brain.gd")
const CutterUnit := preload("res://src/custodian/cutter_unit.gd")
const DroneUnit := preload("res://src/custodian/drone_unit.gd")
const CustodianVoice := preload("res://src/custodian/custodian_voice.gd")
const Fx := preload("res://src/custodian/custodian_fx.gd")

## A burn landed on this player.
signal player_hit(player_id: int, source: String, amount: float, from: Vector2, who: String)
## CUSTODIAN said something.
signal spoke(line: String)
## It just woke: "tier" or "prize".
signal woke(reason: String)
## A unit lit itself up. Key is the unit, `at` its position: nothing hurts unseen.
signal revealed(unit: Node3D, at: Vector2)
## A call went through and no cutter was near: the deck alerts the nearest stalker. `called` says what came of it.
signal stalker_wanted(player_id: int, at: Vector2, from: Vector2)
## A call went through: "cutter" (one woke) or "stalker" (the deck was asked).
signal called(player_id: int, how: String)

const CALLED_CUTTER := "cutter"
const CALLED_STALKER := "stalker"

var cfg: Dictionary
var cutters: Array = []
var drones: Array = []
var voice: CustodianVoice
var awake := false
## Calls that went through this shift, and calls somebody broke.
var calls_done := 0
var calls_broken := 0

var _trace: Callable
var _visibility: RefCounted
var _knows: Callable
var _terminals: Array = []


## `trace`: (from, to) -> {clear, point}. `visibility`: the walls, for the cone. `bind`: SightMask.bind.
## `knows`: (p) -> has the player seen this spot?
func setup(config: Dictionary, layout: RefCounted, trace: Callable, visibility: RefCounted, bind: Callable,
		knows: Callable, mask_texture: Texture2D, bounds: Rect2, mix_rate: int) -> void:
	cfg = config
	_trace = trace
	_visibility = visibility
	_knows = knows
	voice = CustodianVoice.new(cfg.voice)
	for spec: Dictionary in cfg.cutters:
		var c := CutterUnit.new()
		c.name = "Cutter%d" % (cutters.size() + 1)
		add_child(c)
		c.setup(cfg, spec, layout.point_in(String(spec.space), spec.at), bind, knows, mix_rate)
		c.set_meta("on_wake", bool(spec.on_wake))
		cutters.append(c)
	for spec: Dictionary in cfg.drones:
		var route: Array = []
		for at: Array in spec.route:
			route.append(layout.point_in(String(spec.space), at))
		var d := DroneUnit.new()
		d.name = "Drone%d" % (drones.size() + 1)
		add_child(d)
		d.setup(cfg, spec, layout.point_in(String(spec.space), spec.at), route, bind, mix_rate)
		d.set_mask(mask_texture, bounds)
		drones.append(d)
	_make_terminals(layout, bind)
	reset()


func _make_terminals(layout: RefCounted, bind: Callable) -> void:
	var t: Dictionary = cfg.terminals
	var shell: Dictionary = cfg.shell
	for spec: Dictionary in t.at:
		var p: Vector2 = layout.point_in(String(spec.space), spec.at)
		var root := Node3D.new()
		add_child(root)
		root.global_position = Vector3(p.x, float(t.height_m), p.y)
		Fx.box(root, t.size_m, Vector3.ZERO, String(shell.dark), float(shell.roughness))
		var mark := Fx.lens(root, cfg.lens, Vector3(0.0, 0.0, float(t.lens_out_m)), bind)
		var word := Label3D.new()
		word.text = String(t.word)
		word.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		word.pixel_size = float(t.word_pixel_size)
		word.font_size = int(t.word_font_size)
		word.modulate = Color(String(cfg.lens.color))
		word.position = Vector3(0.0, float(t.word_up_m), 0.0)
		word.visible = false
		root.add_child(word)
		_terminals.append({"mark": mark, "word": word, "at": p})


## Back to sleep, for a new shift.
func reset() -> void:
	awake = false
	calls_done = 0
	calls_broken = 0
	voice.reset()
	for c: Node3D in cutters:
		c.reset()
	for d: Node3D in drones:
		d.reset()
	_show_terminals()


## Wakes it, once a shift. `reason` names the line it says ("tier", "prize"), which is said even if it's
## already up: the prize still gets its line.
func wake(reason: String) -> bool:
	_say(String(cfg.wake[reason]))
	if awake:
		return false
	awake = true
	for c: Node3D in cutters:
		if bool(c.get_meta("on_wake")):
			c.wake()
	for d: Node3D in drones:
		d.wake()
	_show_terminals()
	woke.emit(reason)
	return true


## One step. `players`: [{id, pos: Vector2, body: Vector3, alive}]. Asleep, it does nothing.
func tick(delta: float, players: Array) -> void:
	voice.step(delta)
	if not awake:
		return
	for c: Node3D in cutters:
		for ev: Dictionary in c.tick(delta, players, _trace):
			_on_cutter_event(c, ev)
	for d: Node3D in drones:
		for ev: Dictionary in d.tick(delta, players, _trace, _visibility):
			_on_drone_event(d, ev)
	_show_terminals()


## Is anything of this kind on this player right now? For the suit's alarm strip.
func cutter_on(player_id: int) -> bool:
	for c: Node3D in cutters:
		if c.brain.aiming() and c.brain.target_id == player_id:
			return true
	return false


func drone_on(player_id: int) -> bool:
	for d: Node3D in drones:
		if d.brain.calling() and d.brain.target_id == player_id:
			return true
	return false


func _on_cutter_event(c: Node3D, ev: Dictionary) -> void:
	match String(ev.type):
		CutterBrain.EV_AIM:
			revealed.emit(c, c.floor_position())
			_say("detect")
		CutterBrain.EV_BURN:
			revealed.emit(c, c.floor_position())
		CutterBrain.EV_HIT:
			_say("charged")
			player_hit.emit(int(ev.player_id), String(cfg.cutter.source), float(ev.amount), c.floor_position(), c.label)


func _on_drone_event(d: Node3D, ev: Dictionary) -> void:
	match String(ev.type):
		DroneBrain.EV_CALL_START:
			_say("detect")
		DroneBrain.EV_CALL_BROKEN:
			calls_broken += 1
		DroneBrain.EV_CALLED:
			calls_done += 1
			_say("charged")
			_reinforce(d, int(ev.player_id), ev.at)


## The nearest sleeping cutter in reach of the drone wakes. With none, the deck is asked for a stalker.
func _reinforce(d: Node3D, player_id: int, at: Vector2) -> void:
	var best: Node3D = null
	var best_d := float(cfg.call.wake_cutter_m)
	for c: Node3D in cutters:
		var dist: float = c.floor_position().distance_to(d.floor_position())
		if not c.brain.awake() and dist <= best_d:
			best = c
			best_d = dist
	if best != null:
		best.wake()
		revealed.emit(best, best.floor_position())
		called.emit(player_id, CALLED_CUTTER)
		return
	stalker_wanted.emit(player_id, at, d.floor_position())
	called.emit(player_id, CALLED_STALKER)


func _say(event: String) -> void:
	var line := voice.say(event)
	if line != "":
		spoke.emit(line)


func _show_terminals() -> void:
	for t: Dictionary in _terminals:
		Fx.lens_set_bright(t.mark, cfg.lens, awake)
		(t.word as Label3D).visible = awake and bool(_knows.call(t.at))
