extends SceneTree
## PS EVIDENCE, items 31, 41 and 68 (playtest 2026-11-05): nobody gets inside a building.
## 31: she stands with her back to the Market's front wall and the lens is swung round her in
##     eight steps, so the arm presses into the wall; the lens position is printed, and whether
##     it is inside the Market's footprint.
## 41: she walks (move_forward held) at the Depot's door from 4 m; a frame every half second.
## 68: she is put down inside the Depot; a frame every quarter second from outside, and the
##     player's own view, until she is out.
##   xvfb-run ... godot --display-driver x11 --path game -s res://scenes/test/ps_walls_shot.gd -- --out=/abs/dir
const BootIntentScript := preload("res://world/boot_intent.gd")
const WorldStateScript := preload("res://systems/world_state.gd")
var out := ""
var ranch: Node


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("SHOT ", name)


func _mouse_to_corner() -> void:
	var m := InputEventMouseMotion.new()
	m.position = Vector2(4, 4)
	m.global_position = Vector2(4, 4)
	Input.parse_input_event(m)
	Input.warp_mouse(Vector2(4, 4))


func _boot() -> void:
	root.get_window().size = Vector2i(1600, 900)
	BootIntentScript.driven = true
	BootIntentScript.request_new_game()
	change_scene_to_file("res://world/ranch.tscn")
	for i in 900:
		await process_frame
		ranch = current_scene
		if ranch != null and ranch.get("people") != null and i > 30:
			break
	await _frames(120)
	_mouse_to_corner()
	var cs: Node = ranch.get("creation_screen")
	if cs != null and bool(cs.call("is_open")):
		cs.call("confirm")
	for i in 90:
		await process_frame
		var lp: Node = ranch.get("letter_panel")
		if lp != null and lp.get("visible") and lp.has_method("close_button_node"):
			(lp.call("close_button_node") as Button).pressed.emit()
			print("LETTER closed by its button")
			break
	paused = false
	_mouse_to_corner()


func _h(x: float, z: float) -> float:
	return float(ranch.get("terrain").call("height_at", x, z))


func _building(n: String) -> Building:
	return ranch.get_node(NodePath("Buildings/" + n)) as Building


