extends "res://test_input/input_test.gd"
## INPUT_TEST_REALTIME
## OWNER PLAYTEST 2026-10-25: "game window resized when i hit new game". From the title,
## click New game with the mouse and watch the OS window's size and mode every frame through
## the loading screen, the creator and the ranch. Neither may change: only the Settings menu's
## Display tab ever resizes the window. Run at the game's own window size (no --resolution).

var _sizes: Array[String] = []
var _first: Vector2i
var _mode: int


func _play() -> void:
	_deadline_s = 300.0
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await frames(30)
	_first = DisplayServer.window_get_size()
	_mode = DisplayServer.window_get_mode()
	note("title window %s mode %d" % [_first, _mode])
	process_frame.connect(_watch)
	if not await click_text("New game"):
		return
	if RI.find_text(root, "Really start over") != null:
		await click_text("New game")
	await wait(8.0)
	var over: Array[String] = []
	for step in ["Your pony", "Mane and tail", "Your cutie mark"]:
		await click_text(step)
		await wait(0.8)
		_shot("creator_%s" % step.replace(" ", "_"))
		over.append_array(_overflow())
	await click_text("Mane and tail")
	await wait(0.5)
	if not over.is_empty():
		fail("the creator runs off a %s window: %s" % [_first, ", ".join(over.slice(0, 8))])
		return
	if not await click_text("This is me", 20.0):
		return
	await wait(10.0)
	if not _sizes.is_empty():
		fail("the window changed: %s" % ", ".join(_sizes.slice(0, 6)))
		return
	ok("the window stayed %s in mode %d from the title to the ranch" % [_first, _mode])


func _watch() -> void:
	var s := DisplayServer.window_get_size()
	var m := DisplayServer.window_get_mode()
	if (s != _first or m != _mode) and _sizes.size() < 20:
		_sizes.append("%s mode %d at %s" % [s, m, root.get_child(root.get_child_count() - 1).name])


## Every visible control of the creator, drawn inside the window.
func _overflow() -> Array[String]:
	var out: Array[String] = []
	var screen := root.get_visible_rect().grow(1.0)
	var cs := RI.find_text(root, "This is me")
	var top: Node = cs
	while top != null and not (top is CanvasLayer) and top.get_parent() != root:
		top = top.get_parent()
	for n in (top if top != null else root).find_children("*", "Control", true, false):
		var c := n as Control
		if c.is_visible_in_tree() and c.size.x > 0 and not screen.encloses(c.get_global_rect()):
			if c is Button or c is Label or c is LineEdit:
				out.append("%s %s" % [c.name, c.get_global_rect()])
	return out


func _shot(tag: String) -> void:
	var dir := "res://../build/playtest_evidence/round2/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var img := root.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(dir + "%s_%dx%d.png" % [tag, _first.x, _first.y]))
