class_name GuideTrail
extends Node3D
## THE WAY, SHOWN ON THE GROUND (game/systems/guide.gd decides where). A short run of soft
## rainbow motes floats along the ground from just ahead of her toward the goal, drifting
## the way she should go, and a tall faint column of light stands on a goal too far off to
## see. Magic, like the beam: no arrows and no floating words (owner's bar, 2026-09-02: "the
## floating text in game looks bad").
##
## The motes only run the first stretch of the way and are thinned out at their ends, so
## the trail reads as a hint underfoot, not a road painted across the world; when she is
## standing at the goal there is nothing at all.

## Motes hang this far over the ground.
const HOVER := 0.55
## The first mote this far ahead of her, and the run no longer than this.
const START := 3.0
const MAX_LEN := 15.0
const SPACING := 1.25
## Closer than this to the goal she has arrived: no trail.
const ARRIVE := 2.5
## The last mote stops this short of the goal.
const STOP := 1.2
## Past this the goal gets its column of light.
const BEACON_FROM := 14.0
## How fast the motes drift along the way, metres a second.
const DRIFT := 1.1

## (x, z) -> ground height; unset, the line between the two ends is used.
var height_at: Callable

var _from := Vector3.ZERO
var _to := Vector3.INF
var _phase := 0.0
var _clock := 0.0
var _motes: MultiMeshInstance3D
var _beacon: MeshInstance3D
var _strength := 0.0
## What _layout() last placed (the headless renderer keeps no MultiMesh transforms to read).
var _placed: Array[Vector3] = []


func _ready() -> void:
	_motes = MultiMeshInstance3D.new()
	_motes.name = "Motes"
	_motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var quad := QuadMesh.new()
	quad.size = Vector2(0.62, 0.62)
	mm.mesh = quad
	mm.instance_count = int(ceil(MAX_LEN / SPACING)) + 2
	mm.visible_instance_count = 0
	_motes.multimesh = mm
	_motes.material_override = _mote_material()
	add_child(_motes)
	_beacon = MeshInstance3D.new()
	_beacon.name = "Beacon"
	_beacon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var col := CylinderMesh.new()
	col.top_radius = 0.55
	col.bottom_radius = 0.75
	col.height = 16.0
	col.cap_top = false
	col.cap_bottom = false
	col.radial_segments = 20
	_beacon.mesh = col
	_beacon.material_override = _beacon_material()
	_beacon.visible = false
	add_child(_beacon)
	top_level = true
	global_transform = Transform3D.IDENTITY


## Aim the trail: from her feet `from` to the goal `to` (Vector3.INF for none).
func point(from: Vector3, to: Vector3) -> void:
	_from = from
	_to = to
	_layout()


## Where the motes are drawn now, for the suite.
func mote_positions() -> Array[Vector3]:
	return _placed.duplicate()


func beacon_shown() -> bool:
	return _beacon != null and _beacon.visible


func _process(delta: float) -> void:
	_clock += delta
	_phase = fmod(_phase + delta * DRIFT / SPACING, 1.0)
	# Fade in and out rather than pop when the goal comes and goes.
	var want := 0.0 if _to == Vector3.INF else 1.0
	_strength = move_toward(_strength, want, delta * 2.0)
	_layout()


func _ground(x: float, z: float, fallback: float) -> float:
	return float(height_at.call(x, z)) if height_at.is_valid() else fallback


func _layout() -> void:
	if _motes == null:
		return
	var mm := _motes.multimesh
	_placed.clear()
	if _to == Vector3.INF:
		mm.visible_instance_count = 0
		_beacon.visible = false
		return
	var flat := Vector2(_to.x - _from.x, _to.z - _from.z)
	var dist := flat.length()
	if dist < ARRIVE:
		mm.visible_instance_count = 0
		_beacon.visible = false
		return
	var dir := flat / dist
	var end := minf(dist - STOP, START + MAX_LEN)
	var n := 0
	var cap := mm.instance_count
	var d := START + _phase * SPACING
	while d < end and n < cap:
		var x := _from.x + dir.x * d
		var z := _from.z + dir.y * d
		var t := d / dist
		var y := _ground(x, z, lerpf(_from.y, _to.y, t))
		# A slow bob, out of step mote to mote.
		y += HOVER + sin(_clock * 2.6 + d * 1.7) * 0.08
		# Thin at both ends: fade in just ahead of her, out toward the run's end.
		var a := clampf((d - START) / 1.5, 0.0, 1.0) * clampf((end - d) / 2.5, 0.0, 1.0)
		var hue := fmod(d * 0.06 + _clock * 0.05, 1.0)
		var c := Color.from_hsv(hue, 0.55, 1.0, a * _strength * 0.95)
		var s := 0.75 + 0.25 * sin(_clock * 4.0 + d)
		mm.set_instance_transform(n, Transform3D(Basis().scaled(Vector3.ONE * s), Vector3(x, y, z)))
		mm.set_instance_color(n, c)
		_placed.append(Vector3(x, y, z))
		n += 1
		d += SPACING
	mm.visible_instance_count = n
	_beacon.visible = dist > BEACON_FROM and _strength > 0.01
	if _beacon.visible:
		var gy := _ground(_to.x, _to.z, _to.y)
		_beacon.global_position = Vector3(_to.x, gy + 8.0, _to.z)
		var far := clampf((dist - BEACON_FROM) / 20.0, 0.0, 1.0)
		(_beacon.material_override as ShaderMaterial).set_shader_parameter(&"strength",
			far * _strength)


static func _mote_material() -> ShaderMaterial:
	var sh := Shader.new()
	# Mixed, not added: added light washes out to nothing on bright sand and grass. A
	# coloured halo with a white core and a thin dark rim reads on any ground.
	sh.code = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

void vertex() {
	// Billboard, keeping the instance's scale.
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s,
		INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	// A four-point star: a soft disc pinched along the diagonals.
	float ang = atan(p.y, p.x);
	float pinch = 0.55 + 0.45 * pow(abs(cos(ang * 2.0)), 3.0);
	float star = smoothstep(0.95 * pinch, 0.75 * pinch, r);
	float core = smoothstep(0.32, 0.12, r);
	float rim = smoothstep(0.95 * pinch, 0.85 * pinch, r) - star;
	vec3 col = mix(COLOR.rgb, vec3(1.0), core);
	col = mix(col, COLOR.rgb * 0.45, clamp(rim, 0.0, 1.0) * 0.6);
	ALBEDO = col;
	ALPHA = clamp(star + rim * 0.5, 0.0, 1.0) * COLOR.a;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


static func _beacon_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform float strength = 1.0;

void fragment() {
	// Bright at the foot, gone at the top; soft at the silhouette edges.
	float up = clamp(1.0 - UV.y, 0.0, 1.0);
	float rise = smoothstep(0.0, 0.12, UV.y) * pow(UV.y, 0.6);
	float edge = pow(clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 1.5);
	float shimmer = 0.85 + 0.15 * sin(UV.y * 40.0 - TIME * 3.0);
	vec3 tint = mix(vec3(1.0, 0.86, 0.55), vec3(0.85, 0.75, 1.0), up);
	float a = rise * edge * shimmer * 0.38 * strength;
	ALBEDO = tint * a;
	ALPHA = a;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m
