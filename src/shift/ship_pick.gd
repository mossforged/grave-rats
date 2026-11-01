extends RefCounted
## Scene-free: which ship a shift runs on. data/shift.json `ships` (deck files), `ship_pick` ("first",
## "rotate", "random_seeded"). `contract_no` counts from 1.

const FIRST := "first"
const ROTATE := "rotate"
const RANDOM_SEEDED := "random_seeded"


static func pick(cfg: Dictionary, contract_no: int, rng: RandomNumberGenerator) -> String:
	var ships: Array = cfg.ships
	match String(cfg.ship_pick):
		ROTATE:
			return String(ships[(contract_no - 1) % ships.size()])
		RANDOM_SEEDED:
			return String(ships[rng.randi() % ships.size()])
		FIRST:
			return String(ships[0])
	push_error("ship_pick: unknown mode %s" % cfg.ship_pick)
	return String(ships[0])
