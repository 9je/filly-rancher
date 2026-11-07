extends SceneTree
## PLAYTEST SHOTS (PLAN.md PS0): the owner's 2026-11-05 screenshots, re-taken. Each pose puts
## the player and the game's own camera where screenshot [N] was taken (estimated by eye from
## the owner's image), so a before and an after of an item can be set beside the owner's.
## Run it inside the invisible display:
##
##   xvfb-run ... tools/bin/godot --display-driver x11 --path game \
##     -s res://scenes/test/playtest_shots.gd -- --item=29 --out=/abs/dir
##
## --item=all takes every pose. Writes item<N>_<label>_<variant>.png; world items get a day
## and a night-in-rain variant (the owner played through both). Prints PLAYTEST_SHOTS_OK <n>.

const BootIntentScript := preload("res://world/boot_intent.gd")
const WorldStateScript := preload("res://systems/world_state.gd")

## One pose per owner screenshot. anchor: a node path under the ranch, "prop:<file>" for the
## first placed prop of that model, or a Vector2 map point. front: metres out from the
## anchor along its front (a building's +Z, else from the anchor toward the map's centre).
## side: metres to the anchor's right. look: the camera's heading relative to the line from
## the player to the anchor, degrees. face_cam: the player turns to the lens (the owner's
## shot shows her face). zoom: metres added to the camera arm. shot: the owner's image.
const POSES := [
	{"items": [24, 26], "shot": 24, "label": "plot_brambles", "anchor": "overgrown", "front": 5.0, "side": -3.0, "pitch": -30.0, "world": true},
	{"items": [25], "shot": 25, "label": "yellow_blob", "anchor": "overgrown", "front": 9.0, "side": -7.0, "pitch": -35.0, "zoom": 2.0, "world": true},
	{"items": [29], "shot": 27, "label": "market_door", "anchor": ^"Buildings/Market", "front": 2.2, "face_cam": true, "world": true},
	{"items": [31], "shot": 29, "label": "market_wall_camera", "anchor": ^"Buildings/Market", "front": 1.0, "look": 180.0, "zoom": 2.0, "world": true},
	{"items": [32], "shot": 30, "label": "barn_yard", "anchor": ^"Buildings/Barn", "front": 9.0, "side": -6.0, "face_cam": true, "zoom": 2.0, "world": true},
	{"items": [29], "shot": 31, "label": "depot_door", "anchor": ^"Buildings/Depot", "front": 2.0, "world": true},
	{"items": [14], "shot": 32, "label": "fingerpost", "anchor": Vector2(4.6, 0.9), "front": 2.0, "side": 1.0, "face_cam": true, "world": true},
	{"items": [36], "shot": 33, "label": "ponyville_row", "anchor": "prop:pv_pink_b", "front": 14.0, "side": 4.0, "zoom": 2.0, "world": true},
	{"items": [37], "shot": 34, "label": "strip", "anchor": "aabb:Strip", "front": 14.0, "zoom": 2.0, "world": true},
	{"items": [41, 68], "shot": 35, "label": "depot_inside", "anchor": ^"Buildings/Depot", "front": 0.3, "world": true},
	{"items": [43], "shot": 37, "label": "palace_plinth", "anchor": ^"Buildings/Palace", "front": 3.5, "side": 4.0, "world": true},
	{"items": [40, 53], "shot": 45, "label": "paddock_trail", "anchor": ^"PenPlots", "front": 8.0, "world": true},
	{"items": [61], "shot": 48, "label": "lake_bank", "anchor": ^"Zones/Lake", "front": 24.0, "world": true},
	{"items": [61], "shot": 49, "label": "lake_close", "anchor": ^"Zones/Lake", "front": 19.0, "side": 4.0, "world": true},
	{"items": [17, 65], "shot": 52, "label": "pens", "anchor": ^"PenPlots", "front": 4.0, "look": 0.0, "zoom": 3.0, "pitch": -35.0, "world": true},
	{"items": [17], "shot": 21, "label": "plaza_palace", "anchor": ^"Buildings/Palace", "front": 22.0, "side": -5.0, "world": false},
]

