extends GutTest
## The Rescue path's places (game/world/act3_world.gd): a Collector's lantern counts only in
## the dark, and a raid with too small a bag leaves the corral open for the rest.

const Act3WorldScript := preload("res://world/act3_world.gd")
const StoryScript := preload("res://systems/story.gd")
const StoryV1Script := preload("res://systems/story_v1.gd")
const Rules := preload("res://systems/path_rules.gd")


func _world(night: bool) -> Act3World:
	var w: Act3World = Act3WorldScript.new()
	w.story = StoryScript.new()
	StoryV1Script.choose_path(w.story, "rescue")
	w.is_night = func() -> bool: return night
	autofree(w)
	return w


func test_a_lantern_by_day_adds_no_heat() -> void:
	var w := _world(false)
	w._on_spotted()
	assert_eq(Rules.heat(w.story), 0)


func test_a_lantern_at_night_does() -> void:
	var w := _world(true)
	w._on_spotted()
	assert_eq(Rules.heat(w.story), Rules.HEAT.spotted)


func test_a_small_bag_leaves_the_corral_open() -> void:
	var w := _world(true)
	var corral := Node3D.new()
	w.add_child(corral)
	for i in 3:
		var p := Node3D.new()
		p.set_meta(&"penned", true)
		corral.add_child(p)
	var room := [2]
	w.bag_room = func() -> int: return room[0]
	w.bag_store = func(_inst: PonyInstance) -> bool:
		room[0] -= 1
		return true
	var site := {"id": "corral_orchard", "kind": "corral", "node": corral, "hold": 1.0}
	var r: Dictionary = w._raid(site)
	assert_eq(int(r.freed), 2)
	assert_false("corral_orchard" in (w.story.get_var("raided", []) as Array), "one still inside")
	room[0] = 5
	r = w._raid(site)
	assert_eq(int(r.freed), 1)
	assert_true("corral_orchard" in (w.story.get_var("raided", []) as Array))
	assert_eq(Rules.heat(w.story), Rules.HEAT.raid * 3)
