extends RefCounted
## One gun's shot, everything but the rules: the layers of sound, smoke and haze, the casing, the wisps after a long
## burst, the magazine, the round landing. Each gun holds one. gun-feel.md sections 1 to 4; numbers in
## data/vfx.json "shot" and data/audio.json "gun". Calling it changes nothing in the game.

const SoundRules := preload("res://src/audio/sound_rules.gd")

static var _next_gun := 0

var gun_id := 0
var burst := 0              # rounds since the last gap in firing

var _since_shot := INF
var _haze_wait := 0.0
var _wisps := 0


func _init() -> void:
	gun_id = _next_gun
	_next_gun += 1


## A round went off. `dir` is the way the barrel points, `rounds_left` what's in the magazine now, `space` the
## room the shooter's in, `local` whether this is the local player's own gun.
func shot(muzzle: Vector3, dir: Vector3, rounds_left: int, space: String, local: bool) -> void:
	_sounds(muzzle, rounds_left, space, local)
	burst += 1
	_since_shot = 0.0
	Audio.note_gunfire(muzzle)
	var s: Dictionary = Data.value("vfx", "shot")
	Vfx.play(String(s.smoke), muzzle, dir)
	if burst >= int(s.haze_after_rounds) and _haze_wait <= 0.0:
		_haze_wait = float(s.haze_every_s)
		Vfx.play(String(s.haze), muzzle)
	Vfx.eject_casing(_port(muzzle, dir), dir)


## What the shot's sound is made of, as played. Local guns are heard dry; everyone else's is filtered by range and walls.
func _sounds(at: Vector3, rounds_left: int, space: String, local: bool) -> void:
	var gun: Dictionary = Data.value("audio", "gun")
	for layer: Variant in SoundRules.shot_layers(gun, rounds_left, local):
		var opts := {"gun": gun_id, "muffle": not local}
		if not local and layer == gun.mechanical:
			opts.volume_db = float(gun.others_mechanical_db)
		Audio.play(String(layer), at, opts)
	Audio.play(Audio.room_tail(space), at, {"gun": gun_id, "muffle": not local, "tail": true})


## The trigger on an empty magazine.
func dry(at: Vector3) -> void:
	var gun: Dictionary = Data.value("audio", "gun")
	if Audio.play(String(gun.dry), at):
		Audio.play(String(gun.dry_tail), at)


## The old magazine falls.
func drop_magazine(muzzle: Vector3, dir: Vector3) -> void:
	Vfx.drop_magazine(_port(muzzle, dir), dir)


## Where a round landed. `target` may be null (cover stopped it). A body that plays its own hit has done so.
func land(target: Object, point: Vector3, normal: Vector3, dir: Vector3, damage: float) -> void:
	if target == null or not target.has_method("plays_own_hit"):
		Vfx.land(target, point, normal, dir, damage)


## Once per step, with the barrel where it is now: a long burst's end sets the barrel smoking.
func step(delta: float, muzzle: Vector3, dir: Vector3) -> void:
	_haze_wait = maxf(_haze_wait - delta, 0.0)
	if _wisps != 0:
		Vfx.move(_wisps, muzzle, dir)
	if burst == 0:
		return
	_since_shot += delta
	var s: Dictionary = Data.value("vfx", "shot")
	if _since_shot < float(s.burst_gap_s):
		return
	if burst >= int(s.wisps_after_rounds):
		_wisps = Vfx.start(String(s.wisps), muzzle, dir)
	burst = 0


func _port(muzzle: Vector3, dir: Vector3) -> Vector3:
	return muzzle - dir * float(Data.value("vfx", "casing").port_back_m)
