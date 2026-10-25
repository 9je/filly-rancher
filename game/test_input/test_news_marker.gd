extends "res://test_input/input_test.gd"
## OWNER PLAYTEST 2026-10-25: "i found marigold but it wasnt clear if you dont know the
## pony". From a fresh save: before the welcome, Marigold wears the gold "!" bubble; it is
## gone while she talks; the screen shows it (a screenshot is kept).


func _play() -> void:
	if not await boot_new_game():
		return
	if not await finish_creator():
		return
	await wait(1.0)
	await close_letter()
	var people: Node = ranch.get("people")
	var m: Node3D = people.call("npc", &"marigold")
	var seen := false
	var t := 0.0
	while t < 30.0 and not bool(people.call("is_talking")):
		if bool(people.call("shows_news", &"marigold")):
			seen = true
			if t > 0.5:
				await look_at_point(m.global_position + Vector3(0, 1.2, 0), true, 0.03, 30)
				_shot("news_marigold")
				break
		await wait(0.2)
		t += 0.2
	if not check(seen, "Marigold never wore the news bubble before her welcome"):
		return
	t = 0.0
	while t < 40.0 and not bool(people.call("is_talking")):
		await wait(0.2)
		t += 0.2
	await wait(0.5)
	if bool(people.call("is_talking")) and not check(not bool(people.call("shows_news", &"marigold")),
			"the bubble stays up while she is the one talking"):
		return
	ok("Marigold wears the gold bubble until she talks")


func _shot(tag: String) -> void:
	var dir := ProjectSettings.globalize_path("res://../build/playtest_evidence/round2/")
	DirAccess.make_dir_recursive_absolute(dir)
	root.get_texture().get_image().save_png(dir + tag + ".png")
