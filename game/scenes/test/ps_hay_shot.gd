extends SceneTree
## PS EVIDENCE, item 57 (playtest 2026-11-05: "A pony hidden inside a haystack"). In a new
## game: every hay pile, crate and basket in the region dressing is checked solid (a 0.2 m ball
## at its foot on the PROPS layer) and against the spawner's own re-roll test
## (Spawner._blocked_by_prop at its foot); every wild pony's distance to the nearest hay pile;
## and the spawner's own placement (_ground_point) drawn 200 times on every marker whose disc
## holds hay, none within 1 m of a pile. Then the hay with the most wild ponies round it is
## photographed from above and at pony height.
##   xvfb-run ... godot --display-driver x11 --path game -s res://scenes/test/ps_hay_shot.gd -- --out=/abs/dir
const Boot := preload("res://scenes/test/ps_boot.gd")
const LayersScript := preload("res://world/collision_layers.gd")
var out := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _run() -> void:
	var ranch: Node = await Boot.boot(self)
	await Boot.frames(self, 30)
	var dressing: Node = ranch.find_child("Dressing", true, false)
	var spawner: Node = ranch.get("spawner")
	var space: PhysicsDirectSpaceState3D = ranch.get_world_3d().direct_space_state
	var ball := SphereShape3D.new()
	ball.radius = 0.2
	var hay: Array[Vector3] = []
	var solid := 0
	var refused := 0
	var props := 0
	for placed: Dictionary in dressing.get("placements"):
		var model := String(placed.model)
		if not (model in ["saa_hay_pile", "mlp_crate", "mlp_basket"]):
			continue
		props += 1
		var at: Vector3 = placed.at
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = ball
		q.transform = Transform3D(Basis(), at + Vector3(0, 0.3, 0))
		q.collision_mask = LayersScript.PROPS
		var is_solid := not space.intersect_shape(q, 1).is_empty()
		var blocked: bool = spawner.call("_blocked_by_prop", space, at)
		solid += int(is_solid)
		refused += int(blocked)
		if model == "saa_hay_pile":
			hay.append(at)
		print("ITEM57 %s at %s: solid %s, the spawner refuses a pony here %s" % [model, at, is_solid, blocked])
	print("ITEM57 props %d (hay piles %d): solid %d, refused by the spawner %d" % [props, hay.size(), solid, refused])
	var wild: Array = spawner.call("get_spawned")
	var nearest_all := INF
	var near_count := {}
	for p: Node3D in wild:
		var nd := INF
		var ni := -1
		for i in hay.size():
			var d := _flat(p.global_position, hay[i])
			if d < nd:
				nd = d
				ni = i
		nearest_all = minf(nearest_all, nd)
		if ni >= 0 and nd < 15.0:
			near_count[ni] = int(near_count.get(ni, 0)) + 1
	print("ITEM57 wild ponies %d; nearest any stands to a hay pile's middle: %.2f m" % [wild.size(), nearest_all])
	# The spawner's placement itself, drawn over and over on the markers that hold hay.
	var draws := 0
	var close := 0
	var worst := INF
	for m: Node in ranch.find_children("*", "ZoneMarker", true, false):
		var marker := m as ZoneMarker
		var holds := false
		for h in hay:
			if _flat(marker.global_position, h) < marker.spawn_radius:
				holds = true
		if not holds:
			continue
		for slot in 200:
			var pt: Vector3 = spawner.call("_ground_point", marker, 1000 + slot)
			draws += 1
			for h in hay:
				var d := _flat(pt, h)
				worst = minf(worst, d)
				if d < 1.0:
					close += 1
		print("ITEM57 marker %s (%s, r %.0f m) holds hay: 200 draws" % [marker.name, marker.zone_id, marker.spawn_radius])
	print("ITEM57 spawner draws %d on hay markers: %d within 1 m of a pile's middle, nearest %.2f m" % [draws, close, worst])
	# The pile with the most ponies about it.
	var pick := 0
	var most := -1
	for i in hay.size():
		if int(near_count.get(i, 0)) > most:
			most = int(near_count.get(i, 0))
			pick = i
	if hay.is_empty():
		print("ITEM57 no hay")
		quit(1)
		return
	var c := hay[pick]
	print("ITEM57 photographing hay %s with %d wild ponies within 15 m" % [c, most])
	var hud := ranch.get_node_or_null(^"HUD") as CanvasLayer
	if hud != null:
		hud.visible = false
	var cam := Camera3D.new()
	cam.fov = 60.0
	ranch.add_child(cam)
	cam.global_position = c + Vector3(0.5, 16.0, 9.0)
	cam.look_at(c)
	cam.make_current()
	await Boot.frames(self, 10)
	await Boot.shot(self, out, "item57_hay_from_above")
	cam.global_position = c + Vector3(7.0, 2.0, 7.0)
	cam.look_at(c + Vector3(0, 0.6, 0))
	await Boot.frames(self, 10)
	await Boot.shot(self, out, "item57_hay_pony_height")
	print("PS_HAY_SHOT_OK")
	quit(0)
