extends GutTest
## The score (game/systems/music.gd): a change of context cut short never leaves a third
## track playing, and nothing in it reaches for a player before _ready made them.

const MusicScript := preload("res://systems/music.gd")


func test_calls_before_ready_do_not_crash() -> void:
	var m: Node = MusicScript.new()
	autofree(m)
	m.set_dread(0.5)
	m.stop_all()
	m.play_context(&"day")
	assert_eq(m.context, &"day")


func test_quick_changes_leave_at_most_two_players_going() -> void:
	var m: Node = MusicScript.new()
	add_child_autofree(m)
	for ctx in [&"day", &"town", &"night", &"casino", &"", &"day"]:
		m.play_context(ctx)
	var going := 0
	for n in [m.get("_a"), m.get("_b")]:
		if (n as AudioStreamPlayer).playing:
			going += 1
	assert_lte(going, 2)
	m.play_context(&"")
	m.play_context(&"day")
	m.play_context(&"")
	var still := 0
	for n in [m.get("_a"), m.get("_b")]:
		if (n as AudioStreamPlayer).playing:
			still += 1
	assert_lte(still, 1, "only the one fading out is left; the stale one was stopped")


## FS5.2: a sting over the bed on the moments that matter, the bed dipping for it and coming
## back when it is done.
func test_a_sting_dips_the_bed_and_lets_it_back_up() -> void:
	var m: Node = get_node("/root/Music")
	assert_true(bool(m.call("stinger", &"delivery")))
	await wait_frames(10)
	assert_lt(float(m.get("duck_db")), -1.0, "the bed dips under the sting")
	await wait_seconds(float(m.call("sting_seconds", &"delivery")) + 0.6)
	assert_almost_eq(float(m.get("duck_db")), 0.0, 0.01, "and is back once it is done")


func test_an_unknown_sting_plays_nothing() -> void:
	var m: Node = get_node("/root/Music")
	assert_false(bool(m.call("stinger", &"no_such_sting")))


func test_every_moment_has_its_sting() -> void:
	var m: Node = get_node("/root/Music")
	for id: StringName in [&"first_catch", &"rare", &"delivery", &"bloom"]:
		assert_true(ResourceLoader.exists(String(m.STINGS[id])), String(id))
