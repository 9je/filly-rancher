extends GutTest
## The ending table (game/systems/endings.gd, STORY.md section 6) as a truth table: every
## ending is reachable, each by the conditions the story gives it, and nothing ends before
## the climax except the Placement fail-forward.

const EndingsScript := preload("res://systems/endings.gd")


func _s(extra: Dictionary) -> Dictionary:
	var base := {"path": "", "climax": false, "placed": false, "rescued": 0, "delivered": 0,
		"allies": 0, "clover": false}
	base.merge(extra, true)
	return base


func test_no_ending_before_the_climax() -> void:
	assert_eq(EndingsScript.select(_s({"path": "factory"})), EndingsScript.NONE)
	assert_eq(EndingsScript.select(_s({"path": "rescue", "rescued": 50})), EndingsScript.NONE)
	assert_eq(EndingsScript.select(_s({})), EndingsScript.NONE)


func test_the_factory_endings() -> void:
	assert_eq(EndingsScript.select(_s({"path": "factory", "climax": true})), EndingsScript.BRIGHTEST_RAINBOW)
	assert_eq(EndingsScript.select(_s({"path": "factory", "climax": true, "rescued": 4})),
		EndingsScript.BRIGHTEST_RAINBOW)
	assert_eq(EndingsScript.select(_s({"path": "factory", "climax": true, "rescued": 5})),
		EndingsScript.GRAY_GOLD, "five ponies secretly saved is the mixed ending")


func test_lights_out_needs_everything() -> void:
	var full := {"path": "rescue", "climax": true, "rescued": 20, "allies": 3, "clover": true}
	assert_eq(EndingsScript.select(_s(full)), EndingsScript.LIGHTS_OUT)
	for missing in [{"rescued": 19}, {"allies": 2}, {"clover": false}, {"delivered": 1}]:
		var d := full.duplicate()
		d.merge(missing, true)
		assert_eq(EndingsScript.select(_s(d)), EndingsScript.HALF_LIGHT,
			"missing %s is Half Light" % missing)


func test_placement_is_the_fail_forward_and_beats_the_climax() -> void:
	assert_eq(EndingsScript.select(_s({"path": "rescue", "placed": true})), EndingsScript.PLACEMENT)
	assert_eq(EndingsScript.select(_s({"path": "rescue", "placed": true, "climax": true,
		"rescued": 30, "allies": 3, "clover": true})), EndingsScript.PLACEMENT)
	assert_eq(EndingsScript.select(_s({"path": "factory", "placed": true})), EndingsScript.NONE,
		"only the Rescue path's Heat can place you")


func test_every_ending_is_reachable_and_titled() -> void:
	var reached := {}
	for path in ["factory", "rescue"]:
		for climax in [true, false]:
			for rescued in [0, 5, 25]:
				for allies in [0, 3]:
					for clover in [false, true]:
						for placed in [false, true]:
							var e := EndingsScript.select(_s({"path": path, "climax": climax,
								"rescued": rescued, "allies": allies, "clover": clover, "placed": placed}))
							if e != EndingsScript.NONE:
								reached[e] = true
	for e in EndingsScript.ALL:
		assert_true(reached.has(e), "%s is reachable" % e)
		assert_ne(EndingsScript.title(e), "", "%s has a title" % e)
