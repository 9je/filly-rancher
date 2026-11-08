class_name InputTest
extends SceneTree
## THE BASE OF EVERY REAL-INPUT TEST (tools/run_input_tests.sh, PLAYTEST_FIXES.md). The game
## boots from its own main scene in a real window, exactly as the export does, and the test
## plays it the way a person does: mouse on the title screen's rows, the creator's buttons
## and the letter's Close, WASD to walk, the mouse to look, the right button for the beam.
## Every action goes through RealInput; the test only READS the game to decide what a
## person looking at the screen would do next.
##
## A test overrides _play() and calls ok() or fail(). It must run WINDOWED: the game treats a
## headless run as "no person at the keyboard" (TitleScreen.is_interactive()) and skips the
## title, the creator, and the Scoop gate -- which is how the old suite missed the first pony.

const RI := preload("res://test_input/real_input.gd")

var ranch: Node = null
var player: CharacterBody3D = null
var rig: Node3D = null
var _done := false
var _deadline_s := 600.0
var _t0 := 0


func _initialize() -> void:
	_t0 = Time.get_ticks_msec()
	if DisplayServer.get_name() == "headless":
		print("INPUT_TEST_FAILED %s must run windowed (tools/run_input_tests.sh)" % name())
		quit(2)
		return
	_watchdog.call_deferred()
	_main.call_deferred()


func name() -> String:
	return (get_script() as Script).resource_path.get_file().get_basename()


func _main() -> void:
	await _play()
	# Every test reaches its own verdict. A script error ends _play() early and returns
	# here as if it had finished, so falling through is a failure, never a pass.
	if not _done:
		fail("_play() ended without a verdict (a script error cut it short?)")


## Override.
func _play() -> void:
	pass


func ok(msg: String = "") -> void:
	if _done:
		return
	_done = true
	print("INPUT_TEST_OK %s %s" % [name(), msg])
	_release_all()
	quit(0)


func fail(msg: String) -> void:
	if _done:
		return
	_done = true
	print("INPUT_TEST_FAILED %s %s" % [name(), msg])
	_release_all()
	quit(1)


func check(cond: bool, msg: String) -> bool:
	if not cond:
		fail(msg)
	return cond


func note(msg: String) -> void:
	print("INPUT_TEST_NOTE %.1fs %s" % [(Time.get_ticks_msec() - _t0) / 1000.0, msg])


## Counted in GAME seconds: under the invisible display (xvfb, software rendering, run with
## --fixed-fps 60) a game second can take several real ones, and that is not the game's fault.
func _watchdog() -> void:
	var t := 0.0
	while not _done:
		await create_timer(1.0).timeout
		t += 1.0
		if t > _deadline_s:
			fail("timed out after %ds of game time (%s)" % [int(_deadline_s), _where()])


## Where a timed-out test was stuck: the scene, the loading screen and the player, so a rare
## hang says what it was waiting on instead of only that it waited.
func _where() -> String:
	var parts: Array[String] = []
	parts.append("scene %s" % (current_scene.name if current_scene != null else "none"))
	parts.append("paused %s" % str(paused))
	var ls = LoadingScreen._current
	if is_instance_valid(ls):
		var staged: String = "%.2f" % float(ls._loader.progress()) if ls._loader != null else "none"
		parts.append("loading state %d at %.2f '%s' staged load %s claimed %s" % [ls._state,
			ls._target, ls._caption, staged, str(ls._claimed)])
	if is_instance_valid(player):
		parts.append("player at %s" % str(player.global_position))
	return ", ".join(parts)


func _release_all() -> void:
	for a: StringName in [&"move_forward", &"move_back", &"move_left", &"move_right", &"beam",
			&"sneak", &"gallop", &"interact"]:
		RI.release(a)


func frames(n: int) -> void:
	for i in n:
		await process_frame


func physics(n: int) -> void:
	for i in n:
		await physics_frame


func wait(s: float) -> void:
	await create_timer(s, true, true).timeout


## Click a Control with the left button, the way a mouse does: move there, press, release.
func click(c: Control) -> void:
	var at := RI.screen_centre(c)
	RI.move_mouse(at)
	await frames(2)
	RI.mouse_button(MOUSE_BUTTON_LEFT, true, at)
	await frames(2)
	RI.mouse_button(MOUSE_BUTTON_LEFT, false, at)
	await frames(3)


## Click the visible control reading `text`; fail the test if there is none within `secs`.
func click_text(text: String, secs := 10.0) -> bool:
	var t := 0.0
	while t < secs:
		var c := RI.find_text(root, text)
		if c != null:
			await click(c)
			return true
		await wait(0.1)
		t += 0.1
	fail("no '%s' on screen" % text)
	return false


func tap(action: StringName, hold_frames := 3) -> void:
	RI.press(action)
	await frames(hold_frames)
	RI.release(action)
	await frames(2)


