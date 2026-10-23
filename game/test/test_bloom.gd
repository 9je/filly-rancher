extends GutTest
## The Bloom curve (game/systems/bloom.gd): the best case lands on its promise, nothing
## grows a mark on a hungry, crowded, Calm-Lamped or already-marked pony, and the bonuses
## stack in the order the GDD gives them.

const BloomScript := preload("res://systems/bloom.gd")


func _kept(extra := {}) -> Dictionary:
	var c := {"happiness": 1.0, "hunger": 0.1, "favorite_glow": 60.0, "has_friend": true,
		"pen_count": 2, "calm_lamp": false, "marked": false}
	c.merge(extra, true)
	return c


func test_the_best_case_blooms_on_schedule() -> void:
	assert_almost_eq(BloomScript.seconds_to_bloom(_kept()), BloomScript.BEST_CASE_SECONDS, 0.5)


func test_an_ordinary_fed_pony_takes_much_longer() -> void:
	var plain := BloomScript.seconds_to_bloom(_kept({"favorite_glow": 0.0, "has_friend": false, "happiness": 0.7}))
	# 8 to 30 minutes: the v1 fun pass (MISSION.md pacing) brought the first Bloom forward.
	assert_between(plain, 480.0, 1800.0, "about 8 to 30 minutes without the bonuses")


func test_nothing_blooms_when_it_should_not() -> void:
	for blocker in [{"calm_lamp": true}, {"marked": true}, {"hunger": 0.9}, {"happiness": 0.3},
			{"pen_count": BloomScript.CROWDED_AT}]:
		assert_eq(BloomScript.gain(_kept(blocker), 10.0), 0.0, "blocked by %s" % blocker)


func test_favorite_beats_friend_and_both_beat_neither() -> void:
	var none := BloomScript.gain(_kept({"favorite_glow": 0.0, "has_friend": false}), 1.0)
	var friend := BloomScript.gain(_kept({"favorite_glow": 0.0}), 1.0)
	var fav := BloomScript.gain(_kept({"has_friend": false}), 1.0)
	var both := BloomScript.gain(_kept(), 1.0)
	assert_lt(none, friend)
	assert_lt(friend, fav)
	assert_lt(fav, both)


func test_friendship_follows_temperament() -> void:
	assert_true(BloomScript.are_friends(2, 1), "curious gets on with anyone")
	assert_true(BloomScript.are_friends(1, 0), "bold and shy")
	assert_false(BloomScript.are_friends(1, 1), "two bold ponies butt heads")
