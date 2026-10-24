extends SceneTree
## Owner report 2026-10-24: "i cant get the beam to work". The real ranch, the real input:
## a wild pony stood 5 m ahead of the camera, the beam action held, and what the beam saw.
##   tools/bin/godot --path game --audio-driver Dummy -s res://scenes/test/beam_probe.gd

const BootIntentScript = preload("res://world/boot_intent.gd")
const PonyScript = preload("res://actors/pony/pony.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	BootIntentScript.driven = true
	BootIntentScript.request_new_game()
	change_scene_to_file("res://world/ranch.tscn")
	var ranch: Node = null
	for i in 600:
		await process_frame
		ranch = current_scene
		if ranch != null and ranch.get("people") != null and i > 20:
			break
	for i in 30:
		await process_frame
	var cs: Node = ranch.get("creation_screen")
	if cs != null and bool(cs.call("is_open")):
		cs.call("confirm")
	for i in 10:
		await process_frame
	var lp: Node = ranch.get("letter_panel")
	if lp != null and bool(lp.call("is_open")):
		lp.call("close")
	paused = false
	for i in 120:
		await physics_frame
	var player: Node3D = ranch.get("player")
	var beam: Node = player.call("get_magic_beam")
	var rig: Node3D = player.call("get_camera_pivot").get_node("CameraRig")
	print("BEAM_PROBE engine=%s tree_paused=%s" % [
		ProjectSettings.get_setting("physics/3d/physics_engine"), paused])
	var pony: Node3D = null
	for n in ranch.find_children("*", "CharacterBody3D", true, false):
		if n is PonyScript:
			pony = n
			break
	if pony == null:
		print("BEAM_PROBE no wild pony")
		quit(1)
		return
	var fwd := -rig.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var hud := ranch.get_node_or_null(^"HUD")
	var people: Node = ranch.get("people")
	if bool(people.call("is_talking")):
		print("BEAM_PROBE talking at start; closing")
		pass
	for i in 240:
		await physics_frame
	print("BEAM_PROBE talking=%s toast_before=%s" % [people.call("is_talking"), hud.call("toast_text")])
	Input.action_press(&"beam")
	for i in 3:
		await physics_frame
	Input.action_release(&"beam")
	await physics_frame
	print("BEAM_PROBE no-scoop toast=%s" % hud.call("toast_text"))
	var gs: Node = root.get_node(^"/root/GameState")
	gs.get("story").call("set_flag", "has_scoop")
	ranch.call("_apply_beam_recall")
	for tries in 1:
		pony.global_position = player.global_position + fwd * 5.0 + Vector3.UP * 0.2
		pony.set("velocity", Vector3.ZERO)
		for i in 10:
			await physics_frame
		var ray = rig.call("get_aim_ray")
		var space := (player as Node3D).get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(ray.origin, ray.origin + ray.direction * 30.0)
		var hit := space.intersect_ray(q)
		print("BEAM_PROBE try=%d pony_at=%s dist=%.1f has_target=%s ray_hit=%s layer=%s" % [
			tries, pony.global_position, pony.global_position.distance_to(player.global_position),
			beam.call("has_target"), hit.get("collider", null),
			(hit.get("collider") as CollisionObject3D).collision_layer if hit.has("collider") \
				and hit["collider"] is CollisionObject3D else -1])
		Input.action_press(&"beam")
		var held := false
		for i in 240:
			await physics_frame
			held = held or bool(beam.call("is_holding"))
			if bool(beam.call("is_secured")):
				break
		print("BEAM_PROBE   active=%s ever_held=%s secured=%s" % [beam.call("is_active"), held,
			beam.call("is_secured")])
		Input.action_release(&"beam")
		for i in 30:
			await physics_frame
		rig.call("add_look_delta", 0.0, deg_to_rad(-6.0))
	quit(0)
