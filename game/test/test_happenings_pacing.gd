extends GutTest
## WORLD EVENTS ARE SPACED AND WAIT FOR A PERSON (playtest 2026-11-10 items 3, 5, 6).
## A stand-in ranch: Happenings only asks it a handful of things.

const HappeningsScript := preload("res://world/happenings.gd")
const GameStateScript := preload("res://systems/game_state.gd")


class FakeRanch:
	extends Node3D
	var _game_state: Node
	var player: Node3D
	var people: Node = null
	var _in_palace := false
	var _interactive := true
	var terrain: Node = null
	var toasts: Array[String] = []

	func _no_other_menu_open() -> bool:
		return true

	func _toast(text: String) -> void:
		toasts.append(text)

	func _novelty(_k: String, id: String, label: String) -> bool:
		return _game_state.note_novelty("event", id, label)

	func get_world_state() -> WorldState:
		return null

	func _bag() -> Storage:
		return null


## The ladder's events stand in as marks: what is under test is when they fire.
class QuietHappenings:
	extends "res://world/happenings.gd"
	func _rainboom() -> void:
		_mark("rainboom")
	func _derpy_mail() -> void:
		_mark("derpy_mail")
	func _trixie_show() -> void:
		_mark("trixie_show")
	func _sighting() -> bool:
		return false


var _ranch: FakeRanch
var _h: Happenings


func before_each() -> void:
	_ranch = FakeRanch.new()
	add_child_autofree(_ranch)
	_ranch._game_state = GameStateScript.new()
	autofree(_ranch._game_state)
	_ranch.player = Node3D.new()
	_ranch.add_child(_ranch.player)
	_h = QuietHappenings.new()
	_h.ranch = _ranch
	add_child_autofree(_h)


## Drive the ladder `seconds` of play, one check a second, the player walking about unless
## `still`.
func _run(seconds: int, still := false) -> void:
	for i in seconds:
		_ranch._game_state.play_seconds += 1.0
		if not still:
			_ranch.player.position.x += 1.0
		_h._check_t = 1.0
		_h._last_check_ms = Time.get_ticks_msec() - 1000
		_h._physics_process(0.0)


func _happened() -> Array:
	return _ranch._game_state.story.get_var("happened", [])


func test_a_backlog_of_events_comes_one_at_a_time_not_all_at_once() -> void:
	# An hour in the Palace: rainboom, derpy and trixie are all due at once.
	_ranch._game_state.story.set_flag("palace_open")
	_ranch._game_state.play_seconds = 64.0 * 60.0
	for id in ["sun_shower", "palace_flyer", "newsletter", "race_day", "lost_foal",
			"collector_visit", "starry"]:
		_ranch._game_state.story.set_var("happened", _happened() + [id])
	_run(5)
	assert_eq(_happened().size(), 8, "one event fired, not three: %s" % str(_happened()))
	_run(int(HappeningsScript.EVENT_GAP) - 10)
	assert_eq(_happened().size(), 8, "the next waits out EVENT_GAP")
	_run(15)
	assert_eq(_happened().size(), 9, "then the next")


func test_nothing_fires_while_she_stands_idle() -> void:
	# She walks away from the keyboard before anything is due ...
	_ranch._game_state.play_seconds = 60.0
	_run(int(HappeningsScript.IDLE_HOLD) + 5, true)
	# ... and an hour of play time passes while she is gone.
	_ranch._game_state.play_seconds = 64.0 * 60.0
	_ranch._game_state.story.set_flag("palace_open")
	_run(30, true)
	assert_eq(_happened().size(), 0, "fired while she was away: %s" % str(_happened()))
	_run(3)
	assert_gt(_happened().size(), 0, "she is back: the world goes on")


func test_race_day_is_quiet_if_she_has_raced_already() -> void:
	_ranch._game_state.note_novelty("mechanic", "first_race", "First race at the track")
	_h._race_day()
	assert_eq(_ranch.toasts.size(), 0, "no invitation to what she has done: %s" % str(_ranch.toasts))
	assert_true("race_day" in _happened())
