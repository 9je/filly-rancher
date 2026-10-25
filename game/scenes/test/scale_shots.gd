extends SceneTree
## SCALE EVIDENCE SHOTS (docs/playtest_fixes/scale.md): the player pony stood at every
## building's door and beside the props SCALE.md sizes, photographed from a fixed camera, so
## a before and an after can be laid side by side. Run it inside the invisible display:
##
##   xvfb-run ... tools/bin/godot --display-driver x11 --path game -s res://scenes/test/scale_shots.gd -- --out=/abs/dir
##
## Prints SCALE_SHOTS_OK <count>.

const BootIntentScript := preload("res://world/boot_intent.gd")
const WorldStateScript := preload("res://systems/world_state.gd")

var out := ""
var ranch: Node
var cam: Camera3D
var shots := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	if out == "":
		out = ProjectSettings.globalize_path("res://").path_join("../build/playtest_evidence/scale")
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	root.get_window().size = Vector2i(1280, 720)
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
	var w: Object = ranch.get("_world")
	if w != null:
		w.call("pin", WorldStateScript.Phase.DAY, WorldStateScript.Weather.CLEAR)
		var sky: Node = ranch.get("sky_rig")
		if sky != null and sky.has_method("apply_immediately"):
			sky.call("apply_immediately", w)
	var hud := ranch.get_node_or_null(^"HUD") as CanvasLayer
	if hud != null:
		hud.visible = false
	# Only the player pony in frame: she is the yardstick, and a resident wandering in front of
	# the lens hides the very thing the shot is of.
	for crowd in [^"Spawner", ^"People", ^"Attendants", ^"Spike"]:
		var n := ranch.get_node_or_null(crowd)
		if n != null:
			n.process_mode = Node.PROCESS_MODE_DISABLED
			for c in n.get_children():
				if c is Node3D:
					(c as Node3D).visible = false
				if c is CollisionObject3D:
					(c as CollisionObject3D).collision_layer = 0
			if n is Node3D:
				(n as Node3D).visible = false
	await _frames(30)
	for b: Node in ranch.get_node(^"Buildings").get_children():
		if b is Building:
			var model := b.get_node_or_null(^"Model") as Node3D
			var box: AABB = Props.world_aabb(model if model != null else b)
			var fwd := (b as Node3D).global_basis.z
			await _frame("building_" + String(b.name).to_snake_case(), box, Vector2(fwd.x, fwd.z))
	var props: Node = ranch.get_node(^"Props")
	var done: Dictionary = {}
	for p: Node3D in props.call("get_placed"):
		var file: String = String(props.call("entry_of", p).get("file", "")).get_basename()
		if file in SUBJECTS and not done.has(file):
			done[file] = true
			var toward := Vector2(-p.global_position.x, -p.global_position.z).normalized()
			await _frame("prop_" + file, Props.world_aabb(p), toward)
	for r in [["orchard", Vector2(72, 40)], ["everfree", Vector2(-74, -49)],
			["lake", Vector2(60, -62)], ["nightmeadow", Vector2(-61, 69)]]:
		var c: Vector2 = r[1]
		var box := AABB(Vector3(c.x - 4, _h(c.x, c.y), c.y - 4), Vector3(8, 5, 8))
		await _frame("region_" + String(r[0]), box, -c.normalized(), 14.0)
	# The homestead from straight above, so the buildings' footprints can be read against
	# each other, the pens and the path.
	var player: Node3D = ranch.get("player")
	player.global_position = Vector3(1.5, _h(1.5, 2.0) + 0.1, 2.0)
	cam.global_position = Vector3(0.0, 48.0, 3.0)
	cam.look_at(Vector3(0.0, 0.0, 3.0), Vector3(0, 0, -1))
	cam.fov = 60.0
	await _frames(30)
	await _save("yard_from_above")
	print("SCALE_SHOTS_OK %d" % shots)
	quit(0)


func _save(shot: String) -> void:
	_quiet()
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out.path_join(shot + ".png"))
	shots += 1
	print("SCALE_SHOT %s" % shot)


## No conversation bubble hanging over a view of somewhere else.
func _quiet() -> void:
	var people: Node = ranch.get("people")
	var tb: Node = people.get("talk_box") if people != null else null
	if tb != null and bool(tb.call("is_open")):
		tb.call("close")


func _h(x: float, z: float) -> float:
	return float(ranch.get("terrain").call("height_at", x, z))


const SUBJECTS := ["pv_pink_b", "pv_ogb_1", "pv_courtyard_b", "pv_balcony_b", "kenney_market_stall",
	"saa_barn", "saa_shed", "saa_fence_old", "school_belltower", "mlp_basket", "saa_wagon",
	"mlp_apple_tree", "lp_skeeball"]


## The pony standing just off `box` on the side `dir` points to, and the camera further out
## that way and a little to one side, framing both.
func _frame(shot: String, box: AABB, dir: Vector2, extra := 0.0) -> void:
	dir = dir.normalized()
	var c := box.get_center()
	var r := maxf(absf(dir.x) * box.size.x, absf(dir.y) * box.size.z) * 0.5
	var stand := Vector3(c.x + dir.x * (r + 2.0), 0.0, c.z + dir.y * (r + 2.0))
	var side := Vector2(-dir.y, dir.x)
	var dist := maxf(box.size.y * 1.5, 6.0) + extra
	var from := Vector3(stand.x + dir.x * dist + side.x * dist * 0.35, 0.0,
		stand.z + dir.y * dist + side.y * dist * 0.35)
	var at := Vector3((c.x + stand.x) * 0.5, 0.0, (c.z + stand.z) * 0.5)
	at.y = _h(at.x, at.z) + maxf(box.size.y * 0.4, 1.2)
	await _stand_and_shoot(shot, stand, from, at)


func _stand_and_shoot(shot: String, stand: Vector3, from: Vector3, at: Vector3) -> void:
	var player: CharacterBody3D = ranch.get("player")
	stand.y = _h(stand.x, stand.z) + 0.1
	player.global_position = stand
	player.velocity = Vector3.ZERO
	var look := at - stand
	player.get("visuals").global_rotation.y = atan2(look.x, look.z)
	if cam == null:
		cam = Camera3D.new()
		ranch.add_child(cam)
	cam.fov = 55.0
	from.y = maxf(_h(from.x, from.z), stand.y) + 1.8
	await _frames(20)
	# A clear line from the lens to the pony and to what she is standing beside: swing the
	# camera round her (same distance, same height) until nothing solid is in the way.
	var chest := player.global_position + Vector3(0, 1.2, 0)
	var space: PhysicsDirectSpaceState3D = (ranch as Node3D).get_world_3d().direct_space_state
	var offset := from - stand
	for k in 12:
		var cand := stand + offset.rotated(Vector3.UP, deg_to_rad(float((k + 1) / 2) * 30.0 * (1.0 if k % 2 == 0 else -1.0)))
		if k == 0:
			cand = from
		cand.y = maxf(_h(cand.x, cand.z), stand.y) + 1.8
		var clear := true
		for target: Vector3 in [chest, at]:
			var q := PhysicsRayQueryParameters3D.create(cand, target)
			q.collision_mask = 0xFFFFFFFF
			q.exclude = [player.get_rid()]
			var hit: Dictionary = space.intersect_ray(q)
			if not hit.is_empty() and (hit.position as Vector3).distance_to(target) > 1.5:
				clear = false
		if clear:
			from = cand
			break
	cam.global_position = from
	cam.look_at(at)
	cam.make_current()
	_quiet()
	await _frames(25)
	await _save(shot)
