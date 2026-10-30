extends RefCounted
## Scene-free suit integrity: damage, the big-hit stagger, death. Numbers from data/health.json.

var cfg: Dictionary
var integrity := 0.0
var stagger_left := 0.0
var dead := false
var last_source := ""


func _init(config: Dictionary) -> void:
	cfg = config
	reset()


func reset() -> void:
	integrity = float(cfg.suit.max)
	stagger_left = 0.0
	dead = false
	last_source = ""


func fraction() -> float:
	return integrity / float(cfg.suit.max)


func staggered() -> bool:
	return stagger_left > 0.0


## One hit. Returns {amount, staggered, died}. A hit of at least the threshold staggers; a dead
## suit takes nothing.
func take(amount: float, source: String) -> Dictionary:
	if dead or amount <= 0.0:
		return {"amount": 0.0, "staggered": false, "died": false}
	var big := amount >= float(cfg.stagger.threshold_fraction) * float(cfg.suit.max)
	var dealt := minf(amount, integrity)
	integrity -= dealt
	last_source = source
	if big:
		stagger_left = float(cfg.stagger.control_loss_s)
	var died := integrity <= 0.0
	if died:
		dead = true
	return {"amount": dealt, "staggered": big, "died": died}


func step(delta: float) -> void:
	stagger_left = maxf(stagger_left - delta, 0.0)
