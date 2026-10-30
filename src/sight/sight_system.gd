extends Node
## The Godot adapter over Visibility and SightGrid: pulls occluders from a DeckLayout and from
## nodes in the "sight_occluder" group, works out sight each frame, hides SightTargets and tells
## whoever listens (the mask, the flashlight, the debug view) through `sight_updated`.

const Visibility := preload("res://src/sight/visibility.gd")
const SightGrid := preload("res://src/sight/sight_grid.gd")
const SightTarget := preload("res://src/sight/sight_target.gd")
const OCCLUDER_GROUP := &"sight_occluder"

signal sight_updated(polygon: PackedVector2Array, reveal: Array)

var cfg: Dictionary
var visibility: Visibility
var grid: SightGrid
var bounds := Rect2()
var polygon := PackedVector2Array()
## Tall props and door panels the player's sight stopped at: shown whole, walls only at their face.
var reveal: Array = []
var eye := Vector2.ZERO
var aim_yaw := 0.0
var light_on := true

var _props: Array = []
var _movers: Array = []
var _since_grid := INF


## Static occluders: walls, door frames and props at least `tall_prop_min_m` high.
func setup(layout: RefCounted) -> void:
	cfg = Data.load_data("sight")
	bounds = layout.bounds.grow(float(cfg.mask.bounds_margin_m))
	visibility = Visibility.new(cfg)
	grid = SightGrid.new(bounds, float(cfg.memory.cell_m))
	var rects: Array = layout.walls.duplicate()
	for d: Dictionary in layout.doors:
		rects.append_array(d.frames)
	visibility.set_static(rects)
	var tall := float(cfg.tall_prop_min_m)
	for p: Dictionary in layout.props:
		if float((p.size as Vector3).y) >= tall:
			_props.append(p.rect)


## Call after adding or removing occluder nodes.
func refresh_occluders() -> void:
	_movers = get_tree().get_nodes_in_group(OCCLUDER_GROUP)


## One update from where the eye is. `force_memory` writes the grid now, whatever the rate.
func update_sight(from: Vector2, yaw: float, light: bool, delta: float, force_memory := false) -> void:
	eye = from
	aim_yaw = yaw
	light_on = light
	var dyn: Array = _props.duplicate()
	for m: Node in _movers:
		dyn.append(m.sight_rect() if m.blocks_sight() else Rect2())
	visibility.set_dynamic(dyn)
	polygon = visibility.polygon(from, yaw, light)
	reveal.clear()
	for i: int in visibility.hit_dynamic:
		reveal.append(dyn[i])
	_since_grid += delta
	if force_memory or _since_grid >= 1.0 / float(cfg.memory.update_hz):
		_since_grid = 0.0
		grid.update(polygon, reveal)
	_update_targets(from, yaw, light)
	sight_updated.emit(polygon, reveal)


func _update_targets(from: Vector2, yaw: float, light: bool) -> void:
	var r := float(cfg.target_radius_m)
	for t: SightTarget in get_tree().get_nodes_in_group(SightTarget.GROUP):
		var p := t.floor_position()
		t.set_seen(visibility.can_see(from, yaw, light, p)
				or visibility.can_see(from, yaw, light, p + Vector2(r, 0))
				or visibility.can_see(from, yaw, light, p + Vector2(-r, 0))
				or visibility.can_see(from, yaw, light, p + Vector2(0, r))
				or visibility.can_see(from, yaw, light, p + Vector2(0, -r)))


func forget() -> void:
	grid.clear()
	_since_grid = INF
