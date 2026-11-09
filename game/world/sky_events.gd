extends Node3D
## THE VALLEY'S LITTLE SHOWS (P8 S9; owner playtest 2026-11-08 item 78 and the jiggle note:
## "Derpy crashing and falling would be a funny flank jiggle cinematic; random events like the
## Sonic Rainboom too"). Every so often, while she is outdoors with nothing open, one of these
## plays through the Cinematic player:
##
##   derpy_crash()     Derpy comes down out of the sky flailing, lands rump first in front of
##                     her (the bounce at its biggest), lies dazed, shakes it off and flies on.
##   sonic_rainboom()  Rainbow Dash streaks across the sky and the ring blooms where she breaks
##                     through, leaving a rainbow trail that fades.
##
## Self-driven off the ranch (a child of it), so ranch.gd needs no hook beyond being its parent.
## Never during a menu, a talk, the Palace or another cinematic; at most one per EVENT_GAP.

const DERPY := "res://data/ponies/derpyhooves.tres"
const DASH := "res://data/ponies/rainbowdash.tres"
const RAINBOW_SHADER := preload("res://shaders/rainbow.gdshader")
const BloomCeremonyScript := preload("res://world/bloom_ceremony.gd")

## Seconds of outdoor play between shows, the first one later than the rest.
const FIRST_GAP := Vector2(360.0, 540.0)
const EVENT_GAP := Vector2(480.0, 780.0)

var _wait := 0.0
var _next := 0
var _rng := RandomNumberGenerator.new()
var _busy := false


func _ready() -> void:
	_rng.randomize()
	_wait = _rng.randf_range(FIRST_GAP.x, FIRST_GAP.y)
	_next = _rng.randi_range(0, 1)


func _process(delta: float) -> void:
	if _busy or not _free_to_show():
		return
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = _rng.randf_range(EVENT_GAP.x, EVENT_GAP.y)
	if _next == 0:
		derpy_crash()
	else:
		sonic_rainboom()
	_next = 1 - _next


func _ranch() -> Node:
	return get_parent()


func _free_to_show() -> bool:
	var r := _ranch()
	if r == null or r.get("player") == null:
		return false
	if bool(r.call("is_in_palace")) if r.has_method("is_in_palace") else false:
		return false
	if r.has_method("_no_other_menu_open") and not bool(r.call("_no_other_menu_open")):
		return false
	var people: Node = r.get("people")
	if people != null and people.has_method("is_talking") and bool(people.call("is_talking")):
		return false
	return not Cinematic.shared(get_tree()).playing


func _ground(x: float, z: float) -> float:
	var terrain: Node = _ranch().get("terrain")
	return float(terrain.call("height_at", x, z)) if terrain != null else 0.0


func _body(path: String) -> Node3D:
	var body: Node3D = PonyVisuals.build(load(path))
	if body == null:
		return null
	body.rotate_y(PI)
	var holder := Node3D.new()
	holder.add_child(body)
	add_child(holder)
	for sim: SkeletonModifier3D in body.find_children("*", "SpringBoneSimulator3D", true, false):
		sim.active = true
	return holder


func _play(holder: Node3D, clip: StringName) -> void:
	for ap: AnimationPlayer in holder.find_children("*", "AnimationPlayer", true, false):
		if ap.has_animation(clip):
			ap.play(clip, 0.15)


