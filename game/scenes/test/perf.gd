extends SceneTree
## THE PERFORMANCE CHECK (tools/perf.sh): a real ranch, rendered (never headless), with the
## herd topped up so `--ponies` of them stand in front of a camera that flies a fixed path.
## Frame times are measured over the path, after a warm-up, and printed:
##
##   PERF ponies=60 frames=1200 avg_ms=7.10 p95_ms=8.40 p99_ms=9.90 max_ms=14.2 worst_1s_fps=118
##   PERF_OK (every frame of the path inside the budget) / PERF_FAILED
##
## Vsync is off so the number is what the frame costs, not what the monitor allows. The budget
## is 16.6 ms at the 99th percentile and for the worst one-second window (a "stable 60").
##
##   tools/bin/godot --path game --audio-driver Dummy -s res://scenes/test/perf.gd -- \
##       [--ponies=60] [--seconds=20] [--quality=2] [--profile]

const RANCH := "res://world/ranch.tscn"
const BootIntentScript := preload("res://world/boot_intent.gd")
const SettingsScript := preload("res://systems/settings.gd")
const PonyScene := preload("res://actors/pony/pony.tscn")
const StockShy := preload("res://data/hidden/stock_shy.tres")
const GeneratorScript := preload("res://systems/pony_generator.gd")
const BUDGET_MS := 16.6

var ponies := 60
var seconds := 20.0
var quality := 2
var profile := false
## Experiments, to find what a frame is spent on: noshadow (ponies cast none), hide (ponies
## invisible), still (pony physics and scripts off), noworld (everything but ponies hidden).
var exp: PackedStringArray = []
var ranch: Node
var _cam: Camera3D
var _centre := Vector3.ZERO


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ponies="):
			ponies = int(a.substr(9))
		elif a.begins_with("--seconds="):
			seconds = float(a.substr(10))
		elif a.begins_with("--quality="):
			quality = int(a.substr(10))
		elif a == "--profile":
			profile = true
		elif a.begins_with("--exp="):
			exp = a.substr(6).split(",")
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("PERF_FAILED the perf check needs a real renderer")
		quit(2)
		return
	BootIntentScript.driven = true
	BootIntentScript.request_new_game()
	change_scene_to_file(RANCH)
	for i in 600:
		await process_frame
		ranch = current_scene
		if ranch != null and ranch.get("people") != null and i > 20:
			break
	# A fresh save opens on the creator and the welcome letter: take the default pony.
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
	root.get_window().size = Vector2i(1920, 1080)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var s := SettingsScript.new()
	s.quality = quality
	s.vsync = false
	s.apply_graphics(root.get_viewport())
	var hud := ranch.get_node_or_null(^"HUD") as CanvasLayer
	var player: Node3D = ranch.get("player")
	_centre = player.global_position + Vector3(0, 0, -10)
	var added := _top_up()
	_cam = Camera3D.new()
	_cam.fov = 60
	ranch.add_child(_cam)
	_cam.make_current()
	_place(0.0)
	_experiments()
	if "timing" in exp:
		await _timing()
	if "proc" in exp:
		await _proc_timing()
	if "phys" in exp:
		await _phys_timing()
	# Warm-up: shaders compile, the herd settles.
	for i in 180:
		await process_frame
	var times: PackedFloat64Array = []
	var t := 0.0
	var last := Time.get_ticks_usec()
	var vp_rid := root.get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp_rid, true)
	var r_cpu := 0.0
	var r_gpu := 0.0
	var proc := 0.0
	var phys := 0.0
	while t < seconds:
		await process_frame
		var now := Time.get_ticks_usec()
		var ms := (now - last) / 1000.0
		last = now
		times.append(ms)
		t += ms / 1000.0
		_place(t / seconds)
		r_cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp_rid) + RenderingServer.get_frame_setup_time_cpu()
		r_gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp_rid)
		proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	if "spikes" in exp:
		var line := ""
		var acc := 0.0
		for i in times.size():
			acc += times[i]
			if times[i] > 20.0:
				line += "%.2fs:%.0f " % [acc / 1000.0, times[i]]
		print("PERF_SPIKES ", line)
	var nf := float(maxi(1, times.size()))
	print("PERF_SPLIT render_cpu_ms=%.2f render_gpu_ms=%.2f process_ms=%.2f physics_ms=%.2f" % [
		r_cpu / nf, r_gpu / nf, proc / nf, phys / nf])
	_report(times, added, hud != null and hud.visible)
	quit(0)


## Top the herd up so `ponies` stand within the camera's ring (generated Drifters, physics on,
## wandering like any other).
func _top_up() -> int:
	var near := 0
	for n in ranch.find_children("*", "CharacterBody3D", true, false):
		if (n as Node3D).global_position.distance_to(_centre) < 26.0 and n.has_method("set_stock"):
			near += 1
	var terrain: Node = ranch.get("terrain")
	var added := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 60
	while near + added < ponies:
		var p: CharacterBody3D = PonyScene.instantiate()
		ranch.add_child(p)
		p.set_stock(GeneratorScript.generate(4000 + added * 17).to_dict())
		p.setup(StockShy)
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 20.0
		var x := _centre.x + cos(a) * r
		var z := _centre.z + sin(a) * r
		var y := float(terrain.call("height_at", x, z)) if terrain != null and terrain.has_method("height_at") else _centre.y
		p.global_position = Vector3(x, y + 0.3, z)
		p.rotation.y = rng.randf() * TAU
		added += 1
	return added


