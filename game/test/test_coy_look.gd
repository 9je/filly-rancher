extends GutTest
## THE LOOK THE OWNER LIKED, ON PURPOSE (PS1, playtest 2026-11-05 item 67: "The half-lidded
## 'looking at you' eyes switch off as you get close (backwards). The owner LIKED them: keep
## them, make them deliberate and shared by more ponies"). A calm pony the player comes near
## gives her the look at ANY distance inside COY_RADIUS, close up included; Drifters and shy
## ponies too; and it is a moment (COY_HOLD seconds, her eyes on the player), then it rests a
## while before it can come again, rather than a face she wears the whole time.

const PonyScript := preload("res://actors/pony/pony.gd")


func test_close_up_is_when_she_gives_it_not_when_it_stops() -> void:
	for d: float in [0.8, 1.5, 2.0, 5.0, 12.0]:
		assert_true(PonyScript.coy_near(d, true), "%.1f m away and calm: the look" % d)
	assert_false(PonyScript.coy_near(PonyScript.COY_RADIUS + 1.0, true), "too far to notice")
	assert_false(PonyScript.coy_near(1.0, false), "not while frightened or held")


func test_every_kind_of_pony_has_it() -> void:
	# The look no longer needs named data or a bold heart: a Drifter and a shy pony give it.
	assert_true(PonyScript.coy_allowed(null), "a Drifter (stock, no PonyData)")
	var shy := PonyData.new()
	shy.personality = PonyData.Personality.SHY
	assert_true(PonyScript.coy_allowed(shy), "a shy pony, a shy glance")


func test_it_is_a_moment_then_a_rest() -> void:
	var st := {}
	assert_true(PonyScript.coy_next(st, true, 0, 0.5), "she notices: the look")
	assert_true(PonyScript.coy_next(st, true, int(PonyScript.COY_HOLD * 1000.0) - 100, 0.5), "held")
	assert_false(PonyScript.coy_next(st, true, int(PonyScript.COY_HOLD * 1000.0) + 100, 0.5),
		"then she looks away, though the player is still near")
	assert_false(PonyScript.coy_next(st, true, int((PonyScript.COY_HOLD + 15.0) * 1000.0), 0.5),
		"and rests")
	var back := int((PonyScript.COY_HOLD + PonyScript.COY_REST.y + 1.0) * 1000.0)
	assert_true(PonyScript.coy_next(st, true, back, 0.5), "and gives it again later")


func test_walking_away_ends_it() -> void:
	var st := {}
	PonyScript.coy_next(st, true, 0, 0.5)
	assert_false(PonyScript.coy_next(st, false, 500, 0.5))
