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
