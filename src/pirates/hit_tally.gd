extends RefCounted
## Scene-free: rounds add up. A rifle round alone is small, but rounds landing close together are a
## big hit, which staggers, for pirates and for you. Numbers come from the caller's data.

var window_s := 0.0
var threshold := 0.0

var _hits: Array = []  # [age, amount]


func _init(window: float, big: float) -> void:
	window_s = window
	threshold = big


func step(delta: float) -> void:
	for h: Array in _hits:
		h[0] += delta
	_hits = _hits.filter(func(h: Array) -> bool: return h[0] <= window_s)


## One round landed. True when the rounds in the window now make a big hit (which empties it).
func add(amount: float) -> bool:
	_hits.append([0.0, amount])
	var total := 0.0
	for h: Array in _hits:
		total += h[1]
	if total < threshold:
		return false
	_hits.clear()
	return true


func clear() -> void:
	_hits.clear()
