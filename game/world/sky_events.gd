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
const LayersScript := preload("res://world/collision_layers.gd")

## The Rainboom's cutaway: a lens on the open slope south of the plaza (metres over the
## ground at this spot), looking out over the southern hills.
const RAINBOOM_EYE := Vector3(6.0, 2.6, -2.0)
const RAINBOOM_LOOK := Vector3(-10.0, 6.0, 61.6)

## Seconds of outdoor play between shows, the first one later than the rest.
const FIRST_GAP := Vector2(360.0, 540.0)
const EVENT_GAP := Vector2(480.0, 780.0)

var _wait := 0.0
var _next := 0
var _rng := RandomNumberGenerator.new()
var _busy := false
var _fall_tween: Tween


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
	# Shows for a clear day: a Rainboom in the rain at night is neither (render check).
	var w: Object = r.get("_world")
	if w != null and (int(w.call("phase")) != WorldState.Phase.DAY
			or int(w.call("weather")) != WorldState.Weather.CLEAR):
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


## Her mouth moving on her line for `secs` (Fable AAA round 3, #4: "same closed mouth" on
## three frames of dialogue): the face's jaw driven like a townspony's babble.
func _say(holder: Node3D, secs: float) -> void:
	var faces := holder.find_children("*", "PonyFace", true, false)
	if faces.is_empty():
		return
	var face: PonyFace = faces[0]
	face.talking = true
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		if is_instance_valid(face):
			face.talk_amount = 0.5 + 0.5 * sin(t * TAU * 4.5) * (0.7 + 0.3 * sin(t * 7.0)), 0.0, secs, secs)
	tw.tween_callback(func() -> void:
		if is_instance_valid(face):
			face.talking = false
			face.talk_amount = 0.0)


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
	# The landing is seen from beyond her, looking back toward the player, so nobody standing
	# by the player is between the lens and Derpy (render check: Spike filled the frame).
	var cam_side := land + fwd * 3.2 + side * 1.4 + Vector3.UP * 1.3
	if not _clear_line(cam_side, land + Vector3.UP * 0.7):
		# Something in the way from beyond her: from the player's side instead.
		cam_side = land - fwd * 3.6 + side * 1.4 + Vector3.UP * 1.4
	var fall := 1.7
	# HER FACE IS THE PAYOFF (Fable AAA round 1, #10: "the payoff shot is two grey lumps ...
	# her face is never shown"). She is turned on landing to face the impact lens (render
	# check: a holder's -Z is her tail, so both shots had her rump), and the close-up stands
	# off her nose a little to the side, at her eye height sitting up.
	var facing := cam_side - land
	facing.y = 0.0
	facing = facing.normalized()
	var fside := facing.cross(Vector3.UP).normalized()
	# She comes to rest sitting up, dazed, and gets to her hooves on the line (the shake): the
	# frame is aimed between her sitting face (1.0 m) and her standing one (1.7 m), far enough
	# back that standing up never takes her head out of the top (render check: it did at 2.3 m).
	var face := land + facing * 0.5 + Vector3.UP * 1.3
	var close := face + facing * 3.4 + fside * 0.7 + Vector3.UP * 0.1
	if not _clear_line(close, face):
		close = face + facing * 3.4 - fside * 0.7 + Vector3.UP * 0.1
	var shots := [
		# A long lens on the way down, so she fills the frame instead of a smudge by a roof.
		{"from": "here", "to": player.global_position - fwd * 1.0 + Vector3.UP * 2.6,
			"look_node": derpy, "look_height": 0.8, "time": fall, "fov": 45.0, "fov_to": 26.0,
			"call": func() -> void: _fall(derpy, start, land, fall)},
		{"from": cam_side, "to": cam_side + side * 0.4 - Vector3.UP * 0.3,
			"look": land + Vector3.UP * 0.6, "time": 2.2, "fov": 50.0, "fov_to": 44.0,
			"shake": 0.16, "caption": "Derpy!",
			"call": func() -> void: _flop(derpy, land, facing)},
		{"from": close, "to": close.lerp(face, 0.04), "look": face, "time": 2.4,
			"fov": 42.0, "fov_to": 38.0,
			"caption": "\"I just don't know what went wrong!\"",
			"call": func() -> void:
				_play(derpy, &"shake")
				_say(derpy, 2.2)},
		{"from": "here", "to": player.global_position - fwd * 4.0 + Vector3.UP * 3.0,
			"look": land + Vector3.UP * 4.0, "time": 1.6, "fov": 55.0,
			"call": func() -> void: _fly_off(derpy, land, fwd)},
	]
	await Cinematic.shared(get_tree()).play(shots, {"freeze": [player], "host": _ranch()})
	if is_instance_valid(derpy):
		derpy.queue_free()
	_busy = false


