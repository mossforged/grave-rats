extends RefCounted
## Who's playing and who decides. The players (ID, crew, input source), the command layer, the one
## seeded RNG, `is_authority()`, and the rules the crew shares (the hold, "if anyone extracts", the
## quota). Scene-free. One local player is a session of one. See src/session/CONTRACT.md.

const SessionPlayer := preload("res://src/session/session_player.gd")
const Commands := preload("res://src/session/commands.gd")

const SOURCE_LOCAL := "local"
const SOURCE_SCRIPTED := "scripted"
const SOURCE_REMOTE := "remote"

var cfg: Dictionary
var players: Array = []
var local_id := 0
## The one RNG the simulation draws from. A system that needs its own stream asks `seed_for`.
var rng := RandomNumberGenerator.new()
var seed_value := 0
## Always true until there's a network. Tests turn it off to prove the guards hold.
var authority := true
## The shift and the quota, once a deck has them: what the crew shares.
var shift: RefCounted
var quota: RefCounted
## (command) -> void: the deck's half of the command layer.
var world_commands := Callable()
var commands_sent := 0


func _init(config: Dictionary) -> void:
	cfg = config
	local_id = int(cfg.local_player_id)


func is_authority() -> bool:
	return authority


## Null if the ID is taken or the crew is full.
func add_player(id: int, crew: String, source: String) -> SessionPlayer:
	if has_player(id) or players.size() >= int(cfg.max_players):
		return null
	var p := SessionPlayer.new(id, crew, source, players.size())
	players.append(p)
	return p


func has_player(id: int) -> bool:
	return player(id) != null


func player(id: int) -> SessionPlayer:
	for p: SessionPlayer in players:
		if p.id == id:
			return p
	return null


## The player this machine shows: whose sight, suit and HUD are on the screen.
func local() -> SessionPlayer:
	return player(local_id)


func ids() -> Array:
	return players.map(func(p: SessionPlayer) -> int: return p.id)


## Everybody else's position at the spawn: a line along X from the data's spawn point.
func spawn_offset(p: SessionPlayer) -> Vector2:
	return Vector2(float(p.index) * float(cfg.spawn_spacing_m), 0.0)


## A new run of the RNG. 0 rolls one. Returns the seed.
func reseed(value := 0) -> int:
	if value != 0:
		rng.seed = value
	else:
		rng.randomize()
	seed_value = rng.seed
	return seed_value


## A seed for one named stream, from the session's seed, without drawing on the main RNG: adding a
## stream never changes what the others roll.
func seed_for(key: String) -> int:
	return hash("%d:%s" % [seed_value, key])


## The command layer: a player's action goes to whatever consumes it. False if nobody has that ID.
## A client will hand these to the host here instead.
func send(cmd: Dictionary) -> bool:
	var p := player(int(cmd.player_id))
	if p == null:
		return false
	commands_sent += 1
	if Commands.is_body(String(cmd.type)):
		p.operator.apply_command(cmd)
	elif world_commands.is_valid():
		world_commands.call(cmd)
	return true


# --- what the crew shares ---

func hold() -> RefCounted:
	return shift.hold


## If anyone extracts, everything in the hold counts for the crew.
func haul_counts() -> bool:
	return shift.outcome == shift.EXTRACTED


func banked() -> int:
	return shift.banked()


## The only way the quota moves. Returns the quota's verdict.
func close_quota(net_cr: int, how: String) -> String:
	if not is_authority():
		return quota.verdict
	return quota.close_shift(net_cr, how)
