extends SceneTree
## P9 W3 items 46 to 49: the race the way the owner reaches it. Into the Palace, up to the
## racing booth, E; click a pony card (must NOT bet), click the 200 chip, click Place bet, then
## frames of the race itself.
##   -s res://scenes/test/laneb_race.gd -- --out=<dir>
const Boot := preload("res://scenes/test/laneb_boot.gd")
var out := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _stage_point(menu: Node, r: Rect2) -> Vector2:
	var stage: Control = menu.get("_stage")
	return root.get_final_transform() * (stage.get_global_transform() * r.get_center())


func _run() -> void:
	var ranch: Node = await Boot.boot(self)
	var gs = ranch.get("_game_state")
	gs.casino.add_chips(400)
	# This save predates the Palace opening; the story beat that opens it is a flag.
	gs.story.set_flag("palace_open")
	print("ENTER ", ranch.call("enter_palace", true))
	for i in 60:
		await process_frame
	var interior: Node3D = ranch.get("palace_interior")
	var spot: Vector3 = interior.call("station_point", &"racing")
	var player: Node3D = ranch.get("player")
	Boot.stand(ranch, spot, spot + (spot - player.global_position).normalized())
	for i in 30:
		await process_frame
	print("PROMPT ", ranch.get_node("HUD").call("prompt_text"))
	await Boot.press(self, &"interact")
	var menu: Node = ranch.get("race_menu")
	for i in 30:
		await process_frame
	print("OPEN ", menu.call("is_open"))
	await Boot.shot(self, out.path_join("race_guide.png"), 10)
	var chips_before: int = gs.casino.chips
	await Boot.click(self, _stage_point(menu, menu.call("card_rect", 1)))
	await Boot.shot(self, out.path_join("race_picked.png"), 10)
	print("AFTER CARD chips %d -> %d picked=%d open=%s" % [chips_before, gs.casino.chips,
		menu.call("picked_index"), menu.call("is_open")])
	await Boot.click(self, _stage_point(menu, menu.call("stake_chip_rect", 2)))
	await Boot.shot(self, out.path_join("race_stake.png"), 10)
	print("AFTER CHIP chips=%d stake=%d open=%s" % [gs.casino.chips, menu.call("selected_stake"), menu.call("is_open")])
	await Boot.click(self, _stage_point(menu, menu.call("bet_button_rect")))
	print("AFTER BET chips=%d open=%s" % [gs.casino.chips, menu.call("is_open")])
	for k in 8:
		await Boot.shot(self, out.path_join("race_run_%d.png" % k), 70)
	print("LANEB_RACE_OK")
	quit(0)
