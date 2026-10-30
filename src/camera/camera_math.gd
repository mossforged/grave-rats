extends RefCounted
## Scene-free camera math for the follow rig: preset -> transform, projection to the screen,
## follow smoothing and the wall cut-away zone. Everything static so tests run headless.
## A preset is one entry of data/camera.json "presets":
##   {name, projection ("perspective"|"orthographic"), pitch_deg, yaw_deg, fov_deg, distance_m, ortho_size_m}


## Unit vector from the focus point toward the camera. Pitch is degrees below horizontal;
## yaw 0 puts the camera due south (+Z) looking north (-Z), so screen-up is world -Z.
static func offset_dir(preset: Dictionary) -> Vector3:
	var pitch := deg_to_rad(float(preset.pitch_deg))
	var yaw := deg_to_rad(float(preset.yaw_deg))
	return Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))


## Camera transform looking at `focus` from the preset's pitch, yaw and distance.
static func camera_transform(focus: Vector3, preset: Dictionary) -> Transform3D:
	var pos := focus + offset_dir(preset) * float(preset.distance_m)
	return Transform3D(Basis.looking_at(focus - pos, Vector3.UP), pos)


static func is_ortho(preset: Dictionary) -> bool:
	return String(preset.projection) == "orthographic"


## Normalised device coords of world point `p` (x right, y up, both -1..1 at the screen edge)
## for a camera with transform `xf`, the preset's projection and the given aspect (width/height).
## Godot keeps the vertical FOV / ortho size fixed, as Camera3D.KEEP_HEIGHT does.
## Returns Vector3(x, y, depth); depth <= 0 means the point is behind the camera.
static func project_ndc(xf: Transform3D, preset: Dictionary, p: Vector3, aspect: float) -> Vector3:
	var l := xf.affine_inverse() * p
	var depth := -l.z
	var half_h: float
	if is_ortho(preset):
		half_h = float(preset.ortho_size_m) * 0.5
	else:
		if depth <= 0.0:
			return Vector3(0, 0, depth)
		half_h = depth * tan(deg_to_rad(float(preset.fov_deg)) * 0.5)
	return Vector3(l.x / (half_h * aspect), l.y / half_h, depth)


## Fraction of screen height a vertical object of `height_m` standing at `base` takes.
static func screen_height_fraction(xf: Transform3D, preset: Dictionary, base: Vector3,
		height_m: float, aspect: float) -> float:
	var a := project_ndc(xf, preset, base, aspect)
	var b := project_ndc(xf, preset, base + Vector3.UP * height_m, aspect)
	return absf(b.y - a.y) * 0.5


## Frame-rate independent exponential follow toward `desired`.
static func follow_step(current: Vector3, desired: Vector3, delta: float, hz: float) -> Vector3:
	if hz <= 0.0:
		return desired
	return current.lerp(desired, 1.0 - exp(-hz * delta))


## Horizontal (XZ) unit direction from the focus toward the camera.
static func to_camera_2d(preset: Dictionary) -> Vector2:
	var d := offset_dir(preset)
	var v := Vector2(d.x, d.z)
	return v.normalized() if v.length() > 0.0001 else Vector2(0, 1)


## True when the XZ footprint `rect` overlaps the cut-away zone: a rectangle starting `behind` m
## behind the player and running `depth` m toward the camera, `half_width` m to each side.
## Separating-axis test of that oriented rectangle against the axis-aligned footprint.
static func in_cut_zone(rect: Rect2, player: Vector2, to_cam: Vector2,
		half_width: float, depth: float, behind: float) -> bool:
	var u := to_cam.normalized()
	var v := Vector2(-u.y, u.x)
	var c := player + u * (depth - behind) * 0.5
	var hu := (depth + behind) * 0.5
	var corners := [rect.position, rect.position + Vector2(rect.size.x, 0),
			rect.end, rect.position + Vector2(0, rect.size.y)]
	var zone := [c + u * hu + v * half_width, c + u * hu - v * half_width,
			c - u * hu + v * half_width, c - u * hu - v * half_width]
	for axis in [Vector2.RIGHT, Vector2.DOWN, u, v]:
		var r := _span(corners, axis)
		var z := _span(zone, axis)
		if r.y < z.x or z.y < r.x:
			return false
	return true


static func _span(points: Array, axis: Vector2) -> Vector2:
	var lo := INF
	var hi := -INF
	for p in points:
		var d: float = (p as Vector2).dot(axis)
		lo = minf(lo, d)
		hi = maxf(hi, d)
	return Vector2(lo, hi)