## Time one physics tick's pieces per pony, by hand: the whole _physics_process, then
## move_and_slide alone, then the animation update alone.
func _timing() -> void:
	var bodies: Array = []
	for b in ranch.find_children("*", "CharacterBody3D", true, false):
		if b.has_method("set_stock"):
			bodies.append(b)
			b.set_physics_process(false)
	var full := 0
	var slide := 0
	var anim := 0
	var frames := 120
	for f in frames:
		await physics_frame
		for b in bodies:
			var t0 := Time.get_ticks_usec()
			b._physics_process(1.0 / 60.0)
			var t1 := Time.get_ticks_usec()
			b.move_and_slide()
			var t2 := Time.get_ticks_usec()
			b._update_animation(b.get_ground_speed())
			var t3 := Time.get_ticks_usec()
			full += t1 - t0
			slide += t2 - t1
			anim += t3 - t2
	var k := float(frames * bodies.size())
	print("PERF_TIMING bodies=%d per_pony_us full=%.1f slide=%.1f anim=%.1f per_tick_ms full=%.2f" % [
		bodies.size(), full / k, slide / k, anim / k, full / float(frames) / 1000.0])
	for b in bodies:
		b.set_physics_process(true)


## Which scripts the idle frame is spent in: every processing node's _process, timed by
## hand for 120 frames and summed by script.
func _proc_timing() -> void:
	var nodes: Array = []
	for n in root.find_children("*", "", true, false):
		if n.is_processing() and n.get_script() != null and n.has_method("_process"):
			nodes.append(n)
	for n in nodes:
		n.set_process(false)
	var by: Dictionary = {}
	var count: Dictionary = {}
	for f in 120:
		await process_frame
		var dt := root.get_process_delta_time()
		for n in nodes:
			if not is_instance_valid(n):
				continue
			var t0 := Time.get_ticks_usec()
			n._process(dt)
			var k := (n.get_script() as Script).resource_path.get_file()
			by[k] = int(by.get(k, 0)) + Time.get_ticks_usec() - t0
			count[k] = int(count.get(k, 0)) + 1
	var keys := by.keys()
	keys.sort_custom(func(a, b) -> bool: return by[a] > by[b])
	for k in keys.slice(0, 14):
		print("PERF_PROC %-28s %7.2f ms/frame  nodes=%d" % [k, by[k] / 120000.0, count[k] / 120])
	for n in nodes:
		if is_instance_valid(n):
			n.set_process(true)


## Which scripts the physics ticks are spent in, the same way as _proc_timing().
func _phys_timing() -> void:
	var nodes: Array = []
	for n in root.find_children("*", "", true, false):
		if n.is_physics_processing() and n.get_script() != null and n.has_method("_physics_process"):
			nodes.append(n)
	for n in nodes:
		n.set_physics_process(false)
	var by: Dictionary = {}
	var count: Dictionary = {}
	for f in 120:
		await physics_frame
		for n in nodes:
			if not is_instance_valid(n):
				continue
			var t0 := Time.get_ticks_usec()
			n._physics_process(1.0 / 60.0)
			var k := (n.get_script() as Script).resource_path.get_file()
			by[k] = int(by.get(k, 0)) + Time.get_ticks_usec() - t0
			count[k] = int(count.get(k, 0)) + 1
	var keys := by.keys()
	keys.sort_custom(func(a, b) -> bool: return by[a] > by[b])
	for k in keys.slice(0, 14):
		print("PERF_PHYS %-28s %7.2f ms/tick  nodes=%d" % [k, by[k] / 120000.0, count[k] / 120])
	for n in nodes:
		if is_instance_valid(n):
			n.set_physics_process(true)


