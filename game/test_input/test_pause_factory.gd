extends "res://test_input/input_test.gd"
## PAUSE IN THE RAINBOW FACTORY (owner playtest 2026-11-10, item 74: "you cant pause when youre
## in dialogue and this whole time im up here"). The Factory scene had no pause menu at all.
## Loaded the way the cloud-lift loads it; Marigold's welcome is up; Esc must open the pause
## menu over it, freeze the tree, and Esc again must put the line back where it was.
## FILLY_SHOT_DIR, when set, gets a frame of the menu open over the welcome.

const FACTORY_SCENE := "res://world/factory.tscn"


func _play() -> void:
	_deadline_s = 600.0
	change_scene_to_file(FACTORY_SCENE)
	var scene: Node = null
	var t := 0.0
	while t < 60.0:
		var s := current_scene
		if s != null and s.get("player") != null and s.get("people") != null:
			scene = s
			break
		await wait(0.1)
		t += 0.1
	if not check(scene != null, "the Factory scene never came up"):
		return
	var people: Node = scene.get("people")
	t = 0.0
	while t < 60.0 and not bool(people.call("is_talking")):
		await wait(0.2)
		t += 0.2
	if not check(bool(people.call("is_talking")), "Marigold's welcome never started"):
		return
	await wait(1.0)
	var menu: CanvasLayer = scene.get("pause_menu")
	if not check(menu != null, "the Factory has no pause menu"):
		return
	RI.press(&"pause")
	await wait(0.1)
	RI.release(&"pause")
	await wait(0.6)
	if not check(menu.visible and paused, "Esc in the welcome did not pause (menu %s, paused %s)"
			% [menu.visible, paused]):
		return
	var dir := OS.get_environment("FILLY_SHOT_DIR")
	if not dir.is_empty():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(dir.path_join("factory_pause_open.png"))
	RI.press(&"pause")
	await wait(0.1)
	RI.release(&"pause")
	await wait(0.6)
	if not check(not menu.visible and not paused, "Esc did not close the pause menu"):
		return
	if not check(bool(people.call("is_talking")), "the welcome did not wait under the pause"):
		return
	if not dir.is_empty():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(dir.path_join("factory_pause_closed.png"))
	ok("Esc pauses over Marigold's welcome in the Factory and the line waits")
