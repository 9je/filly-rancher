class_name PortraitBaker
extends Node
## HER FACE, NOT A COLOUR SQUARE (P8 S5/S8; docs/aaa-review-2026-11-08.md 2.6 and 2.10; owner
## playtest 2026-11-08 items 61 and 69: "colour-square portraits", "icons are generic shapes,
## not faces"). Bakes a head-and-shoulders picture of a pony from her own body, once, into a
## plain texture any menu can draw: the race form guide's runners, the Depot's rows.
##
## One baker for the whole game (`shared(tree)`), one small SubViewport, one pony at a time:
## a request copies her visuals onto the stage (sharing every mesh and material, as the catch
## card's portrait does), waits two drawn frames, reads the picture back and caches it by
## `key`. A request already cached answers at once; `baked` fires when a new one lands, so a
## menu can redraw.

signal baked(key: String)

const SIZE := Vector2i(192, 192)
const STUDIO_FILL := Color(0.92, 0.90, 1.0)

static var _shared: PortraitBaker

var _cache := {}
var _queue: Array = []
var _busy := false
var _viewport: SubViewport
var _stage: Node3D
var _camera: Camera3D


static func shared(tree: SceneTree) -> PortraitBaker:
	if _shared == null or not is_instance_valid(_shared):
		_shared = PortraitBaker.new()
		_shared.name = "PortraitBaker"
		tree.root.add_child.call_deferred(_shared)
	return _shared


## Her picture if it is baked, else null (and a bake is queued from `body`, her live body).
func portrait(key: String, body: Node3D) -> Texture2D:
	if _cache.has(key):
		return _cache[key]
	if body != null and is_instance_valid(body) and not _queued(key):
		_queue.append([key, body])
		_pump.call_deferred()
	return null


func has_portrait(key: String) -> bool:
	return _cache.has(key)


func _queued(key: String) -> bool:
	for q: Array in _queue:
		if q[0] == key:
			return true
	return false


func _pump() -> void:
	if _busy or _queue.is_empty() or not is_inside_tree():
		return
	_busy = true
	while not _queue.is_empty():
		var job: Array = _queue.pop_front()
		var key: String = job[0]
		var body: Node3D = job[1]
		if not is_instance_valid(body) or _cache.has(key):
			continue
		if not _pose(body):
			continue
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := _viewport.get_texture().get_image()
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_clear_stage()
		if img != null and not img.is_empty():
			_cache[key] = ImageTexture.create_from_image(img)
			baked.emit(key)
	_busy = false


func _pose(body: Node3D) -> bool:
	_ensure_viewport()
	_clear_stage()
	# A pony keeps her body under `visuals`; an Attendant (the casino's staff) keeps it as her
	# own first child.
	var vis := body.get("visuals") as Node3D
	if vis == null:
		vis = body
	var source: Node3D = vis.get_child(0) as Node3D if vis.get_child_count() > 0 else null
	if source == null:
		return false
	var copy := source.duplicate(0) as Node3D
	if copy == null:
		return false
	copy.transform = Transform3D(Basis.from_scale(vis.scale if vis != body else source.scale), Vector3.ZERO)
	_stage.add_child(copy)
	for sk in copy.find_children("*", "Skeleton3D", true, false):
		(sk as Skeleton3D).reset_bone_poses()
	var anim := copy.get_node_or_null(^"AnimationPlayer") as AnimationPlayer
	if anim != null and anim.has_animation(&"idle"):
		anim.play(&"idle")
		anim.seek(0.4, true)
	_frame(copy)
	return true


func _ensure_viewport() -> void:
	if _viewport != null:
		return
	_viewport = SubViewport.new()
	_viewport.size = SIZE
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	_stage = Node3D.new()
	_viewport.add_child(_stage)
	_camera = Camera3D.new()
	_camera.fov = 30.0
	_camera.current = true
	_viewport.add_child(_camera)
	# The studio the review asks for (2.2): a warm key, and a cool even fill from the ambient.
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35.0, 150.0, 0.0)
	key.light_energy = 0.95
	_viewport.add_child(key)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = STUDIO_FILL
	e.ambient_light_energy = 0.5
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = e
	_viewport.add_child(env)


## Her head and withers, three-quarter on: the top front of her bounds (the models face -Z).
func _frame(model: Node3D) -> void:
	var box := AABB()
	var first := true
	for n in model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or not mi.visible:
			continue
		var b: AABB = model.global_transform.affine_inverse() * mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	if first:
		box = AABB(Vector3(-0.5, 0.0, -0.8), Vector3(1.0, 2.0, 1.6))
	var height := box.size.y
	var head := Vector3(box.get_center().x, box.position.y + height * 0.66,
		box.position.z + box.size.z * 0.16)
	var dist := height * 1.55
	_camera.look_at_from_position(head + Vector3(dist * 0.5, height * 0.06, -dist * 0.86),
		head, Vector3.UP)


func _clear_stage() -> void:
	if _stage == null:
		return
	for c in _stage.get_children():
		_stage.remove_child(c)
		c.queue_free()
