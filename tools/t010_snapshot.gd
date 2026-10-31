extends SceneTree
## Writes tests/fixtures/t009_deck_snapshot.json: every collision box, sight occluder and cover class
## of the main deck and the pirate deck, as the T009 grey-box builder made them. Run once on T009:
##   godot --headless --path . -s tools/t010_snapshot.gd
## tests/test_kit.gd holds the kit builder to this file.

const DeckLayout := preload("res://src/study/deck_layout.gd")
const DeckBuilder := preload("res://src/study/deck_builder.gd")


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var data: Node = root.get_node("Data")
	var deck: Dictionary = (data.load_data("deck") as Dictionary).duplicate(true)
	var pirates: Dictionary = (deck.duplicate(true) as Dictionary)
	var p: Dictionary = data.value("pirates", "deck", {})
	pirates.spaces = (pirates.spaces as Array).filter(func(s: Dictionary) -> bool: return (p.keep_spaces as Array).has(s.name))
	pirates.doors = (p.doors as Array).duplicate(true)
	pirates.props = (p.props as Array).duplicate(true)
	var out := {"main": _snap(deck), "pirates": _snap(pirates)}
	var f := FileAccess.open("res://tests/fixtures/t009_deck_snapshot.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(out, " ", true))
	f.close()
	print("snapshot: %d + %d bodies" % [(out.main.bodies as Array).size(), (out.pirates.bodies as Array).size()])
	quit(0)


func _snap(deck: Dictionary) -> Dictionary:
	var layout := DeckLayout.new(deck, float(deck.room_scale))
	var built := DeckBuilder.build(layout)
	root.add_child(built)
	var bodies: Array = []
	for b: StaticBody3D in built.find_children("*", "StaticBody3D", true, false):
		var cs: CollisionShape3D = b.get_child(0)
		var s: Vector3 = (cs.shape as BoxShape3D).size
		var g := b.global_position
		bodies.append([snappedf(g.x, 0.001), snappedf(g.y, 0.001), snappedf(g.z, 0.001), snappedf(s.x, 0.001), snappedf(s.y, 0.001), snappedf(s.z, 0.001)])
	bodies.sort()
	built.free()
	var blockers: Array = []
	for r: Rect2 in layout.blockers():
		blockers.append([snappedf(r.position.x, 0.001), snappedf(r.position.y, 0.001), snappedf(r.size.x, 0.001), snappedf(r.size.y, 0.001)])
	blockers.sort()
	var cover: Array = []
	for pr: Dictionary in layout.props:
		cover.append([pr.type, pr.cover])
	return {"bodies": bodies, "blockers": blockers, "cover": cover}
