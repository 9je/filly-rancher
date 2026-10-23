extends GutTest
## People in the world (game/world/people.gd): the cast stands where SPOTS puts her, only
## the nearest one in reach is a TALK candidate, a conversation runs to its end through the
## talk box's signals, and what it does comes out as effects.

const PeopleScript := preload("res://world/people.gd")
const InteractionScript := preload("res://world/interaction.gd")

var _people: People
var _player: Node3D
var _flags := {}


func before_each() -> void:
	_flags = {}
	_player = Node3D.new()
	add_child_autofree(_player)
	_people = PeopleScript.new()
	_people.player = _player
	_people.context_provider = func() -> Dictionary:
		return {"chapter": 0, "path": "", "flags": _flags, "counts": {}, "name": "Juniper", "tumble": "Tumble"}
	_people.presence = func(id: StringName) -> bool: return id != &"static" and id != &"clover"
	add_child_autofree(_people)
	_people.effect.connect(func(kind: StringName, value: String) -> void:
		if kind == &"flag":
			_flags[value] = true)
	_people.populate()
	await wait_physics_frames(2)


func test_the_present_cast_stands_and_the_absent_do_not() -> void:
	for id in [&"marigold", &"fennel", &"pip", &"bramble", &"tumble"]:
		assert_not_null(_people.npc(id), "%s stands" % id)
	assert_null(_people.npc(&"static"), "Static is only around on the Rescue path")
	var m := _people.npc(&"marigold")
	assert_almost_eq(m.global_position.x, PeopleScript.SPOTS[&"marigold"][0].x, 0.5)


func test_only_someone_in_reach_is_a_talk_candidate() -> void:
	var far := _people.candidates(Vector3(500, 0, 500))
	assert_eq(far.size(), 0)
	var at: Vector3 = PeopleScript.SPOTS[&"fennel"][0] + Vector3(1.0, 0, 0)
	var near := _people.candidates(at)
	assert_eq(near.size(), 1)
	assert_eq(int(near[0].kind), InteractionScript.Kind.TALK)
	assert_eq(String(near[0].subject), "Old Fennel")


func test_marigolds_arrival_runs_to_the_end_and_hands_over_the_scoop() -> void:
	assert_true(_people.talk("marigold"))
	assert_true(_people.is_talking())
	assert_true(_people.talk_box.is_open())
	var steps := 0
	while _people.is_talking() and steps < 40:
		if _people.runner.has_choices():
			_people.talk_box.chose.emit(0)
		else:
			_people.talk_box.advanced.emit()
		steps += 1
	assert_false(_people.is_talking(), "the conversation ended")
	assert_false(_people.talk_box.is_open(), "and the bubble closed")
	assert_true(_flags.get("has_scoop", false), "she set the has_scoop flag")
	assert_true(_people.library.seen.has("marigold_arrival"), "and it is not offered again")


func test_a_character_with_nothing_new_still_has_a_bark() -> void:
	_people.library.mark_seen(&"marigold_arrival")
	_flags["has_scoop"] = true
	assert_false(_people.has_news(&"marigold"))
	assert_true(_people.talk("marigold"), "a bark is still something to say")
