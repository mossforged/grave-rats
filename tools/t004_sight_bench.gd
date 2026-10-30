extends SceneTree
## CPU cost of one sight update on the real deck: polygon, plus the grid's fill.
## godot --headless --path . -s tools/t004_sight_bench.gd

const DeckLayout := preload("res://src/study/deck_layout.gd")
const Visibility := preload("res://src/sight/visibility.gd")
const SightGrid := preload("res://src/sight/sight_grid.gd")
const RUNS := 2000


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var data: Node = root.get_node("Data")
	var deck: Dictionary = data.load_data("deck")
	var cfg: Dictionary = data.load_data("sight")
	var layout := DeckLayout.new(deck, float(deck.room_scale))
	var vis := Visibility.new(cfg)
	var rects: Array = layout.walls.duplicate()
	for d: Dictionary in layout.doors:
		rects.append_array(d.frames)
	vis.set_static(rects)
	var dyn: Array = []
	for p: Dictionary in layout.props:
		if float((p.size as Vector3).y) >= float(cfg.tall_prop_min_m):
			dyn.append(p.rect)
	for d: Dictionary in layout.doors:
		dyn.append(d.rect)
	vis.set_dynamic(dyn)
	var grid := SightGrid.new(layout.bounds, float(cfg.memory.cell_m))
	var free: Array[Vector2] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	while free.size() < RUNS:
		var p := layout.bounds.position + Vector2(rng.randf(), rng.randf()) * layout.bounds.size
		if layout.is_free(p, 0.4):
			free.append(p)
	var poly_us := 0
	var grid_us := 0
	var points := 0
	for i in RUNS:
		var yaw := rng.randf() * TAU
		var t0 := Time.get_ticks_usec()
		var poly := vis.polygon(free[i], yaw, true)
		var t1 := Time.get_ticks_usec()
		grid.update(poly)
		grid_us += Time.get_ticks_usec() - t1
		poly_us += t1 - t0
		points += poly.size()
	print("edges %d, average %d polygon points" % [vis.edge_count(), points / RUNS])
	print("polygon %.3f ms, grid fill %.3f ms (average of %d random spots)" % [poly_us / 1000.0 / RUNS, grid_us / 1000.0 / RUNS, RUNS])
	quit(0)
