extends RefCounted
## Scene-free door rules: closed, opening, open, closing, locked, broken, and how far the panel has
## slid. Only a person opens a door; a stalker can only break it, slowly, and then it stays broken.
## Numbers from data/doors.json. See src/doors/CONTRACT.md.

enum State { CLOSED, OPENING, OPEN, CLOSING, LOCKED, BROKEN }

var state := State.CLOSED
var progress := 0.0            # 0 = shut, 1 = fully slid away
var bash_progress := 0.0       # 0 = untouched, 1 = broken; damage stays if the basher leaves
var cfg: Dictionary


func _init(config: Dictionary, start := "closed") -> void:
	cfg = config
	match start:
		"open":
			state = State.OPEN
			progress = 1.0
		"locked":
			state = State.LOCKED
		"closed":
			state = State.CLOSED
		_:
			push_error("door: unknown state %s" % start)


## E pressed. Returns what happened: "opening", "closing", "locked" or "blocked".
## `doorway_clear` is false when someone stands where the panel would close.
func interact(doorway_clear := true) -> String:
	match state:
		State.LOCKED:
			return "locked"
		State.BROKEN:
			return "broken"
		State.CLOSED, State.CLOSING:
			state = State.OPENING
			return "opening"
		_:
			if not doorway_clear:
				return "blocked"
			state = State.CLOSING
			return "closing"


## A stalker working on a shut door for `delta`. True on the step it breaks. A locked door holds.
func bash(delta: float) -> bool:
	if state == State.LOCKED or state == State.BROKEN or not blocks():
		return false
	bash_progress = minf(bash_progress + delta / float(cfg.bash.break_s), 1.0)
	if bash_progress < 1.0:
		return false
	state = State.BROKEN
	progress = 1.0
	return true


func is_broken() -> bool:
	return state == State.BROKEN


func unlock() -> void:
	if state == State.LOCKED:
		state = State.CLOSED


## `doorway_clear` false while closing sends the panel back: it never shuts on anyone.
func step(delta: float, doorway_clear := true) -> void:
	if state == State.CLOSING and not doorway_clear:
		state = State.OPENING
	if state == State.OPENING:
		progress = minf(progress + delta / float(cfg.open_s), 1.0)
		if progress >= 1.0:
			state = State.OPEN
	elif state == State.CLOSING:
		progress = maxf(progress - delta / float(cfg.close_s), 0.0)
		if progress <= 0.0:
			state = State.CLOSED


func is_locked() -> bool:
	return state == State.LOCKED


## Sight and movement are blocked by the panel, so anything short of fully open still has a panel.
func blocks() -> bool:
	return progress < 1.0 - float(cfg.open_tolerance)


## The word for the prompt: "open", "close", "locked" or "broken".
func prompt_key() -> String:
	if state == State.LOCKED:
		return "locked"
	if state == State.BROKEN:
		return "broken"
	return "open" if state == State.CLOSED or state == State.CLOSING else "close"