func _fall(derpy: Node3D, start: Vector3, land: Vector3, secs: float) -> void:
	var tw := create_tween()
	_fall_tween = tw
	tw.tween_method(func(k: float) -> void:
		if not is_instance_valid(derpy):
			return
		var p := start.lerp(land, k)
		p.y += sin(k * PI) * 3.0 * (1.0 - k)
		derpy.global_position = p
		# Two whole tumbles, so the last frame of the fall is right way up (one and a half
		# left her on her back: Fable round 2 renders, "two grey lumps" were her hooves).
		derpy.rotation.z = k * TAU * 2.0, 0.0, 1.0, secs).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _flop(derpy: Node3D, land: Vector3, facing: Vector3) -> void:
	# The fall's last tick can land after the cut on a slow frame and undo the flop.
	if _fall_tween != null and _fall_tween.is_valid():
		_fall_tween.kill()
	derpy.global_position = land
	derpy.rotation = Vector3.ZERO
	# The holder looks down -Z at her tail, so it looks away from where her face should go.
	derpy.look_at(land - facing, Vector3.UP)
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
		at.y = _ground(at.x, at.z)
		# No prop there either (render check: she came down behind the Palace's heart rail).
		if _prop_near(at, 2.2):
			continue
		var free := true
		for b in bodies:
			if is_instance_valid(b) and Vector2(b.global_position.x - at.x,
					b.global_position.z - at.z).length() < 2.5:
				free = false
				break
		if free:
			return at
	return around + side * 1.5


func _prop_near(at: Vector3, radius: float) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	q.shape = sphere
	q.transform = Transform3D(Basis.IDENTITY, at + Vector3.UP * (radius + 0.2))
	q.collision_mask = LayersScript.PROPS
	return not get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


## True when nothing solid stands between `from` and `to`.
func _clear_line(from: Vector3, to: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to, LayersScript.PROPS)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Rainbow Dash breaks the sound barrier across the sky.
func sonic_rainboom() -> void:
	_busy = true
	var player: Node3D = _ranch().get("player")
	# A CUTAWAY TO THE MEADOW, NOT A LENS AT HER SHOULDER (two render checks: from wherever she
	# stood, a cottage wall or an awning filled the frame; their trims have no collision, so no
	# sightline test can see them). The lens cuts to the open slope south of the plaza, looking
	# out over the hills, and the boom happens in that sky.
	var eye := RAINBOOM_EYE
	eye.y = _ground(eye.x, eye.z) + RAINBOOM_EYE.y
	var fwd := RAINBOOM_LOOK - RAINBOOM_EYE
	fwd.y = 0.0
	fwd = fwd.normalized()
	var side := fwd.cross(Vector3.UP).normalized()
	var mid := eye + fwd * 42.0 + Vector3.UP * 18.0
	var a := mid - side * 55.0 + Vector3.UP * 5.0
	var b := mid + side * 55.0 - Vector3.UP * 3.0
	var dash := _body(DASH)
	if dash == null:
		_busy = false
		return
	dash.scale = Vector3.ONE * 2.2
	dash.global_position = a
	dash.look_at(b, Vector3.UP)
	_play(dash, &"gallop")
	var trail := _trail()
	var streak := 2.6
	# A LONG LENS ON HER, THEN THE BOOM (Fable AAA round 1, #10: "Rainbow Dash is a 30 px
	# sprite ... no bloom, flash, shake"). The streak is followed on a telephoto so she is the
	# size of a hand in the frame; the boom whites the screen out and kicks the camera.
	var shots := [
		{"from": eye, "to": eye + side * 0.6, "look_node": dash, "look_height": 0.0,
			"time": streak * 0.5, "fov": 16.0, "fov_to": 11.0,
			"call": func() -> void: _streak(dash, trail, a, b, streak)},
		{"from": eye, "to": eye + Vector3.UP * 0.5, "look": mid, "time": 1.8,
			"fov": 52.0, "fov_to": 60.0, "flash": 0.55, "shake": 0.35,
			"call": func() -> void: _ring(mid, fwd)},
		{"from": "here", "to": eye + Vector3.UP * 1.6 - side * 1.5, "look": mid,
			"look_to": b, "time": 2.4, "caption": "A Sonic Rainboom!"},
	]
	await Cinematic.shared(get_tree()).play(shots, {"freeze": [player], "host": _ranch()})
	if is_instance_valid(dash):
		dash.queue_free()
	var fade := create_tween()
	fade.tween_method(func(v: float) -> void:
		if is_instance_valid(trail):
			(trail.material_override as ShaderMaterial).set_shader_parameter(&"alpha", v),
		0.9, 0.0, 6.0)
	fade.tween_callback(trail.queue_free)
	_busy = false


