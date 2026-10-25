extends "res://test_input/input_test.gd"
## INPUT_TEST_REALTIME
## PLAYTEST NOTE "No loading screen after New Game. I thought it froze." THE ORDER: a loading
## screen with visible progress for New Game, Load and area transitions; nothing may freeze
## the screen for more than half a second without feedback.
##
## Played from the title with the mouse, exactly as the owner did, four times over:
##   1. New game          title -> creator (then "This is me" -> the ranch, the letter up)
##   2. Load game         the pause menu's Save game, then its Load game (the ranch reloads)
##   3. Continue          a fresh launch of the title, Continue -> the ranch
##   4. The lift          a save at Color Day morning; walk to Marigold at the Depot, talk,
##                        "Let's go." -> the Rainbow Factory (world/factory.tscn)
##
## THE MEASUREMENT. Every frame the main loop starts (SceneTree.process_frame), the test takes
## the wall clock and what the screen is showing: is the loading screen up, and what does its
## bar read. A gap between two frames is time the window showed one still picture. The gap a
## frame normally takes is the window's MEDIAN gap (on the real GPU about 16 ms; it absorbs a
## slow renderer if one is ever used), so a frame's STALL is its gap minus that median. A
## stall over STALL_LIMIT_S is a freeze, and a freeze is only allowed while the loading screen
## was on the picture the player was staring at AND its bar had moved on by the next frame
## (or the screen had finished). Each transition must also show the loading screen at all, with
## its bar taking at least three different values on the way. This runs in REAL time
## (no --fixed-fps): the thing measured is wall-clock time.
##
## THE COLOR DAY SAVE IS THE ONE THING NOT PLAYED. Reaching the lift by hand is hours of play
## (the invitation comes at the end of Act One), so step 4 writes the save a player has on that
## morning -- the ranch she made in steps 1 to 3, plus the two story flags Color Day needs --
## and then launches the title again and plays on from there with input only.

const STALL_LIMIT_S := 0.5

var _rec: Array[Dictionary] = []
var _recording := false
var _results: Array[String] = []
var _failures: Array[String] = []


func _play() -> void:
	_deadline_s = 900.0
	process_frame.connect(_on_frame)

	# --- 1. New game ------------------------------------------------------------------
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await frames(30)
	_start()
	if not await click_text("New game"):
		return
	if RI.find_text(root, "Really start over") != null:
		await click_text("New game")
	if not await _until(func() -> bool: return _creator_open(), 120.0, "the creator never opened"):
		return
	await frames(30)
	_judge("new game: title -> creator")

	_start()
	if not await click_text("This is me", 20.0):
		return
	if not await _until(func() -> bool: return _letter_open(), 60.0, "the welcome letter never opened"):
		return
	await frames(30)
	_judge("new game: This is me -> the ranch")
	await close_letter()
	await wait(1.0)

	# --- 2. Load game from the pause menu ----------------------------------------------
	await tap(&"pause")
	if not await click_text("Save game"):
		return
	await wait(0.5)
	var old_ranch: Node = ranch
	_start()
	if not await click_text("Load game"):
		return
	if not await _until(func() -> bool: return _ranch_booted(old_ranch), 120.0,
			"Load game never brought the ranch back"):
		return
	await frames(30)
	_judge("load game: pause menu -> the ranch")

	# --- 3. Continue from a fresh title -------------------------------------------------
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await frames(30)
	old_ranch = null
	_start()
	if not await click_text("Continue"):
		return
	if not await _until(func() -> bool: return _ranch_booted(old_ranch), 120.0,
			"Continue never reached the ranch"):
		return
	await frames(30)
	_judge("continue: title -> the ranch")

	# --- 4. The lift to the Rainbow Factory ---------------------------------------------
	var gs: Node = root.get_node("GameState")
	gs.get("story").call("set_flag", "invited")
	gs.get("story").call("set_flag", "color_day")
	gs.call("save_to_slot")
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await frames(30)
	if not await click_text("Continue"):
		return
	if not await _until(func() -> bool: return _ranch_booted(null), 120.0,
			"Continue (Color Day) never reached the ranch"):
		return
	var people: Node = ranch.get("people")
	var marigold: Node3D = people.call("npc", &"marigold")
	if not check(marigold != null, "Marigold is not on the map on Color Day"):
		return
	# Walk over the way a person does: close whatever letter pops up, read whatever
	# conversation starts, follow her if she moves off, and press E when she is in reach.
	note("walking to Marigold at %s from %s" % [marigold.global_position, player.global_position])
	var t0 := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - t0) / 1000.0 < 120.0:
		if bool(people.call("is_talking")) and people.get("_speaker") == &"marigold":
			break
		await _clear_popups()
		var d := player.global_position.distance_to(marigold.global_position)
		if d > 2.2:
			await walk_to(marigold.global_position, 2.0, 4.0)
			continue
		await look_at_point(marigold.global_position + Vector3(0, 0.8, 0))
		await tap(&"interact")
		await wait(0.3)
	if not check(bool(people.call("is_talking")) and people.get("_speaker") == &"marigold",
			"Marigold would not talk (at %.1f m)"
			% player.global_position.distance_to(marigold.global_position)):
		return
	var t := 0.0
	# Read through to the choice and take "Let's go."; the frame the lift is ridden starts
	# the measurement.
	var left := false
	t = 0.0
	while t < 30.0 and current_scene == ranch:
		var go := RI.find_text(root, "Let's go.")
		if go != null and go is Button:
			_start()
			await click(go)
			left = true
			break
		await tap(&"interact")
		await wait(0.35)
		t += 0.4
	if not check(left, "Marigold never offered the lift"):
		return
	# "Wonderful! Hold on to your hat." is one more line; the lift goes when it is read.
	t = 0.0
	while t < 20.0 and not _factory_up():
		if current_scene == ranch and bool(people.call("is_talking")):
			await tap(&"interact")
		await wait(0.3)
		t += 0.3
	if not await _until(func() -> bool: return _factory_up(), 120.0,
			"the lift never reached the Rainbow Factory"):
		return
	await frames(30)
	_judge("the lift: Depot -> the Rainbow Factory")

	for r in _results:
		print("INPUT_TEST_LOADING " + r)
	if _failures.is_empty():
		ok("every transition showed a moving loading screen over every stall")
	else:
		fail(" | ".join(_failures))


