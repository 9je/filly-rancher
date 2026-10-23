extends GutTest
## The Color Day reveal (game/world/factory_run.gd) runs end to end headless, fast, through
## both of the window's choices, and each choice sets the path the endings read.

const FactoryScene := preload("res://world/factory.tscn")
const FactoryRunScript := preload("res://world/factory_run.gd")
const StoryV1Script := preload("res://systems/story_v1.gd")

var _gs: Node
var _saved: Dictionary


func before_each() -> void:
	_gs = get_node_or_null("/root/GameState")
	if _gs != null:
		_gs.reset()


func _run(pin: StringName) -> Array:
	FactoryRunScript.mode = &"reveal"
	var f: Node3D = FactoryScene.instantiate()
	f.skip_waits = true
	f.outcome = pin
	var steps: Array = []
	f.step_reached.connect(func(s: StringName) -> void: steps.append(s))
	add_child_autofree(f)
	await wait_for_signal(f.finished, 60.0)
	return [f, steps]


func test_signing_the_contract_takes_the_factory_path() -> void:
	var r: Array = await _run(&"factory")
	var f: Node3D = r[0]
	var steps: Array = r[1]
	assert_eq(f.outcome, &"factory")
	for s in [&"landing", &"welcome", &"classroom", &"giftshop", &"walkway", &"gallery",
			&"window_done", &"choice", &"contract"]:
		assert_has(steps, s, "the reveal passes %s" % s)
	if _gs != null:
		assert_eq(StoryV1Script.path(_gs.story), "factory")


func test_running_for_tumble_takes_the_rescue_path() -> void:
	var r: Array = await _run(&"rescue")
	var f: Node3D = r[0]
	var steps: Array = r[1]
	assert_eq(f.outcome, &"rescue")
	for s in [&"window_done", &"choice", &"escape_grab", &"escape_run", &"lift"]:
		assert_has(steps, s, "the escape passes %s" % s)
	if _gs != null:
		assert_eq(StoryV1Script.path(_gs.story), "rescue")
		assert_eq(_gs.story.chapter, Story.Chapter.RESISTANCE)
