extends GutTest
## Tests for the pure rules underneath the magic beam (game/actors/player/magic_beam.gd).
##
## The beam itself is a scene-level thing -- it needs a camera, a physics space and a live
## pony to mean anything, and that is what scenes/test/capture_test.tscn exists for. What
## is pinned HERE is the arithmetic the scene cannot isolate: the two clocks that make a
## capture a contest, the struggle times that make the three personalities feel different,
## and the zoom-invariance of the reach and hold distances. All are static and pure
## precisely so they can be checked in milliseconds instead of inferred from where a pony
## ended up 200 frames into a render.
##
## THE FIRST PLAYTEST REWROTE HALF OF THIS FILE, and the reason is worth stating plainly:
## a test here USED to assert that the beam out-reaches a pony's detection radius, and it
## was green, and it was pinning the project's worst gameplay bug in place. Numbers that
## are individually reasonable can still be wrong RELATIVE to each other, and a test that
## states the wrong relationship confidently is worse than no test at all. See
## test_a_pony_notices_the_player_before_the_beam_can_reach_her.
##
## Preloads by path rather than by the global class_name, matching the convention
## documented at the top of game/scripts/pony_rig.gd.

const MagicBeamScript := preload("res://actors/player/magic_beam.gd")
const PonyDataScript := preload("res://systems/pony_data.gd")
## The gear tests below need a LIVE beam rather than the static rules, so they need the
## player it hangs off; the notice-invariant test needs Pony.notice_radius_for(), which is
## static and pure and wants no pony in the world at all.
const PlayerScene := preload("res://actors/player/player.tscn")
const PonyScript := preload("res://actors/pony/pony.gd")
## The body a stock pony's colours are minted off, and the record her instance resolves to.
const PonyScene := preload("res://actors/pony/pony.tscn")
const PonyRegistryScript := preload("res://systems/pony_registry.gd")

## Floor for the beam fixture, matching game/test/test_player.gd: big enough that nothing
## here can walk off it.
const FIXTURE_FLOOR_SIZE := Vector3(40.0, 1.0, 40.0)

## A full, un-anticipated visual reaction time -- press-and-release to a flash, with no
## warning that it is coming. The bar the capture windows are held to below, and it is
## deliberately HARSHER than what the mechanic actually asks of a player: the catch ring
## fills toward a visible finish line, so a real release is anticipated rather than
## reacted to, and anticipated timing lands inside about a tenth of a second. Clearing the
## harsher bar on every grade's WORST roll is the margin that stops "tight" turning into
## "unfair" -- which is the acceptance criterion the owner put above every number here
## ("i dont want the mechanic to get annoying").
const REACTION_TIME := 0.25

## How many independent seeded streams the wrench sweeps below run. Large enough that a
## first-attempt wrench chance of 0.5 cannot go unobserved by luck (the chance of that is
## 2^-1000), small enough to stay a millisecond-scale unit test.
const SEED_SWEEP := 1000

## The most grabs a design may ask of a player before a wrenching pony has to be catchable,
## asserted independently of what MagicBeam.WRENCH_GRACE_HOLDS happens to say.
##
## THE FAILURE PROOF EARNED THIS CONSTANT. Breaking MagicBeam.WRENCH_CHANCE_FALLOFF to a
## millionth leaves the wrench chance still reaching zero -- after five million grabs -- and
## WRENCH_GRACE_HOLDS is DERIVED from the falloff, so every test phrased as "she is caught
## inside WRENCH_GRACE_HOLDS attempts" stayed green while a pony could in practice fight the
## player off indefinitely. A bound that is computed from the thing it is bounding is not a
## bound. This is the outside opinion, and the loops below are capped by it so a broken
## falloff fails in milliseconds instead of hanging the suite.
const MAX_HONEST_ATTEMPTS := 3


func test_bold_ponies_struggle_sooner_than_curious_ones_and_shy_ones() -> void:
	# INVERTED BY THE SECOND PLAYTEST, and the direction is the whole point -- this test
	# asserted the opposite until then, and was green while pinning a build the owner
	# called impossible. A SHY pony FREEZES in the beam (she is too frightened to fight)
	# and a BOLD one thrashes (she was never frightened of you in the first place). See
	# the STRUGGLE_* block in magic_beam.gd.
	var shy: float = MagicBeamScript.struggle_seconds_for(PonyDataScript.Personality.SHY)
	var curious: float = MagicBeamScript.struggle_seconds_for(PonyDataScript.Personality.CURIOUS)
	var bold: float = MagicBeamScript.struggle_seconds_for(PonyDataScript.Personality.BOLD)
	assert_lt(bold, curious, "a BOLD pony must break free before a CURIOUS one")
	assert_lt(curious, shy, "...and a CURIOUS one before a SHY one")


func test_every_struggle_time_outlasts_the_pull_in() -> void:
	# The floor that makes the mechanic playable at all: a pony who breaks free before she
	# has even reached the hold point is one the player never got to see. The pull closes
	# 90% of the gap in ln(10)/PULL_RESPONSE seconds; a struggle time under that would
	# make her grade unobservable rather than merely difficult.
	#
	# QUANTIFIED OVER THE WORST ROLL OF EVERY GRADE, and over a WRENCHING attempt too --
	# which is the one that could plausibly break it, since a wrench deliberately rolls a
	# struggle time SHORTER than its own subdue clock. A wrench that landed inside the reel
	# would read as the beam failing to pick her up rather than as her winning, and it is
	# the one place in this design where "she escaped" and "it is broken" look alike.
	var pull_in: float = log(10.0) / MagicBeamScript.PULL_RESPONSE
	for personality in PonyDataScript.Personality.values():
		var who: String = PonyDataScript.Personality.keys()[personality]
		var worst: float = MagicBeamScript.secure_bounds().x \
			+ MagicBeamScript.window_bounds_for(personality).x
		assert_gt(worst, pull_in * 2.0,
			"%s must resist for longer than the beam takes to reel her in (%.3f s)" % [
				who, pull_in])
	var earliest_wrench: float = MagicBeamScript.secure_bounds().x * MagicBeamScript.WRENCH_AT_MIN
	assert_gt(earliest_wrench, pull_in,
		("the EARLIEST a wrench can land (%.3f s) must be past the reel (%.3f s), or she " +
		"tears free before the player has seen what they grabbed") % [earliest_wrench, pull_in])


