extends RefCounted
## Scene-free: one sheet's particles, as a fixed ring of instance data for a MultiMesh. A spawn writes one
## slot and nothing else happens per frame: the shader (vfx_core.gdshaderinc) works out where each particle
## is from these numbers and the clock, so the only CPU cost is at the spawn. A full ring overwrites its
## oldest. position_at() is the shader's sum in GDScript, for the tests.
##
## Slot layout, the MultiMesh's TRANSFORM_3D + color + custom. The rows aren't a transform: the shader reads
## them as numbers. Row 0: from.xyz, born. Row 1: vel.xyz, life. Row 2: size_start, size_end, gravity, drag.
## Color: rgba. Custom: frame, frames, fps (0 holds, below 0 loops), bounce (below 0: none).

const STRIDE := 20

var capacity: int
var buffer := PackedFloat32Array()
var dirty := false
var spawned := 0
var floor_y := 0.0

var _head := 0
var _latest_death := 0.0


func _init(slots: int, floor_height := 0.0) -> void:
	capacity = slots
	floor_y = floor_height
	buffer.resize(slots * STRIDE)
	buffer.fill(0.0)


func spawn(now: float, from: Vector3, vel: Vector3, life: float, size_start: float, size_end: float,
		gravity: float, drag: float, color: Color, frame: float, frames: float, fps: float, bounce: float) -> void:
	var i := _head * STRIDE
	_head = (_head + 1) % capacity
	buffer[i] = from.x
	buffer[i + 1] = from.y
	buffer[i + 2] = from.z
	buffer[i + 3] = now
	buffer[i + 4] = vel.x
	buffer[i + 5] = vel.y
	buffer[i + 6] = vel.z
	buffer[i + 7] = life
	buffer[i + 8] = size_start
	buffer[i + 9] = size_end
	buffer[i + 10] = gravity
	buffer[i + 11] = drag
	buffer[i + 12] = color.r
	buffer[i + 13] = color.g
	buffer[i + 14] = color.b
	buffer[i + 15] = color.a
	buffer[i + 16] = frame
	buffer[i + 17] = frames
	buffer[i + 18] = fps
	buffer[i + 19] = bounce
	dirty = true
	spawned += 1
	_latest_death = maxf(_latest_death, now + life)


## Is anything still alive? When not, the sheet needn't draw.
func active(now: float) -> bool:
	return now < _latest_death


## How many slots are alive. A scan: for tests and readouts, not for every frame.
func alive_count(now: float) -> int:
	var n := 0
	for s in capacity:
		var i := s * STRIDE
		if buffer[i + 7] > 0.0 and now - buffer[i + 3] < buffer[i + 7]:
			n += 1
	return n


func forget() -> void:
	buffer.fill(0.0)
	_head = 0
	_latest_death = 0.0
	dirty = true


## Where slot `s` is at `now`: the same sum as the shader's.
func position_at(s: int, now: float) -> Vector3:
	var i := s * STRIDE
	var p0 := Vector3(buffer[i], buffer[i + 1], buffer[i + 2])
	var v0 := Vector3(buffer[i + 4], buffer[i + 5], buffer[i + 6])
	var t := now - buffer[i + 3]
	var g := buffer[i + 10]
	var drag := buffer[i + 11]
	var bounce := buffer[i + 19]
	var along := (1.0 - exp(-drag * t)) / drag if drag > 0.0 else t
	var p := p0 + v0 * along
	p.y -= 0.5 * g * t * t
	if bounce >= 0.0 and g > 0.0:
		var hit := (v0.y + sqrt(maxf(v0.y * v0.y + 2.0 * g * (p0.y - floor_y), 0.0))) / g
		if t > hit:
			var dt := t - hit
			var up := -(v0.y - g * hit) * bounce
			p = Vector3(p0.x + v0.x * hit + v0.x * bounce * dt, floor_y + up * dt - 0.5 * g * dt * dt,
					p0.z + v0.z * hit + v0.z * bounce * dt)
	p.y = maxf(p.y, floor_y)
	return p
