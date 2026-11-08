extends SceneTree
## P8 S2 RENDER (playtest 2026-11-08 items 3, 11): the farmhouse door at night offers sleep;
## pressing it fades out, skips to dawn and saves.
##   sleep_prompt   the player at the farmhouse door at night: "E: sleep till dawn"
##   sleep_morning  after the press: dawn, "Good morning! Day N. The ranch is saved."
## Run: xvfb, -s res://scenes/test/sleep_shot.gd -- --out=<dir>
const BootIntentScript := preload("res://world/boot_intent.gd")
const FIXTURE := "res://test/fixtures/old_save_pre_ps/slot_0.json"
var out := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _shot(shot_name: String, frames: int = 20) -> void:
	for i in frames:
		await process_frame
	root.get_texture().get_image().save_png(out.path_join(shot_name + ".png"))
	print("SHOT ", shot_name)


func _run() -> void:
	root.get_window().size = Vector2i(1280, 720)
	var dst := ProjectSettings.globalize_path(SaveIO.slot_path(0))
	DirAccess.make_dir_recursive_absolute(dst.get_base_dir())
	var f := FileAccess.open(dst, FileAccess.WRITE)
	f.store_string(FileAccess.get_file_as_string(FIXTURE))
	f.close()
	BootIntentScript.driven = true
	change_scene_to_file("res://world/ranch.tscn")
	var ranch: Node = null
	for i in 1200:
		await process_frame
		ranch = current_scene
		if ranch != null and bool(ranch.get("boot_done")):
			break
	for i in 60:
		await process_frame
	var lp: Node = ranch.get("letter_panel")
	if lp != null and bool(lp.call("is_open")):
		lp.call("close")
	paused = false
	var world: WorldState = ranch.call("get_world_state")
	world.set_elapsed(world.cycle_index() * WorldState.CYCLE_SECONDS + 900.0)
	var house: Node3D = ranch.get_node("Buildings/Farmhouse")
	var player: Node3D = ranch.get("player")
	var door: Vector3 = house.global_position + house.global_transform.basis.z * (float(house.get("depth")) * 0.5 + 1.6)
	player.global_position = door + Vector3(0, 1.0, 0)
	ranch.set("_interactive", true)
	for i in 40:
		await physics_frame
	print("PHASE ", world.phase(), " can_sleep ", ranch.call("can_sleep_here"))
	print("ACTION ", ranch.call("current_interaction"))
	print("PROMPT ", ranch.get_node("HUD").call("prompt_text"))
	await _shot("sleep_prompt", 10)
	ranch.call("perform_interaction", ranch.call("current_interaction"))
	await _shot("sleep_dark", 45)
	for i in 120:
		await process_frame
	print("AFTER phase ", world.phase(), " cycle ", world.cycle_index(), " toast ", ranch.get_node("HUD").call("toast_text"))
	ranch.set("_interactive", false)
	await _shot("sleep_morning", 10)
	quit(0)