func test_an_unknown_personality_gets_the_hard_grade_rather_than_a_broken_one() -> void:
	# A roster addition with a personality this file has not heard of must not become an
	# uncatchable (or instantly-escaping) pony.
	assert_eq(MagicBeamScript.grade_for(99), MagicBeamScript.Grade.HARD,
		"an unknown personality falls back to the HARD grade")
	var fallback: float = MagicBeamScript.capture_window_for(99)
	assert_eq(fallback, MagicBeamScript.WINDOW_HARD,
		"...and therefore to the HARD window")
	# HARD is the STRICTEST hold since the second playtest's inversion, so this fallback
	# stopped being the forgiving one. It still has to leave a window a human can hit --
	# checked against the WORST roll, not the nominal one -- or a roster addition with an
	# unrecognised personality would be flatly uncatchable on a bad day.
	var floor_seconds: float = MagicBeamScript.window_bounds_for(99).x
	assert_gt(floor_seconds, REACTION_TIME,
		("the fallback's WORST roll must still leave more than a reaction time (%.3f s " +
		"against %.2f s)") % [floor_seconds, REACTION_TIME])
	# ...and it must be able to wrench, because the fallback grade is the wrenching one:
	# a fallback that quietly lost the wrench would make an unknown personality EASIER
	# than the grade it claims to be.
	assert_gt(MagicBeamScript.wrench_chance_for(99, 0), 0.0,
		"an unknown personality is graded HARD, so she can wrench like any other HARD pony")


func test_the_hold_point_sits_hold_lead_metres_past_the_player() -> void:
	var origin := Vector3(0.0, 2.0, 5.0)
	var direction := Vector3(0.0, 0.0, -1.0)
	var anchor := Vector3(0.0, 2.0, 1.5)  # 3.5 m along the ray -- a default-zoom camera
	var point: Vector3 = MagicBeamScript.hold_point(origin, direction, anchor)
	var along: float = (point - anchor).dot(direction)
	assert_almost_eq(along, MagicBeamScript.HOLD_LEAD, 0.0001,
		"the hold point is HOLD_LEAD past the player, measured ALONG the ray")


func test_the_hold_point_is_offset_off_the_ray_so_the_player_does_not_hide_it() -> void:
	# The bug the first offscreen render caught: with the hold point dead on the aim ray,
	# a held pony sits exactly behind the player's own body from the camera's point of
	# view and is completely invisible. Every number was green; the picture was of nothing
	# happening. The offset is what makes the mechanic visible, so it is pinned here.
	var origin := Vector3(0.0, 2.0, 5.0)
	var direction := Vector3(0.0, 0.0, -1.0)
	var anchor := Vector3(0.0, 2.0, 1.5)
	var point: Vector3 = MagicBeamScript.hold_point(origin, direction, anchor)
	var offset := point - (origin + direction * (point - origin).dot(direction))
	assert_almost_eq(offset.length(), Vector2(MagicBeamScript.HOLD_SIDE,
		MagicBeamScript.HOLD_LIFT).length(), 0.0001,
		"the hold point must sit off the ray by HOLD_SIDE across and HOLD_LIFT up")
	assert_gt(MagicBeamScript.HOLD_SIDE, 0.6,
		"the sideways offset must clear the player's own silhouette, not graze it")
	assert_almost_eq(offset.y, MagicBeamScript.HOLD_LIFT, 0.0001,
		"a level ray must lift the hold point straight up")


func test_the_hold_offset_follows_the_view_rather_than_the_world() -> void:
	# Screen-right, not world-X: turn the camera around and the offset has to turn with
	# it, or a pony held on your left while facing north is held on your right facing
	# south -- and is back behind the player's body for half of every turn.
	var origin := Vector3.ZERO
	var anchor := Vector3(0.0, 0.0, 0.0)
	var north: Vector3 = MagicBeamScript.hold_point(origin, Vector3(0.0, 0.0, -1.0), anchor)
	var south: Vector3 = MagicBeamScript.hold_point(origin, Vector3(0.0, 0.0, 1.0), anchor)
	assert_almost_eq(north.x, MagicBeamScript.HOLD_SIDE, 0.0001, "screen-right looking -Z is +X")
	assert_almost_eq(south.x, -MagicBeamScript.HOLD_SIDE, 0.0001,
		"...and screen-right looking +Z is -X")


func test_the_hold_point_survives_aiming_straight_down() -> void:
	# Straight down collapses the UP cross product the offset is built from; without the
	# fallback this is a NaN hold point and a held pony teleported to nowhere.
	var point: Vector3 = MagicBeamScript.hold_point(
		Vector3(0.0, 5.0, 0.0), Vector3.DOWN, Vector3(0.0, 3.0, 0.0))
	assert_false(is_nan(point.x) or is_nan(point.y) or is_nan(point.z),
		"aiming straight down must still produce a real hold point (got %s)" % point)


func test_the_hold_point_and_the_reach_do_not_move_when_the_player_zooms() -> void:
	# The whole reason both are measured from the PLAYER's projection onto the ray rather
	# than from the ray's origin. If this regressed, zooming in would silently shorten the
	# beam and pull captured ponies into the camera's face -- and no gate that fixes the
	# zoom at its default would ever see it.
	var direction := Vector3(0.0, 0.0, -1.0)
	var anchor := Vector3(0.0, 2.0, 0.0)
	var near_point: Vector3 = MagicBeamScript.hold_point(
		Vector3(0.0, 2.0, 1.2), direction, anchor)   # zoomed in  (CameraRig.SPRING_MIN)
	var far_point: Vector3 = MagicBeamScript.hold_point(
		Vector3(0.0, 2.0, 6.5), direction, anchor)   # zoomed out (CameraRig.SPRING_MAX)
	assert_almost_eq(near_point.distance_to(far_point), 0.0, 0.0001,
		"the hold point must be the same world point at either zoom extreme")

	var near_reach: float = MagicBeamScript.reach_distance(
		Vector3(0.0, 2.0, 1.2), direction, anchor) - 1.2
	var far_reach: float = MagicBeamScript.reach_distance(
		Vector3(0.0, 2.0, 6.5), direction, anchor) - 6.5
	assert_almost_eq(near_reach, far_reach, 0.0001,
		"and the beam must reach the same distance past her at either zoom extreme")
	assert_almost_eq(near_reach, MagicBeamScript.REACH, 0.0001,
		"...namely REACH metres past her")


func test_the_hold_point_never_lands_inside_the_camera() -> void:
	# Degenerate zoom: the anchor is BEHIND the ray origin, so the unclamped hold point
	# would sit almost on the lens.
	var origin := Vector3.ZERO
	var direction := Vector3(0.0, 0.0, -1.0)
	var point: Vector3 = MagicBeamScript.hold_point(origin, direction, Vector3(0.0, 0.0, 3.0))
	# Measured ALONG the ray -- the sideways offset would otherwise flatter this check
	# into passing on a hold point sitting level with the lens.
	assert_gte((point - origin).dot(direction), MagicBeamScript.MIN_HOLD_DISTANCE - 0.0001,
		"a held body must never be pulled into the camera's near plane")


