extends SceneTree
## P8 S0: THE OWNER'S SITUATION, NOT A CALM ONE (docs/sprint-retro-2026-11-08.md rule 3; items
## 28, 29, 30, 32). A Grand pen packed with eight, the Mane Six among them; rain, then night;
## the live player walking up to each corner of the pen and jumping there, with the game's own
## camera behind her. Every few frames a still goes on a contact sheet, and the whole run is
## measured: the most any resident tips off upright (28), the worst overlap between two of
## them (29), anyone standing in the air (32), and the player's tail on her landings (30).
## Writes <out>/sheet.png and prints STRESS lines and STRESS_PEN_OK.
##   xvfb-run ... godot --display-driver x11 --path game -s res://scenes/test/stress_pen.gd -- --out=/abs/dir
const Boot := preload("res://scenes/test/ps_boot.gd")
const WorldStateScript := preload("res://systems/world_state.gd")
const PonyInstanceScript := preload("res://systems/pony_instance.gd")
const BodySpaceScript := preload("res://systems/body_space.gd")
const CAST := [&"twilight", &"fluttershy", &"rarity", &"applejack", &"rainbowdash", &"pinkiepie",
	&"derpyhooves", &"applebloom"]
const FRAME_EVERY := 12
const THUMB := Vector2i(320, 180)
var out := ""
var _frames: Array[Image] = []
var _tip := {}
var _worst_overlap := 0.0
var _floating := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _run() -> void:
	var ranch: Node = await Boot.boot(self)
	root.get_window().size = Vector2i(1280, 720)
	await Boot.frames(self, 30)
	ranch.call("get_story").call("set_flag", "has_scoop")
	var w: Object = ranch.get("_world")
	var sky: Node = ranch.get("sky_rig")
	w.call("pin", WorldStateScript.Phase.DAY, WorldStateScript.Weather.RAIN)
	sky.call("apply_immediately", w)
	var plot: PlotData = null
	for p: PlotData in ranch.call("plots_catalogue").all():
		if String(p.id) == "pen_grand":
			plot = p
	var slot: PlotSlot = (ranch.call("plot_slots") as Array)[0]
	if slot.is_empty():
		slot.build(plot)
	var pen := slot.get_built() as Pen
	for id: StringName in CAST:
		if pen.is_full():
			break
		pen.add_pony(PonyInstanceScript.create(id))
	print("STRESS residents=%d" % pen.count())
	await Boot.frames(self, 60)
	var player: Node3D = ranch.get("player")
	var c := slot.global_position
	var corners := [c + Vector3(5.5, 0, 5.5), c + Vector3(-5.5, 0, 5.5), c + Vector3(-5.5, 0, -5.5),
		c + Vector3(5.5, 0, -5.5)]
	var terrain: Node = ranch.get("terrain")
	var f := 0
	for leg in 8:
		if leg == 4:
			w.call("pin", WorldStateScript.Phase.NIGHT, WorldStateScript.Weather.RAIN)
			sky.call("apply_immediately", w)
		var a: Vector3 = corners[leg % 4]
		var b: Vector3 = corners[(leg + 1) % 4]
		# Walk the edge in steps, facing along it, the camera following her as in play.
		for step in 40:
			var p := a.lerp(b, float(step) / 39.0)
			p.y = float(terrain.call("height_at", p.x, p.z)) + 0.05
			player.global_position = p
			var to := (b - a)
			if player.has_method("face"):
				player.call("face", atan2(-to.x, -to.z))
			await physics_frame
			f += 1
			_measure(pen, terrain)
			if f % FRAME_EVERY == 0:
				await _grab()
		# A jump at the corner: the landing is where the tail misbehaved.
		Input.action_press(&"jump")
		await physics_frame
		Input.action_release(&"jump")
		for k in 50:
			await physics_frame
			f += 1
			_measure(pen, terrain)
			if k % 6 == 0:
				await _grab()
	var worst_tip := 0.0
	var who := ""
	for k: String in _tip:
		if float(_tip[k]) > worst_tip:
			worst_tip = float(_tip[k])
			who = k
	print("STRESS tip_max=%.1f deg (%s) overlap_max=%.2f floating_frames=%d frames=%d" % [
		worst_tip, who, _worst_overlap, _floating, _frames.size()])
	_sheet()
	print("STRESS_PEN_OK")
	quit(0)


func _measure(pen: Pen, terrain: Node) -> void:
	var bodies: Array = []
	for inst: PonyInstance in pen.ponies():
		var b := pen.body_for(inst.uid)
		if b == null:
			continue
		bodies.append(b)
		var vis: Node3D = b.get("visuals")
		var up := vis.global_basis.y.normalized() if vis != null else Vector3.UP
		var tilt := rad_to_deg(acos(clampf(up.dot(Vector3.UP), -1.0, 1.0)))
		_tip[String(b.name)] = maxf(float(_tip.get(String(b.name), 0.0)), tilt)
		var ground := float(terrain.call("height_at", b.global_position.x, b.global_position.z))
		if b.global_position.y - ground > 0.6 and int(b.get("state")) != 5:  # 5: HELD
			_floating += 1
	for i in bodies.size():
		for j in range(i + 1, bodies.size()):
			_worst_overlap = maxf(_worst_overlap, BodySpaceScript.overlap(
				BodySpaceScript.footprint_of(bodies[i]), BodySpaceScript.footprint_of(bodies[j])))


func _grab() -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.resize(THUMB.x, THUMB.y)
	_frames.append(img)


func _sheet() -> void:
	var cols := 6
	var rows := int(ceil(_frames.size() / float(cols)))
	var sheet := Image.create(cols * THUMB.x, maxi(1, rows) * THUMB.y, false, Image.FORMAT_RGBA8)
	for i in _frames.size():
		var img := _frames[i]
		img.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, THUMB), Vector2i((i % cols) * THUMB.x, int(i / cols) * THUMB.y))
	sheet.save_png(out.path_join("sheet.png"))
