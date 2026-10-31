extends RefCounted
## Scene-free: what falls out of a gun. Casings or magazines thrown, bouncing and settling, up to a cap with the
## oldest going first. No collision with players or AI. It knows the floor and the one wall the throw is
## heading for (the caller finds them when it throws). data/vfx.json "casing", "magazine".

var cfg: Dictionary
var cap: int
var slots: Array[Dictionary] = []
var count := 0             # slots in use (they fill from 0, then the oldest is reused)
var bounced: Array[int] = []  # slots that hit the floor this step
var moved: Array[int] = []    # slots whose transform changed this step

var _next := 0


func _init(config: Dictionary, slot_count: int) -> void:
	cfg = config
	cap = slot_count
	for i in cap:
		slots.append({"pos": Vector3.ZERO, "vel": Vector3.ZERO, "axis": Vector3.UP, "spin": 0.0, "basis": Basis.IDENTITY,
				"rest": Basis.IDENTITY, "floor": 0.0, "plane": Vector3.ZERO, "wall": Vector3.ZERO, "bounces": 0, "moving": false})


## Throws one, returns its slot. `floor_y`: the floor under where it lands. `wall_normal` is zero with no wall ahead.
func throw(from: Vector3, vel: Vector3, floor_y: float, wall_at: Vector3, wall_normal: Vector3, rng: RandomNumberGenerator) -> int:
	var i := _next
	_next = (_next + 1) % cap
	count = mini(count + 1, cap)
	var s := slots[i]
	s.pos = from
	s.vel = vel
	s.axis = Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)).normalized()
	s.spin = deg_to_rad(rng.randf_range(float(cfg.spin_deg_s[0]), float(cfg.spin_deg_s[1])))
	s.basis = Basis(s.axis, rng.randf_range(0.0, TAU))
	s.rest = Basis(Vector3.UP, rng.randf_range(0.0, TAU))
	s.floor = floor_y + float(cfg.rest_y_m)
	s.plane = wall_at
	s.wall = wall_normal
	s.bounces = rng.randi_range(int(cfg.bounces[0]), int(cfg.bounces[1]))
	s.moving = true
	return i


func step(delta: float) -> void:
	bounced.clear()
	moved.clear()
	var g := float(cfg.gravity_m_s2)
	for i in count:
		var s := slots[i]
		if not s.moving:
			continue
		moved.append(i)
		s.vel.y -= g * delta
		s.pos += s.vel * delta
		s.basis = (Basis(s.axis, s.spin * delta) * s.basis).orthonormalized()
		if s.wall != Vector3.ZERO and (s.pos - s.plane).dot(s.wall) < 0.0:
			s.pos += s.wall * -(s.pos - s.plane).dot(s.wall)
			s.vel = s.vel.bounce(s.wall) * float(cfg.restitution)
			s.wall = Vector3.ZERO
		if s.pos.y <= s.floor and s.vel.y < 0.0:
			s.pos.y = s.floor
			bounced.append(i)
			if s.bounces <= 0:
				s.vel = Vector3.ZERO
				s.basis = s.rest
				s.moving = false
				continue
			s.bounces -= 1
			var flat := float(cfg.friction)
			s.vel = Vector3(s.vel.x * flat, -s.vel.y * float(cfg.restitution), s.vel.z * flat)
			s.spin *= float(cfg.settle_share)
		elif s.bounces <= 0:
			# On its last drop it turns to lie flat, so it doesn't snap as it lands.
			s.basis = s.basis.slerp(s.rest, clampf(delta / maxf(float(cfg.settle_share), delta), 0.0, 1.0))


func moving_count() -> int:
	var n := 0
	for i in count:
		if slots[i].moving:
			n += 1
	return n


func clear() -> void:
	count = 0
	_next = 0
	for s: Dictionary in slots:
		s.moving = false