func test_a_running_player_is_noticed_before_the_beam_can_reach_her() -> void:
	# THE INVARIANT THE FIRST PLAYTEST WAS LOST TO, AND THE ONE ASSERTION THAT WOULD HAVE
	# CAUGHT IT. The test that used to live here asserted the OPPOSITE -- that the beam
	# out-reaches a pony's detection radius -- and it passed, because that is exactly what
	# the build did: REACH 8.5 against DETECTION_RADIUS 5.0. The consequence was that no
	# pony could ever react before being grabbed, so the entire flee behaviour, which works
	# and is itself gated, never once happened in play. The owner found it in his first
	# session: "I could just hold click and walk up and catch them -- they should start
	# running away farther than the range of the beam."
	#
	# It is a relationship between two constants in two different files, which is the kind
	# of thing that has no natural home and therefore ends up with no owner. It gets one
	# here. A margin rather than a bare `>` because MagicBeam.GRAB_ASSIST_RADIUS already
	# makes the effective grab distance longer than REACH, and because Phase 1B's shop is
	# going to sell REACH upgrades -- so "detection is bigger by a hair" is not enough, it
	# has to stay bigger by something a player can act inside.
	#
	# QUANTIFIED OVER EVERY PERSONALITY SINCE THE SECOND PLAYTEST, because the notice
	# radius stopped being one shared constant: a SHY pony sees 2 m further than the others
	# (Pony.SHY_NOTICE_BONUS). Checking only the base number would leave a future
	# personality with a NEGATIVE bonus able to slip under the invariant unseen, which is
	# exactly the class of bug this test exists for. Sneaking is deliberately excluded --
	# see test_sneaking_is_allowed_to_beat_the_head_start_and_only_sneaking.
	for personality in PonyDataScript.Personality.values():
		var radius: float = PonyScript.notice_radius_for(personality, false)
		var margin: float = radius - MagicBeamScript.REACH
		assert_gte(margin, MagicBeamScript.MIN_DETECTION_MARGIN,
			("a %s pony must notice a RUNNING player at least MIN_DETECTION_MARGIN " +
			"(%.1f m) before he can beam her -- notice %.1f m, reach %.1f m, margin " +
			"%.1f m") % [
				PonyDataScript.Personality.keys()[personality],
				MagicBeamScript.MIN_DETECTION_MARGIN, radius, MagicBeamScript.REACH, margin])
	assert_gt(MagicBeamScript.MIN_DETECTION_MARGIN, MagicBeamScript.GRAB_ASSIST_RADIUS,
		"the required margin must at least swallow the grab-assist radius, or a pony " +
		"could be snatched out of the forgiveness pass before she had reacted")


func test_sneaking_is_allowed_to_beat_the_head_start_and_only_sneaking() -> void:
	# THE ONE SANCTIONED EXCEPTION TO THE INVARIANT ABOVE, and it is asserted rather than
	# merely permitted -- a sneak that did NOT bring the notice radius inside the beam's
	# reach would be a stealth option that buys nothing, which is the failure mode a "the
	# radius got smaller" check would happily pass.
	#
	# Both directions are pinned. Too little reduction and creeping is pointless; too much
	# and a pony has effectively stopped reacting to the player at all, which would undo
	# the first playtest's fix by a different route.
	var pony_script := load("res://actors/pony/pony.gd")
	for personality in PonyDataScript.Personality.values():
		var running: float = pony_script.notice_radius_for(personality, false)
		var sneaking: float = pony_script.notice_radius_for(personality, true)
		var who: String = PonyDataScript.Personality.keys()[personality]
		assert_lt(sneaking, MagicBeamScript.REACH,
			("sneaking must get the player inside beam range of a %s pony unnoticed " +
			"(%.1f m sneaking against %.1f m of reach) or the stealth option buys " +
			"nothing") % [who, sneaking, MagicBeamScript.REACH])
		assert_lt(sneaking, running * 0.75,
			"a %s pony's notice radius must drop MATERIALLY when the player creeps " % who +
			"(%.1f m -> %.1f m)" % [running, sneaking])
		assert_gt(sneaking, MagicBeamScript.HOLD_LEAD * 2.0,
			("...but a sneaking player must still be noticeable well before he is on top " +
			"of a %s pony (%.1f m)") % [who, sneaking])


func test_reaching_a_pony_and_holding_her_get_harder_in_opposite_directions() -> void:
	# THE DESIGN DECISION THE OWNER MADE IN THE SECOND PLAYTEST, pinned as one assertion
	# because it is a claim about two files at once and neither file can state it alone.
	#
	# "It makes sense Fluttershy runs but freezes." So a SHY pony is the hardest to REACH
	# (she notices you from furthest away, and she is the only personality that runs) and
	# the easiest to HOLD; a BOLD pony has no reaction at all -- you walk right up to her --
	# and is the hardest to hold. Before this, both dials pointed the same way, which made
	# BOLD (Rainbow Dash, RARE) the easiest pony in the game to collect and SHY two hard
	# things in series.
	#
	# Without this test the ordering could be re-inverted one constant at a time and every
	# other check in the project would stay green, because each individual number would
	# still look perfectly reasonable.
	var pony_script := load("res://actors/pony/pony.gd")
	var reach_hardness := {}
	var hold_hardness := {}
	for personality in PonyDataScript.Personality.values():
		reach_hardness[personality] = pony_script.notice_radius_for(personality, false)
		hold_hardness[personality] = -MagicBeamScript.capture_window_for(personality)

	var shy: int = PonyDataScript.Personality.SHY
	var bold: int = PonyDataScript.Personality.BOLD
	assert_gt(reach_hardness[shy], reach_hardness[bold],
		"a SHY pony must be harder to REACH than a BOLD one -- she notices you sooner")
	assert_gt(hold_hardness[bold], hold_hardness[shy],
		"...and a BOLD pony must be harder to HOLD than a SHY one -- she is the one " +
		"who fights")
	assert_eq(pony_script.reaction_state(bold), pony_script.NO_REACTION,
		"...and 'trivial to reach' for a BOLD pony means literally no reaction at all")
	assert_eq(pony_script.reaction_state(shy), pony_script.State.FLEE,
		"...while a SHY pony is hard to reach because she actually runs")


func test_the_capture_needs_a_real_hold_rather_than_a_click() -> void:
	# The fix for "catching is really quick": releasing the button no longer stores
	# whatever is in the beam, it has to have been held SECURE_SECONDS first. The floor is
	# the pull-in -- a secure time that completed while she was still in transit would put
	# the mechanic straight back where it was, with the whole contest over before the
	# player had seen what they caught.
	var pull_in: float = log(10.0) / MagicBeamScript.PULL_RESPONSE
	assert_gt(MagicBeamScript.SECURE_SECONDS, pull_in * 2.0,
		"securing a pony must take longer than reeling her in (%.3f s)" % pull_in)
	assert_lt(MagicBeamScript.SECURE_SECONDS, 2.0,
		"...and not so long that the twelfth catch of a session is a chore")


