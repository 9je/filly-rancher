extends SceneTree
## P9 item 31, round 3: a pony dropped from beam height lands and her flank jiggles. A wild
## pony near the player is lifted to where the beam holds one (2.4 m up) and let go; a camera
## beside her films the landing, a frame every 2 ticks, and logs the bounce spring.
##   -s res://scenes/test/laneb_w5_drop.gd -- --out=<dir>
const Boot := preload("res://scenes/test/laneb_boot.gd")
var out := ""
var want := "Pony21_stock_curious"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _run() -> void:
	var ranch: Node = await Boot.boot(self)
	var player: Node3D = ranch.get("player")
	var best: Node3D = null
	for n: Node in ranch.find_children("*", "CharacterBody3D", true, false):
		if not (n is Pony) or n.is_in_group(&"penned") or not (n as Node3D).is_visible_in_tree():
			continue
		if n.name == want:
			best = n
			break
		if best == null or (n as Node3D).global_position.distance_to(player.global_position) \
				< best.global_position.distance_to(player.global_position):
			best = n
	var pony := best as Pony
	# The player well away, so she does not shy from her.
	var away := pony.global_position + Vector3(25.0, 0.0, 0.0)
	Boot.stand(ranch, away, pony.global_position)
	print("PONY ", pony.name, " at ", pony.global_position)
	var terrain: Node = ranch.get("terrain")
	var at := pony.global_position
	at.y = float(terrain.call("height_at", at.x, at.z))
	var vp := SubViewport.new()
	vp.size = Vector2i(1200, 900)
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var cam := Camera3D.new()
	cam.fov = 35.0
	vp.add_child(cam)
	cam.current = true
	var rb: Node = pony.find_child("RumpBounce", true, false)
	# Hold her still at beam height, then let go.
	pony.set_physics_process(false)
	pony.global_position = at + Vector3.UP * 2.4
	pony.velocity = Vector3.ZERO
	var vis := pony.get_node(^"Visuals") as Node3D
	var side := vis.global_transform.basis.x
	side.y = 0.0
	side = side.normalized()
	var fwd := -vis.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var rump := at + Vector3.UP * 0.95 - fwd * 0.5
	cam.fov = 24.0
	cam.global_position = rump + side * 3.6 + Vector3.UP * 0.1
	cam.look_at(rump, Vector3.UP)
	for i in 20:
		await process_frame
	pony.set_physics_process(true)
	var peak := 0.0
	var k := 0
	for f in 90:
		await physics_frame
		var amt := float(rb.call("amount")) if rb != null else 0.0
		peak = maxf(peak, absf(amt))
		# The lens rides beside her rump, square to her side, wherever she has got to.
		var f2 := -vis.global_transform.basis.z
		f2.y = 0.0
		f2 = f2.normalized()
		var s2 := side
		var sk := pony.find_child("Skeleton3D", true, false) as Skeleton3D
		var r2 := sk.global_transform * (rb.call("centre") as Vector3)
		cam.global_position = r2 + s2 * 3.6 + Vector3.UP * 0.1
		cam.look_at(r2, Vector3.UP)
		if f >= 47 and f % 2 == 0 and k < 16:
			await RenderingServer.frame_post_draw
			vp.get_texture().get_image().save_png(out.path_join("drop_%02d.png" % k))
			k += 1
		if f % 6 == 0:
			print("F", f, " y=%.2f amount=%.3f" % [pony.global_position.y - at.y, amt])
	print("PEAK %.3f" % peak)
	print("LANEB_DROP_OK")
	quit(0)
