extends SceneTree
## P8 EVIDENCE, item 24 (playtest 2026-11-08: "When catching, ponies sometimes stay on the
## ground; should always be up"). A new game; the nearest wild pony set 3 m ahead; the beam
## held on her with the camera looking as far down as it goes (the aim that ran the hold point
## into the ground), photographed after 1 s and 3 s of holding, plus the gap under her hooves.
##   xvfb-run ... godot --display-driver x11 --path game -s res://scenes/test/beam_low_shot.gd -- --out=/abs/dir
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
	await Boot.frames(self, 30)
	var player: Node3D = ranch.get("player")
	var beam: Node = player.call("get_magic_beam")
	var rig: Node = player.call("get_camera_pivot").get_node("CameraRig")
	var pony: Node3D = null
	var best := INF
	var spawner: Node = ranch.get("spawner")
	for p: Node3D in spawner.call("get_spawned"):
		var d := p.global_position.distance_to(player.global_position)
		if d < best and not p.is_in_group(&"penned"):
			best = d
			pony = p
	var fwd := -player.global_transform.basis.z
	fwd.y = 0.0
	pony.global_position = player.global_position + fwd.normalized() * 3.0
	rig.set("_look_pitch", -60.0)
	await Boot.frames(self, 10)
	beam.call("_begin_hold", pony)
	for i in 60:
		await physics_frame
	var gap := _gap(pony)
	await Boot.shot(self, out, "beam_low_1s")
	for i in 120:
		await physics_frame
	print("GAP 1s=%.2f 3s=%.2f m (min wanted %.2f)" % [gap, _gap(pony), beam.get("HOLD_MIN_LIFT")])
	await Boot.shot(self, out, "beam_low_3s")
	quit(0)


func _gap(pony: Node3D) -> float:
	var at := pony.global_position
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 3.0, at + Vector3.DOWN * 5.0, 1)
	var hit := pony.get_world_3d().direct_space_state.intersect_ray(q)
	return at.y - (hit["position"].y if not hit.is_empty() else 0.0)
