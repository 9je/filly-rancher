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
	# make her personality unobservable rather than merely difficult.
	var pull_in: float = log(10.0) / MagicBeamScript.PULL_RESPONSE
	for personality in PonyDataScript.Personality.values():
		var seconds: float = MagicBeamScript.struggle_seconds_for(personality)
		assert_gt(seconds, pull_in * 2.0,
			"%s must resist for longer than the beam takes to reel her in (%.3f s)" % [
				PonyDataScript.Personality.keys()[personality], pull_in])


func test_an_unknown_personality_gets_the_bold_default_rather_than_zero() -> void:
	# A roster addition with a personality this file has not heard of must not become an
	# uncatchable (or instantly-escaping) pony.
	var fallback: float = MagicBeamScript.struggle_seconds_for(99)
	assert_eq(fallback, MagicBeamScript.STRUGGLE_BOLD,
		"an unknown personality falls back to BOLD's struggle time")
	assert_gt(fallback, 0.0)
	# BOLD is the STRICTEST hold since the second playtest's inversion, so this fallback
	# stopped being the forgiving one. It still has to leave a window a human can hit, or a
	# roster addition with an unrecognised personality would be flatly uncatchable.
	assert_gt(fallback - MagicBeamScript.SECURE_SECONDS, 0.4,
		"the fallback must still leave a hittable window (%.2f s of struggle against " % fallback +
		"%.2f s of securing)" % MagicBeamScript.SECURE_SECONDS)


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
	var pony_script := load("res://actors/pony/pony.gd")
	for personality in PonyDataScript.Personality.values():
		var radius: float = pony_script.notice_radius_for(personality, false)
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


func test_every_personality_has_a_window_wide_enough_to_hit() -> void:
	# The two clocks only produce a mechanic if the second is comfortably past the first.
	# A struggle time at or under SECURE_SECONDS would make that personality flatly
	# UNCATCHABLE -- and nothing else in the project would say so, because both numbers
	# would still look individually reasonable and every other test would still pass.
	for personality in PonyDataScript.Personality.values():
		var window: float = MagicBeamScript.capture_window_for(personality)
		assert_gt(window, 0.4,
			("%s must leave a window a human can act inside (got %.2f s: struggle %.2f s " +
			"minus secure %.2f s)") % [
				PonyDataScript.Personality.keys()[personality], window,
				MagicBeamScript.struggle_seconds_for(personality),
				MagicBeamScript.SECURE_SECONDS])


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
