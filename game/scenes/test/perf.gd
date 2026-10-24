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
const LayersScript := preload("res://world/collision_layers.gd")
const PropsScript := preload("res://world/props.gd")
const BUDGET_MS := 16.6

var ponies := 60
var seconds := 20.0
var quality := 2
var profile := false
## Experiments, to find what a frame is spent on: noshadow (ponies cast none), hide (ponies
## invisible), still (pony physics and scripts off), noworld (everything but ponies hidden).
## Added 2026-10-24: ticks (frame times split by physics ticks in the frame), steptime and
## frametime (probes round the physics tick and the idle pass), groups (draws per ranch
## group), casters / regionlist / parts / nodes / lights / subvp / shapes / census / herd
## (what is in the scene), slideab (move_and_slide settings, A/B in one run), freeze and
## latephys (herd standing / herd ticks off once settled), shadowdist=N, shot:/abs/prefix.
##
## WHICH THREAD IS BUSY: Godot runs the render thread as WorkerThread 0. Sample it from /proc
## (utime+stime per task) during a run; at 60 ponies it was the one near 100%, not the main.
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
	var spawner: Node = ranch.get("spawner")
	if spawner != null:
		spawner.set("restock", false)
	# The wild herd lands over the first frames: let it, then make the ring exactly `ponies`.
	for i in 120:
		await process_frame
	var added := _top_up()
	print("PERF_HERD topup added=%d" % added)
	_cam = Camera3D.new()
	_cam.fov = 60
	ranch.add_child(_cam)
	_cam.make_current()
	_place(0.0)
	await _experiments()
	if "timing" in exp:
		await _timing()
	if "frametime" in exp:
		var first := Node.new()
		first.set_script(load("res://scenes/test/perf_probe2.gd"))
		first.process_priority = -100000
		var last := Node.new()
		last.set_script(load("res://scenes/test/perf_probe2.gd"))
		last.set("role", 1)
		last.process_priority = 100000
		first.set("other", last)
		last.set("other", first)
		root.add_child(first)
		root.add_child(last)
		for i in 300:
			await process_frame
		var fr := maxi(1, int(first.get("frames")))
		print("PERF_FRAME idle_pass_ms=%.2f rest_ms=%.2f frames=%d" % [
			int(last.get("proc_us")) / 1000.0 / fr, int(first.get("rest_us")) / 1000.0 / fr, fr])
		first.queue_free()
		last.queue_free()
	if "groups" in exp:
		await _groups()
	if "steptime" in exp:
		await _step_time()
	if "slideab" in exp:
		await _slide_ab()
	if "proc" in exp:
		await _proc_timing()
	if "phys" in exp:
		await _phys_timing()
	# Warm-up: shaders compile, the herd settles.
	for i in 180:
		await process_frame
	for a in exp:
		if a.begins_with("shot:"):
			# Two still frames of the path (start and a third in), for comparing settings.
			for k in 2:
				_place(k * 0.33)
				for i in 8:
					await process_frame
				await RenderingServer.frame_post_draw
				root.get_viewport().get_texture().get_image().save_png(a.substr(5) + "_%d.png" % k)
	if "latephys" in exp:
		for b in ranch.find_children("*", "CharacterBody3D", true, false):
			if b.has_method("set_stock"):
				b.set_physics_process(false)
	var times: PackedFloat64Array = []
	var t := 0.0
	var last := Time.get_ticks_usec()
	var vp_rid := root.get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp_rid, true)
	var r_cpu := 0.0
	var r_gpu := 0.0
	var proc := 0.0
	var phys := 0.0
	var ticks_now := [0]
	var tick_cb := func() -> void: ticks_now[0] += 1
	physics_frame.connect(tick_cb)
	var by_ticks := {}
	while t < seconds:
		await process_frame
		var now := Time.get_ticks_usec()
		var ms := (now - last) / 1000.0
		last = now
		times.append(ms)
		if "ticks" in exp:
			var k: int = ticks_now[0]
			if not by_ticks.has(k):
				by_ticks[k] = []
			(by_ticks[k] as Array).append(ms)
		ticks_now[0] = 0
		t += ms / 1000.0
		_place(t / seconds)
		if "herd" in exp and times.size() % 240 == 0:
			var n_all := 0
			var n_near := 0
			for b in ranch.find_children("*", "CharacterBody3D", true, false):
				if b.has_method("set_stock"):
					n_all += 1
					if (b as Node3D).global_position.distance_to(_centre) < 26.0:
						n_near += 1
			var tiers := [0, 0, 0]
			var inst := [0, 0, 0]
			for b in ranch.find_children("*", "CharacterBody3D", true, false):
				if b.has_method("set_stock") and (b as Node3D).global_position.distance_to(_centre) < 26.0:
					var d := int(b.get("detail"))
					tiers[d] += 1
					for m in b.find_children("*", "MeshInstance3D", true, false):
						if (m as MeshInstance3D).is_visible_in_tree():
							inst[d] += 1
			var states := {}
			for b in ranch.find_children("*", "CharacterBody3D", true, false):
				if b.has_method("set_stock") and (b as Node3D).global_position.distance_to(_centre) < 26.0:
					var st := int(b.get("state"))
					states[st] = int(states.get(st, 0)) + 1
			print("PERF_HERD t=%.1f all=%d near=%d tiers(full,mid,far)=%s visible_meshes=%s states=%s" % [t, n_all, n_near, tiers, inst, states])
			if times.size() == 240:
				var by := {}
				for b in ranch.find_children("*", "CharacterBody3D", true, false):
					if b.has_method("set_stock") and (b as Node3D).global_position.distance_to(_centre) < 26.0:
						var k := "%s/%s" % [b.get_parent().name, String(b.name).left(6)]
						by[k] = int(by.get(k, 0)) + 1
				print("PERF_HERD who ", by)
		# These are SYNCHRONOUS RenderingServer calls: each one waits for the render thread to
		# drain, so asking every frame serialises the two threads the game runs in parallel.
		# Sampled once a second, the split still reads and the frame times stay the game's.
		if times.size() % 60 == 0:
			r_cpu += (RenderingServer.viewport_get_measured_render_time_cpu(vp_rid) + RenderingServer.get_frame_setup_time_cpu()) * 60.0
			r_gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp_rid) * 60.0
		proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	physics_frame.disconnect(tick_cb)
	for k in by_ticks:
		var arr: Array = (by_ticks[k] as Array).duplicate()
		arr.sort()
		var slow := 0
		for v in arr:
			if v > 16.6:
				slow += 1
		print("PERF_TICKS ticks_in_frame=%d frames=%d median_ms=%.2f p99_ms=%.2f over_budget=%d" % [
			k, arr.size(), arr[arr.size() / 2], arr[mini(arr.size() - 1, int(arr.size() * 0.99))], slow])
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
	var ring: Array = []
	for n in ranch.find_children("*", "CharacterBody3D", true, false):
		if (n as Node3D).global_position.distance_to(_centre) < 26.0 and n.has_method("set_stock"):
			ring.append(n)
	# More than asked for already standing there: the farthest go, so the ring holds `ponies`.
	ring.sort_custom(func(a, b) -> bool:
		return (a as Node3D).global_position.distance_to(_centre) < (b as Node3D).global_position.distance_to(_centre))
	for i in range(ponies, ring.size()):
		(ring[i] as Node).queue_free()
	near = mini(ring.size(), ponies)
	var terrain: Node = ranch.get("terrain")
	var added := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 60
	# On open ground, as the spawner stands a Drifter: never inside the coop or a barn wall,
	# where she would grind the slide solver every tick in a way no real herd does.
	var blocked: Array[AABB] = []
	for group in [^"Props", ^"Buildings"]:
		var g := ranch.get_node_or_null(group)
		if g != null:
			for c in g.get_children():
				if c is Node3D:
					blocked.append(PropsScript.world_aabb(c).grow(0.8))
	while near + added < ponies:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 20.0
		var x := _centre.x + cos(a) * r
		var z := _centre.z + sin(a) * r
		var inside := false
		for box in blocked:
			if x > box.position.x and x < box.end.x and z > box.position.z and z < box.end.z:
				inside = true
				break
		if inside:
			continue
		var p: CharacterBody3D = PonyScene.instantiate()
		# Layered the way spawner.gd layers a real Drifter. Left on the scene's default layer 1,
		# her 14 m detection sphere pairs with the ground, every prop and every other pony
		# (5019 broadphase pairs for this herd) and the check measures a herd the game never has.
		p.collision_layer = LayersScript.PONY
		p.collision_mask = LayersScript.PONY_WALKABLE
		var det := p.get_node(^"DetectionArea") as Area3D
		det.collision_layer = LayersScript.INTERACTION
		det.collision_mask = LayersScript.PLAYER
		ranch.add_child(p)
		p.set_stock(GeneratorScript.generate(4000 + added * 17).to_dict())
		p.setup(StockShy)
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
	var per := {}
	var hits := {}
	for f in 60:
		await physics_frame
		for b in bodies:
			b._physics_process(1.0 / 60.0)
			var t1 := Time.get_ticks_usec()
			b.move_and_slide()
			per[b] = int(per.get(b, 0)) + Time.get_ticks_usec() - t1
			for c in b.get_slide_collision_count():
				var col := b.get_slide_collision(c).get_collider() as Node
				if col != null:
					var nm := String(col.get_parent().name) if col.get_parent() != null else String(col.name)
					if not hits.has(b):
						hits[b] = {}
					hits[b][nm] = true
	var order := per.keys()
	order.sort_custom(func(a, b) -> bool: return per[a] > per[b])
	for b in order.slice(0, 12):
		print("PERF_SLIDE %6.1f us %s hits=%s" % [per[b] / 60.0, b.name, (hits.get(b, {}) as Dictionary).keys()])
	var k := float(frames * bodies.size())
	print("PERF_TIMING bodies=%d per_pony_us full=%.1f slide=%.1f anim=%.1f per_tick_ms full=%.2f" % [
		bodies.size(), full / k, slide / k, anim / k, full / float(frames) / 1000.0])
	for b in bodies:
		b.set_physics_process(true)


