extends SceneTree
## THE HUD IN THE LIVE VALLEY (Fable AAA round 4, the HUD collisions): a new game booted as the
## player boots it (ps_boot.gd), then
##   sign_hud.png    an overgrown plot's price sign at 7 m and eye height, the HUD up
##   sign_clean.png  the same frame with the HUD down: a clean world still for the fast probes
##                   (catch_card_shot --bg), with no crosshair baked into it
##   compass_<deg>.png  the top strip of the screen from the plaza, turned in 30 degree steps,
##                   so every cardinal letter is seen passing every place badge
##   godot --display-driver wayland --path game -s res://scenes/test/hud_world_probe.gd -- --out=/abs/dir
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
	var sign: Node3D = null
	for slot: Node in ranch.get_node(^"Plots").get_children():
		if slot.has_method("is_overgrown") and bool(slot.call("is_overgrown")):
			sign = slot.find_child("Sign", true, false)
			break
	var cam := Camera3D.new()
	cam.fov = 70.0
	ranch.add_child(cam)
	cam.make_current()
	var hud := ranch.get_node_or_null(^"HUD") as CanvasLayer
	if sign != null:
		var board: Node3D = sign.get_node(^"Board")
		var face: Vector3 = board.global_transform.basis.z
		face.y = 0.0
		face = face.normalized()
		PlaceSign.subject = null
		cam.global_position = board.global_position + face * 7.0
		cam.global_position.y = 1.7
		cam.look_at(board.global_position + Vector3(0, -0.3, 0))
		await Boot.frames(self, 12)
		await Boot.shot(self, out, "sign_hud")
		if hud != null:
			hud.visible = false
		await Boot.frames(self, 6)
		await Boot.shot(self, out, "sign_clean")
		if hud != null:
			hud.visible = true
	# The compass from the plaza, turning.
	cam.global_position = Vector3(0.0, 2.0, 0.0)
	for k in 12:
		var yaw := deg_to_rad(float(k) * 30.0)
		cam.global_transform = Transform3D(Basis(Vector3.UP, yaw), cam.global_position)
		await Boot.frames(self, 4)
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		img = img.get_region(Rect2i(400, 0, 800, 120))
		img.save_png(out.path_join("compass_%03d.png" % (k * 30)))
	print("HUD_WORLD_PROBE_OK")
	quit()