## Derpy comes down in front of the player. Returns when the scene is over.
func derpy_crash() -> void:
	_busy = true
	var player: Node3D = _ranch().get("player")
	var fwd := -player.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.1 else Vector3.FORWARD
	var side := fwd.cross(Vector3.UP).normalized()
	var land := _clear_spot(player.global_position + fwd * 7.0, side, fwd)
	land.y = _ground(land.x, land.z)
	var start := land - side * 14.0 + Vector3.UP * 11.0 - fwd * 3.0
	var derpy := _body(DERPY)
	if derpy == null:
		_busy = false
		return
	derpy.global_position = start
	derpy.look_at(land, Vector3.UP)
	_play(derpy, &"struggle")
	var cam_side := land + side * 4.5 + fwd * 2.0 + Vector3.UP * 1.4
	var fall := 1.7
	var shots := [
		{"from": "here", "to": player.global_position - fwd * 1.0 + Vector3.UP * 2.6,
			"look_node": derpy, "look_height": 0.8, "time": fall,
			"call": func() -> void: _fall(derpy, start, land, fall)},
		{"from": cam_side, "to": cam_side + side * 0.4 - Vector3.UP * 0.3,
			"look": land + Vector3.UP * 0.7, "time": 2.6,
			"caption": "Derpy!",
			"call": func() -> void: _flop(derpy, land)},
		{"from": cam_side + side * 0.4 - Vector3.UP * 0.3, "to": cam_side + side * 1.5 + Vector3.UP * 1.2,
			"look": land + Vector3.UP * 0.9, "time": 2.2,
			"caption": "\"I just don't know what went wrong!\"",
			"call": func() -> void: _play(derpy, &"shake")},
		{"from": "here", "to": player.global_position - fwd * 4.0 + Vector3.UP * 3.0,
			"look": land + Vector3.UP * 4.0, "time": 1.6,
			"call": func() -> void: _fly_off(derpy, land, fwd)},
	]
	await Cinematic.shared(get_tree()).play(shots, {"freeze": [player], "host": _ranch()})
	if is_instance_valid(derpy):
		derpy.queue_free()
	_busy = false


func _fall(derpy: Node3D, start: Vector3, land: Vector3, secs: float) -> void:
	var tw := create_tween()
	tw.tween_method(func(k: float) -> void:
		if not is_instance_valid(derpy):
			return
		var p := start.lerp(land, k)
		p.y += sin(k * PI) * 3.0 * (1.0 - k)
		derpy.global_position = p
		derpy.rotation.z = k * TAU * 1.5, 0.0, 1.0, secs).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _flop(derpy: Node3D, land: Vector3) -> void:
	derpy.global_position = land
	derpy.rotation.z = 0.0
	_play(derpy, &"lie")
	RumpBounce.kick_on(derpy, 2.0)
	var puff := BloomCeremonyScript.sparkles([Color(0.95, 0.9, 0.8), Color(0.85, 0.8, 0.7)])
	puff.amount = 24
	puff.lifetime = 0.8
	add_child(puff)
	puff.global_position = land + Vector3.UP * 0.3
	puff.emitting = true
	get_tree().create_timer(1.6).timeout.connect(puff.queue_free)
	# A second, smaller bounce as she settles, for the joke.
	get_tree().create_timer(0.7).timeout.connect(func() -> void:
		if is_instance_valid(derpy):
			RumpBounce.kick_on(derpy, 1.0))


func _fly_off(derpy: Node3D, land: Vector3, fwd: Vector3) -> void:
	if not is_instance_valid(derpy):
		return
	_play(derpy, &"jump")
	var tw := create_tween()
	tw.tween_property(derpy, "global_position", land + fwd * 6.0 + Vector3.UP * 16.0, 1.6) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## Somewhere near `around` with nobody standing on it (P8 render check: Derpy came down on
## Spike): the first of a few spots round it with no pony, townspony or companion within 2.5 m.
func _clear_spot(around: Vector3, side: Vector3, fwd: Vector3) -> Vector3:
	var bodies: Array[Node3D] = []
	for g: StringName in [&"townsfolk"]:
		for n: Node in get_tree().get_nodes_in_group(g):
			if n is Node3D:
				bodies.append(n as Node3D)
	var spawner: Node = _ranch().get("spawner")
	if spawner != null:
		for p: Node3D in spawner.call("get_spawned"):
			bodies.append(p)
	var spike: Node3D = _ranch().get("spike")
	if spike != null:
		bodies.append(spike)
	for offset: Vector3 in [side * 1.5, -side * 2.5, side * 4.0, fwd * 3.0 + side * 2.0,
			-side * 5.0, fwd * 5.0, fwd * 2.0 - side * 4.0]:
		var at := around + offset
		var free := true
		for b in bodies:
			if is_instance_valid(b) and Vector2(b.global_position.x - at.x,
					b.global_position.z - at.z).length() < 2.5:
				free = false
				break
		if free:
			return at
	return around + side * 1.5