func test_the_windows_are_the_ones_the_owner_asked_for() -> void:
	# THE THIRD PLAYTEST'S BRIEF, WRITTEN DOWN AS AN ASSERTION. "Medium ones only have like
	# a half sec window and easy have the full second window something like that", with the
	# hardest grade tighter still -- against a build that shipped 3.45 / 1.85 / 1.15 s and
	# was reported as "all the character super easy to catch too, no real challenge with
	# the wiggling out".
	#
	# Pinned as the actual numbers rather than only as an ordering, because an ordering
	# test stays green through a retune that drifts all three back up together, which is
	# exactly the direction they drifted from last time.
	assert_almost_eq(MagicBeamScript.capture_window_for(PonyDataScript.Personality.SHY),
		1.0, 0.0001, "the EASY grade gets the full second the owner asked for")
	assert_almost_eq(MagicBeamScript.capture_window_for(PonyDataScript.Personality.CURIOUS),
		0.5, 0.0001, "the MEDIUM grade gets the half second the owner asked for")
	assert_lt(MagicBeamScript.capture_window_for(PonyDataScript.Personality.BOLD), 0.5,
		"and the HARD grade is tighter still")
	# Every one of them SHRANK. The old build's tightest window (1.15 s) was wider than
	# this build's most forgiving one, which is the whole of what "super easy" meant.
	assert_lt(MagicBeamScript.capture_window_for(PonyDataScript.Personality.SHY), 1.15,
		"even the EASY grade must now be tighter than the OLD build's HARDEST one")


func test_every_grade_leaves_a_window_a_human_can_actually_hit() -> void:
	# The two clocks only produce a mechanic if the second is comfortably past the first.
	# A struggle time at or under the subdue time would make that grade flatly UNCATCHABLE
	# -- and nothing else in the project would say so, because both numbers would still
	# look individually reasonable and every other test would still pass.
	#
	# CHECKED AT THE WORST ROLL, not at the nominal value. Now that both clocks are
	# jittered per attempt (SECURE_JITTER, WINDOW_JITTER), a floor asserted on the average
	# is a floor asserted on an attempt that mostly does not happen -- and the attempt that
	# matters is the unlucky one. REACTION_TIME is a full un-anticipated visual reaction,
	# which is deliberately harsher than what the mechanic actually asks of the player: the
	# catch ring fills toward a visible finish line, so a release is anticipated rather than
	# reacted to. Clearing the harsher bar on every grade's worst roll is the margin.
	for personality in PonyDataScript.Personality.values():
		var bounds: Vector2 = MagicBeamScript.window_bounds_for(personality)
		var who: String = PonyDataScript.Personality.keys()[personality]
		var grade: String = MagicBeamScript.grade_name(MagicBeamScript.grade_for(personality))
		assert_gt(bounds.x, REACTION_TIME,
			("%s (%s) must leave more than a reaction time even on her WORST roll " +
			"(%.3f s against %.2f s)") % [who, grade, bounds.x, REACTION_TIME])
		assert_lt(bounds.y, 2.0,
			"%s (%s) must not be able to roll a window so wide it stops being a window " % [
				who, grade] + "(%.3f s)" % bounds.y)


func test_a_correct_release_always_wins_on_the_easy_grade() -> void:
	# "EASY" has to mean something specific or it is just a smaller number: a player who
	# lets go when the ring closes wins, every time, however the dice fell. Stated as the
	# margin a player has after the cue rather than as the window itself, and swept over
	# the whole rolled range rather than checked at the middle of it.
	var bounds: Vector2 = MagicBeamScript.window_bounds_for(PonyDataScript.Personality.SHY)
	assert_gt(bounds.x, REACTION_TIME * 3.0,
		("the EASY grade must survive a badly late release on its worst roll -- three " +
		"whole reaction times (%.2f s) inside %.3f s") % [REACTION_TIME * 3.0, bounds.x])
	# Driven through roll_clocks over the actual roll space, so this is a claim about what
	# the mechanic DOES rather than about two constants that feed it. A hundred and twenty
	# one combinations of the two jitters, and the player is late by a full reaction time
	# on every one of them.
	var worst := INF
	for secure_step in range(11):
		for window_step in range(11):
			var clocks: Dictionary = MagicBeamScript.roll_clocks(
				PonyDataScript.Personality.SHY, 0,
				1.0, float(secure_step) / 10.0, float(window_step) / 10.0)
			assert_false(clocks["wrenches"], "an EASY pony can never wrench free")
			var release_at: float = float(clocks["secure"]) + REACTION_TIME
			worst = minf(worst, float(clocks["struggle"]) - release_at)
			assert_lt(release_at, float(clocks["struggle"]),
				("a release a whole reaction time late must still land her: secured at " +
				"%.3f s, released at %.3f s, she leaves at %.3f s") % [
					clocks["secure"], release_at, clocks["struggle"]])
	assert_gt(worst, 0.4,
		"...and not by a hair: the tightest of those had %.3f s still to spare" % worst)


func test_a_bold_pony_is_the_hardest_hold_and_a_shy_one_the_easiest() -> void:
	# The whole point of per-personality struggle times, stated as the thing a player
	# actually experiences -- how much slack they get -- rather than as raw timer values.
	var shy: float = MagicBeamScript.capture_window_for(PonyDataScript.Personality.SHY)
	var curious: float = MagicBeamScript.capture_window_for(PonyDataScript.Personality.CURIOUS)
	var bold: float = MagicBeamScript.capture_window_for(PonyDataScript.Personality.BOLD)
	assert_lt(bold, curious, "a BOLD pony must be a tighter hold than a CURIOUS one")
	assert_lt(curious, shy, "...and a CURIOUS one than a SHY one")
	assert_gt(shy, bold * 2.0,
		"and the spread must be big enough to feel: SHY should be a comfortable hold " +
		"where BOLD is a scramble")


func test_losing_her_costs_the_player_the_re_grab() -> void:
	# An escape that the beam can undo on the next frame is not an escape. The cooldown
	# also has to outlast the time she needs to get her legs under her -- she accelerates
	# at Pony.ACCELERATION from a standstill at the hold point, a couple of metres from the
	# player's face, so a cooldown much under a second hands her straight back.
	assert_gt(MagicBeamScript.ESCAPE_COOLDOWN, 1.0,
		"a lost pony must get long enough to become a moving target again")


func test_a_wrench_costs_the_player_less_than_a_mistake_does() -> void:
	# THE ACCEPTANCE CRITERION THAT OUTRANKS THE NUMBERS: "i dont want the mechanic to get
	# annoying". ESCAPE_COOLDOWN is the price of a MISTAKE -- you let go too soon, or you
	# held too long -- and a wrench is the one loss the player did not make. Charging full
	# price for it is how a fair mechanic gets a reputation for cheating.
	assert_lt(MagicBeamScript.WRENCH_COOLDOWN, MagicBeamScript.ESCAPE_COOLDOWN,
		"a loss the player did not cause must cost less than one they did")
	# ...but it is still an escape, not a stumble: the beam has to visibly let go of her,
	# or a wrench at 60% of the ring would be undone before the player's finger moved and
	# would read as a flicker rather than as her winning.
	assert_gt(MagicBeamScript.WRENCH_COOLDOWN, 0.4,
		"...and must still be long enough to read as her getting away")


# --- the grading -----------------------------------------------------------------------

