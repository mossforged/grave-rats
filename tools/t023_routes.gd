extends SceneTree
## T023: route lengths for the handoff, both ships, on the stalkers' nav with every door open: hold to the
## black box, and on the survey round each side of the loop. Times at the player's walk speed, and home at the
## heavy class's speed. usage: godot --headless --path . -s tools/t023_routes.gd

const DeckLayout := preload("res://src/study/deck_layout.gd")
const StalkerNav := preload("res://src/enemies/stalker_nav.gd")


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _length(path: PackedVector2Array) -> float:
	var m := 0.0
	for i in path.size() - 1:
		m += path[i].distance_to(path[i + 1])
	return m


func _line(data: Node, what: String, nav: StalkerNav, a: Vector2, b: Vector2) -> void:
	var m := _length(nav.path(a, b))
	var run := float(data.load_data("player").move.walk_speed_m_s)
	var heavy := float(data.value("salvage", "classes").heavy.speed_mult)
	print("ROUTE %-34s %5.1f m  out %4.1f s  home heavy %4.1f s" % [what, m, m / run, m / (run * heavy)])


func _run() -> void:
	var data: Node = root.get_node("Data")
	for ship: String in ["deck", "deck_survey"]:
		data.use_ship(ship)
		var deck: Dictionary = data.load_data("deck")
		var layout := DeckLayout.new(deck, float(deck.room_scale))
		var nav := StalkerNav.new(data.value("enemies", "stalker"), layout)
		var air: Dictionary = data.value("shift", "airlock")
		var hold: Vector2 = (layout.point_in(air.space, air.from) + layout.point_in(air.space, air.to)) * 0.5
		var box := Vector2.ZERO
		for s: Dictionary in data.value("salvage", "placements"):
			if s.kind == "black_box":
				box = layout.point_in(s.space, s.at)
		_line(data, "%s: hold to black box" % ship, nav, hold, box)
		if ship == "deck_survey":
			for d: Dictionary in layout.doors:
				if (d.rect as Rect2).has_point(Vector2(10.25, 4.0)):
					nav.set_blocker("d2", d.rect)
			_line(data, "survey: round the east (D2 shut)", nav, hold, box)
			nav.set_blocker("d2", Rect2())
			_line(data, "survey: hold to engineering part", nav, hold, Vector2(33.0, 17.0))
	data.reset_ship()
	quit()
