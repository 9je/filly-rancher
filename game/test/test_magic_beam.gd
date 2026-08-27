extends GutTest
## Tests for the pure rules underneath the magic beam (game/actors/player/magic_beam.gd).
##
## The beam itself is a scene-level thing -- it needs a camera, a physics space and a live
## pony to mean anything, and that is what scenes/test/capture_test.tscn exists for. What
## is pinned HERE is the arithmetic the scene cannot isolate: the struggle times that make
## the three personalities feel different, and the zoom-invariance of the reach and hold
## distances. Both are static and pure precisely so they can be checked in milliseconds
## instead of inferred from where a pony ended up 200 frames into a render.
##
## Preloads by path rather than by the global class_name, matching the convention
## documented at the top of game/scripts/pony_rig.gd.

const MagicBeamScript := preload("res://actors/player/magic_beam.gd")
const PonyDataScript := preload("res://systems/pony_data.gd")


func test_shy_ponies_struggle_sooner_than_curious_ones_and_bold_ones() -> void:
	var shy: float = MagicBeamScript.struggle_seconds_for(PonyDataScript.Personality.SHY)
	var curious: float = MagicBeamScript.struggle_seconds_for(PonyDataScript.Personality.CURIOUS)
	var bold: float = MagicBeamScript.struggle_seconds_for(PonyDataScript.Personality.BOLD)
	assert_lt(shy, curious, "a SHY pony must break free before a CURIOUS one")
	assert_lt(curious, bold, "...and a CURIOUS one before a BOLD one")


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


func test_the_beam_reaches_past_a_ponys_detection_radius() -> void:
	# Sizing check with teeth: a SHY pony starts fleeing at Pony.DETECTION_RADIUS. A reach
	# shorter than that would mean she is always already running by the time she is
	# grabbable, and catching one would be a foot race rather than an aim.
	var pony_script := load("res://actors/pony/pony.gd")
	assert_gt(MagicBeamScript.REACH, pony_script.DETECTION_RADIUS,
		"the beam must out-reach the radius at which a shy pony bolts")
