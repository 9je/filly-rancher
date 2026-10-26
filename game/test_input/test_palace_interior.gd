extends "res://test_input/input_test.gd"
## OWNER PLAYTEST 2026-10-25: "spectra palace not real yet? weird sign you gotta walk through to
## get in". Played with W, the mouse and E, nothing else: a new game, the walk down to the
## Strip, straight up the Palace steps and through the doors (no key: walking in is going in),
## across the hall to a slot machine, E, the slots screen, Escape, back across the hall to the
## doors, E, and out onto the steps with her bits exactly as she took them in.
## SETUP, NOT PLAY: the grand opening flag (a quarter of an hour of play away on a new save,
## the way test_loading seeds story flags) and 77 bits to carry in and out.
## Screenshots go to build/playtest_evidence/round2/palace_interior_*.png.

const InteractionScript := preload("res://world/interaction.gd")
const PalaceInteriorScript := preload("res://world/palace_interior.gd")

var _shots := ""


func _play() -> void:
	_deadline_s = 600.0
	_shots = ProjectSettings.globalize_path("res://").path_join("../build/playtest_evidence/round2")
	DirAccess.make_dir_recursive_absolute(_shots)
	if not await boot_new_game():
		return
	if not await finish_creator():
		return
	await wait(1.0)
	await close_letter()
	await _settle(40.0)
	(ranch.get("_game_state").get("story") as Object).call("set_flag", "palace_open")
	var econ: Object = ranch.call("get_economy")
	econ.set("bits", 77)
	var clock: Object = ranch.get("_world")
	var t_before: float = float(clock.call("elapsed"))

	# 1. Down to the Strip by the road, round the town row, up the Palace steps.
	var palace: Node3D = ranch.get_node(^"Buildings/Palace")
	var out_dir: Vector3 = palace.global_basis.z
	var steps: Vector3 = palace.global_position + out_dir * (float(palace.get("depth")) * 0.5 + 0.9)
	for p: Vector3 in [Vector3(1.0, 0, 20.0), Vector3(1.0, 0, 51.5), Vector3(steps.x, 0, 52.5)]:
		await _walk(p, 1.2, 40.0)
	if not await _walk(steps, 0.45, 20.0):
		return
	note("at the Palace steps %s, prompt '%s'" % [player.global_position.snapped(Vector3.ONE * 0.1),
		_prompt()])
	if not check(_prompt().contains("go into the Spectra Palace"),
			"the Palace door does not say it goes in: '%s'" % _prompt()):
		return
	await look_at_point(palace.global_position + Vector3(0, 3.0, 0), true, 0.06, 60)
	await wait(0.3)
	_shot("palace_interior_0_doors.png")

	# 2. Walk straight in: W toward the doorway, no key.
	var door: Vector3 = palace.global_position + out_dir * (float(palace.get("depth")) * 0.5)
	var t := 0.0
	RI.press(&"move_forward")
	while t < 12.0 and not bool(ranch.call("is_in_palace")):
		await look_at_point(door, false, 0.08, 4)
		await physics_frame
		t += 1.0 / 60.0
	RI.release(&"move_forward")
	if not check(bool(ranch.call("is_in_palace")), "walking into the doorway did not take her in"):
		return
	while bool(ranch.get("_palace_moving")):
		await wait(0.1)
	await wait(0.5)
	note("inside at %s after %.1f s of walking" % [player.global_position.snapped(Vector3.ONE * 0.1), t])
	if not check(int(econ.get("bits")) == 77, "going in changed her bits (%d)" % int(econ.get("bits"))):
		return
	_shot("palace_interior_1_arrival.png")

	# 3. Across the hall to the nearest free slot machine.
	var hall: Node3D = ranch.get("palace_interior")
	var slot := _nearest(hall.call("station_points", &"slots") as Array, player.global_position)
	var floor_y: float = player.global_position.y
	for p: Vector3 in [hall.to_global(Vector3(0, 0, 9.0)), hall.to_global(Vector3(-8.5, 0, 4.0)),
			Vector3(slot.x, floor_y, slot.z)]:
		await _walk(p, 0.7, 25.0)
	if not check(_prompt().contains("play the slots"),
			"at the slot machine the prompt is '%s'" % _prompt()):
		return
	# The camera, swung all the way round against the west wall, stays in the room.
	var bad: int = await _sweep_in(hall)
	if not check(bad == 0, "%d frames had the camera outside the hall at the slots" % bad):
		return
	await tap(&"interact")
	await wait(0.6)
	var slots: Node = ranch.get("slots_menu")
	if not check(bool(slots.call("is_open")), "E at the slot machine did not open the slots"):
		return
	_shot("palace_interior_2_slots_screen.png")
	await tap(&"ui_cancel")
	await wait(0.6)
	if not check(not bool(slots.call("is_open")), "Escape did not close the slots"):
		return

	# 4. Back to the doors and out.
	var exit: Vector3 = hall.call("station_point", &"exit")
	for p: Vector3 in [hall.to_global(Vector3(-7.0, 0, 5.0)), hall.to_global(Vector3(0, 0, 9.5)),
			Vector3(exit.x, floor_y, exit.z)]:
		await _walk(p, 0.6, 25.0)
	if not check(_prompt().contains("leave the Palace"), "at the doors the prompt is '%s'" % _prompt()):
		return
	bad = await _sweep_in(hall)
	if not check(bad == 0, "%d frames had the camera outside the hall at the doors" % bad):
		return
	await look_at_point(exit + Vector3(0, 1.0, 1.5), false, 0.05, 90)
	_shot("palace_interior_3_way_out.png")
	await tap(&"interact")
	await wait(1.4)
	if not check(not bool(ranch.call("is_in_palace")), "E at the doors did not take her out"):
		return
	var flat := Vector2(player.global_position.x - palace.global_position.x,
		player.global_position.z - palace.global_position.z).length()
	if not check(flat < 9.0 and player.global_position.y > palace.global_position.y - 3.0,
			"she came out somewhere else: %s" % player.global_position):
		return
	if not check(int(econ.get("bits")) == 77, "the visit changed her bits (%d)" % int(econ.get("bits"))):
		return
	if not check(float(clock.call("elapsed")) > t_before, "the clock stopped while she was inside"):
		return
	await wait(0.5)
	_shot("palace_interior_4_back_outside.png")
	ok("walked in through the doors, played the slots screen, walked out with her 77 bits")


