extends SceneTree
## P9 item 30, round 3: a full pen by day and at night, from the player's camera outside the
## fence, a frame every few seconds; logs each pair of residents closer than a body width and
## any body tipped over.
##   -s res://scenes/test/laneb_w5_pen.gd -- --out=<dir> [--secs=60] [--every=6]
const Boot := preload("res://scenes/test/laneb_boot.gd")
const PonyInstanceScript := preload("res://systems/pony_instance.gd")
var out := ""
var secs := 60.0
var every := 6.0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--secs="):
			secs = float(a.substr(7))
		elif a.begins_with("--every="):
			every = float(a.substr(8))
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _run() -> void:
	var ranch: Node = await Boot.boot(self)
	var pens: Array = Boot.pens(ranch)
	var pen: Pen = pens[0]
	for p: Pen in pens:
		if p.capacity > pen.capacity:
			pen = p
	# THE OWNER'S WAY IN: the pen emptied, then filled from the full Scoop with real E presses
	# at its gate, a few at a time with the pen living in between (as play goes).
	for inst in pen.ponies():
		pen.remove_pony(inst.uid)
	var side: int = posmod(int(round(pen.gate_yaw_degrees / 90.0)), 4)
	var outward := Vector3(cos(float(side) * PI * 0.5), 0.0, sin(float(side) * PI * 0.5))
	var at := pen.global_position + outward * (Pen.HALF_EXTENT + 0.45)
	var terrain: Node = ranch.get("terrain")
	at.y = float(terrain.call("height_at", at.x, at.z)) + 0.2
	await _fill(ranch, pen, at)
	# PLAY CYCLES RESIDENTS: two are delivered (as at the Depot) and two more penned in their
	# place, the way a pen lives through a day.
	var res := pen.ponies()
	for idx in [2, 5]:
		if idx < res.size():
			pen.remove_pony(res[idx].uid)
	for i in 120:
		await process_frame
	await _fill(ranch, pen, at)
	# An overhead view beside the player's (its own viewport on the same world).
	var vp := SubViewport.new()
	vp.size = Vector2i(1600, 900)
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var cam := Camera3D.new()
	cam.fov = 50.0
	vp.add_child(cam)
	cam.current = true
	cam.global_position = pen.global_position + outward * 6.5 + Vector3.UP * 6.0
	cam.look_at(pen.global_position, Vector3.UP)
	for phase in ["day", "night"]:
		if phase == "night":
			ranch.call("rest_till_night")
			for i in 60:
				await process_frame
			print("AFTER REST pen=", pen.count())
			await _fill(ranch, pen, at)
		var t := 0.0
		var n := 0
		while t <= secs:
			Boot.stand(ranch, at, pen.global_position)
			var rig: Node = ranch.get("player").get_node(^"CameraPivot/CameraRig")
			rig.call("add_look_delta", 0.0, -0.35)
			await Boot.shot(self, out.path_join("%s_%02d.png" % [phase, n]), 2)
			vp.get_texture().get_image().save_png(out.path_join("top_%s_%02d.png" % [phase, n]))
			_log(pen, "%s t=%.0f" % [phase, t])
			for i in int(every * 60.0):
				await process_frame
			t += every
			n += 1
	print("LANEB_PEN_OK")
	quit(0)


func _fill(ranch: Node, pen: Pen, at: Vector3) -> void:
	var hud: Node = ranch.get_node("HUD")
	var tries := 0
	while not pen.is_full() and tries < 30:
		Boot.stand(ranch, at, pen.global_position)
		for i in 20:
			await process_frame
		if tries == 0:
			print("PROMPT ", hud.call("prompt_text"))
		await Boot.press(self, &"interact")
		for i in 60 * (1 + tries % 3):
			await process_frame
		tries += 1
	print("PEN ", pen.name, " cap ", pen.capacity, " count ", pen.count(), " presses ", tries)


func _log(pen: Pen, tag: String) -> void:
	var bodies: Array = []
	for inst in pen.ponies():
		var b := pen.body_for(inst.uid)
		if b != null:
			bodies.append(b)
	var close := 0
	var worst := 99.0
	for i in bodies.size():
		var a: Node3D = bodies[i]
		var up := a.global_transform.basis.y.normalized()
		var vis := a.get_node_or_null(^"Visuals") as Node3D
		if vis != null:
			up = vis.global_transform.basis.y.normalized()
		if up.dot(Vector3.UP) < 0.9:
			print(tag, " TIPPED ", a.name, " up=", up)
		for j in range(i + 1, bodies.size()):
			var b: Node3D = bodies[j]
			var d := Vector2(a.global_position.x - b.global_position.x,
				a.global_position.z - b.global_position.z).length()
			worst = minf(worst, d)
			if d < 0.75:
				close += 1
	var shared := 0
	for i in bodies.size():
		for j in range(i + 1, bodies.size()):
			var pa: Vector3 = bodies[i].get("pen_patch")
			var pb: Vector3 = bodies[j].get("pen_patch")
			if pa.distance_to(pb) < 0.1:
				shared += 1
	print(tag, " pairs<0.75m=", close, " closest=%.2f" % worst, " shared_patches=", shared)