func _trail() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 5.5)
	mi.mesh = quad
	var mat := ShaderMaterial.new()
	mat.shader = RAINBOW_SHADER
	mat.set_shader_parameter(&"alpha", 0.9)
	mat.set_shader_parameter(&"brightness", 1.3)
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
			(trail.mesh as QuadMesh).size = Vector2(length, 5.5)
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
	torus.inner_radius = 0.7
	torus.outer_radius = 1.0
	# Smooth at the size it grows to: 48 sides read as a jagged polygon at full spread.
	torus.rings = 160
	torus.ring_segments = 16
	ring.mesh = torus
	var mat := ShaderMaterial.new()
	mat.shader = RAINBOW_SHADER
	mat.set_shader_parameter(&"alpha", 1.0)
	mat.set_shader_parameter(&"brightness", 1.8)
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
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter(&"alpha", v), 1.0, 0.0, 2.6)
	tw.chain().tween_callback(ring.queue_free)
	# The hot core: a white burst at the heart of the ring, gone in a blink.
	var core := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	# Added light, unfogged: alpha-blended, the fog and a half-faded alpha turned it a brown
	# disc in front of the sky (Fable round 2 renders).
	var cm := StandardMaterial3D.new()
	cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	cm.disable_fog = true
	cm.no_depth_test = true
	cm.albedo_color = Color(1.0, 0.98, 0.92, 1.0)
	sm.material = cm
	core.mesh = sm
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(core)
	core.global_position = at
	core.scale = Vector3.ONE * 0.6
	var ct := create_tween().set_parallel(true)
	ct.tween_property(core, "scale", Vector3.ONE * 7.0, 0.55).set_trans(Tween.TRANS_EXPO) \
		.set_ease(Tween.EASE_OUT)
	ct.tween_property(cm, "albedo_color", Color.BLACK, 0.8)
	ct.chain().tween_callback(core.queue_free)
	_cloud_ring(at, fwd)


## THE SHOCK RING (Fable AAA round 2, #6 and round 3, #4: puffs of cloud read as "a
## soap-bubble hoop"). The show draws the boom as a hard white ring racing out ahead of the
## rainbow one: a flat, opaque, unshaded torus, thin, out fast, gone fast.
func _cloud_ring(at: Vector3, fwd: Vector3) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.93
	torus.outer_radius = 1.0
	torus.rings = 160
	torus.ring_segments = 8
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.disable_fog = true
	mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	torus.material = mat
	ring.mesh = torus
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	ring.global_position = at
	ring.look_at(at - fwd, Vector3.UP)
	ring.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector3.ONE * 40.0, 0.9).set_trans(Tween.TRANS_EXPO) \
		.set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.5).set_delay(0.45)
	tw.chain().tween_callback(ring.queue_free)