# --- what the screen is doing --------------------------------------------------------------

func _loading_screen() -> Node:
	return get_first_node_in_group(&"loading_screen")


func _on_frame() -> void:
	if not _recording:
		return
	var ls := _loading_screen()
	var showing := ls != null and bool(ls.call("is_showing"))
	if showing:
		_maybe_capture(ls)
	_rec.append({"t": Time.get_ticks_usec(), "loading": showing,
		"progress": float(ls.call("progress")) if showing else -1.0,
		"caption": String(ls.call("caption")) if showing else "",
		"scene": String(current_scene.name) if current_scene != null else "-"})


## The evidence: one picture of each look of the loading screen, mid-bar, as the window
## shows it (build/playtest_evidence/loading/). Reading the screen, not acting on it.
var _captured := {}


func _maybe_capture(ls: Node) -> void:
	var look := "factory" if int(ls.get("look")) == 1 else "ranch"
	var p := float(ls.call("progress"))
	if _captured.has(look) or p < (0.55 if look == "ranch" else 0.35):
		return
	_captured[look] = true
	var dir := ProjectSettings.globalize_path("res://").path_join("../build/playtest_evidence/loading")
	DirAccess.make_dir_recursive_absolute(dir)
	var img := root.get_texture().get_image()
	var path := dir.path_join("loading_%s.png" % look)
	img.save_png(path)
	note("captured %s at %.0f%%" % [path.simplify_path(), p * 100.0])


func _start() -> void:
	_rec.clear()
	_recording = true


