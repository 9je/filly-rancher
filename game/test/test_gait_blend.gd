extends GutTest
## STARTS, STOPS AND TURNS (FS4.2; gap list item 4: "animation is clips sped up, no transitions
## or reactions"). systems/gait_blend.gd stands between a body's ground speed and its clip: a
## stop from a gallop steps down through the trot and the walk instead of snapping to idle, and
## a sharp turn leans her into it.

const GaitBlendScript := preload("res://systems/gait_blend.gd")
const GaitScript := preload("res://systems/gait.gd")
const DT := 1.0 / 60.0


func test_a_steady_speed_is_shown_as_it_is() -> void:
	var g := GaitBlendScript.new()
	var shown := 0.0
	for i in 120:
		shown = g.shown_speed(0.5, DT)
	assert_almost_eq(shown, 0.5, 0.001)
	assert_eq(g.clip(shown, true), &"walk", "0.5 m/s walks")


func test_a_stop_from_a_gallop_passes_through_the_trot_and_the_walk() -> void:
	var g := GaitBlendScript.new()
	for i in 60:
		g.clip(g.shown_speed(7.8, DT), true)
	var seen: Array[StringName] = []
	var t := 0.0
	while t < 2.0:
		var c := g.clip(g.shown_speed(0.0, DT), true)
		if seen.is_empty() or seen[-1] != c:
			seen.append(c)
		t += DT
	assert_eq(seen, [&"gallop", &"trot", &"walk", &"idle"] as Array[StringName])
	assert_eq(g.clip(g.shown_speed(0.0, DT), true), &"idle", "and she is standing within 2 s")


func test_the_settle_is_quick() -> void:
	var g := GaitBlendScript.new()
	for i in 60:
		g.clip(g.shown_speed(7.8, DT), true)
	var t := 0.0
	while g.clip(g.shown_speed(0.0, DT), true) != &"idle":
		t += DT
	assert_between(t, 0.3, 1.0, "a few settle steps, not a long skid (%.2f s)" % t)


func test_a_dip_in_speed_is_no_flicker() -> void:
	var g := GaitBlendScript.new()
	for i in 60:
		g.clip(g.shown_speed(2.2, DT), true)
	assert_eq(g.clip(g.shown_speed(2.2, DT), true), &"gallop", "2.2 m/s gallops")
	var seen: Array[StringName] = []
	var under := 0
	for i in 30:
		# Four frames under the gallop's band, then back up to speed.
		var shown := g.shown_speed(1.5 if i >= 10 and i < 14 else 2.2, DT)
		if shown < GaitScript.GALLOP_HANDOVER_SPEED:
			under += 1
		var c := g.clip(shown, true)
		if not c in seen:
			seen.append(c)
	assert_gt(under, 0, "the dip really left the gallop's band")
	assert_eq(seen, [&"gallop"] as Array[StringName], "a dip shorter than DWELL stays a gallop")


func test_a_start_is_not_held_back() -> void:
	var g := GaitBlendScript.new()
	var shown := 0.0
	for i in 10:
		shown = g.shown_speed(5.2, DT)
	assert_gt(shown, 4.0, "a sixth of a second gets her running")


func test_a_body_without_a_trot_steps_down_through_the_walk() -> void:
	var g := GaitBlendScript.new()
	for i in 60:
		g.clip(g.shown_speed(7.8, DT), false)
	var seen: Array[StringName] = []
	for i in 120:
		var c := g.clip(g.shown_speed(0.0, DT), false)
		if seen.is_empty() or seen[-1] != c:
			seen.append(c)
	assert_eq(seen, [&"gallop", &"walk", &"idle"] as Array[StringName])


func test_a_sharp_turn_leans_her_into_it_and_a_gentle_one_does_not() -> void:
	var g := GaitBlendScript.new()
	var roll := 0.0
	for i in 30:
		roll = g.lean(deg_to_rad(60.0), 5.0, DT)
	assert_almost_eq(roll, 0.0, 0.001, "60 deg/s is no lean")
	for i in 30:
		roll = g.lean(deg_to_rad(240.0), 5.0, DT)
	# She faces -Z, so her right side is +X and a positive roll about Z lifts it: a lean left.
	assert_gt(roll, deg_to_rad(3.0), "a fast left turn rolls her into it")
	assert_lt(roll, GaitBlendScript.LEAN_MAX + 0.001, "within the cap")
	for i in 30:
		roll = g.lean(deg_to_rad(-240.0), 5.0, DT)
	assert_lt(roll, -deg_to_rad(3.0), "and a right turn the other way")
	for i in 60:
		roll = g.lean(0.0, 5.0, DT)
	assert_almost_eq(roll, 0.0, deg_to_rad(0.5), "straight again, upright again")


func test_standing_she_does_not_lean() -> void:
	var g := GaitBlendScript.new()
	var roll := 0.0
	for i in 30:
		roll = g.lean(deg_to_rad(400.0), 0.0, DT)
	assert_almost_eq(roll, 0.0, 0.001, "turning on the spot is no bank")