## What each of the ranch's top-level groups costs: hidden in turn for 90 frames each, the
## camera held still, against the frame with everything shown.
func _groups() -> void:
	for i in 60:
		await process_frame
	var measure := func() -> Array:
		var t0 := Time.get_ticks_usec()
		for i in 90:
			await process_frame
		return [(Time.get_ticks_usec() - t0) / 90000.0,
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)]
	var base: Array = await measure.call()
	print("PERF_GROUP %-22s ms=%.2f draws=%d" % ["(all shown)", base[0], base[1]])
	for c in ranch.get_children():
		if not (c is Node3D) or not (c as Node3D).visible:
			continue
		var n3 := c as Node3D
		n3.visible = false
		var r: Array = await measure.call()
		n3.visible = true
		if absf(r[0] - base[0]) > 0.3 or absi(int(r[1]) - int(base[1])) > 40:
			print("PERF_GROUP %-22s ms=%.2f draws=%d (saves %.2f ms, %d draws)" % [c.name, r[0], r[1], base[0] - r[0], int(base[1]) - int(r[1])])


## Scripts' physics tick against the physics server's step, timed by two probe nodes.
func _step_time() -> void:
	var last := Node.new()
	last.set_script(load("res://scenes/test/perf_probe.gd"))
	last.process_physics_priority = 100000
	last.process_priority = -100000
	root.add_child(last)
	var t0 := Time.get_ticks_usec()
	var cb := func() -> void: last.set("t_start", Time.get_ticks_usec())
	physics_frame.connect(cb)
	last.set("phase", 1)
	# Scripts first (one physics probe), then the step: the probe's _process only counts the
	# step on a frame whose tick it saw, and only the LAST tick of a frame is followed by it.
	for i in 300:
		await process_frame
		last.set("phase", 2 if i > 0 else 1)
	physics_frame.disconnect(cb)
	var ticks := int(last.get("ticks"))
	var fr := int(last.get("frames_with_tick"))
	print("PERF_STEP ticks=%d scripts_ms_per_tick=%.2f step_ms_per_frame_with_tick=%.2f wall_s=%.1f" % [
		ticks, int(last.get("scripts_us")) / 1000.0 / maxi(1, ticks),
		int(last.get("step_us")) / 1000.0 / maxi(1, fr), (Time.get_ticks_usec() - t0) / 1e6])
	last.queue_free()