func test_the_grade_is_a_reading_of_the_personality_she_already_has() -> void:
	# THE BRIEF SAID "tag them with different difficulties", AND THE TAG IS NOT A NEW FIELD.
	# PonyData.personality is the tier this mechanic has always been keyed on, and inventing
	# a parallel `difficulty` on the same resource would give the project two sources of
	# truth about one pony, kept in step by hand, diverging the first time somebody authors
	# a .tres and fills in only one of them. Grade is a pure function of personality, and
	# this is the test that says so.
	assert_eq(MagicBeamScript.grade_for(PonyDataScript.Personality.SHY),
		MagicBeamScript.Grade.EASY, "a SHY pony has frozen: she is the EASY hold")
	assert_eq(MagicBeamScript.grade_for(PonyDataScript.Personality.CURIOUS),
		MagicBeamScript.Grade.MEDIUM, "a CURIOUS pony is the MEDIUM hold")
	assert_eq(MagicBeamScript.grade_for(PonyDataScript.Personality.BOLD),
		MagicBeamScript.Grade.HARD, "a BOLD pony fights: she is the HARD hold")

	# Every personality on the enum has to land on a grade, or a roster addition would be
	# graded by the fallback while looking like it had been graded on purpose.
	var seen := {}
	for personality in PonyDataScript.Personality.values():
		var grade: int = MagicBeamScript.grade_for(personality)
		assert_between(grade, 0, MagicBeamScript.Grade.size() - 1,
			"%s must map to a real grade" % PonyDataScript.Personality.keys()[personality])
		seen[grade] = true
	assert_eq(seen.size(), MagicBeamScript.Grade.size(),
		"all three grades must be reachable from the roster's personalities -- a grade no " +
		"pony can have is a difficulty setting nobody can play")


func test_the_grades_are_ordered_and_separated_enough_to_feel() -> void:
	# An ordering alone is satisfied by 0.51 / 0.50 / 0.49, which is three names for one
	# difficulty. The SEPARATION is what makes a player able to tell, without being told,
	# that the pony in their beam is a different kind of problem from the last one.
	var easy: float = MagicBeamScript.capture_window_for(PonyDataScript.Personality.SHY)
	var medium: float = MagicBeamScript.capture_window_for(PonyDataScript.Personality.CURIOUS)
	var hard: float = MagicBeamScript.capture_window_for(PonyDataScript.Personality.BOLD)
	assert_gt(easy, medium, "EASY must be a wider window than MEDIUM")
	assert_gt(medium, hard, "...and MEDIUM than HARD")
	assert_gt(easy, medium * 1.5, "EASY must be a different EXPERIENCE from MEDIUM, not a nudge")
	assert_gt(medium, hard * 1.25, "...and MEDIUM from HARD")

	# AND THE GRADES MUST NOT OVERLAP ONCE THE JITTER IS APPLIED. This is the check that
	# actually has teeth: a jitter wide enough that an unlucky EASY roll is tighter than a
	# lucky MEDIUM one would make the grading unlearnable, because the same pony would
	# sometimes be harder than a pony of a harder grade. It is also the failure mode a
	# "just add more randomness" retune reaches first.
	var easy_bounds: Vector2 = MagicBeamScript.window_bounds_for(PonyDataScript.Personality.SHY)
	var medium_bounds: Vector2 = MagicBeamScript.window_bounds_for(PonyDataScript.Personality.CURIOUS)
	var hard_bounds: Vector2 = MagicBeamScript.window_bounds_for(PonyDataScript.Personality.BOLD)
	assert_gt(easy_bounds.x, medium_bounds.y,
		("the WORST EASY roll (%.3f s) must still beat the BEST MEDIUM one (%.3f s), or " +
		"the grades overlap and nothing is learnable") % [easy_bounds.x, medium_bounds.y])
	assert_gt(medium_bounds.x, hard_bounds.y,
		"...and the worst MEDIUM roll (%.3f s) the best HARD one (%.3f s)" % [
			medium_bounds.x, hard_bounds.y])


# --- the randomness --------------------------------------------------------------------

func test_the_jitter_stays_inside_the_bounds_the_file_publishes() -> void:
	# "Bounded, seeded per attempt, and never so wide that a good release loses" is the
	# brief, and the bounds are published (secure_bounds, window_bounds_for) precisely so
	# they can be checked rather than trusted. Driven through a REAL generator rather than
	# through hand-picked rolls, because the thing being pinned is the arithmetic in
	# roll_clocks, not the arithmetic in this file.
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260828
	var secure_bounds: Vector2 = MagicBeamScript.secure_bounds()
	var lowest := INF
	var highest := -INF
	for personality in PonyDataScript.Personality.values():
		var window_bounds: Vector2 = MagicBeamScript.window_bounds_for(personality)
		var who: String = PonyDataScript.Personality.keys()[personality]
		for i in range(4000):
			# prior_holds past the grace, so nothing here wrenches: this test is about the
			# jitter on an ordinary attempt. The wrench has its own tests below.
			var clocks: Dictionary = MagicBeamScript.roll_clocks(personality,
				MagicBeamScript.WRENCH_GRACE_HOLDS, rng.randf(), rng.randf(), rng.randf())
			var secure: float = clocks["secure"]
			var window: float = float(clocks["struggle"]) - secure
			assert_between(secure, secure_bounds.x - 0.0001, secure_bounds.y + 0.0001,
				"a rolled subdue time for %s left its published bounds" % who)
			assert_between(window, window_bounds.x - 0.0001, window_bounds.y + 0.0001,
				"a rolled window for %s left its published bounds" % who)
			lowest = minf(lowest, window / MagicBeamScript.capture_window_for(personality))
			highest = maxf(highest, window / MagicBeamScript.capture_window_for(personality))

	# NOT VACUOUS: the sweep has to actually visit most of the range, or a roll_clocks that
	# ignored its jitter arguments entirely would pass every assertion above.
	assert_lt(lowest, 1.0 - MagicBeamScript.WINDOW_JITTER * 0.9,
		"the sweep must actually reach the bottom of the range (got %.3f)" % lowest)
	assert_gt(highest, 1.0 + MagicBeamScript.WINDOW_JITTER * 0.9,
		"...and the top of it (got %.3f)" % highest)


func test_the_subdue_clock_is_jittered_but_never_into_a_click_or_a_chore() -> void:
	# The variance the owner asked for lives on BOTH clocks -- jittering only the struggle
	# time leaves the ring completing on a metronome, which is the exact habit ("one... and
	# let go") that stops a player looking at the screen. Both ends of it are load-bearing.
	var bounds: Vector2 = MagicBeamScript.secure_bounds()
	var pull_in: float = log(10.0) / MagicBeamScript.PULL_RESPONSE
	assert_gt(MagicBeamScript.SECURE_JITTER, 0.05,
		"a jitter too small to notice is a metronome with extra steps")
	assert_gt(bounds.x, pull_in * 2.0,
		("even the LUCKIEST subdue roll (%.3f s) must outlast the reel (%.3f s), or the " +
		"contest completes while she is still in transit and is invisible again") % [
			bounds.x, pull_in])
	assert_lt(bounds.y, 2.0,
		"even the UNLUCKIEST subdue roll (%.3f s) must not make the twelfth catch of a " % bounds.y +
		"session a chore")
	# And the third playtest's actual instruction -- "id decrease the current fvalues" --
	# against the build he played, which subdued in a flat 1.15 s.
	assert_lt(MagicBeamScript.SECURE_SECONDS, 1.15,
		"the subdue time was asked to come DOWN from the 1.15 s of the build he played")