## Title -> New game (twice: the second is its confirm) -> the ranch.
func boot_new_game() -> bool:
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await frames(10)
	if not await click_text("New game"):
		return false
	if RI.find_text(root, "Really start over") != null:
		await click_text("New game")
	# WALL-CLOCK SECONDS, NOT GAME SECONDS. The ranch loads on a worker thread in real time,
	# while the loading screen draws no 3D and its frames are nearly free: under --fixed-fps
	# 60 game seconds of them can pass in a few real ones, and a slow load lost that race --
	# the test quit mid-load, and every preload the worker still had pending then failed.
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 180000:
		var s := current_scene
		if s != null and s.get("people") != null and s.get("player") != null:
			ranch = s
			break
		await wait(0.1)
	if not check(ranch != null, "New game never reached the ranch"):
		return false
	player = ranch.get("player")
	rig = player.call("get_camera_pivot").get_node("CameraRig")
	return true


## The creator: keep the default pony and take it.
func finish_creator() -> bool:
	return await click_text("This is me", 20.0)


## The welcome letter's Close button.
func close_letter() -> bool:
	var lp: Node = ranch.get("letter_panel")
	var t := 0.0
	while t < 10.0:
		if lp != null and bool(lp.call("is_open")):
			var b: Button = lp.call("close_button_node")
			await click(b)
			return true
		await wait(0.1)
		t += 0.1
	return true


## Mouse-look until the camera faces `point` (yaw within `tol` radians). Pitch toward it too
## when `pitch` is set, for aiming. `from_body` measures the heading from her body instead of
## the lens: walking goes where the camera faces FROM HER, and the lens sits 3.5 m behind and
## off her shoulder, so near the point a heading taken from the lens swung her round it.
func look_at_point(point: Vector3, pitch := false, tol := 0.03, max_frames := 120,
		from_body := false) -> void:
	var sens: float = rig.get("mouse_sensitivity")
	for i in max_frames:
		var cam: Camera3D = rig.call("get_camera")
		var from := player.global_position if from_body else cam.global_position
		var d := point - from
		var yaw_t := atan2(-d.x, -d.z)
		var err := wrapf(yaw_t - rig.global_rotation.y, -PI, PI)
		var rel := Vector2(-err / sens * 0.5, 0.0)
		var perr := 0.0
		if pitch:
			var fwd := -cam.global_basis.z
			var want := atan2(d.y, Vector2(d.x, d.z).length())
			var have := atan2(fwd.y, Vector2(fwd.x, fwd.z).length())
			perr = want - have
			rel.y = -perr / sens * 0.5
		if absf(err) < tol and (not pitch or absf(perr) < tol):
			return
		rel = rel.clamp(Vector2(-200, -120), Vector2(200, 120))
		RI.look(rel)
		await physics_frame


## Walk (W held, steering with the mouse) until within `arrive` metres of `point`, or give up.
func walk_to(point: Vector3, arrive := 1.5, max_s := 30.0, sneak := false) -> bool:
	var t := 0.0
	if sneak:
		RI.press(&"sneak")
	RI.press(&"move_forward")
	var last := player.global_position
	var stuck := 0.0
	while t < max_s:
		var flat := Vector2(point.x - player.global_position.x, point.z - player.global_position.z)
		if flat.length() < arrive:
			break
		await look_at_point(point, false, 0.08, 4, true)
		await physics_frame
		t += 1.0 / 60.0
		if player.global_position.distance_to(last) < 0.02:
			stuck += 1.0 / 60.0
		else:
			stuck = 0.0
		last = player.global_position
		if stuck > 1.5:
			# Step round whatever is in the way, the way a person would.
			RI.release(&"move_forward")
			RI.press(&"move_right")
			await wait(0.6)
			RI.release(&"move_right")
			RI.press(&"move_forward")
			stuck = 0.0
	RI.release(&"move_forward")
	if sneak:
		RI.release(&"sneak")
	await physics(4)
	return Vector2(point.x - player.global_position.x, point.z - player.global_position.z).length() < arrive


func hud_tip() -> String:
	var hud := ranch.get_node_or_null(^"HUD")
	var label := hud.find_child("Tip", true, false) as Label if hud != null else null
	return label.text if label != null and label.is_visible_in_tree() else ""


## Click through the conversation that is open, and stop when IT finishes: one more E would
## start a new one with whoever is in reach (Tumble follows you everywhere).
func talk_through(max_s := 60.0) -> void:
	var people: Node = ranch.get("people")
	if not bool(people.call("is_talking")):
		return
	var state := {"finished": false}
	var on_finish := func(_who: StringName, _id: StringName) -> void: state.finished = true
	people.connect("talk_finished", on_finish)
	var t := 0.0
	while t < max_s and not state.finished:
		var box := RI.find_text(root, "1.  ")
		if box != null and box is Button:
			await click(box)
		else:
			await tap(&"interact")
		await wait(0.35)
		t += 0.4
	people.disconnect("talk_finished", on_finish)
