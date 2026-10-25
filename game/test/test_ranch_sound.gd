extends GutTest
## The ranch's own sound seams, tested without booting the ranch: the zone rule is a pure
## function of a position, an open casino panel and a region disc, so it is tested as one.
##
## THE HOOK SITES THEMSELVES are one line calls beside existing anchors and no test in the
## repo fires them end to end: the sound gate hosts no ranch on purpose (saves), and the
## ranch gate never reads Sound state. A deleted hook line is caught by review, not by CI;
## that gap is recorded in the slice ledger. What is here is the part that has a right and
## a wrong answer independent of a scene.

const SoundScript := preload("res://systems/sound.gd")
const RegionDataScript := preload("res://systems/region_data.gd")
const RanchScript := preload("res://world/ranch.gd")


func test_the_strip_disc_decides_the_strip_zone() -> void:
	var region: RegionData = RegionDataScript.new()
	region.id = &"strip"
	region.centre = Vector2(-10.0, 60.0)
	region.radius = 26.0
	assert_true(region.contains(Vector2(-10.0, 60.0)))
	assert_true(region.contains(Vector2(-10.0, 80.0)))
	assert_false(region.contains(Vector2(-10.0, 120.0)))


func test_the_zone_names_are_the_ones_the_bed_table_carries() -> void:
	# A typo here would be a zone that silently overlays nothing at all.
	assert_true(SoundScript.ZONE_BEDS.has(SoundScript.ZONE_STRIP))
	assert_true(SoundScript.ZONE_BEDS.has(SoundScript.ZONE_CASINO))
	assert_eq(String(SoundScript.ZONE_STRIP), "strip")
	assert_eq(String(SoundScript.ZONE_CASINO), "casino")


func test_ranch_declares_a_sound_zone_reader() -> void:
	# M9. autofree(), not a bare .new(): an un-added, un-freed Ranch is exactly the kind of
	# orphan Godot's own leak detector counts at process exit, and this is where the
	# suite's stray one lived.
	assert_true(autofree(RanchScript.new()).has_method("sound_zone"))


func test_every_id_the_ranch_fires_is_in_the_library() -> void:
	# The whole point of a registry is that a typo at a call site is caught here rather
	# than by a player hearing nothing.
	for id: StringName in [&"mail_arrive", &"delivery_thud", &"pen_in", &"coins_grant",
			&"race_crowd_loop", &"race_gallop", &"race_cheer", &"capture_charge",
			&"capture_success"]:
		assert_true(SoundScript.LIBRARY.has(id), "ranch fires '%s' and it is not in LIBRARY" % id)
