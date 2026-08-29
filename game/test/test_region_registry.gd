extends GutTest
## The regions as data: game/systems/region_data.gd, game/systems/region_registry.gd,
## and game/data/regions/*.tres. Same shape as test_shop_registry.gd.

const RegionRegistryScript := preload("res://systems/region_registry.gd")
const RegionDataScript := preload("res://systems/region_data.gd")
const TerrainScript := preload("res://world/terrain.gd")
const RegionFenceScript := preload("res://world/region_fence.gd")


func _registry() -> RegionRegistry:
	var reg: RegionRegistry = RegionRegistryScript.new()
	reg.load_all(RegionRegistryScript.REGION_DIR)
	return reg


func test_the_four_regions_load() -> void:
	var ids: Array = []
	for r in _registry().all():
		ids.append(String(r.id))
	ids.sort()
	assert_eq(ids, ["everfree", "lake", "nightmeadow", "orchard"])


func test_all_is_sorted_by_permit_cost_then_id_and_costs_are_positive() -> void:
	var items := _registry().all()
	for i in range(items.size()):
		assert_gt(items[i].permit_cost, 0, "%s must cost something" % items[i].id)
		if i > 0:
			var a := items[i - 1]
			var b := items[i]
			assert_true(a.permit_cost < b.permit_cost or (a.permit_cost == b.permit_cost and String(a.id) < String(b.id)))


func test_every_region_sits_outside_the_homestead_apron_and_inside_the_map() -> void:
	for r in _registry().all():
		var d: float = r.centre.distance_to(TerrainScript.HOMESTEAD_CENTRE)
		assert_gt(d - r.radius, TerrainScript.BLEND_RADIUS, "%s must be clear of the apron" % r.id)
		var reach: float = maxf(absf(r.centre.x), absf(r.centre.y)) + r.radius + RegionFenceScript.RING_MARGIN
		assert_lt(reach, TerrainScript.HALF - 5.0, "%s must fit inside the boundary wall" % r.id)


func test_regions_do_not_overlap_each_other() -> void:
	var items := _registry().all()
	for i in range(items.size()):
		for j in range(i + 1, items.size()):
			var gap: float = items[i].centre.distance_to(items[j].centre) - items[i].radius - items[j].radius
			assert_gt(gap, 6.0, "%s and %s need a walkable gap between their fences" % [items[i].id, items[j].id])


func test_display_names_carry_no_dashes() -> void:
	for r in _registry().all():
		assert_false(r.display_name.is_empty())
		assert_false(r.display_name.contains("--") or r.display_name.contains("—"))


func test_permit_id_and_contains() -> void:
	var r: RegionData = RegionDataScript.new()
	r.id = &"orchard"
	r.centre = Vector2(10.0, 10.0)
	r.radius = 5.0
	assert_eq(r.permit_id(), &"permit_orchard")
	assert_true(r.contains(Vector2(12.0, 12.0)))
	assert_false(r.contains(Vector2(20.0, 10.0)))


func test_region_at_finds_the_disc_or_null() -> void:
	var reg := _registry()
	var orchard: RegionData = reg.by_id(&"orchard")
	assert_not_null(orchard)
	assert_eq(reg.region_at(orchard.centre), orchard)
	assert_null(reg.region_at(Vector2.ZERO), "the homestead is open ranch")


func test_exactly_one_region_has_a_lake() -> void:
	var lakes := 0
	for r in _registry().all():
		if r.has_lake:
			lakes += 1
			assert_gt(r.lake_depth, 0.0)
	assert_eq(lakes, 1)
