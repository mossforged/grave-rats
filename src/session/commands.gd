extends RefCounted
## Every player action, as data with a player ID. Local input makes these, a bot makes these, and later
## a client sends these to the host. Scene-free. Session.send routes them. See src/session/CONTRACT.md.

const MOVE := "move"
const AIM := "aim"
const FIRE := "fire"
const RELOAD := "reload"
const CROUCH := "crouch"
const INTERACT := "interact"
const TAKE := "take"
const DROP := "drop"
const DOOR := "door"
const TIP := "tip"
const LEAVE := "leave"
const LOCK := "lock"
const LOCK_CONTROLS := "lock_controls"
## The operator consumes these; the deck consumes the rest.
const BODY := [MOVE, AIM, FIRE, RELOAD, CROUCH]
const ALL := [MOVE, AIM, FIRE, RELOAD, CROUCH, INTERACT, TAKE, DROP, DOOR, TIP, LEAVE, LOCK, LOCK_CONTROLS]


static func is_body(type: String) -> bool:
	return BODY.has(type)


## `keys` are screen-relative, `yaw_deg` the sender's camera: W is screen-up on whoever's screen it is.
static func move(id: int, keys: Vector2, sprint: bool, yaw_deg: float) -> Dictionary:
	return {"type": MOVE, "player_id": id, "keys": keys, "sprint": sprint, "yaw_deg": yaw_deg}


static func aim(id: int, point: Vector3) -> Dictionary:
	return {"type": AIM, "player_id": id, "point": point}


static func fire(id: int, held: bool) -> Dictionary:
	return {"type": FIRE, "player_id": id, "held": held}


static func reload_gun(id: int) -> Dictionary:
	return {"type": RELOAD, "player_id": id}


static func crouch(id: int, held: bool) -> Dictionary:
	return {"type": CROUCH, "player_id": id, "held": held}


## E: whatever's in reach, in the order the deck decides (salvage, a bed, a door).
static func interact(id: int) -> Dictionary:
	return {"type": INTERACT, "player_id": id}


static func take(id: int) -> Dictionary:
	return {"type": TAKE, "player_id": id}


static func drop(id: int) -> Dictionary:
	return {"type": DROP, "player_id": id}


static func door(id: int) -> Dictionary:
	return {"type": DOOR, "player_id": id}


static func tip(id: int) -> Dictionary:
	return {"type": TIP, "player_id": id}


static func leave(id: int, held: bool) -> Dictionary:
	return {"type": LEAVE, "player_id": id, "held": held}


## The lock key: locks if it can, lets go if locked.
static func lock(id: int) -> Dictionary:
	return {"type": LOCK, "player_id": id}


## While locked, what the player holds. `keys` and `yaw_deg` as in move; `aim` raises over the cover,
## `tap` is a click that fires as soon as it can, however short.
static func lock_controls(id: int, keys: Vector2, aim_held: bool, fire_held: bool, tap: bool, yaw_deg: float) -> Dictionary:
	return {"type": LOCK_CONTROLS, "player_id": id, "keys": keys, "aim": aim_held, "fire": fire_held, "tap": tap, "yaw_deg": yaw_deg}