func test_the_same_rolls_always_produce_the_same_attempt() -> void:
	# roll_clocks is pure, and that is not a stylistic claim -- it is what makes a seeded
	# gate reproducible and what lets the sweeps in this file stand in for thousands of
	# live captures. A stray Time or randf() inside it would break both silently.
	var first: Dictionary = MagicBeamScript.roll_clocks(
		PonyDataScript.Personality.BOLD, 0, 0.11, 0.73, 0.29)
	var second: Dictionary = MagicBeamScript.roll_clocks(
		PonyDataScript.Personality.BOLD, 0, 0.11, 0.73, 0.29)
	assert_eq(first, second, "the same rolls must produce the same attempt, exactly")


# --- the wrench, and why it cannot trap the player -------------------------------------

func test_only_the_hard_grade_can_wrench_free_before_you_land_her() -> void:
	# "The hardest ones have a chance to wiggle out before you catch." Only the hardest
	# ones -- a wrench on an EASY pony would take away the one grade that exists to be the
	# exhale after a chase.
	for personality in PonyDataScript.Personality.values():
		var who: String = PonyDataScript.Personality.keys()[personality]
		var hard: bool = MagicBeamScript.grade_for(personality) == MagicBeamScript.Grade.HARD
		var chance: float = MagicBeamScript.wrench_chance_for(personality, 0)
		if hard:
			assert_gt(chance, 0.0, "a HARD pony (%s) must be able to wrench free" % who)
		else:
			assert_eq(chance, 0.0, "a %s pony must never wrench free" % who)


func test_a_wrench_lands_before_the_catch_ring_closes_and_can_be_seen_coming() -> void:
	# A wrench IS a struggle time rolled shorter than that attempt's own subdue time -- that
	# is the entire implementation, and it is what makes the HUD show the loss honestly
	# (the red ring visibly outruns the green one). If a "wrench" could ever roll a struggle
	# time LONGER than the subdue, it would silently become an ordinary catch and the
	# hardest grade would quietly lose its teeth.
	for step in range(21):
		var roll: float = float(step) / 20.0
		var clocks: Dictionary = MagicBeamScript.roll_clocks(
			PonyDataScript.Personality.BOLD, 0, 0.0, roll, roll)
		assert_true(clocks["wrenches"], "a zero wrench roll on a fresh HARD pony must wrench")
		assert_lt(float(clocks["struggle"]), float(clocks["secure"]),
			("a wrench must land BEFORE the catch ring closes (struggle %.3f s against " +
			"subdue %.3f s)") % [clocks["struggle"], clocks["secure"]])
		var fraction: float = float(clocks["struggle"]) / float(clocks["secure"])
		assert_between(fraction,
			MagicBeamScript.WRENCH_AT_MIN - 0.0001, MagicBeamScript.WRENCH_AT_MAX + 0.0001,
			"a wrench must land in the published stretch of the ring (%.3f)" % fraction)
	# The late end matters as much as the early one: a wrench at 97% of the ring is
	# indistinguishable from the player's own mistimed release, which would teach exactly
	# the wrong lesson about a loss that was never their fault.
	assert_lt(MagicBeamScript.WRENCH_AT_MAX, 0.95,
		"a wrench must not land so close to the ring closing that it reads as the " +
		"player's own mistake")


func test_the_wrench_chance_falls_to_zero_and_stays_there() -> void:
	# THE LOAD-BEARING "but" IN THE OWNER'S BRIEF: "(but will eventaully let you catch)".
	# The falloff is not a pity timer sitting next to a dice roll, it is the dice being
	# taken away -- so this asserts the chance actually REACHES zero, at a stated grab, and
	# never comes back for any number of grabs after it.
	assert_between(MagicBeamScript.WRENCH_GRACE_HOLDS, 1, MAX_HONEST_ATTEMPTS - 1,
		("the bound must be small enough to BE a promise -- a chance that reaches zero " +
		"after %d grabs is not one") % MagicBeamScript.WRENCH_GRACE_HOLDS)
	var previous: float = INF
	for prior_holds in range(mini(MagicBeamScript.WRENCH_GRACE_HOLDS, MAX_HONEST_ATTEMPTS)):
		var chance: float = MagicBeamScript.wrench_chance_for(
			PonyDataScript.Personality.BOLD, prior_holds)
		assert_gt(chance, 0.0,
			"she must still have some fight in her after %d grabs" % prior_holds)
		assert_lt(chance, previous, "...but less than she had after %d" % (prior_holds - 1))
		previous = chance
	for prior_holds in range(mini(MagicBeamScript.WRENCH_GRACE_HOLDS, MAX_HONEST_ATTEMPTS), 40):
		assert_eq(MagicBeamScript.wrench_chance_for(
				PonyDataScript.Personality.BOLD, prior_holds), 0.0,
			("after %d grabs she must be out of fight ENTIRELY -- a chance that merely " +
			"got small is a loop the player can still be stuck in") % prior_holds)
	# Negative or absurd counts must not resurrect it either: the counter is a plain public
	# var on the pony, so it is exactly the kind of thing a future caller can hand rubbish.
	assert_eq(MagicBeamScript.wrench_chance_for(PonyDataScript.Personality.BOLD, -5),
		MagicBeamScript.wrench_chance_for(PonyDataScript.Personality.BOLD, 0),
		"a nonsense hold count must not be MORE forgiving than a fresh pony")


