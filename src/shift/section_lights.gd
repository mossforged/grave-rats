extends Node
## Lights failing by section. Finds a space's practicals among `DeckLighting.lights` (by name) and
## its strip fixtures under the deck's walls (by render layer), never touching `src/kit`. A failing
## section flickers on data/shift.json "lights", then stays off. A new shift brings them all back.

const KitPieces := preload("res://src/kit/kit_pieces.gd")

const ON := "on"
const FLICKER := "flicker"
const OFF := "off"

var rng := RandomNumberGenerator.new()

var _cfg: Dictionary
var _sections := {}       # space -> {lights: [{light, energy}], fixtures: [MeshInstance3D], state, left, gap, lit}


func setup(config: Dictionary, layout: RefCounted, lights: Array, walls: Node) -> void:
	_cfg = config
	var fixtures := walls.find_children("Fixture*", "MeshInstance3D", true, false)
	for space: String in layout.space_order:
		var row := {"lights": [], "fixtures": [], "state": ON, "left": 0.0, "gap": 0.0, "lit": true}
		for l: Light3D in lights:
			if String(l.name).begins_with("Practical_%s_" % space):
				row.lights.append({"light": l, "energy": l.light_energy})
		var layer: int = KitPieces.space_layer(layout, space)
		for f: MeshInstance3D in fixtures:
			if f.layers == layer and String(f.get_meta("kit_piece", "")) == "fixture":
				row.fixtures.append(f)
		_sections[space] = row


func state_of(space: String) -> String:
	return String(_sections[space].state)


func lit_lights(space: String) -> int:
	var n := 0
	for e: Dictionary in _sections[space].lights:
		if (e.light as Light3D).visible:
			n += 1
	return n


func light_count(space: String) -> int:
	return (_sections[space].lights as Array).size()


func fixture_count(space: String) -> int:
	return (_sections[space].fixtures as Array).size()


func fail(space: String) -> void:
	var s: Dictionary = _sections[space]
	s.state = FLICKER
	s.left = float(_cfg.flicker_s)
	s.gap = 0.0
	s.lit = true


func tick(delta: float) -> void:
	for s: Dictionary in _sections.values():
		if s.state != FLICKER:
			continue
		s.left = float(s.left) - delta
		if float(s.left) <= 0.0:
			s.state = OFF
			_show(s, false, 0.0)
			continue
		s.gap = float(s.gap) - delta
		if float(s.gap) <= 0.0:
			s.gap = rng.randf_range(float(_cfg.gap_min_s), float(_cfg.gap_max_s))
			s.lit = not bool(s.lit)
			_show(s, bool(s.lit), float(_cfg.flicker_energy))


func reset() -> void:
	for s: Dictionary in _sections.values():
		s.state = ON
		_show(s, true, 1.0)


func _show(s: Dictionary, lit: bool, energy_share: float) -> void:
	for e: Dictionary in s.lights:
		var l: Light3D = e.light
		l.visible = lit
		l.light_energy = float(e.energy) * energy_share
	for f: MeshInstance3D in s.fixtures:
		f.visible = lit
