extends SceneTree
## P9 W3 item 50: the slot machine the way the owner reaches it (into the Palace, the slots
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
	var spot: Vector3 = interior.call("station_point", &"slots")
	var player: Node3D = ranch.get("player")
	Boot.stand(ranch, spot, spot + (spot - player.global_position).normalized())
	for i in 30:
		await process_frame
	print("PROMPT ", ranch.get_node("HUD").call("prompt_text"))
	await Boot.press(self, &"interact")
	var menu: Node = ranch.get("slots_menu")
	for i in 30:
		await process_frame
	await Boot.shot(self, out.path_join("slots_open.png"), 5)
	var tries := 0
	while tries < 2000:
		tries += 1
		var r: Dictionary = ranch.call("play_slots", 10)
		if SlotsScript.bonus_spins(r["reels"]) > 0:
			print("BONUS after %d spins: %s" % [tries, SlotsScript.line_text(r["reels"])])
			break
	for i in 150:
		await process_frame
		if i == 95:
			await Boot.shot(self, out.path_join("slots_bonus_flash.png"), 0)
	await Boot.shot(self, out.path_join("slots_bonus_banked.png"), 5)
	print("FREE ", menu.get("free_spins"), " chips ", gs.casino.chips)
	var before: int = gs.casino.chips
	await Boot.press(self, &"ui_accept")
	for i in 30:
		await process_frame
	print("FREE SPIN chips %d -> %d free=%s" % [before, gs.casino.chips, menu.get("free_spins")])
	await Boot.shot(self, out.path_join("slots_free_spin.png"), 90)
	print("LANEB_SLOTS_OK")
	quit(0)