func test_a_player_who_keeps_doing_it_right_always_lands_her() -> void:
	# THE CONVERGENCE PROPERTY, PROVED RATHER THAN ASSERTED -- the brief's own instruction.
	# A thousand independent seeded streams, each one a player who plays a fresh HARD pony
	# correctly (releases the instant the catch ring closes) and keeps going until she is
	# caught. Not one of them may be held off past the published bound, and the bound is
	# small.
	#
	# This is the test that fails if the falloff is ever softened into "the chance gets
	# smaller", which is the natural-looking retune that reintroduces the unbounded loop.
	var rng := RandomNumberGenerator.new()
	var attempts_needed := {}
	var worst_run := 0
	var first_attempt_wrenches := 0
	for stream in range(SEED_SWEEP):
		rng.seed = stream
		var holds := 0
		var wrenches := 0
		var caught := false
		# One more attempt than the bound allows, and never more than MAX_HONEST_ATTEMPTS
		# whatever the build claims its bound is -- so a design that needs MORE attempts
		# than a player would sit through fails here rather than being accommodated by its
		# own generous arithmetic.
		for attempt in range(mini(MagicBeamScript.WRENCH_GRACE_HOLDS + 1, MAX_HONEST_ATTEMPTS)):
			var clocks: Dictionary = MagicBeamScript.roll_clocks(
				PonyDataScript.Personality.BOLD, holds,
				rng.randf(), rng.randf(), rng.randf())
			holds += 1
			if clocks["wrenches"]:
				wrenches += 1
				if attempt == 0:
					first_attempt_wrenches += 1
				continue
			# She did not wrench, so the contest is the ordinary one -- and the player
			# plays it correctly, letting go a reaction time after the ring closes.
			assert_lt(float(clocks["secure"]) + REACTION_TIME, float(clocks["struggle"]),
				"a correct release must land a HARD pony who did not wrench")
			caught = true
			break
		assert_true(caught,
			("seed %d held the player off for all %d attempts -- the mechanic can trap a " +
			"player who is doing everything right") % [
				stream, MagicBeamScript.WRENCH_GRACE_HOLDS + 1])
		worst_run = maxi(worst_run, wrenches)
		attempts_needed[wrenches + 1] = int(attempts_needed.get(wrenches + 1, 0)) + 1

	assert_lt(MagicBeamScript.WRENCH_GRACE_HOLDS, MAX_HONEST_ATTEMPTS,
		("a player may lose at most %d catches to the dice before the pony has to become " +
		"catchable; this build says %d") % [
			MAX_HONEST_ATTEMPTS - 1, MagicBeamScript.WRENCH_GRACE_HOLDS])
	assert_lte(worst_run, MagicBeamScript.WRENCH_GRACE_HOLDS,
		("no pony may wrench more than %d times in a row (worst seen: %d)") % [
			MagicBeamScript.WRENCH_GRACE_HOLDS, worst_run])
	# NOT VACUOUS. If the wrench never fired, every assertion above would pass on a
	# mechanic that does not exist -- which is precisely the shape of green-but-empty gate
	# this project has shipped before.
	assert_gt(first_attempt_wrenches, SEED_SWEEP / 4,
		("the wrench must actually fire: only %d of %d fresh HARD ponies wrenched on the " +
		"first grab") % [first_attempt_wrenches, SEED_SWEEP])
	# AND IT MUST NOT BE THE NORM EITHER. "I don't want the mechanic to get annoying" is the
	# criterion that outranks the numbers, and a hard pony who usually costs three tries is
	# annoying however well-bounded the three is.
	var one_shot: int = int(attempts_needed.get(1, 0))
	assert_gt(one_shot, SEED_SWEEP / 3,
		("a decent share of HARD ponies must go in on the first honest attempt (%d of " +
		"%d did)") % [one_shot, SEED_SWEEP])
	gut.p("wrench convergence over %d seeds: attempts->count %s, worst run %d" % [
		SEED_SWEEP, attempts_needed, worst_run])


func test_an_easy_or_medium_pony_is_caught_on_the_first_honest_attempt_every_time() -> void:
	# The other half of the grading: only the hardest grade may ever take an attempt away.
	# A player working through a field of Fluttershys must never lose one to the dice.
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for personality in [PonyDataScript.Personality.SHY, PonyDataScript.Personality.CURIOUS]:
		var who: String = PonyDataScript.Personality.keys()[personality]
		for i in range(SEED_SWEEP):
			var clocks: Dictionary = MagicBeamScript.roll_clocks(personality, 0,
				rng.randf(), rng.randf(), rng.randf())
			assert_false(clocks["wrenches"], "a %s pony must never wrench" % who)
			assert_lt(float(clocks["secure"]) + REACTION_TIME, float(clocks["struggle"]),
				"a correct release must always land a %s pony" % who)


# --- gear (Phase 2's shop) --------------------------------------------------------------

## A live MagicBeam, hanging off a real Player in a minimal world.
##
## THE ONLY FIXTURE IN THIS FILE, and it exists reluctantly: everything above is static and
## pure precisely so it needs no tree. The gear does not get that luxury. MagicBeam._ready()
## is what mints the Storage the saddlebag resizes, and _ready() only runs once the node is
## in a tree, so a beam built with `.new()` has no bag to grow.
##
## Built exactly the way game/test/test_player.gd's before_each builds one, with a floor
## under her and a camera for the aim ray, so the two fixtures cannot drift into disagreeing
## about what a player needs. The world is autofreed, so a test that takes a beam does not
## have to give it back.
func _beam() -> MagicBeamScript:
	var world := Node3D.new()
	add_child_autofree(world)

	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = FIXTURE_FLOOR_SIZE
	floor_shape.shape = box
	floor_shape.position = Vector3(0.0, -FIXTURE_FLOOR_SIZE.y * 0.5, 0.0)
	floor_body.add_child(floor_shape)
	world.add_child(floor_body)

	var camera := Camera3D.new()
	world.add_child(camera)

	var player: CharacterBody3D = PlayerScene.instantiate()
	world.add_child(player)
	return player.get_magic_beam() as MagicBeamScript


func test_unlocks_grow_the_saddlebag_and_the_reach() -> void:
	var beam := _beam()
	var base_reach := beam.reach()
	var base_capacity: int = beam.get_storage().capacity
	beam.apply_unlocks(["bigger_saddlebag", "long_beam"])
	assert_eq(beam.get_storage().capacity, MagicBeamScript.BIGGER_SADDLEBAG_CAPACITY)
	assert_gt(beam.get_storage().capacity, base_capacity)
	assert_almost_eq(beam.reach(), base_reach + MagicBeamScript.LONG_BEAM_BONUS, 0.0001)
	# Without this the whole file passes on LONG_BEAM_BONUS := 0.0, which is a shop item that
	# takes the player's money and does nothing.
	assert_gt(MagicBeamScript.LONG_BEAM_BONUS, 0.0, "the upgrade must be felt")


func test_unlocks_are_idempotent_and_unknown_ids_are_ignored() -> void:
	var beam := _beam()
	beam.apply_unlocks(["long_beam"])
	var once := beam.reach()
	beam.apply_unlocks(["long_beam", "long_beam", "hat_of_wonders"])
	assert_almost_eq(beam.reach(), once, 0.0001, "applying twice does not stack")


func test_reach_stays_under_the_notice_invariant_even_with_the_long_beam() -> void:
	# magic_beam.gd's own invariant: every personality notices a running player from
	# further than the beam reaches, by MIN_DETECTION_MARGIN. The long beam must not eat
	# through that margin or a pony can be taken without a chase.
	var beam := _beam()
	beam.apply_unlocks(["long_beam"])
	for personality in PonyDataScript.Personality.values():
		var notice: float = PonyScript.notice_radius_for(personality, false)
		assert_gte(notice - beam.reach(), MagicBeamScript.MIN_DETECTION_MARGIN,
			"personality %d notices from %.1f, long beam reaches %.1f" % [personality, notice, beam.reach()])


