extends SceneTree
## PS EVIDENCE, item 21 (playtest 2026-11-05: "Dropping a pony from the beam at height should
## trigger the rump bounce"). In the ranch, a wild pony near the player is lifted 4 m over the
## grass (where the beam holds one up; the probe stands in for the beam's hold) and let go.
## A side lens on her hindquarters; a frame every second physics tick from just before she
## lands; per tick her height over the ground, her fall speed and RumpBounce.amount() printed.
##   xvfb-run ... godot --display-driver x11 --path game -s res://scenes/test/ps_bounce_shot.gd -- --out=/abs/dir
const Boot := preload("res://scenes/test/ps_boot.gd")
var out := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _run() -> void:
	var ranch: Node = await Boot.boot(self)
	await Boot.talk_through(self, ranch)
	var player: Node3D = ranch.get("player")
	var spawner: Node = ranch.get("spawner")
	var pony: CharacterBody3D = null
	var best := INF
	for p: Node3D in spawner.call("get_spawned"):
		var d := p.global_position.distance_to(player.global_position)
		if d < best and not p.is_in_group(&"penned"):
			best = d
			pony = p as CharacterBody3D
	var terrain: Node = ranch.get("terrain")
	# Open grass beside the player, the pony 4 m up over it, the player 5 m off watching.
	var spot := player.global_position + Vector3(5.0, 0, 0)
	var ground := float(terrain.call("height_at", spot.x, spot.z))
	pony.global_position = Vector3(spot.x, ground + 4.0, spot.z)
	pony.velocity = Vector3.ZERO
	print("ITEM21 pony ", (pony.call("get_data") as PonyData).display_name, " let go 4.0 m over the grass at ", pony.global_position)
	var bounce: Node = pony.find_children("RumpBounce", "", true, false)[0]
	var cam := Camera3D.new()
	cam.fov = 45.0
	ranch.add_child(cam)
	# Side on to her, from the far side from the player (nobody between), 5.5 m off.
	var away := Vector3(spot.x - player.global_position.x, 0, spot.z - player.global_position.z).normalized()
	var across := away.cross(Vector3.UP).normalized()
	cam.global_position = Vector3(spot.x, ground + 1.3, spot.z) + away * 4.0 + across * 3.5
	cam.look_at(Vector3(spot.x, ground + 0.8, spot.z))
	cam.make_current()
	var landed := -1
	var shots := 0
	var peak := 0.0
	var airborne := false
	var t0 := Engine.get_physics_frames()
	# A drawn frame at a time (RumpBounce steps in _process): from 0.9 m up every frame is
	# photographed, until 1.5 s after she lands.
	for i in 2000:
		await process_frame
		var f := int(Engine.get_physics_frames() - t0)
		var h := pony.global_position.y - float(terrain.call("height_at", pony.global_position.x, pony.global_position.z))
		var a := float(bounce.call("amount"))
		peak = maxf(peak, absf(a))
		if not pony.is_on_floor():
			airborne = true
		if airborne and landed < 0 and pony.is_on_floor():
			landed = f
			print("ITEM21 LANDED at physics tick %d" % f)
		var rel := f - (landed if landed >= 0 else 999999)
		var near := h < 0.9 and landed < 0
		if near or (rel >= 0 and rel <= 90):
			print("ITEM21 tick %3d: height %.2f m, vy %+.2f m/s, on floor %s, RumpBounce %+.3f" % [f, h, pony.velocity.y, pony.is_on_floor(), a])
			await Boot.shot(self, out, "item21_t%03d_amt%+.3f" % [f, a])
			shots += 1
		elif i % 10 == 0:
			print("ITEM21 tick %3d: height %.2f m, vy %+.2f m/s, RumpBounce %+.3f" % [f, h, pony.velocity.y, a])
		if rel > 90:
			break
	print("ITEM21 peak |RumpBounce| %.3f, frames %d" % [peak, shots])
	print("PS_BOUNCE_SHOT_OK")
	quit(0)
