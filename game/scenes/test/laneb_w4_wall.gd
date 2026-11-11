extends SceneTree
## P9 W4 item 69: a field pony sent wandering into the Farmhouse's front wall, and a townspony
## sent to a spot against it; frames after they give up / arrive, and which way they face.
##   -s res://scenes/test/laneb_w4_wall.gd -- --out=<dir>
const Boot := preload("res://scenes/test/laneb_boot.gd")
var out := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _run() -> void:
	var ranch: Node = await Boot.boot(self)
	var farm := ranch.get_node(^"Buildings/Farmhouse") as Node3D
	var wall_z: float = farm.global_position.z + float(farm.get("depth")) * 0.5
	var terrain: Node = ranch.get("terrain")
	var pony: Node3D = null
	for p in ranch.get_node(^"Spawner").get_children():
		if p is Pony:
			pony = p
			break
	var start := Vector3(-3.0, 0.0, wall_z + 4.0)
	start.y = float(terrain.call("height_at", start.x, start.z)) + 0.3
	pony.global_position = start
	pony.call("wander_to", Vector3(-3.0, start.y, wall_z - 6.0))
	var people: Node = ranch.get_node(^"People")
	var npcs: Dictionary = people.get("npcs")
	var npc: Npc = null
	for id in npcs:
		if npcs[id] is Npc and (npcs[id] as Npc).mode == Npc.Mode.STAND:
			npc = npcs[id]
			break
	var nstart := Vector3(4.0, 0.0, wall_z + 5.0)
	nstart.y = float(terrain.call("height_at", nstart.x, nstart.z)) + 0.3
	npc.global_position = nstart
	npc.set_mode_walk_to(Vector3(4.0, nstart.y, wall_z + 0.4))
	Boot.stand(ranch, Vector3(1.0, start.y, wall_z + 30.0), Vector3(1.0, start.y, wall_z))
	var settled := 0
	for i in 900:
		await process_frame
		settled = settled + 1 if (int(pony.get("state")) == 0 and bool(pony.get("_stood_still"))) else 0
		if settled > 40:
			break
	var pv: Node3D = pony.get_node(^"Visuals")
	var nv: Node3D = npc.get_node(^"Visuals")
	var pf := Vector3(-sin(pv.global_rotation.y), 0, -cos(pv.global_rotation.y))
	var nf := Vector3(-sin(nv.global_rotation.y), 0, -cos(nv.global_rotation.y))
	print("WALL wall_z=%.2f pony at %s faces %s (toward wall=%s) state=%s; npc %s at %s faces %s (toward wall=%s)" % [
		wall_z, pony.global_position, pf, pf.z < -0.5, pony.get("state"), npc.name, npc.global_position, nf, nf.z < -0.5])
	# Walk the camera up for the frame (she has settled; a few seconds is not enough to spook her).
	Boot.stand(ranch, Vector3(4.0, start.y, wall_z + 13.0), Vector3(0.5, start.y, wall_z))
	await Boot.shot(self, out.path_join("wall_after.png"), 8)
	print("WALL_OK")
	quit()
