extends GutTest
## game/world/strip.gd: the lamp ring and marquee on the Strip. Position arithmetic and the
## avoid_footprint() clearance rule, not rendering; no ground sampler is handed over (the
## lamps' y is irrelevant to every claim here), and no scene beyond the node itself.

const StripScript := preload("res://world/strip.gd")
const RegionDataScript := preload("res://systems/region_data.gd")

## Mirrors game/data/regions/strip.tres. A copy rather than a load off disk so this file's
## geometry claims stay pinned to numbers written in the test, not to whatever the .tres
## happens to say today; test_region_registry.gd is where the shipped file itself is
## checked.
const STRIP_CENTRE := Vector2(0.0, 74.0)


func _strip() -> Strip:
	var s: Strip = autofree(StripScript.new())
	add_child_autofree(s)
	var region: RegionData = RegionDataScript.new()
	region.id = &"strip"
	region.centre = STRIP_CENTRE
	region.radius = 26.0
	s.configure(region, Callable())
	return s


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
