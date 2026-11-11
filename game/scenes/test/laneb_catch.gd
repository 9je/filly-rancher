extends SceneTree
## P9 W3 item 28: a Drifter caught with the beam, then a one-of-a-kind (Lyra), as frame strips
## from the GAMEPLAY camera. The beam button is held through Input like a player holds it; the
## pony stands grazing a few metres in front of the player.
##   -s res://scenes/test/laneb_catch.gd -- --out=<dir>
const Boot := preload("res://scenes/test/laneb_boot.gd")
const GeneratorScript := preload("res://systems/pony_generator.gd")
const PonyScript := preload("res://actors/pony/pony.gd")
var out := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _catch(ranch: Node, tag: String, data: PonyData, look: Dictionary, base: Vector3) -> void:
	var terrain: Node = ranch.get("terrain")
	var at := Vector3(base.x, float(terrain.call("height_at", base.x, base.z)), base.z)
	var pony: Node3D = ranch.get("spawner").call("spawn_guest", data, look, at, 9.0)
	if pony == null:
		# Already standing in the valley: any one-of-a-kind who is not.
		for f in DirAccess.get_files_at("res://data/ponies"):
			if f.ends_with(".tres"):
				pony = ranch.get("spawner").call("spawn_guest", load("res://data/ponies/" + f), {}, at, 9.0)
				if pony != null:
					print("ONE_OF_A_KIND ", f)
					break
	pony.set("_state_timer", 60.0)
	pony.call("_transition_to", PonyScript.State.GRAZE)
	var stand := at + Vector3(0, 0.3, 4.2)
	Boot.stand(ranch, stand, at + Vector3(0, 0.6, 0))
	var player: Node3D = ranch.get("player")
	for i in 20:
		Boot.stand(ranch, stand, at + Vector3(0, 0.6, 0))
		await physics_frame
	var beam: Node = player.call("get_magic_beam")
	var caught := [false]
	pony.connect(&"captured", func() -> void: caught[0] = true)
	Input.action_press(&"beam")
	beam.set("_beaming", true)
	beam.call("_begin_hold", pony)
	var frame := 0
	for i in 600:
		await physics_frame
		if i % 15 == 0:
			await Boot.shot(self, out.path_join("%s_%02d.png" % [tag, frame]), 0)
			print("FRAME %s %d caught=%s light=%s moment=%s" % [tag, frame, caught[0],
				ranch.get_node("HUD").call("catch_card").call("is_light"),
				ranch.get_node("HUD").call("catch_card").call("in_moment")])
			frame += 1
		if frame >= 24:
			break
	Input.action_release(&"beam")
	for i in 400:
		await process_frame


func _run() -> void:
	var ranch: Node = await Boot.boot(self)
	var bag: Storage = ranch.get("player").call("get_magic_beam").call("get_storage")
	while bag.count() > 0:
		bag.release()
	var base := Vector3(20, 0, -30)
	var look := GeneratorScript.generate(777).to_dict()
	await _catch(ranch, "drifter", load("res://data/hidden/stock_curious.tres"), look, base)
	await _catch(ranch, "lyra", load("res://data/ponies/lyra.tres"), {}, base + Vector3(6, 0, 0))
	print("LANEB_CATCH_OK")
	quit(0)
