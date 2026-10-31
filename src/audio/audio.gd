extends Node
## The game's sound. Autoloaded as `Audio`. Builds the buses and the master limiter from data/audio.json,
## loads every cue once, and plays them from a fixed pool of voices. World cues are positional, heard from
## the local player; the rest are flat. See src/audio/CONTRACT.md.
##
## This is what the player hears, and nothing else. What the AI hears is the noise ring's business
## (src/hud, StalkerPack.noise) and never reads this.

const AudioBank := preload("res://src/audio/audio_bank.gd")
const SoundRules := preload("res://src/audio/sound_rules.gd")

## Every one-shot the moment it starts; the tests listen here.
signal played(cue: String, at: Vector3, pitch: float)
signal loop_started(key: String, cue: String)
signal loop_stopped(key: String)

var cfg: Dictionary
var bank: AudioBank
var rng := RandomNumberGenerator.new()
var streams := {}             # cue -> AudioStream
var listener: AudioListener3D

var _positional: Array[AudioStreamPlayer3D] = []
var _flat: Array[AudioStreamPlayer] = []
var _started := {}            # voice -> order it last started in
var _order := 0
var _loops := {}              # key -> {voice, cue}
var _pending: Array = []      # {left, cue, at, opts}
var _following: Node3D
var _room_shares := {}        # room tone cue -> 0..1
var _room_cue := ""
var _ambience_on := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	cfg = Data.load_data("audio")
	bank = AudioBank.new(cfg)
	_build_buses()
	_build_voices()
	_load_streams()
	listener = AudioListener3D.new()
	listener.name = "Listener"
	add_child(listener)
	# Capture runs are unattended and nobody needs a siren in the room.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-out="):
			AudioServer.set_bus_mute(0, true)


func _build_buses() -> void:
	for bus: String in cfg.buses:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, AudioServer.get_bus_name(0))
	var l: Dictionary = cfg.master.limiter
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = float(l.ceiling_db)
	limiter.pre_gain_db = float(l.pre_gain_db)
	limiter.release = float(l.release_s)
	AudioServer.add_bus_effect(0, limiter)
	_apply_bus_volumes()


func _build_voices() -> void:
	var v: Dictionary = cfg.voices
	var p: Dictionary = cfg.positional
	for i in int(v.positional):
		var a := AudioStreamPlayer3D.new()
		a.name = "World%d" % i
		a.unit_size = float(p.unit_size_m)
		a.max_db = float(p.max_db)
		a.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		add_child(a)
		_positional.append(a)
	for i in int(v.flat):
		var a := AudioStreamPlayer.new()
		a.name = "Flat%d" % i
		add_child(a)
		_flat.append(a)


func _load_streams() -> void:
	for cue: String in bank.cues:
		var c: Dictionary = bank.spec(cue)
		var path := String(c.file)
		var s: AudioStream = load(path) if ResourceLoader.exists(path) else null
		if s == null:
			push_error("Audio: cue %s has no file at %s" % [cue, path])
			continue
		if bool(c.get("loop", false)):
			_make_loop(s)
		streams[cue] = s


## Whichever format the file turns out to be, so real audio can land file by file.
func _make_loop(s: AudioStream) -> void:
	if s is AudioStreamWAV:
		var w := s as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(round(w.get_length() * w.mix_rate))
	elif "loop" in s:
		s.set("loop", true)


func _process(delta: float) -> void:
	advance(delta)
	_apply_bus_volumes()
	_place_listener()


## Time passes for the cooldowns, the delayed cues and the room tones. Public so tests can step it.
func advance(delta: float) -> void:
	bank.advance(delta)
	var still: Array = []
	for p: Dictionary in _pending:
		p.left = float(p.left) - delta
		if float(p.left) > 0.0:
			still.append(p)
		else:
			_start(String(p.cue), p.at, p.opts)
	_pending = still
	if _ambience_on:
		_step_rooms(delta)


## F1 writes these numbers straight into the data; they apply on the next frame.
func _apply_bus_volumes() -> void:
	AudioServer.set_bus_volume_db(0, float(cfg.master.volume_db))
	for bus: String in cfg.buses:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus), float(cfg.buses[bus].volume_db))


## Plays a cue unless it's resting. `at` is ignored by flat cues. opts: "pitch" (times the cue's own
## variance), "volume_db" (on top of the bank's), "delay" (seconds, instead of the bank's "delay_s").
## False if it's on cooldown or isn't in the bank (which is also an error).
func play(cue: String, at := Vector3.ZERO, opts := {}) -> bool:
	if not bank.has(cue):
		push_error("Audio: no cue %s" % cue)
		return false
	if not bank.take(cue):
		return false
	var delay := float(opts.get("delay", bank.spec(cue).get("delay_s", 0.0)))
	if delay > 0.0:
		_pending.append({"left": delay, "cue": cue, "at": at, "opts": opts})
	else:
		_start(cue, at, opts)
	return true


func _start(cue: String, at: Vector3, opts: Dictionary) -> void:
	var pitch := bank.pitch_for(cue, rng) * float(opts.get("pitch", 1.0))
	if streams.has(cue):
		_voice_for(cue, at, pitch, float(opts.get("volume_db", 0.0))).play()
	played.emit(cue, at, pitch)


