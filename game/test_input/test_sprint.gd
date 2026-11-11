extends "res://test_input/input_test.gd"
## OWNER PLAYTEST 2026-10-25: "i dont like that i cant run". Shift used to be the sneak key,
## so holding it to run slowed her down. Now: W alone runs, W + Shift sprints (at least 1.4x
## the run), W + C sneaks (slower than the run), all by real key presses.


func _play() -> void:
	if not await boot_new_game():
		return
	if not await finish_creator():
		return
	await close_letter()
	await talk_through(30.0)
	# Run is a toggle that starts on (playtest 2026-11-10 item 75): W alone sprints, one
	# tap of Shift drops to the plain gait, a second tap brings the run back.
	# The welcome can still hold her for a moment after talk_through(): walk until she moves.
	RI.press(&"move_forward")
	var start: Vector3 = player.global_position
	var t := 0.0
	while t < 30.0 and player.global_position.distance_to(start) < 0.5:
		await wait(0.25)
		t += 0.25
	RI.release(&"move_forward")
	await wait(0.6)
	var sprint := await _speed([])
	await _tap(&"sprint")
	var run := await _speed([])
	await _tap(&"sprint")
	var back := await _speed([])
	var sneak := await _speed([&"sneak"])
	if not check(back >= run * 1.4, "the second Shift tap did not bring the run back: %.2f" % back):
		return
	note("run %.2f sprint %.2f sneak %.2f m/s" % [run, sprint, sneak])
	if not check(maxf(sprint, back) >= run * 1.4, "the default gait is not the run: %.2f vs a run of %.2f m/s" % [sprint, run]):
		return
	if not check(sneak < run * 0.6, "C did not sneak: %.2f vs a run of %.2f m/s" % [sneak, run]):
		return
	ok("W runs %.1f m/s after one Shift tap, by default sprints %.1f m/s, C sneaks %.1f m/s" % [run, maxf(sprint, back), sneak])


func _tap(action: StringName) -> void:
	RI.press(action)
	await wait(0.1)
	RI.release(action)
	await wait(0.1)


## Hold W (and `mods`) for two seconds; her ground speed over the last second.
func _speed(mods: Array) -> float:
	for m: StringName in mods:
		RI.press(m)
	RI.press(&"move_forward")
	await wait(1.0)
	var a: Vector3 = player.global_position
	await wait(1.0)
	var b: Vector3 = player.global_position
	RI.release(&"move_forward")
	for m: StringName in mods:
		RI.release(m)
	await wait(0.6)
	# Turn round so the next leg runs back over open ground.
	RI.look(Vector2(900, 0))
	await wait(0.3)
	return Vector2(b.x - a.x, b.z - a.z).length()