func _judge(label: String) -> void:
	_recording = false
	var gaps: Array[float] = []
	for i in range(_rec.size() - 1):
		gaps.append((_rec[i + 1].t - _rec[i].t) / 1000000.0)
	if gaps.is_empty():
		_failures.append("%s: no frames recorded" % label)
		return
	var sorted := gaps.duplicate()
	sorted.sort()
	var median: float = sorted[sorted.size() / 2]
	var total: float = (_rec[-1].t - _rec[0].t) / 1000000.0
	var worst := 0.0
	var worst_uncovered := 0.0
	var stalls := 0
	var uncovered := 0
	var seen_loading := false
	var values := {}
	for i in gaps.size():
		var a: Dictionary = _rec[i]
		var b: Dictionary = _rec[i + 1]
		if a.loading:
			seen_loading = true
			values[snappedf(a.progress, 0.001)] = true
		var stall := gaps[i] - median
		worst = maxf(worst, stall)
		if stall <= STALL_LIMIT_S:
			continue
		stalls += 1
		var covered: bool = a.loading and (not b.loading or b.progress > a.progress)
		print("INPUT_TEST_STALL %s frame %d: %.2f s (gap %.2f s) loading=%s %.3f -> %s %.3f scene %s -> %s '%s' -> '%s'" % [
			label, i, stall, gaps[i], a.loading, a.progress, b.loading, b.progress, a.scene, b.scene,
			a.caption, b.caption])
		if not covered:
			uncovered += 1
			worst_uncovered = maxf(worst_uncovered, stall)
	var line := "%s: %.1f s, %d frames, median frame %.0f ms, worst stall %.2f s, %d stalls over %.1f s (%d with no moving loading screen, worst %.2f s), loading screen seen=%s with %d bar values" % [
		label, total, gaps.size(), median * 1000.0, worst, stalls, STALL_LIMIT_S, uncovered,
		worst_uncovered, seen_loading, values.size()]
	_results.append(line)
	print("INPUT_TEST_LOADING " + line)
	if uncovered > 0:
		_failures.append("%s: %d freeze(s) over %.1f s with no moving loading screen (worst %.2f s)"
			% [label, uncovered, STALL_LIMIT_S, worst_uncovered])
	elif total > STALL_LIMIT_S and (not seen_loading or values.size() < 3) \
			and not label.begins_with("new game: This is me"):
		# Taking the pony is a button in a menu already on screen, not a load.
		_failures.append("%s: took %.1f s and no loading screen with a moving bar was shown"
			% [label, total])


## A letter on screen gets its Close clicked; a conversation gets read through.
func _clear_popups() -> void:
	for i in 6:
		var lp: Node = ranch.get("letter_panel")
		if lp != null and bool(lp.call("is_open")):
			await click(lp.call("close_button_node"))
			await wait(0.3)
			continue
		var people: Node = ranch.get("people")
		if people != null and bool(people.call("is_talking")):
			if people.get("_speaker") == &"marigold":
				return
			await talk_through(20.0)
			continue
		return


func _until(cond: Callable, secs: float, why: String) -> bool:
	var t0 := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - t0) / 1000.0 < secs:
		if cond.call():
			return true
		await process_frame
	fail(why)
	return false


func _creator_open() -> bool:
	if not _bind_ranch():
		return false
	var cs: Node = ranch.get("creation_screen")
	return cs != null and bool(cs.call("is_open")) and RI.find_text(root, "This is me") != null \
		and not _loading_up()


func _letter_open() -> bool:
	var lp: Node = ranch.get("letter_panel")
	return lp != null and bool(lp.call("is_open"))


func _loading_up() -> bool:
	var ls := _loading_screen()
	return ls != null and bool(ls.call("is_showing"))


## The ranch is up and the player can play: a NEW ranch is the current scene, its boot has
## finished (every self-check and probe done), and nothing is covering it.
func _ranch_booted(not_this: Node) -> bool:
	var s := current_scene
	if s == null or s == not_this or not is_instance_valid(s) or s.get("people") == null:
		return false
	if not _bind_ranch():
		return false
	if s.get("boot_done") != null:
		return bool(s.get("boot_done")) and not _loading_up()
	# The code before this fix has no boot_done: the boot's last await is the self-check
	# report, after which the pause menu is wired; a bound pause menu is "playable".
	var pm: Node = s.get("pause_menu")
	return bool(s.get("_herd_ready")) and pm != null and pm.get("can_open") is Callable \
		and bool((pm.get("can_open") as Callable).call())


func _bind_ranch() -> bool:
	var s := current_scene
	if s == null or s.get("people") == null or s.get("player") == null:
		return false
	ranch = s
	player = s.get("player")
	rig = player.call("get_camera_pivot").get_node("CameraRig")
	return true


func _factory_up() -> bool:
	var s := current_scene
	return s != null and s is FactoryRun and s.get("player") != null and not _loading_up()