## Swing the mouse a full turn and a half, then pitch it from the floor to the ceiling and
## back, checking every frame that the lens is inside the hall's own walls, floor and ceiling.
## Returns the number of frames it was not.
func _sweep_in(hall: Node3D) -> int:
	var bad := 0
	var cam: Camera3D = rig.call("get_camera")
	var moves: Array[Vector2] = []
	for i in 90:
		moves.append(Vector2(30, 0))
	for i in 20:
		moves.append(Vector2(0, 40))
	for i in 40:
		moves.append(Vector2(12, -40))
	for i in 20:
		moves.append(Vector2(0, 40))
	for m: Vector2 in moves:
		RI.look(m)
		await process_frame
		var p: Vector3 = hall.to_local(cam.global_position)
		var inside: bool = absf(p.x) < PalaceInteriorScript.HALF_WIDTH - 0.05 \
			and absf(p.z) < PalaceInteriorScript.HALF_DEPTH - 0.05 \
			and p.y > 0.05 and p.y < PalaceInteriorScript.HEIGHT - 0.05
		if not inside:
			bad += 1
			if bad < 4:
				note("camera outside the hall at %s" % p.snapped(Vector3.ONE * 0.01))
	return bad


func _walk(p: Vector3, arrive: float, secs: float) -> bool:
	if bool(ranch.get("people").call("is_talking")):
		await talk_through(20.0)
	return await walk_to(p, arrive, secs)


func _nearest(points: Array, to: Vector3) -> Vector3:
	var best: Vector3 = points[0]
	for p: Vector3 in points:
		if p.distance_to(to) < best.distance_to(to):
			best = p
	return best


func _prompt() -> String:
	var hud := ranch.get_node_or_null(^"HUD")
	return str(hud.call("prompt_text")) if hud != null else ""


func _shot(file: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(_shots.path_join(file))
	note("screenshot %s" % _shots.path_join(file))


## Read the screen the way a person would: a conversation or a letter in the way is read and
## closed before anything else.
func _settle(secs: float) -> void:
	var people: Node = ranch.get("people")
	var lp: Node = ranch.get("letter_panel")
	var t := 0.0
	var quiet := 0.0
	while t < secs and quiet < 4.0:
		if bool(people.call("is_talking")):
			await talk_through()
			quiet = 0.0
		elif bool(lp.call("is_open")):
			await click(lp.call("close_button_node"))
			quiet = 0.0
		else:
			quiet += 0.2
		await wait(0.2)
		t += 0.2