var out := ""
var item := "all"
var ranch: Node
var shots := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--item="):
			item = a.substr(7)
	if out == "":
		out = ProjectSettings.globalize_path("res://").path_join("../build/ps_evidence/shots")
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	root.get_window().size = Vector2i(1600, 900)
	BootIntentScript.driven = true
	BootIntentScript.request_new_game()
	change_scene_to_file("res://world/ranch.tscn")
	for i in 600:
		await process_frame
		ranch = current_scene
		if ranch != null and ranch.get("people") != null and i > 30:
			break
	await _frames(40)
	var cs: Node = ranch.get("creation_screen")
	if cs != null and bool(cs.call("is_open")):
		cs.call("confirm")
	await _frames(10)
	var lp: Node = ranch.get("letter_panel")
	if lp != null and bool(lp.call("is_open")):
		lp.call("close")
	paused = false
	var hud := ranch.get_node_or_null(^"HUD") as CanvasLayer
	if hud != null:
		hud.visible = false
	var wanted := 0
	for pose: Dictionary in POSES:
		if item != "all" and not (pose.items as Array).has(int(item)):
			continue
		wanted += 1
		var variants := [["day", WorldStateScript.Phase.DAY, WorldStateScript.Weather.CLEAR]]
		if bool(pose.get("world", false)):
			variants.append(["night_rain", WorldStateScript.Phase.NIGHT, WorldStateScript.Weather.RAIN])
			# The same hour without the rain, the yardstick item 40's luminance check reads
			# night-in-rain against (playtest 2026-11-05: "night plus rain is very dark").
			variants.append(["night_clear", WorldStateScript.Phase.NIGHT, WorldStateScript.Weather.CLEAR])
		for v: Array in variants:
			await _take(pose, String(v[0]), int(v[1]), int(v[2]))
	if wanted == 0:
		push_error("no pose for item %s" % item)
		quit(1)
		return
	print("PLAYTEST_SHOTS_OK %d" % shots)
	quit(0)


func _take(pose: Dictionary, variant: String, phase: int, weather: int) -> void:
	var w: Object = ranch.get("_world")
	if w != null:
		w.call("pin", phase, weather)
		var sky: Node = ranch.get("sky_rig")
		if sky != null and sky.has_method("apply_immediately"):
			sky.call("apply_immediately", w)
	var at := Vector3.ZERO
	var fwd := Vector3.ZERO
	var anchor: Variant = pose.anchor
	if anchor is Vector2:
		at = Vector3(anchor.x, 0.0, anchor.y)
	elif anchor is String and anchor == "overgrown":
		for slot: Node in ranch.get_node(^"Plots").get_children():
			if slot.has_method("is_overgrown") and bool(slot.call("is_overgrown")):
				at = (slot as Node3D).global_position
				break
	elif anchor is String and String(anchor).begins_with("aabb:"):
		var box: AABB = Props.world_aabb(ranch.get_node(NodePath(String(anchor).substr(5))) as Node3D)
		at = box.get_center()
		at.y = 0.0
	elif anchor is String and String(anchor).begins_with("prop:"):
		var file := String(anchor).substr(5)
		var props: Node = ranch.get_node(^"Props")
		for p: Node3D in props.call("get_placed"):
			if String(props.call("entry_of", p).get("file", "")).get_basename() == file.get_basename():
				at = p.global_position
				break
	else:
		var n := ranch.get_node_or_null(anchor as NodePath) as Node3D
		if n == null:
			push_error("pose %s: no node %s" % [pose.label, anchor])
			return
		at = n.global_position
		if n is Building:
			fwd = n.global_basis.z
			at += fwd * (float(n.get("depth")) * 0.5)
	fwd.y = 0.0
	if fwd.length() < 0.1:
		fwd = Vector3(-at.x, 0.0, -at.z)
	fwd = fwd.normalized() if fwd.length() > 0.1 else Vector3(0, 0, 1)
	var right := fwd.cross(Vector3.UP).normalized() * -1.0
	var stand := at + fwd * float(pose.get("front", 3.0)) + right * float(pose.get("side", 0.0))
	stand.y = _h(stand.x, stand.z) + 0.1
	var player: CharacterBody3D = ranch.get("player")
	player.global_position = stand
	player.velocity = Vector3.ZERO
	# The lens looks from the player toward the anchor, turned by `look`.
	var to_anchor := at - stand
	var heading := atan2(-to_anchor.x, -to_anchor.z) + deg_to_rad(float(pose.get("look", 0.0)))
	var rig := player.get_node_or_null(^"CameraPivot/CameraRig") as Node3D
	if rig != null and rig.has_method("reset_look"):
		rig.call("reset_look", heading)
		if pose.has("zoom"):
			rig.call("add_zoom_delta", float(pose.zoom))
		if pose.has("pitch"):
			rig.call("add_look_delta", 0.0, deg_to_rad(-float(pose.pitch) - float(rig.call("get_look_pitch_degrees"))))
	var face := heading + PI if bool(pose.get("face_cam", false)) else heading
	player.get("visuals").global_rotation.y = face + PI
	await _frames(45)
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	var name := "item%s_shot%d_%s_%s.png" % [_items_tag(pose), int(pose.shot), pose.label, variant]
	img.save_png(out.path_join(name))
	shots += 1
	print("PLAYTEST_SHOT %s" % name)
	if pose.has("zoom") and rig != null:
		rig.call("add_zoom_delta", -float(pose.zoom))


func _items_tag(pose: Dictionary) -> String:
	return "-".join((pose.items as Array).map(func(i: int) -> String: return str(i)))


func _h(x: float, z: float) -> float:
	return float(ranch.get("terrain").call("height_at", x, z))