## Rainbow Dash breaks the sound barrier across the sky.
func sonic_rainboom() -> void:
	_busy = true
	var player: Node3D = _ranch().get("player")
	var fwd := -player.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.1 else Vector3.FORWARD
	var side := fwd.cross(Vector3.UP).normalized()
	var mid := player.global_position + fwd * 60.0 + Vector3.UP * 34.0
	var a := mid - side * 70.0 + Vector3.UP * 6.0
	var b := mid + side * 70.0 - Vector3.UP * 4.0
	var dash := _body(DASH)
	if dash == null:
		_busy = false
		return
	dash.scale = Vector3.ONE * 1.4
	dash.global_position = a
	dash.look_at(b, Vector3.UP)
	_play(dash, &"gallop")
	var trail := _trail()
	var eye := player.global_position + Vector3.UP * 1.6 - fwd * 1.5
	var streak := 2.6
	var shots := [
		{"from": "here", "to": eye, "look": a, "look_to": mid, "time": streak * 0.5, "fov": 55.0,
			"call": func() -> void: _streak(dash, trail, a, b, streak)},
		{"from": eye, "to": eye - fwd * 2.0 + Vector3.UP * 0.5, "look": mid, "time": 1.8,
			"call": func() -> void: _ring(mid, fwd)},
		{"from": "here", "to": eye - fwd * 3.0 + Vector3.UP * 1.0, "look": mid,
			"look_to": b, "time": 2.4, "caption": "A Sonic Rainboom!"},
	]
	await Cinematic.shared(get_tree()).play(shots, {"freeze": [player], "host": _ranch()})
	if is_instance_valid(dash):
		dash.queue_free()
	var fade := create_tween()
	fade.tween_method(func(v: float) -> void:
		if is_instance_valid(trail):
			(trail.material_override as ShaderMaterial).set_shader_parameter(&"alpha", v),
		0.72, 0.0, 6.0)
	fade.tween_callback(trail.queue_free)
	_busy = false


func _trail() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 3.2)
	mi.mesh = quad
	var mat := ShaderMaterial.new()
	mat.shader = RAINBOW_SHADER
	mat.set_shader_parameter(&"alpha", 0.72)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.visible = false
	return mi


func _streak(dash: Node3D, trail: MeshInstance3D, a: Vector3, b: Vector3, secs: float) -> void:
	var tw := create_tween()
	tw.tween_method(func(k: float) -> void:
		if not is_instance_valid(dash):
			return
		var p := a.lerp(b, k)
		dash.global_position = p
		# The trail runs from where she started to where she is, its face to the camera.
		var length := a.distance_to(p)
		if length > 0.5 and is_instance_valid(trail):
			trail.visible = true
			(trail.mesh as QuadMesh).size = Vector2(length, 3.2)
			var midp := (a + p) * 0.5
			var along := (p - a).normalized()
			var cam := get_viewport().get_camera_3d()
			var to_cam := (cam.global_position - midp).normalized() if cam != null else Vector3.BACK
			var up := along.cross(to_cam).normalized()
			trail.global_transform = Transform3D(Basis(along, up, along.cross(up)), midp),
		0.0, 1.0, secs)


func _ring(at: Vector3, fwd: Vector3) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.82
	torus.outer_radius = 1.0
	torus.rings = 48
	ring.mesh = torus
	var mat := ShaderMaterial.new()
	mat.shader = RAINBOW_SHADER
	mat.set_shader_parameter(&"alpha", 0.85)
	mat.set_shader_parameter(&"brightness", 1.4)
	ring.material_override = mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	ring.global_position = at
	# Face the player: the torus lies in its local XZ plane, so tip it up toward her.
	ring.look_at(at - fwd, Vector3.UP)
	ring.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	ring.scale = Vector3.ONE * 0.5
	var tw := create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector3.ONE * 26.0, 1.4).set_trans(Tween.TRANS_EXPO) \
		.set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter(&"alpha", v), 0.85, 0.0, 2.2)
	tw.chain().tween_callback(ring.queue_free)
