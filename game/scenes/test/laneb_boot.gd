extends RefCounted
## P9 W3 probe helpers: boot the ranch from a save the way play.sh loads one, close the opening
## letter, and hand back the ranch; plus input and screenshot helpers for real-flow frames.
const BootIntentScript := preload("res://world/boot_intent.gd")
const FIXTURE := "res://test/fixtures/old_save_pre_ps/slot_0.json"


static func boot(tree: SceneTree, fixture: String = FIXTURE, size := Vector2i(1600, 900)) -> Node:
	tree.root.get_window().size = size
	var dst := ProjectSettings.globalize_path(SaveIO.slot_path(0))
	DirAccess.make_dir_recursive_absolute(dst.get_base_dir())
	var f := FileAccess.open(dst, FileAccess.WRITE)
	f.store_string(FileAccess.get_file_as_string(fixture))
	f.close()
	BootIntentScript.driven = true
	tree.change_scene_to_file("res://world/ranch.tscn")
	var ranch: Node = null
	for i in 1200:
		await tree.process_frame
		ranch = tree.current_scene
		if ranch != null and bool(ranch.get("boot_done")):
			break
	for i in 60:
		await tree.process_frame
	var lp: Node = ranch.get("letter_panel")
	if lp != null and bool(lp.call("is_open")):
		lp.call("close")
	tree.paused = false
	return ranch


static func shot(tree: SceneTree, path: String, frames := 20) -> void:
	for i in frames:
		await tree.process_frame
	await RenderingServer.frame_post_draw
	tree.root.get_texture().get_image().save_png(path)
	print("SHOT ", path)


static func press(tree: SceneTree, action: StringName) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
	await tree.process_frame
	await tree.process_frame
	var r := InputEventAction.new()
	r.action = action
	r.pressed = false
	Input.parse_input_event(r)
	await tree.process_frame


static func click(tree: SceneTree, at: Vector2) -> void:
	await hover(tree, at)
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = at
		e.global_position = at
		tree.root.push_input(e)
		await tree.process_frame


static func hover(tree: SceneTree, at: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = at
	e.global_position = at
	tree.root.push_input(e)
	await tree.process_frame


## Put the player at `pos` looking at `target`, the gameplay camera swung behind her.
static func stand(ranch: Node, pos: Vector3, target: Vector3) -> void:
	var player: Node3D = ranch.get("player")
	player.global_position = pos
	var d := target - pos
	d.y = 0.0
	var yaw := atan2(-d.x, -d.z)
	var vis := player.get_node_or_null(^"Visuals") as Node3D
	if vis != null:
		vis.global_rotation.y = yaw
	var rig := player.get_node_or_null(^"CameraPivot/CameraRig")
	if rig != null:
		rig.call("reset_look", yaw)


## Stand in front of building `path`'s door, facing it (the way ranch._door_gap measures it).
static func at_door(ranch: Node, path: NodePath, out := 1.6) -> void:
	var b := ranch.get_node(path) as Node3D
	var z := b.global_transform.basis.z
	var door: Vector3 = b.global_position + z * (float(b.get("depth")) * 0.5)
	var at := door + z * out
	var terrain: Node = ranch.get("terrain")
	at.y = float(terrain.call("height_at", at.x, at.z)) + 0.2
	stand(ranch, at, door)


static func pens(ranch: Node) -> Array:
	var out := []
	for slot in ranch.call("plot_slots"):
		var p = slot.get_built()
		if p is Pen:
			out.append(p)
	return out


## Screen position of a Control's centre, in window pixels.
static func centre_of(tree: SceneTree, c: Control) -> Vector2:
	return tree.root.get_final_transform() * c.get_global_rect().get_center()
