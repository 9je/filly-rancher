extends SceneTree
## The HUD with everything up at once (PT5: cards that overlap, a toast across the screen,
## an 18 slot saddlebag): tasks, the objective card, a long toast, the catch card.
##   xvfb-run ... godot --display-driver x11 --path game -s res://scenes/test/hud_shot.gd -- --out=/abs/dir [--size=1280x720]
const BootIntentScript := preload("res://world/boot_intent.gd")
const PonyInstanceScript := preload("res://systems/pony_instance.gd")
var out := ""
var size := Vector2i(1280, 720)


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--size="):
			var p := a.substr(7).split("x")
			size = Vector2i(int(p[0]), int(p[1]))
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _run() -> void:
	root.get_window().size = size
	BootIntentScript.driven = true
	BootIntentScript.request_new_game()
	change_scene_to_file("res://world/ranch.tscn")
	var ranch: Node = null
	for i in 900:
		await process_frame
		ranch = current_scene
		if ranch != null and ranch.get("people") != null and i > 30:
			break
	for i in 60:
		await process_frame
	var cs: Node = ranch.get("creation_screen")
	if cs != null and bool(cs.call("is_open")):
		cs.call("confirm")
	var lp: Node = ranch.get("letter_panel")
	if lp != null and bool(lp.call("is_open")):
		lp.call("close")
	paused = false
	var beam: Node = ranch.get("player").call("get_magic_beam")
	beam.call("apply_unlocks", ["bigger_saddlebag"])
	var hud: Node = ranch.get_node("HUD")
	for i in 30:
		await process_frame
	root.get_texture().get_image().save_png(out.path_join("hud_plain.png"))
	ranch.set("_person_aim_t", 9999.0)
	hud.call("set_aiming_person", true)
	for i in 3:
		await process_frame
	root.get_texture().get_image().save_png(out.path_join("hud_person.png"))
	var b: Node = hud.call("get_beam")
	print("PERSON aiming=", hud.call("aiming_person"), " target=", b.call("has_target") if b != null else "nobeam", " holding=", b.call("is_holding") if b != null else "")
	hud.call("set_aiming_person", false)
	hud.call("toast", "Pip: \"Smile! Cloudsdale wants you for the newsletter!\" Steward of the Week: 12 ponies placed, \"a yield of 124% above the valley average.\"")
	hud.call("_on_captured", PonyInstanceScript.create(&"twilight"))
	for i in 20:
		await process_frame
	root.get_texture().get_image().save_png(out.path_join("hud_busy.png"))
	for i in 200:
		await process_frame
	root.get_texture().get_image().save_png(out.path_join("hud_toast.png"))
	print("HUDSHOT_OK cap=", hud.call("get_capacity"))
	quit()
