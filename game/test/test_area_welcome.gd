extends GutTest
## A NEW AREA OPENS WITH A RARE IN IT (PT9; playtest 2026-11-05: "why did i even pay for apple
## area if there were no rare ponies in there?"): one of its uncaught rares steps out inside
## the gate, and the trail leads there.

const RanchScene := preload("res://world/ranch.tscn")


func test_opening_the_orchard_brings_out_one_of_its_rares() -> void:
	var ranch = RanchScene.instantiate()
	add_child_autofree(ranch)
	await wait_physics_frames(4)
	var region: RegionData = ranch.call("_regions_registry").by_id(&"orchard")
	assert_not_null(region)
	var guest: Node3D = ranch.call("_welcome_rare", region)
	assert_not_null(guest, "somepony rare steps out")
	if guest == null:
		return
	var data: PonyData = guest.call("get_data")
	assert_gte(data.rarity, 1, "a rare, not a commoner")
	assert_has(data.spawn_zones, &"orchard", "and one who lives there")
	assert_eq(ranch.get("happenings").get("sighting"), guest, "the trail leads to her")
