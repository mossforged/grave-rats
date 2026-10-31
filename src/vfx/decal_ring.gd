extends RefCounted
## Scene-free: which decal slot the next hole goes in, and which are fading. The cap never moves. As the ring
## nears it the oldest start fading (`fade_band` slots from the cap), and if shots outrun the fade the oldest is
## taken as it stands.

var cap: int
var fade_band: int
var fade_s: float

var _order: Array[int] = []   # in use, oldest first
var _free: Array[int] = []
var _fading := {}             # slot -> seconds left


func _init(slots: int, band: int, fade_seconds: float) -> void:
	cap = slots
	fade_band = band
	fade_s = fade_seconds
	clear()


func clear() -> void:
	_order.clear()
	_free.clear()
	_fading.clear()
	for i in cap:
		_free.append(i)


func in_use() -> int:
	return _order.size()


func fading(slot: int) -> bool:
	return _fading.has(slot)


## The slot for a new decal, newest at the back.
func place() -> int:
	var slot: int
	if _free.is_empty():
		slot = _order.pop_front()
		_fading.erase(slot)
	else:
		slot = _free.pop_back()
	_order.append(slot)
	_start_fades()
	return slot


## How visible a slot is, 0..1.
func strength(slot: int) -> float:
	return float(_fading[slot]) / fade_s if _fading.has(slot) else 1.0


## Time passes. Returns the slots that faded out and are free again.
func step(delta: float) -> Array[int]:
	var done: Array[int] = []
	for slot: int in _fading.keys():
		_fading[slot] = float(_fading[slot]) - delta
		if float(_fading[slot]) <= 0.0:
			done.append(slot)
	for slot: int in done:
		_fading.erase(slot)
		_order.erase(slot)
		_free.append(slot)
	return done


func _start_fades() -> void:
	var over := _order.size() - (cap - fade_band)
	for i in mini(over, _order.size()):
		if not _fading.has(_order[i]):
			_fading[_order[i]] = fade_s