func _experiments() -> void:
	for b in ranch.find_children("*", "CharacterBody3D", true, false):
		if not b.has_method("set_stock"):
			continue
		if "hide" in exp:
			(b as Node3D).visible = false
		if "still" in exp:
			b.process_mode = Node.PROCESS_MODE_DISABLED
		if "nospring" in exp:
			for m in b.find_children("*", "SpringBoneSimulator3D", true, false):
				(m as SkeletonModifier3D).active = false
		if "nopbs" in exp:
			for m in b.find_children("*", "PhysicalBoneSimulator3D", true, false):
				m.queue_free()
		if "noanim" in exp:
			for m in b.find_children("*", "AnimationPlayer", true, false):
				m.process_mode = Node.PROCESS_MODE_DISABLED
		if "nodetect" in exp:
			for m in b.find_children("*", "Area3D", true, false):
				(m as Area3D).monitoring = false
		if "nophys" in exp:
			b.set_physics_process(false)
		if "noshadow" in exp:
			for m in b.find_children("*", "GeometryInstance3D", true, false):
				(m as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if "nodress" in exp:
		var d := ranch.get_node_or_null(^"Regions/Dressing") as Node3D
		if d != null:
			d.visible = false
	if "nohud" in exp:
		for c in ranch.get_children():
			if c is CanvasLayer:
				(c as CanvasLayer).visible = false
				c.process_mode = Node.PROCESS_MODE_DISABLED
	if "nonpc" in exp:
		var people: Node = ranch.get("people")
		if people != null:
			people.process_mode = Node.PROCESS_MODE_DISABLED
			for n in people.find_children("*", "Node3D", false, false):
				(n as Node3D).visible = false
	if "noallanim" in exp:
		for m in root.find_children("*", "AnimationPlayer", true, false):
			m.process_mode = Node.PROCESS_MODE_DISABLED
		for m in root.find_children("*", "SkeletonModifier3D", true, false):
			(m as SkeletonModifier3D).active = false
	if "npcmods" in exp or "npchide" in exp or "npcproc" in exp:
		var people: Node = ranch.get("people")
		for id in people.get("npcs"):
			var n: Node3D = people.get("npcs")[id]
			if "npcmods" in exp:
				for m in n.find_children("*", "SkeletonModifier3D", true, false):
					(m as SkeletonModifier3D).active = false
			if "npchide" in exp:
				n.visible = false
			if "npcproc" in exp:
				n.process_mode = Node.PROCESS_MODE_DISABLED
	if "npcstat" in exp:
		var people: Node = ranch.get("people")
		for id in people.get("npcs"):
			var n: Node3D = people.get("npcs")[id]
			var tris := 0
			var meshes := 0
			for m in n.find_children("*", "MeshInstance3D", true, false):
				var mi := m as MeshInstance3D
				if mi.mesh == null or not mi.is_visible_in_tree():
					continue
				meshes += 1
				for k in mi.mesh.get_surface_count():
					var arr := mi.mesh.surface_get_arrays(k)
					var idx = arr[Mesh.ARRAY_INDEX]
					tris += (idx.size() if idx != null else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
			print("PERF_NPC %s tris=%d meshes=%d skel=%d mods=%d anims=%d nodes=%d" % [id, tris, meshes,
				n.find_children("*", "Skeleton3D", true, false).size(),
				n.find_children("*", "SkeletonModifier3D", true, false).size(),
				n.find_children("*", "AnimationPlayer", true, false).size(),
				n.find_children("*", "", true, false).size()])
	if "nosun" in exp:
		for l in ranch.find_children("*", "DirectionalLight3D", true, false):
			(l as DirectionalLight3D).shadow_enabled = false


## The path: once around the herd, high then low, always looking into it.
func _place(f: float) -> void:
	var a := f * TAU
	var h := lerpf(14.0, 5.0, 0.5 + 0.5 * sin(a * 2.0))
	_cam.global_position = _centre + Vector3(cos(a) * 24.0, h, sin(a) * 24.0)
	_cam.look_at(_centre + Vector3(0, 1.0, 0))


func _report(times: PackedFloat64Array, added: int, hud_on: bool) -> void:
	var sorted := times.duplicate()
	sorted.sort()
	var n := sorted.size()
	var total := 0.0
	for v in times:
		total += v
	var avg := total / maxf(1.0, n)
	var p95 := sorted[int(n * 0.95)] if n > 0 else 0.0
	var p99 := sorted[int(n * 0.99)] if n > 0 else 0.0
	var mx := sorted[n - 1] if n > 0 else 0.0
	# The worst whole second of the path, as frames per second.
	var worst_fps := 1e9
	var acc := 0.0
	var frames := 0
	for v in times:
		acc += v
		frames += 1
		if acc >= 1000.0:
			worst_fps = minf(worst_fps, frames * 1000.0 / acc)
			acc = 0.0
			frames = 0
	var near := 0
	for b in ranch.find_children("*", "CharacterBody3D", true, false):
		if (b as Node3D).global_position.distance_to(_centre) < 26.0 and b.has_method("set_stock"):
			near += 1
	print("PERF ponies=%d added=%d frames=%d avg_ms=%.2f p95_ms=%.2f p99_ms=%.2f max_ms=%.1f worst_1s_fps=%.0f quality=%d hud=%s draw_calls=%d prims=%d" % [
		near, added, n, avg, p95, p99, mx, worst_fps, quality, hud_on,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
	if profile:
		print("PERF_MONITORS process_ms=%.2f physics_ms=%.2f nodes=%d objects=%d" % [
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
			Performance.get_monitor(Performance.OBJECT_COUNT)])
	if p99 <= BUDGET_MS and worst_fps >= 60.0:
		print("PERF_OK")
	else:
		print("PERF_FAILED p99 %.2f ms (budget %.1f), worst second %.0f fps" % [p99, BUDGET_MS, worst_fps])
