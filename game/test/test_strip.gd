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

## The way that half turn points the Palace's own local +Z, which is the gable end its door
## is in: world minus Z. ranch.gd derives this off the live node's basis rather than typing
## it, which is the whole point of the argument.
const PALACE_OUT_DIR := Vector3(0.0, 0.0, -1.0)


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
		PALACE_OUT_DIR,
		Vector2(PALACE_WIDTH * 0.5, PALACE_DEPTH * 0.5),
		PALACE_ORIGIN.y + PALACE_RIDGE_Y)
	strip.build()
	return strip


## The same Strip, mounted on a Palace turned to face somewhere else entirely. Nothing about
## the ranch stands this way; it exists so the claims below are claims about the arithmetic
## rather than about the one angle ranch.tscn happens to use.
func _built_strip_facing(out_dir: Vector3) -> Strip:
	var strip: Strip = StripScript.new()
	add_child_autofree(strip)
	strip.configure(_strip_region(), func(_x: float, _z: float) -> float: return 0.0)
	strip.mount_marquee(
		PALACE_ORIGIN + out_dir * (PALACE_DEPTH * 0.5), out_dir,
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


## The regression this whole file exists for: built with the SHIPPED region geometry, the
## SHIPPED Palace footprint AND its door apron (game/world/ranch.tscn's Buildings/Palace
## transform, Building width/depth/door_width and DOOR_APRON_RUN, restated here as literals
## because this file does not load .tscn or building.gd), no lamp stands inside or against
## the wall OR inside the doorway the apron reaches out into.
##
## THE APRON RECTANGLE, SPELLED OUT, because ranch.gd derives it rather than typing it and
## this file cannot follow that derivation without loading building.gd. Centre (-10, 55.76)
## is the Palace's own X (-10, the same centre the wall rectangle above uses) and the
## midpoint, in world Z, between the apron's near and far reach measured along the
## Palace's own local +Z (apron_foot_z() - DOOR_APRON_RUN = 4.44, and apron_foot_z() = 7.24)
## -- which the shipped Palace's half turn points at world minus Z, so
## 61.6 - (4.44 + 7.24) / 2 = 55.76. Half extents are the BUILDING's own half width (7.0, the
## same half width the wall rectangle uses) by half of DOOR_APRON_RUN (1.4) -- the width is
## deliberately the building's, not the door leaf's own half width (1.6): a lamp reviewed on
## the shipped map stood four metres off the door leaf's own centreline, clearing a
## leaf-width rectangle by 0.41 m while still standing in the doorway a walking player sees.
func test_the_shipped_palace_footprint_and_apron_cost_exactly_two_lamps() -> void:
	var s := _strip()
	s.avoid_footprint(Vector2(-10.0, 61.6), Vector2(7.0, 4.5))
	s.avoid_footprint(Vector2(-10.0, 55.76), Vector2(7.0, 1.4))
	s.build()
	assert_eq(s.light_count(), 8,
		"the shipped Palace's wall and its door apron together cost two of the ten ring spots -- a lamp cannot stand in the doorway")


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


## OWNER PLAYTEST 2026-10-25, "weird sign you gotta walk through to get in": the board hangs
## over the door, its lower edge MARQUEE_CLEARANCE up, where the camera behind a pony on the
## steps never meets it; and no higher than that needs (the worn Palace model's frieze, under
## its dome). The shell's own 4.6 m ridge is hidden inside that model, so it is not the
## roofline any more.
func test_the_marquee_hangs_over_the_door_not_across_it() -> void:
	var strip: Strip = _built_strip()
	var bottom: float = strip.marquee_top_y() - strip.marquee_board_size().y
	assert_gte(bottom, PALACE_ORIGIN.y + StripScript.MARQUEE_CLEARANCE - 0.01,
		"the board's lower edge clears the camera on the steps")
	assert_lte(strip.marquee_top_y(), PALACE_ORIGIN.y + StripScript.MARQUEE_CLEARANCE
		+ StripScript.MARQUEE_HEIGHT + 0.01, "and rises no higher than that needs")


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


## THE SIGN IS ON THE SIDE THE DOOR IS ON, WHICHEVER SIDE THAT IS. strip.gd used to hang the
## board at `front_centre.z - MARQUEE_STANDOFF` and turn its letters by exactly PI: world
## minus Z, written twice, correct only for the one angle ranch.tscn stands the Palace at.
## A Palace turned any other way had its sign standing INSIDE the building with its back to
## the approach. Nothing on the shipped map turns it, so the only way this stays true is a
## test that turns it.
func test_the_marquee_follows_the_building_round_rather_than_facing_world_minus_z() -> void:
	for out_dir: Vector3 in [Vector3(0.0, 0.0, -1.0), Vector3(0.0, 0.0, 1.0),
			Vector3(1.0, 0.0, 0.0), Vector3(-1.0, 0.0, 0.0)]:
		var strip: Strip = _built_strip_facing(out_dir)
		var front: Vector3 = PALACE_ORIGIN + out_dir * (PALACE_DEPTH * 0.5)
		var centre: Vector3 = strip.marquee_board_centre()
		var flat_offset := Vector3(centre.x - front.x, 0.0, centre.z - front.z)
		assert_almost_eq(flat_offset.dot(out_dir), StripScript.MARQUEE_STANDOFF, 0.001,
			"the board stands one standoff OUT from the front face, on the door's own side")
		assert_almost_eq(flat_offset.length(), StripScript.MARQUEE_STANDOFF, 0.001,
			"and nowhere sideways of it")
		assert_almost_eq(strip.marquee_facing().dot(out_dir), 1.0, 0.001,
			"the board looks the same way the door does")


func test_the_marquee_letters_turn_with_the_board() -> void:
	for out_dir: Vector3 in [Vector3(0.0, 0.0, -1.0), Vector3(1.0, 0.0, 0.0)]:
		var strip: Strip = _built_strip_facing(out_dir)
		var headline := strip.get_node_or_null(^"MarqueeHeadline") as Label3D
		assert_not_null(headline, "the board carries a headline")
		# Label3D's own text faces its local plus Z, so the yaw the label is turned by must
		# point that axis along the facing.
		var looks: Vector3 = headline.global_transform.basis * Vector3(0.0, 0.0, 1.0)
		assert_almost_eq(Vector3(looks.x, 0.0, looks.z).normalized().dot(out_dir), 1.0,
			0.001, "the letters read from the approach, not from inside the building")


## THE BULB RAIL IS NOT A LAMP POST. light_count() answers how many lamp posts are standing on
## the ring; this file already pins that at LIGHT_COUNT minus the two skipped clear of the
## Palace (its wall, and since the look pass its door apron), and a bulb rail counted among
## them would break that check for a reason that has nothing to do with lamp posts.
func test_the_marquee_bulbs_and_wash_are_not_counted_among_the_lamp_posts() -> void:
	var strip: Strip = _built_strip()
	assert_not_null(strip.get_node_or_null(^"MarqueeBulbs"))
	assert_not_null(strip.get_node_or_null(^"MarqueeWash"))
	assert_eq(strip.marquee_bulb_count(), StripScript.MARQUEE_BULBS)
	# _built_strip() calls no avoid_footprint(), so all ten ring positions stand: the claim
	# here is only that ten bulbs did not become twenty lamps. The shipped Palace's own
	# "LIGHT_COUNT minus two" case is pinned by this file's existing avoidance tests, which
	# are untouched.
	assert_eq(strip.light_count(), StripScript.LIGHT_COUNT,
		"a bulb rail is not a lamp post and must not be counted as one")


## THE ARCH'S OWN BUILT PEAK, measured off its actual child nodes rather than off any
## accessor: each child's own AABB corners carried through its global_transform, the same
## corner-projection game/test/test_lobby_sign.gd's own _front_reach() uses for a front face,
## here for a top one. This is only possible because _marquee_arch() builds plain
## MeshInstance3D children rather than a MultiMesh: a MultiMesh's instance transforms are
## RenderingServer state, and the headless dummy driver this suite is required to run under
## never allocates that buffer -- get_instance_transform() reads back all zeroes there even
## right after set_instance_transform() wrote real numbers, confirmed against the same code
## run under a real Vulkan context, where the readback is correct. A MeshInstance3D's own
## global_transform carries no such gap; it is a plain node property either way.
func _arch_measured_peak_y(strip: Strip) -> float:
	var root := strip.get_node(^"MarqueeArch")
	var highest := -INF
	for child in root.get_children():
		var mesh := child as MeshInstance3D
		var box: AABB = mesh.get_aabb()
		var xform: Transform3D = mesh.global_transform
		for i in range(8):
			highest = maxf(highest, (xform * box.get_endpoint(i)).y)
	return highest


func test_the_marquee_stands_a_real_arch_over_the_board() -> void:
	var strip: Strip = _built_strip()
	var arch := strip.get_node_or_null(^"MarqueeArch")
	assert_not_null(arch, "the marquee is geometry now, not a label on a slab")
	var segments: Array = arch.get_children()
	assert_eq(segments.size(), StripScript.MARQUEE_ARCH_SEGMENTS,
		"every segment of the arch is drawn, as its own node")
	assert_eq(strip.marquee_arch_segments(), StripScript.MARQUEE_ARCH_SEGMENTS)
	for child in segments:
		assert_true(child is MeshInstance3D,
			"a plain MeshInstance3D per segment, not a MultiMesh a headless run cannot read back")


## MEASURED TWO WAYS ON PURPOSE. marquee_arch_peak_y() is the accessor a caller would use;
## _arch_measured_peak_y() recomputes the same number independently off the actual built
## nodes' own global AABBs, so this test cannot pass merely because the accessor and the
## geometry agree with EACH OTHER while both drift from reality. A prior version of this test
## asserted only against the accessor, which was a pure `marquee_top_y() + MARQUEE_ARCH_RISE`
## identity -- it could not fail for any bug in the actual construction loop, including the
## sunburst overshoot a reviewer found by hand (roughly ridge_y + 0.29m to + 0.55m depending on
## which segment is checked, against nine long, straight, rigid boxes swept by a CIRCULAR
## angle formula applied to what is actually a very flat, wide ellipse -- aspect roughly 15:1
## here, so a circular tangent rotates the shoulder and near-end segments tens of degrees
## steeper than the ellipse's own nearly-flat true tangent). _marquee_arch() now places each
## segment's own endpoints ON the true ellipse and rotates it to the ellipse's own derivative,
## which is what this test actually holds it to.
func test_the_arch_rises_above_the_board_and_stays_under_the_roofline() -> void:
	var strip: Strip = _built_strip()
	var accessor_peak: float = strip.marquee_arch_peak_y()
	var measured_peak: float = _arch_measured_peak_y(strip)
	assert_lte(measured_peak, strip.marquee_top_y() + StripScript.MARQUEE_ARCH_RISE + 0.01,
		"the arch's own built geometry must not overshoot the rise it was budgeted")
	# (The shell's ridge is no longer the roofline: since 2026-10-25 the board hangs on the
	# worn Palace model's frieze, above the shell, and the arch sits under the model's dome.)
	assert_gt(accessor_peak, strip.marquee_top_y(), "the arch rises above the board")
	assert_almost_eq(accessor_peak, measured_peak, 0.01,
		"marquee_arch_peak_y() must report the built mesh's own true peak")


func test_the_bulb_rail_rings_the_whole_arch_rather_than_two_straight_rows() -> void:
	var strip: Strip = _built_strip()
	assert_eq(strip.marquee_bulb_count(), StripScript.MARQUEE_BULBS)
	assert_gte(StripScript.MARQUEE_BULBS, 18, "a marquee's rail is a ring, not five and five")


func test_the_board_and_its_trim_are_never_within_a_hair_of_coplanar() -> void:
	var strip: Strip = _built_strip()
	var board := strip.get_node(^"MarqueeBoard") as MeshInstance3D
	var trim := strip.get_node(^"MarqueeTrim") as MeshInstance3D
	var facing: Vector3 = strip.marquee_facing()
	var board_face: float = board.global_position.dot(facing) \
		+ (board.mesh as BoxMesh).size.z * 0.5
	var trim_face: float = trim.global_position.dot(facing) \
		+ (trim.mesh as BoxMesh).size.z * 0.5
	assert_gt(board_face - trim_face, StripScript.MARQUEE_STANDOFF_LAYER - 0.001,
		"one centimetre of separation is what the flickering gold was")
