extends RefCounted
## Scene-free roles for a squad: one suppresses, one flanks, the rest support. Roles stick until
## something changes: a flanker keeps flanking, and a reloading suppressor hands over if it can.

enum Role { NONE, SUPPRESS, FLANK, SUPPORT }


## `members` are {id, pos: Vector2, reloading: bool, hurt: bool}, the living only. `was` is the last
## answer. Returns id -> Role.
static func assign(members: Array, player: Vector2, was: Dictionary) -> Dictionary:
	var out := {}
	if members.is_empty():
		return out
	if members.size() == 1:
		out[members[0].id] = Role.SUPPORT
		return out
	var flanker: Variant = null
	for m: Dictionary in members:
		if was.get(m.id, Role.NONE) == Role.FLANK and not m.hurt:
			flanker = m.id
	var suppressor: Variant = null
	for m: Dictionary in members:
		if was.get(m.id, Role.NONE) == Role.SUPPRESS and m.id != flanker and not m.reloading:
			suppressor = m.id
	if suppressor == null:
		suppressor = _nearest(members, player, flanker, true)
	if suppressor == null:
		suppressor = _nearest(members, player, flanker, false)
	if flanker == null:
		flanker = _unhurt_furthest(members, player, suppressor)
	for m: Dictionary in members:
		if m.id == suppressor:
			out[m.id] = Role.SUPPRESS
		elif m.id == flanker:
			out[m.id] = Role.FLANK
		else:
			out[m.id] = Role.SUPPORT
	return out


static func _nearest(members: Array, player: Vector2, skip: Variant, ready_only: bool) -> Variant:
	var best: Variant = null
	var best_d := INF
	for m: Dictionary in members:
		if m.id == skip or (ready_only and m.reloading):
			continue
		var d: float = (m.pos as Vector2).distance_to(player)
		if d < best_d:
			best_d = d
			best = m.id
	return best


## The one with the most room to go around, so the one nearest you keeps your head down.
static func _unhurt_furthest(members: Array, player: Vector2, skip: Variant) -> Variant:
	var best: Variant = null
	var best_d := -INF
	for m: Dictionary in members:
		if m.id == skip or m.hurt:
			continue
		var d: float = (m.pos as Vector2).distance_to(player)
		if d > best_d:
			best_d = d
			best = m.id
	return best
