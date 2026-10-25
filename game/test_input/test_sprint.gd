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
	var run := await _speed([])
	var sprint := await _speed([&"sprint"])
	var sneak := await _speed([&"sneak"])
	note("run %.2f sprint %.2f sneak %.2f m/s" % [run, sprint, sneak])
	if not check(sprint >= run * 1.4, "Shift did not sprint: %.2f vs a run of %.2f m/s" % [sprint, run]):
		return
	if not check(sneak < run * 0.6, "C did not sneak: %.2f vs a run of %.2f m/s" % [sneak, run]):
		return
	ok("W runs %.1f m/s, Shift sprints %.1f m/s, C sneaks %.1f m/s" % [run, sprint, sneak])


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
