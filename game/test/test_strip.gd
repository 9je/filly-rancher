extends GutTest
## game/world/strip.gd: the lamp ring and marquee on the Strip. Position arithmetic and the
## avoid_footprint() clearance rule, not rendering; no ground sampler is handed over (the
## lamps' y is irrelevant to every claim here), and no scene beyond the node itself.

const StripScript := preload("res://world/strip.gd")
const RegionDataScript := preload("res://systems/region_data.gd")
const CasinoSignScript := preload("res://systems/casino_sign.gd")

## Mirrors game/data/regions/strip.tres. A copy rather than a load off disk so this file's
## geometry claims stay pinned to numbers written in the test, not to whatever the .tres
## happens to say today; test_region_registry.gd is where the shipped file itself is
## checked.
const STRIP_CENTRE := Vector2(0.0, 74.0)

## Buildings/Palace as ranch.tscn stands it: origin (-10, 0, 61.6), turned a half turn, so
## its door faces the approach from the south. Repeated here rather than read off the scene
## because this test builds a Strip on its own and hands it the same numbers ranch.gd does.
const PALACE_ORIGIN := Vector3(-10.0, 0.0, 61.6)
const PALACE_WIDTH := 14.0
const PALACE_DEPTH := 9.0
const PALACE_RIDGE_Y := 4.6
const PALACE_FRONT_Z := PALACE_ORIGIN.z - PALACE_DEPTH * 0.5


func _strip_region() -> RegionData:
	var region: RegionData = RegionDataScript.new()
	region.id = &"strip"
	region.centre = STRIP_CENTRE
	region.radius = 26.0
	return region


func _strip() -> Strip:
	var s: Strip = autofree(StripScript.new())
	add_child_autofree(s)
	s.configure(_strip_region(), Callable())
	return s


func _built_strip() -> Strip:
	var strip: Strip = StripScript.new()
	add_child_autofree(strip)
	strip.configure(_strip_region(), func(_x: float, _z: float) -> float: return 0.0)
	strip.mount_marquee(
		Vector3(PALACE_ORIGIN.x, PALACE_ORIGIN.y, PALACE_FRONT_Z),
		Vector2(PALACE_WIDTH * 0.5, PALACE_DEPTH * 0.5),
		PALACE_ORIGIN.y + PALACE_RIDGE_Y)
	strip.build()
	return strip


func test_with_nothing_to_avoid_all_ten_lamps_stand() -> void:
	var s := _strip()
	s.build()
	assert_eq(s.light_count(), StripScript.LIGHT_COUNT)
	assert_eq(s.light_positions().size(), StripScript.LIGHT_COUNT)


## Lamp #6 (angle 216 degrees) sits at (-16.99, 61.66); the reviewer's own finding on the
## shipped Palace at (-10, 61.6), width 14, depth 9. A synthetic footprint standing on that
## exact spot pins the skip without needing the real ranch.tscn or Building.gd in this test.
func test_a_footprint_over_a_ring_position_skips_that_lamp_and_no_other() -> void:
	var s := _strip()
	s.avoid_footprint(Vector2(-10.0, 61.6), Vector2(7.0, 4.5))
	s.build()
	assert_eq(s.light_count(), StripScript.LIGHT_COUNT - 1,
		"exactly one of the ten ring positions falls inside this footprint")
	for pos: Vector3 in s.light_positions():
		var gap_x: float = absf(pos.x - -10.0) - 7.0
		var gap_z: float = absf(pos.z - 61.6) - 4.5
		assert_true(gap_x >= StripScript.PALACE_CLEARANCE or gap_z >= StripScript.PALACE_CLEARANCE,
			"lamp at (%.2f, %.2f) does not clear the footprint by PALACE_CLEARANCE" % [pos.x, pos.z])


## The regression this whole file exists for: built with the SHIPPED region geometry and
## the SHIPPED Palace footprint (game/world/ranch.tscn's Buildings/Palace transform and
## Building width/depth, restated here as literals because this file does not load .tscn),
## no lamp stands inside or against the wall.
func test_the_shipped_palace_footprint_costs_exactly_one_lamp() -> void:
	var s := _strip()
	s.avoid_footprint(Vector2(-10.0, 61.6), Vector2(7.0, 4.5))
	s.build()
	assert_eq(s.light_count(), 9, "the shipped Palace sits on exactly one of the ten ring spots")


func test_avoid_footprint_called_after_build_has_no_effect_on_an_idempotent_second_build() -> void:
	var s := _strip()
	s.build()
	var before := s.light_count()
	s.avoid_footprint(Vector2(-10.0, 61.6), Vector2(7.0, 4.5))
	s.build()
	assert_eq(s.light_count(), before, "build() is idempotent; a second call changes nothing")


## THE MARQUEE, AFTER 2026-08-31. It was a bare Label3D with no width limit carrying a 66
## character line at 0.0086 m per pixel: about 18 m of text across a 14 m building, at 5.4 m
## on a building whose ridge is 4.6 m. The owner: "marquee is unreadable and clips the
## roof". It is a fitted board now, and both of those are properties a test can hold.
func test_the_marquee_board_is_narrower_than_the_building_it_advertises() -> void:
	var strip: Strip = _built_strip()
	var size: Vector2 = strip.marquee_board_size()
	assert_gt(size.x, 0.0, "there is a board")
	assert_lt(size.x, PALACE_WIDTH,
		"a sign wider than its own building is the thing that was wrong")


func test_the_marquee_is_mounted_clear_of_the_roofline() -> void:
	var strip: Strip = _built_strip()
	assert_lt(strip.marquee_top_y(), PALACE_RIDGE_Y,
		"the top of the board must sit below the ridge, or it crosses the roof")


func test_the_marquee_hangs_in_front_of_the_wall_rather_than_inside_it() -> void:
	var strip: Strip = _built_strip()
	var centre: Vector3 = strip.marquee_board_centre()
	assert_lt(centre.z, PALACE_FRONT_Z,
		"the board stands on the approach side of the front wall")
	assert_gt(PALACE_FRONT_Z - centre.z, 0.2,
		"and far enough off it not to fight the wall for pixels")


func test_the_marquee_says_the_headline_and_the_sponsor_and_nothing_else() -> void:
	var strip: Strip = _built_strip()
	var lines: Array[String] = strip.marquee_lines()
	assert_eq(lines.size(), 2, "a headline and a sponsor line, in that order")
	assert_eq(lines[0], CasinoSignScript.HEADLINE)
	assert_eq(lines[1], CasinoSignScript.SPONSOR)
	for line in lines:
		assert_false(line.contains("--") or line.contains("—"), line)
