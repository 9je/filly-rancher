extends SceneTree
## Owner 2026-11-11: the SECOND machine, Rainbow Rush, on the island. Was: the slot machine the way the owner reaches it (into the Palace, the slots
## booth, E), spun until two Stars land, then the free spins taken with the Spin button.
##   -s res://scenes/test/laneb_slots.gd -- --out=<dir>
const Boot := preload("res://scenes/test/laneb_boot.gd")
const SlotsScript := preload("res://systems/slots.gd")
var out := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _run() -> void:
	var ranch: Node = await Boot.boot(self)
	var gs = ranch.get("_game_state")
	gs.casino.add_chips(5000)
	gs.story.set_flag("palace_open")
	ranch.call("enter_palace", true)
	for i in 60:
		await process_frame
	var interior: Node3D = ranch.get("palace_interior")
	var spot: Vector3 = interior.call("station_point", &"slots_rush")
	var player: Node3D = ranch.get("player")
	Boot.stand(ranch, spot, spot + (spot - player.global_position).normalized())
	for i in 30:
		await process_frame
	print("PROMPT ", ranch.get_node("HUD").call("prompt_text"))
	await Boot.shot(self, out.path_join("rush_prompt.png"), 5)
	await Boot.press(self, &"interact")
	for i in 30:
		await process_frame
	var menu: Node = ranch.get("slots_menu")
	print("MACHINE ", menu.get("machine"), " TITLE ", menu.call("title_text"))
	await Boot.shot(self, out.path_join("rush_open.png"), 5)
	var r: Dictionary = ranch.call("play_slots", 10)
	for i in 120:
		await process_frame
	await Boot.shot(self, out.path_join("rush_spun.png"), 5)
	print("RUSH_SHOT_OK")
	quit(0)
