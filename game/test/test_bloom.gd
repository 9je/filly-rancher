extends GutTest
## The Bloom curve (game/systems/bloom.gd): good care lands on its promise (about three
## minutes), every shortfall is a slowdown with a name rather than a silent freeze, crowding
## is a slope that never reaches zero (playtest 2026-11-08 item 2: a Grand pen of 8 froze at
## the old CROWDED_AT 7), and only hunger, a Calm Lamp or a mark already worn stop her.

const BloomScript := preload("res://systems/bloom.gd")


func _kept(extra := {}) -> Dictionary:
	var c := {"happiness": 1.0, "hunger": 0.1, "favorite_glow": 60.0, "has_friend": true,
		"pen_count": 2, "comfortable": 6, "calm_lamp": false, "marked": false}
	c.merge(extra, true)
	return c


func test_good_care_blooms_in_about_three_minutes() -> void:
	assert_almost_eq(BloomScript.seconds_to_bloom(_kept()), BloomScript.GOOD_CARE_SECONDS, 0.5)
	assert_between(BloomScript.GOOD_CARE_SECONDS, 150.0, 240.0, "the plan's 3 to 4 minutes")


func test_ordinary_food_is_still_under_four_and_a_half_minutes() -> void:
	var plain := BloomScript.seconds_to_bloom(_kept({"favorite_glow": 0.0}))
	assert_between(plain, 200.0, 270.0, "fed, a friend, room: about four minutes")


func test_a_full_grand_pen_still_blooms() -> void:
	# THE BUG: CROWDED_AT 7 against a Grand pen of 8 froze every pony in it, silently.
	var comfortable := BloomScript.comfortable_for(8)
	for n in range(1, 9):
		var c := _kept({"pen_count": n, "comfortable": comfortable})
		assert_gt(BloomScript.gain(c, 1.0), 0.0, "%d in a Grand pen still Bloom" % n)
	var full := BloomScript.seconds_to_bloom(_kept({"pen_count": 8, "comfortable": comfortable}))
	assert_lt(full, 400.0, "a packed Grand pen is slower, not stopped")


func test_crowding_is_a_gradual_slope() -> void:
	var last := INF
	var comfortable := BloomScript.comfortable_for(8)
	for n in range(comfortable, 13):
		var m := BloomScript.crowd_mult(n, comfortable)
		assert_true(m <= last, "one more pony never speeds her up")
		assert_true(m >= BloomScript.CROWD_FLOOR, "and never takes her below the floor")
		last = m
	assert_eq(BloomScript.crowd_mult(comfortable, comfortable), 1.0, "at the comfortable count, no slowdown")
	assert_lt(BloomScript.crowd_mult(comfortable + 1, comfortable), 1.0, "one past it, a little")


func test_comfortable_counts_by_pen() -> void:
	assert_eq(BloomScript.comfortable_for(3), 3, "a Paddock is never crowded")
	assert_eq(BloomScript.comfortable_for(6), 4)
	assert_eq(BloomScript.comfortable_for(8), 6)


func test_only_hunger_the_lamp_and_a_mark_stop_her() -> void:
	for blocker in [{"calm_lamp": true}, {"marked": true}, {"hunger": 0.9}]:
		assert_eq(BloomScript.gain(_kept(blocker), 10.0), 0.0, "blocked by %s" % blocker)
	for slower in [{"happiness": 0.2}, {"has_friend": false}, {"favorite_glow": 0.0},
			{"pen_count": 12}]:
		assert_gt(BloomScript.gain(_kept(slower), 10.0), 0.0, "%s slows her, never stops her" % slower)


func test_the_blocking_reason_is_the_worst_shortfall() -> void:
	assert_eq(BloomScript.status(_kept())["reason"], &"", "good care: nothing to fix")
	assert_eq(BloomScript.status(_kept({"hunger": 0.9}))["reason"], BloomScript.HUNGRY)
	assert_eq(BloomScript.status(_kept({"favorite_glow": 0.0}))["reason"], BloomScript.WRONG_FOOD)
	assert_eq(BloomScript.status(_kept({"has_friend": false}))["reason"], BloomScript.BORED)
	assert_eq(BloomScript.status(_kept({"pen_count": 10}))["reason"], BloomScript.CROWDED)
	# Both short: the bigger shortfall wins (crowded at 0.35 beats wrong food at 0.7).
	assert_eq(BloomScript.status(_kept({"pen_count": 12, "favorite_glow": 0.0}))["reason"],
		BloomScript.CROWDED)
	for r: StringName in [BloomScript.HUNGRY, BloomScript.WRONG_FOOD, BloomScript.CROWDED,
			BloomScript.BORED]:
		assert_ne(BloomScript.reason_words(r), "", "%s has words for the pen" % r)
	assert_eq(BloomScript.reason_words(BloomScript.WRONG_FOOD, "apples"), "Wants apples")


func test_favorite_and_friend_each_help() -> void:
	var none := BloomScript.gain(_kept({"favorite_glow": 0.0, "has_friend": false}), 1.0)
	var friend := BloomScript.gain(_kept({"favorite_glow": 0.0}), 1.0)
	var both := BloomScript.gain(_kept(), 1.0)
	assert_lt(none, friend)
	assert_lt(friend, both)


func test_friendship_follows_temperament() -> void:
	assert_true(BloomScript.are_friends(2, 1), "curious gets on with anyone")
	assert_true(BloomScript.are_friends(1, 0), "bold and shy")
	assert_false(BloomScript.are_friends(1, 1), "two bold ponies butt heads")
