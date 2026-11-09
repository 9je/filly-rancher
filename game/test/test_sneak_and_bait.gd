extends GutTest
## CATCHING BY BEHAVIOUR (P8 S3; playtest 2026-11-08 items 23, 25; ideas A2, A3): a running
## player is heard all round; a walking one is seen only in front, so you sneak up from
## behind; a skittish pony bolts whatever her temperament; and bait makes her easy.

const PonyScript := preload("res://actors/pony/pony.gd")
const PonyTraitsScript := preload("res://systems/pony_traits.gd")
const MagicBeamScript := preload("res://actors/player/magic_beam.gd")
const SHY := PonyData.Personality.SHY


func test_a_walker_behind_her_is_inside_the_beam_before_she_notices() -> void:
	var behind := PonyScript.notice_radius_for(SHY, true, false)
	var seen := PonyScript.notice_radius_for(SHY, true, true)
	var running := PonyScript.notice_radius_for(SHY, false)
	assert_lt(behind, MagicBeamScript.REACH - 1.5, "from behind at a walk: well inside the reach")
	assert_gt(seen, MagicBeamScript.REACH, "walking into her view: she still sees you first")
	assert_gt(running, seen, "running: she hears you from further still, all round")
	# A skittish pony's sharp eyes double what she SEES, and still she misses a walker behind.
	assert_lt(behind, MagicBeamScript.REACH, "behind is behind, even for sharp eyes")


func test_the_view_cone_is_in_front_of_her() -> void:
	# yaw 0 faces -Z.
	assert_true(PonyScript.in_view_cone(0.0, Vector3(0, 0, -5)), "straight ahead")
	assert_true(PonyScript.in_view_cone(0.0, Vector3(3, 0, -5)), "ahead and a little aside")
	assert_false(PonyScript.in_view_cone(0.0, Vector3(0, 0, 5)), "straight behind")
	assert_false(PonyScript.in_view_cone(0.0, Vector3(5, 0, 1)), "beside and behind")
	assert_true(PonyScript.in_view_cone(PI, Vector3(0, 0, 5)), "turned round, she sees +Z")


func test_skittish_ponies_bolt_whatever_their_temperament() -> void:
	assert_true(PonyTraitsScript.bolts(&"skittish"))
	assert_false(PonyTraitsScript.bolts(&"glutton"))
	assert_string_contains(PonyTraitsScript.quirk_text(&"skittish"), "behind")


func test_a_pony_at_a_treat_is_calm_and_easy() -> void:
	var p: Pony = PonyScript.new()
	autofree(p)
	p.calm = 0.0
	assert_eq(p.hold_personality(), PonyData.Personality.BOLD, "no record: the default is bold")
	p.calm = 5.0
	assert_eq(p.hold_personality(), SHY, "calm (eating a treat): she holds as the easiest grade")
	assert_lt(MagicBeamScript.clean_catch_seconds(p.hold_personality()),
		MagicBeamScript.clean_catch_seconds(PonyData.Personality.BOLD))