func _voice_for(cue: String, at: Vector3, pitch: float, extra_db: float) -> Node:
	var c: Dictionary = bank.spec(cue)
	var positional := bank.positional(cue)
	var v: Node = _free_voice(_positional if positional else _flat)
	v.stop()
	v.stream = streams[cue]
	v.bus = String(c.bus)
	v.volume_db = float(c.volume_db) + extra_db
	v.pitch_scale = pitch
	if positional:
		var a := v as AudioStreamPlayer3D
		a.max_distance = float(c.max_distance_m)
		a.global_position = at
	_order += 1
	_started[v] = _order
	return v


## An idle voice, or the one-shot that's been going longest. A loop's voice is never taken.
func _free_voice(pool: Array) -> Node:
	var best: Node = null
	for v: Node in pool:
		if _holds_loop(v):
			continue
		if not v.playing:
			return v
		if best == null or int(_started.get(v, 0)) < int(_started.get(best, 0)):
			best = v
	return best


func _holds_loop(v: Node) -> bool:
	for l: Dictionary in _loops.values():
		if l.voice == v:
			return true
	return false


## Starts a loop under a name of the caller's. Already going, it stays as it is.
func loop(key: String, cue: String, at := Vector3.ZERO, pitch := 1.0) -> void:
	if _loops.has(key):
		return
	if not bank.has(cue):
		push_error("Audio: no cue %s" % cue)
		return
	if not streams.has(cue):
		return
	var v := _voice_for(cue, at, pitch, 0.0)
	_loops[key] = {"voice": v, "cue": cue}
	v.play()
	loop_started.emit(key, cue)


func looping(key: String) -> bool:
	return _loops.has(key)


func loop_pitch(key: String) -> float:
	return float(_loops[key].voice.pitch_scale) if _loops.has(key) else 0.0


func set_loop_pitch(key: String, pitch: float) -> void:
	if _loops.has(key):
		_loops[key].voice.pitch_scale = pitch


## On top of the bank's level for that cue.
func set_loop_volume(key: String, extra_db: float) -> void:
	if _loops.has(key):
		var l: Dictionary = _loops[key]
		l.voice.volume_db = float(bank.spec(String(l.cue)).volume_db) + extra_db


func stop_loop(key: String) -> void:
	if not _loops.has(key):
		return
	_loops[key].voice.stop()
	_loops.erase(key)
	loop_stopped.emit(key)


## Every room tone starts together, all but the first room's silent, and they crossfade from there.
func start_ambience() -> void:
	if _ambience_on:
		return
	_ambience_on = true
	var rooms: Dictionary = cfg.ambience.rooms
	for room: String in rooms:
		var cue := String(rooms[room])
		if not _room_shares.has(cue):
			_room_shares[cue] = 0.0
			loop(_room_key(cue), cue)
	_step_rooms(0.0)


## Where the local player is, by space name. "" (a doorway) keeps the last room.
func set_room(space: String) -> void:
	var rooms: Dictionary = cfg.ambience.rooms
	if rooms.has(space):
		_room_cue = String(rooms[space])


func current_room_tone() -> String:
	return _room_cue


func room_share(cue: String) -> float:
	return float(_room_shares.get(cue, 0.0))


func _step_rooms(delta: float) -> void:
	SoundRules.fade_rooms(_room_shares, _room_cue, delta, float(cfg.ambience.fade_s))
	for cue: String in _room_shares:
		var share := float(_room_shares[cue])
		set_loop_volume(_room_key(cue), linear_to_db(share) if share > 0.0 else float(cfg.ambience.silent_db))


func _room_key(cue: String) -> String:
	return "room:%s" % cue


## The suit's breathing: faster and a little louder as things get worse. Fractions 0..1.
func breathe(suit: float, oxygen: float) -> void:
	var b: Dictionary = cfg.breathing
	loop("breath", String(b.cue))
	var stress := SoundRules.breath_stress(b, suit, oxygen)
	set_loop_pitch("breath", lerpf(1.0, float(b.max_rate), stress))
	set_loop_volume("breath", float(b.max_extra_db) * stress)


func follow(node: Node3D) -> void:
	_following = node
	listener.make_current()
	_place_listener()


## At the player, so a sound's distance is its distance from you. Turned with the camera, so a sound on
## the left of the screen is in your left ear.
func _place_listener() -> void:
	if not is_instance_valid(_following) or not _following.is_inside_tree():
		return
	var at: Vector3 = _following.global_position + Vector3.UP * float(cfg.listener.height_m)
	var cam := get_viewport().get_camera_3d()
	listener.global_transform = Transform3D(cam.global_basis if cam != null else Basis.IDENTITY, at)


## The world's gone: everything stops, loops and queued cues alike.
func stop_all() -> void:
	for key: String in _loops.keys():
		stop_loop(key)
	_pending = []
	_ambience_on = false
	_room_shares = {}
	_room_cue = ""
	for v: Node in _positional:
		v.stop()
	for v: Node in _flat:
		v.stop()
	_following = null
	listener.clear_current()


## Fresh cooldowns too: tests.
func reset() -> void:
	stop_all()
	bank.reset()