func _run() -> void:
	await _boot()
	var w: Object = ranch.get("_world")
	w.call("pin", WorldStateScript.Phase.DAY, WorldStateScript.Weather.CLEAR)
	var player: CharacterBody3D = ranch.get("player")
	var rig: Node = ranch.find_child("CameraRig", true, false)
	var cam_of := func() -> Camera3D: return rig.call("get_camera") as Camera3D

	# --- 31: the lens round her, her back to the Market's front wall --------------------------
	var market := _building("Market")
	var fwd := market.global_basis.z
	fwd.y = 0
	fwd = fwd.normalized()
	var stand := market.global_position + fwd * (market.depth * 0.5 + 1.0)
	stand.y = _h(stand.x, stand.z) + 0.1
	player.global_position = stand
	player.velocity = Vector3.ZERO
	var inside_count := 0
	for k in 8:
		# k = 0: the lens straight toward the wall behind her (the owner's [29]).
		var yaw := atan2(-fwd.x, -fwd.z) + TAU * k / 8.0
		rig.call("reset_look", yaw)
		await _frames(30)
		var c: Vector3 = cam_of.call().global_position
		var inside := market.contains_point(c)
		if inside:
			inside_count += 1
		var wall_d := (c - market.global_position).dot(fwd) - market.depth * 0.5
		print("ITEM31 step %d yaw %+.0f deg: lens %s, %.2f m from the player, %.2f m off the front wall, inside the Market: %s" % [
			k, rad_to_deg(TAU * k / 8.0), c, c.distance_to(player.global_position + Vector3(0, 1, 0)), wall_d, inside])
		await _shot("item31_lens_round_%d" % k)
	print("ITEM31 lens inside the Market in %d of 8" % inside_count)

	# --- 41: walking at the Depot's door ----------------------------------------------------
	var depot := _building("Depot")
	fwd = depot.global_basis.z
	fwd.y = 0
	fwd = fwd.normalized()
	var start := depot.global_position + fwd * (depot.depth * 0.5 + 4.0)
	start.y = _h(start.x, start.z) + 0.1
	player.global_position = start
	player.velocity = Vector3.ZERO
	var yaw41 := atan2(fwd.x, fwd.z)
	player.call("face", yaw41 + PI)
	rig.call("reset_look", yaw41)
	await _frames(30)
	Input.action_press(&"move_forward")
	var t0 := Time.get_ticks_msec()
	var k41 := 0
	var nearest := INF
	while Time.get_ticks_msec() - t0 < 4500:
		await process_frame
		var front_d := (player.global_position - depot.global_position).dot(fwd) - depot.depth * 0.5
		nearest = minf(nearest, front_d)
		if Time.get_ticks_msec() - t0 >= 500 * k41:
			print("ITEM41 t %.1f s: %.2f m out from the Depot's front wall, inside: %s" % [
				0.5 * k41, front_d, depot.contains_point(player.global_position)])
			await _shot("item41_walk_%02d" % k41)
			k41 += 1
	Input.action_release(&"move_forward")
	print("ITEM41 nearest to the front wall %.2f m" % nearest)
	# The same walk side on, from a lens beside the door.
	var side := Camera3D.new()
	side.fov = 60.0
	ranch.add_child(side)
	var right := fwd.cross(Vector3.UP).normalized()
	side.global_position = depot.global_position + fwd * (depot.depth * 0.5 + 2.0) + right * 7.0 + Vector3(0, 2.5, 0)
	side.global_position.y += _h(side.global_position.x, side.global_position.z)
	side.look_at(player.global_position + Vector3(0, 0.6, 0))
	side.make_current()
	await _frames(4)
	await _shot("item41_stopped_side_view")

	# --- 68: put down inside the Depot, in the rain -----------------------------------------
	w.call("pin", WorldStateScript.Phase.DAY, WorldStateScript.Weather.RAIN)
	var sky: Node = ranch.get("sky_rig")
	if sky != null and sky.has_method("apply_immediately"):
		sky.call("apply_immediately", w)
	var over := Camera3D.new()
	over.fov = 60.0
	ranch.add_child(over)
	over.global_position = depot.global_position + fwd * 9.0 + right * 5.0 + Vector3(0, 7.0, 0)
	over.look_at(depot.global_position + Vector3(0, 1.0, 0) + fwd * 2.0)
	over.make_current()
	side.queue_free()
	player.global_position = depot.to_global(Vector3(0, Building.FLOOR_TOP + 0.2, 0))
	player.velocity = Vector3.ZERO
	t0 = Time.get_ticks_msec()
	var k68 := 0
	var out_at := -1.0
	while Time.get_ticks_msec() - t0 < 2000:
		await process_frame
		var inside68 := depot.contains_point(player.global_position)
		var t := float(Time.get_ticks_msec() - t0) / 1000.0
		if not inside68 and out_at < 0.0:
			out_at = t
			print("ITEM68 out of the Depot at %.2f s, at %s" % [t, player.global_position])
		if t >= 0.25 * k68:
			print("ITEM68 t %.2f s: inside the Depot %s at %s" % [t, inside68, player.global_position])
			await _shot("item68_put_inside_%02d" % k68)
			k68 += 1
	(cam_of.call() as Camera3D).make_current()
	await _frames(30)
	await _shot("item68_her_view_after")
	# And she walks off afterward (no soft-lock): back from the door for a second.
	var before := player.global_position
	Input.action_press(&"move_back")
	await _frames(60)
	Input.action_release(&"move_back")
	await _frames(10)
	print("ITEM68 walked %.2f m after the rescue" % before.distance_to(player.global_position))
	await _shot("item68_walks_off")
	print("PS_WALLS_SHOT_OK")
	quit(0)