# --- a caught stock pony's colours ------------------------------------------------------

func test_catching_a_stock_pony_carries_her_colours_onto_her_record() -> void:
	var beam: MagicBeam = _beam()  # the file's existing helper
	var pony: Pony = PonyScene.instantiate()
	pony.set_stock({"coat": 1, "mane": 7, "eyes": 3})
	add_child_autofree(pony)
	pony.setup(_stock_data())  # a hidden record, resolved through PonyRegistry.by_id
	beam._settle_pony(pony)
	var stored: PonyInstance = beam.get_storage().contents()[0]
	assert_eq(stored.stock, {"coat": 1, "mane": 7, "eyes": 3},
		"her look is minted with her uid, or a caught stock pony is a stranger on reload")


func test_catching_a_named_pony_leaves_her_stock_empty() -> void:
	var beam: MagicBeam = _beam()
	var pony: Pony = PonyScene.instantiate()
	add_child_autofree(pony)
	pony.setup(_named_data())
	beam._settle_pony(pony)
	assert_eq(beam.get_storage().contents()[0].stock, {})


# --- the charge sound tracks the hold, not the clip -------------------------------------

## M8. capture_charge used to be a pooled one shot: unaddressable once fired, so releasing
## the beam a frame after grabbing left it ringing to the end of its 1.19s clip regardless.
## It now runs on play_loop()/stop_loop(), a dedicated voice _take_back_physics() can
## always reach; this pins that a released grab stops it rather than letting it finish.
func test_capture_charge_stops_when_the_grab_is_released_before_it_secures() -> void:
	var beam: MagicBeam = _beam()
	var Sound := get_node("/root/Sound")
	var pony: Pony = PonyScene.instantiate()
	add_child_autofree(pony)
	pony.setup(_stock_data())
	beam._begin_hold(pony)
	assert_true(Sound.looping_ids().has(&"capture_charge"),
		"the charge sound must start with the hold")
	beam.release()
	assert_false(Sound.looping_ids().has(&"capture_charge"),
		"an aborted grab must not let the charge ring out")


func after_each() -> void:
	var Sound := get_node("/root/Sound")
	Sound.stop_all()


# --- the collector's recall (game/systems/ledger.gd's ladder) --------------------------

func test_a_recalled_beam_refuses_to_start() -> void:
	var beam: MagicBeam = _beam()
	assert_false(beam.is_recalled())
	beam.set_recalled(true)
	assert_true(beam.is_recalled())
	beam._start_beam()
	assert_false(beam.is_active(), "the horn is recalled; nothing comes out of it")


func test_the_beam_comes_back_and_works() -> void:
	var beam: MagicBeam = _beam()
	beam.set_recalled(true)
	beam.set_recalled(false)
	beam._start_beam()
	assert_true(beam.is_active())


func test_recalling_a_beam_that_is_holding_a_pony_releases_her_rather_than_losing_her() -> void:
	var beam: MagicBeam = _beam()
	var pony: Pony = PonyScene.instantiate()
	add_child_autofree(pony)
	pony.setup(_named_data())
	var ghost: WeakRef = weakref(pony)
	beam._begin_hold(pony)  # the file's existing helper for putting a pony in the beam
	beam.set_recalled(true)
	assert_false(beam.is_holding(), "she is put down, not vanished")
	assert_not_null(ghost.get_ref(), "NO PONY EVER DIES; a recall is not a way to remove one")


## THE OTHER BRANCH OF release(). The test above pins an UNSECURED hold (set down where
## she is floating, escaped() reported); a hold that has already crossed into SECURED
## territory when the recall lands takes release()'s other branch instead -- the ordinary
## winning one, _settle_pony() -- and must end up stored, not merely "not vanished". A
## recall landing on a secured hold and taking the LOSING branch would free her body with
## no PonyInstance ever minted for it: a pony gone with no record at all, which is a worse
## failure than the one the test above pins.
func test_recalling_a_beam_holding_a_secured_pony_stores_her_as_the_ordinary_catch() -> void:
	var beam: MagicBeam = _beam()
	var pony: Pony = PonyScene.instantiate()
	add_child_autofree(pony)
	var data: PonyData = _named_data()
	pony.setup(data)
	beam._begin_hold(pony)
	beam._hold_seconds = 999.0  # force is_secured() true regardless of this attempt's roll
	assert_true(beam.is_secured(), "test setup: this hold must already read as secured")

	beam.set_recalled(true)

	assert_false(beam.is_holding(), "she leaves the beam either way")
	assert_eq(beam.get_storage().count(), 1,
		"a secured hold recalled mid air is the ordinary catch outcome, not a loss")
	assert_eq(beam.get_storage().contents()[0].data_id, data.id,
		"...and it is HER record that landed in the bag")


## A hidden stock base record, resolved the same way every real caught stock pony's
## PonyInstance.data_id is: through the registry, not a direct path to game/data/hidden/.
func _stock_data() -> PonyData:
	var registry := PonyRegistryScript.new()
	registry.load_all("res://data/ponies")
	return registry.by_id(&"stock_shy")


## An ordinary named character, for the contrast case.
func _named_data() -> PonyData:
	var registry := PonyRegistryScript.new()
	registry.load_all("res://data/ponies")
	return registry.by_id(&"twilight")


# --- the delivery walk is not a shopping trip ----------------------------------------------
##
## THE EXPLOIT THESE PIN. deliver_pony() pays for a pony and points her at the Depot crate;
## she is a live CharacterBody3D walking across the map for the next few seconds. The beam
## used to accept any Pony at all, so the player could shoot the pony she had just been paid
## 4,000 bits for, and release() would settle her straight back into the saddlebag with the
## very PonyInstance the delivery had removed from the save. Credit kept, pony kept, and it
## repeats for as long as she can keep re-catching her.

func test_the_beam_declines_a_pony_who_is_walking_to_the_crate() -> void:
	var beam: MagicBeam = _beam()
	var pony: Pony = PonyScene.instantiate()
	add_child_autofree(pony)
	assert_true(beam._is_grabbable(pony), "an ordinary pony is grabbable, or this pins nothing")
	pony.leave_toward(pony.global_position + Vector3(20.0, 0.0, 0.0))
	assert_true(pony.is_being_delivered(), "sanity: she is on a delivery walk")
	assert_false(beam._is_grabbable(pony),
		"a pony the Company has already paid for is not there to be taken back")


func test_the_beam_still_takes_a_pony_whose_hours_simply_ended() -> void:
	# An ORDINARY departure has no destination and is nobody's property: capture wins over
	# leaving, exactly as it always did. Only the delivery walk is off limits.
	var beam: MagicBeam = _beam()
	var pony: Pony = PonyScene.instantiate()
	add_child_autofree(pony)
	pony.leave()
	assert_true(pony.is_leaving(), "sanity: she is walking off the map")
	assert_false(pony.is_being_delivered(), "...but nobody sent her anywhere")
	assert_true(beam._is_grabbable(pony), "she is catchable to the last step, as she always was")