## The cost of one move_and_slide under each body setting, measured in this same run (so
## run-to-run noise does not swamp it): each pony slides with her current velocity.
func _slide_ab() -> void:
	var bodies: Array = []
	for b in ranch.find_children("*", "CharacterBody3D", true, false):
		if b.has_method("set_stock"):
			bodies.append(b)
			b.set_physics_process(false)
	for f in 30:
		await physics_frame
	var variants := ["base", "terrain_only", "no_ponies", "no_props", "base"]
	var terrain: Node = ranch.get("terrain")
	var tcol := terrain.get_node(^"CollisionShape3D") as CollisionShape3D
	for v in variants:
		if v.begins_with("hmap") and not (tcol.shape is HeightMapShape3D):
			var n := 111
			var hm := HeightMapShape3D.new()
			hm.map_width = n
			hm.map_depth = n
			var data := PackedFloat32Array()
			data.resize(n * n)
			for iz in n:
				for ix in n:
					data[iz * n + ix] = float(terrain.call("height_at", -110.0 + ix * 2.0, -110.0 + iz * 2.0)) * 0.5
			hm.map_data = data
			tcol.shape = hm
			tcol.scale = Vector3(2, 2, 2)
			for f in 3:
				await physics_frame
		for b: CharacterBody3D in bodies:
			b.collision_mask = LayersScript.PONY_WALKABLE
			b.max_slides = 6
			b.floor_snap_length = 0.1
			match v:
				"terrain_only", "hmap_terrain_only": b.collision_mask = LayersScript.TERRAIN
				"no_ponies": b.collision_mask = LayersScript.PONY_WALKABLE & ~LayersScript.PONY
				"slides2": b.max_slides = 2
				"no_props": b.collision_mask = LayersScript.PONY_WALKABLE & ~LayersScript.PROPS
				"nosnap": b.floor_snap_length = 0.0
		var us := 0
		for f in 40:
			await physics_frame
			for b: CharacterBody3D in bodies:
				var keep := b.global_transform
				var vel := b.velocity
				b.velocity = Vector3(1.5, -0.5, 0.8)
				var t0 := Time.get_ticks_usec()
				b.move_and_slide()
				us += Time.get_ticks_usec() - t0
				b.global_transform = keep
				b.velocity = vel
		print("PERF_SLIDEAB %-14s %.1f us/slide" % [v, us / float(40 * bodies.size())])
	for b: CharacterBody3D in bodies:
		b.collision_mask = LayersScript.PONY_WALKABLE
		b.floor_snap_length = 0.1
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
	if "nopp" in exp:
		for b in ranch.find_children("*", "CharacterBody3D", true, false):
			if b.has_method("set_stock"):
				(b as CharacterBody3D).collision_mask &= ~(1 << 3)
	if "hmap" in exp:
		var terrain: Node = ranch.get("terrain")
		var col := terrain.get_node(^"CollisionShape3D") as CollisionShape3D
		var n := 111
		var hm := HeightMapShape3D.new()
		hm.map_width = n
		hm.map_depth = n
		var data := PackedFloat32Array()
		data.resize(n * n)
		for iz in n:
			for ix in n:
				data[iz * n + ix] = float(terrain.call("height_at", -110.0 + ix * 2.0, -110.0 + iz * 2.0)) * 0.5
		hm.map_data = data
		col.shape = hm
		col.scale = Vector3(2, 2, 2)
	if "census" in exp:
		var kinds := {}
		for n in root.find_children("*", "CollisionObject3D", true, false):
			var k := n.get_class()
			if n is Area3D and (n as Area3D).monitoring:
				k += "(monitoring)"
			if n is RigidBody3D and (n as RigidBody3D).sleeping:
				k += "(asleep)"
			kinds[k] = int(kinds.get(k, 0)) + 1
		print("PERF_CENSUS ", kinds)
		await physics_frame
		await physics_frame
		print("PERF_CENSUS active=%d pairs=%d islands=%d" % [
			PhysicsServer3D.get_process_info(PhysicsServer3D.INFO_ACTIVE_OBJECTS),
			PhysicsServer3D.get_process_info(PhysicsServer3D.INFO_COLLISION_PAIRS),
			PhysicsServer3D.get_process_info(PhysicsServer3D.INFO_ISLAND_COUNT)])
	if "parts" in exp:
		var shown := 0
		for b in ranch.find_children("*", "CharacterBody3D", true, false):
			if not b.has_method("set_stock") or shown >= 2:
				continue
			shown += 1
			var line := ""
			var draws := 0
			for m in b.find_children("*", "MeshInstance3D", true, false):
				var mi := m as MeshInstance3D
				if mi.mesh == null or not mi.is_visible_in_tree():
					continue
				var sc := mi.mesh.get_surface_count()
				var np := 0
				for k in sc:
					var mat := mi.get_active_material(k)
					draws += 1
					if mat != null and mat.next_pass != null:
						np += 1
						draws += 1
				line += "%s[%d s,%d np,%s] " % [mi.name, sc, np, "sh" if mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF else "-"]
			print("PERF_PARTS draws=%d detail=%d %s" % [draws, int(b.get("detail")), line])
	if "nodes" in exp:
		var done := 0
		for b in ranch.find_children("*", "CharacterBody3D", true, false):
			if not b.has_method("set_stock") or done >= 2:
				continue
			done += 1
			var kinds := {}
			for n in b.find_children("*", "", true, false):
				kinds[n.get_class()] = int(kinds.get(n.get_class(), 0)) + 1
			var bones := 0
			for sk in b.find_children("*", "Skeleton3D", true, false):
				bones += (sk as Skeleton3D).get_bone_count()
			print("PERF_NODES bones=%d %s" % [bones, kinds])
	if "casters" in exp:
		for c in ranch.get_children():
			if not (c is Node3D):
				continue
			var n := 0
			var small := 0
			var mm := 0
			for g in c.find_children("*", "GeometryInstance3D", true, false):
				var gi := g as GeometryInstance3D
				if not gi.is_visible_in_tree() or gi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
					continue
				n += 1
				if gi is MultiMeshInstance3D:
					mm += 1
				var ab := gi.get_aabb()
				if ab.size.length() * gi.global_transform.basis.get_scale().x < 1.2:
					small += 1
			if n > 0:
				print("PERF_CASTERS %-20s casters=%d small(<1.2m)=%d multimesh=%d" % [c.name, n, small, mm])
	if "regionlist" in exp:
		var by := {}
		var reg := ranch.get_node(^"Regions")
		for g in reg.find_children("*", "GeometryInstance3D", true, false):
			var gi := g as GeometryInstance3D
			if not gi.is_visible_in_tree() or gi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				continue
			var path := String(reg.get_path_to(gi))
			var k := path.get_slice("/", 0) + "/" + path.get_slice("/", 1).left(24)
			by[k] = int(by.get(k, 0)) + 1
		var keys := by.keys()
		keys.sort_custom(func(a, b) -> bool: return by[a] > by[b])
		for k in keys.slice(0, 12):
			print("PERF_REGION %-40s %d" % [k, by[k]])
	if "lights" in exp:
		var by := {}
		for l in root.find_children("*", "Light3D", true, false):
			var li := l as Light3D
			if not li.is_visible_in_tree():
				continue
			var k := "%s shadow=%s parent=%s" % [li.get_class(), li.shadow_enabled, String(li.get_parent().name).left(20)]
			by[k] = int(by.get(k, 0)) + 1
		var n := 0
		for k in by:
			n += by[k]
		print("PERF_LIGHTS visible=%d" % n)
		var keys := by.keys()
		keys.sort_custom(func(a, b) -> bool: return by[a] > by[b])
		for k in keys.slice(0, 15):
			print("PERF_LIGHTS %4d %s" % [by[k], k])
		print("PERF_LIGHTS probes=%d decals=%d gpu_particles=%d" % [root.find_children("*", "ReflectionProbe", true, false).size(),
			root.find_children("*", "Decal", true, false).size(), root.find_children("*", "GPUParticles3D", true, false).size()])
	if "subvp" in exp:
		for v in root.find_children("*", "SubViewport", true, false):
			var sv := v as SubViewport
			print("PERF_SUBVP %s size=%s update=%d own_world=%s path=%s" % [sv.name, sv.size, sv.render_target_update_mode,
				sv.own_world_3d, String(root.get_path_to(sv))])
	if "roundtrip" in exp:
		# A pony far off wears outline-free twins; brought back to FULL she must wear her own
		# outlined materials again, every surface.
		for i in 60:
			await process_frame
		var checked := 0
		var bad := 0
		for b in ranch.find_children("*", "CharacterBody3D", true, false):
			if not b.has_method("set_stock") or int(b.get("detail")) == 0 or checked >= 10:
				continue
			checked += 1
			var bare := 0
			for m in b.find_children("*", "MeshInstance3D", true, false):
				var mi := m as MeshInstance3D
				for k in mi.mesh.get_surface_count():
					var mat := mi.get_surface_override_material(k)
					if mat != null and mat.next_pass != null:
						bad += 1
					elif mat != null and not mat.has_meta(&"bare_of_outline"):
						bare += 1
			b.call("_set_detail", 0)
			var back := 0
			for m in b.find_children("*", "MeshInstance3D", true, false):
				var mi := m as MeshInstance3D
				for k in mi.mesh.get_surface_count():
					var mat := mi.get_surface_override_material(k)
					if mat != null and mat.next_pass != null:
						back += 1
			print("PERF_ROUNDTRIP %s far_surfaces_bare=%d near_surfaces_outlined=%d" % [b.name, bare, back])
		print("PERF_ROUNDTRIP checked=%d far_with_outline=%d" % [checked, bad])
	if "owners" in exp:
		var hist := {}
		for b in ranch.find_children("*", "CharacterBody3D", true, false):
			var co := b as CollisionObject3D
			var shapes := 0
			var types := {}
			for o in co.get_shape_owners():
				for i in co.shape_owner_get_shape_count(o):
					shapes += 1
					types[co.shape_owner_get_shape(o, i).get_class()] = true
			var k := "%s shapes=%d %s" % ["pony" if b.has_method("set_stock") else String(b.name), shapes, types.keys()]
			hist[k] = int(hist.get(k, 0)) + 1
		print("PERF_OWNERS ", hist)
	if "noarea" in exp:
		for b in ranch.find_children("*", "CharacterBody3D", true, false):
			if b.has_method("set_stock"):
				var a := b.get_node_or_null(^"DetectionArea")
				if a != null:
					b.set("detection_area", null)
					a.queue_free()
	if "noblend" in exp or "split2" in exp:
		var sun := ranch.get_node(^"Sun") as DirectionalLight3D
		sun.directional_shadow_blend_splits = false
		if "split2" in exp:
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			sun.directional_shadow_split_1 = 0.2
	if "freeze" in exp:
		for b in ranch.find_children("*", "CharacterBody3D", true, false):
			if b.has_method("set_stock"):
				b.set("_wander_speed", 0.0)
				b.set("_flee_speed", 0.0)
	if "midtiny" in exp:
		for b in ranch.find_children("*", "CharacterBody3D", true, false):
			if b.has_method("set_stock"):
				for m in b.find_children("*", "MeshInstance3D", true, false):
					var nm := String(m.name).to_lower()
					for part in ["highlight", "eyebrow", "eyelash"]:
						if part in nm:
							(m as MeshInstance3D).visible = false
	if "noadvance" in exp:
		for b in ranch.find_children("*", "CharacterBody3D", true, false):
			if b.has_method("set_stock"):
				b.set("_anim", null)
	for a in exp:
		if a.begins_with("shadowdist="):
			(ranch.get_node(^"Sun") as DirectionalLight3D).directional_shadow_max_distance = float(a.substr(11))
	if "caabb" in exp:
		for b in ranch.find_children("*", "CharacterBody3D", true, false):
			for m in b.find_children("*", "MeshInstance3D", true, false):
				var mi := m as MeshInstance3D
				if mi.mesh != null and mi.skin != null or (mi.mesh != null and mi.get_parent() is Skeleton3D):
					mi.custom_aabb = mi.mesh.get_aabb().grow(0.6)
	if "lean" in exp:
		for b in ranch.find_children("*", "CharacterBody3D", true, false):
			if b.has_method("set_stock"):
				(b as CharacterBody3D).max_slides = 2
	if "margin" in exp:
		for b in ranch.find_children("*", "CharacterBody3D", true, false):
			if b.has_method("set_stock"):
				(b as CharacterBody3D).safe_margin = 0.01
	if "noprops" in exp:
		for b in ranch.find_children("*", "CharacterBody3D", true, false):
			if b.has_method("set_stock"):
				(b as CharacterBody3D).collision_mask &= ~LayersScript.PROPS
	if "shapes" in exp:
		var faces := {}
		var total := 0
		for cs in root.find_children("*", "CollisionShape3D", true, false):
			var sh := (cs as CollisionShape3D).shape
			if sh is ConcavePolygonShape3D:
				var f := (sh as ConcavePolygonShape3D).get_faces().size() / 3
				total += f
				var k := String(cs.get_parent().get_parent().name)
				faces[k] = int(faces.get(k, 0)) + f
		var keys := faces.keys()
		keys.sort_custom(func(a, b) -> bool: return faces[a] > faces[b])
		print("PERF_SHAPES concave_faces=%d owners=%d" % [total, keys.size()])
		for k in keys.slice(0, 15):
			print("PERF_SHAPES %-30s %d" % [k, faces[k]])
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
