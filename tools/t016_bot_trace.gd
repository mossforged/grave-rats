extends "res://tools/t012_bots.gd"
## T016: T012's bots on the real shift_deck, watching how close they really walk to the dressing. Not a
## test: tests/test_dressing.gd holds the same pieces to the bots' planned routes; this is the bots' own feet.
## usage: godot --headless --path . --fixed-fps 60 -s tools/t016_bot_trace.gd -- [seeds] [out.json]

var _pieces: Array = []
var _closest := {}   # type -> metres, the nearest a bot's body centre came


func _decide(bot: String) -> void:
	super(bot)
	if _pieces.is_empty():
		# load, not preload: the kit reads the Data autoload, which a -s script compiles ahead of.
		_pieces = load("res://src/kit/dressing.gd").placed(scene.layout).filter(func(d: Dictionary) -> bool: return d.wall == "")
		for p: Dictionary in scene.layout.props:
			if p.type == "gurney":
				_pieces.append({"type": "gurney", "rect": p.rect})
	var at: Vector2 = scene._eye()
	for d: Dictionary in _pieces:
		var r: Rect2 = d.rect
		var gap := Vector2(clampf(at.x, r.position.x, r.end.x), clampf(at.y, r.position.y, r.end.y)).distance_to(at)
		_closest[d.type] = minf(float(_closest.get(d.type, INF)), gap)


func _report(bot: String, rows: Array) -> void:
	super(bot, rows)
	print("OUT    closest a bot's centre came: %s" % JSON.stringify(_closest))
