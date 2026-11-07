extends SceneTree
## THE LAKE FROM ITS SHORE (playtest 2026-11-05 item 61): the bank, the player wading, and a
## wild pony sent at the water from the bank, so the shoreline can be looked at from more than
## the owner's two spots (playtest_shots.gd --item=61 takes those). Run inside the invisible
## display:
##
##   xvfb-run ... tools/bin/godot --display-driver x11 --path game \
##     -s res://scenes/test/lake_shots.gd -- --out=/abs/dir
##
## Writes lake_<label>.png and lake_positions.txt (where the pony and the player ended up, metres
## from the lake's middle, against the shore). Prints LAKE_SHOTS_OK <n>.

const BootIntentScript := preload("res://world/boot_intent.gd")
const WorldStateScript := preload("res://systems/world_state.gd")

var out := ""
var ranch: Node
var shots := 0
var notes := PackedStringArray()


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	if out == "":
		out = ProjectSettings.globalize_path("res://").path_join("../build/ps_evidence/item61")
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
	var w: Object = ranch.get("_world")
	if w != null:
		w.call("pin", WorldStateScript.Phase.DAY, WorldStateScript.Weather.CLEAR)
		var sky: Node = ranch.get("sky_rig")
		if sky != null and sky.has_method("apply_immediately"):
			sky.call("apply_immediately", w)

	var terrain: Node = ranch.get("terrain")
	var lake: RegionData = terrain.get("regions").call("by_id", &"lake")
	var c := lake.centre
	var shore: float = terrain.call("shore_radius", lake)
	var level: float = terrain.call("water_level", lake)
	notes.append("shore radius %.2f m, water level %.2f, bank top %.2f" % [shore, level,
		_h(c.x + shore + 4.0, c.y)])

	# A wild pony, sent at the water: her home moved to the lake's middle so every wander she
	# picks is in it. She is stood on the bank first, facing in.
	var pony: CharacterBody3D = null
	var best := INF
	await _frames(30)
	for p: CharacterBody3D in ranch.get("spawner").call("get_spawned"):
		# Not one the herd's turnover is walking off the map (State.LEAVING).
		if not is_instance_valid(p) or int(p.get("state")) == 6:
			continue
		var d := Vector2(p.global_position.x, p.global_position.z).distance_to(c)
		if d < best:
			best = d
			pony = p
	var pony_dir := Vector2(cos(2.4), sin(2.4))
	if is_instance_valid(pony):
		var at := c + pony_dir * (shore + 5.0)
		pony.global_position = Vector3(at.x, _h(at.x, at.y) + 0.2, at.y)
		pony.set("_home", Vector3(c.x, level, c.y))
		pony.set("roam_radius", 4.0)
		notes.append("pony %s from %.1f m" % [pony.name, shore + 5.0])

	# The player, stood in the water and left to settle onto its bed by her own collider.
	var player: CharacterBody3D = ranch.get("player")
	var p_at := c + Vector2(cos(2.75), sin(2.75)) * (shore - 4.5)
	player.global_position = Vector3(p_at.x, _h(p_at.x, p_at.y) + 0.3, p_at.y)
	player.velocity = Vector3.ZERO
	await _frames(20)
	var ps := 0.0
	for t in 40:
		await _frames(30)
		if is_instance_valid(pony):
			var pr := Vector2(pony.global_position.x, pony.global_position.z).distance_to(c)
			ps = maxf(ps, -pr)
			notes.append("t %.1f s pony %.2f m out (shore %.2f), feet at %.2f, water %.2f" % [
				(t + 1) * 0.5, pr, shore, pony.global_position.y, level])
	var plr := Vector2(player.global_position.x, player.global_position.z).distance_to(c)
	notes.append("player %.2f m out, feet at %.2f, water %.2f (%.2f deep)" % [plr,
		player.global_position.y, level, level - player.global_position.y])

	var rig := player.get_node_or_null(^"CameraPivot/CameraRig") as Node3D
	# 1. The player wading, the camera on the bank behind her looking across the water, the
	# pony on the bank to the right.
	await _shot("wading", rig, player, Vector3(c.x, level, c.y), 0.0, -12.0, 0.0)
	# 2. The pony at the water's edge, from the player's side, low.
	if is_instance_valid(pony):
		var pp := pony.global_position
		player.global_position = Vector3(pp.x, 0, pp.z) + Vector3(cos(2.4 + 0.5), 0, sin(2.4 + 0.5)) * 5.0
		player.global_position.y = _h(player.global_position.x, player.global_position.z) + 0.2
		await _frames(10)
		await _shot("pony_at_shore", rig, player, pp, 0.0, -8.0, -1.0)
	# 3. The bank, low along the shore.
	var b_at := c + Vector2(cos(4.0), sin(4.0)) * (shore + 3.0)
	player.global_position = Vector3(b_at.x, _h(b_at.x, b_at.y) + 0.2, b_at.y)
	await _frames(10)
	var along := c + Vector2(cos(4.6), sin(4.6)) * shore
	await _shot("bank_along", rig, player, Vector3(along.x, level, along.y), 0.0, -6.0, 1.0)
	# 4. High over the bank, the whole pond.
	var o_at := c + Vector2(cos(3.3), sin(3.3)) * (lake.radius - 3.0)
	player.global_position = Vector3(o_at.x, _h(o_at.x, o_at.y) + 0.2, o_at.y)
	await _frames(10)
	await _shot("overview", rig, player, Vector3(c.x, level, c.y), 0.0, -32.0, 4.0)
	# 5. The canoe and the jetty (region_dressing.gd: the jetty at 0.6 rad, the canoe beside it),
	# where the batch check saw the biggest black wedge.
	var canoe := c + Vector2(cos(0.95), sin(0.95)) * (shore * 1.08)
	var j_at := c + Vector2(cos(1.35), sin(1.35)) * (shore + 6.0)
	player.global_position = Vector3(j_at.x, _h(j_at.x, j_at.y) + 0.2, j_at.y)
	await _frames(10)
	await _shot("canoe_jetty", rig, player, Vector3(canoe.x, level, canoe.y), 0.0, -14.0, -1.0)

	var f := FileAccess.open(out.path_join("lake_positions.txt"), FileAccess.WRITE)
	f.store_string("\n".join(notes) + "\n")
	f.close()
	print("\n".join(notes))
	print("LAKE_SHOTS_OK %d" % shots)
	quit(0)


## The game's own camera behind the player, looking at `target`, pitched `pitch` degrees.
func _shot(label: String, rig: Node3D, player: CharacterBody3D, target: Vector3, look: float,
		pitch: float, zoom: float) -> void:
	player.velocity = Vector3.ZERO
	var to := target - player.global_position
	var heading := atan2(-to.x, -to.z) + deg_to_rad(look)
	if rig != null and rig.has_method("reset_look"):
		rig.call("reset_look", heading)
		if zoom != 0.0:
			rig.call("add_zoom_delta", zoom)
		rig.call("add_look_delta", 0.0, deg_to_rad(-pitch - float(rig.call("get_look_pitch_degrees"))))
	player.get("visuals").global_rotation.y = heading + PI
	await _frames(45)
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out.path_join("lake_%s.png" % label))
	shots += 1
	print("LAKE_SHOT %s" % label)
	if zoom != 0.0 and rig != null:
		rig.call("add_zoom_delta", -zoom)


func _h(x: float, z: float) -> float:
	return float(ranch.get("terrain").call("height_at", x, z))
