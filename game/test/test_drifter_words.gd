extends GutTest
## A Drifter reads as a Drifter (playtest 2026-11-08 item 9): under the crosshair, on the catch
## card and at the Depot, a blank Drifter, a Bloomed Drifter and a named pony say which they
## are, and the crosshair line names her favourite food without the Monocle (item 10, and the
## bait in S3 needs it).

const RanchToolsScript := preload("res://world/ranch_tools.gd")
const GeneratorScript := preload("res://systems/pony_generator.gd")


func test_the_crosshair_word_tells_the_three_apart() -> void:
	var blank := PonyInstance.new()
	blank.stock = GeneratorScript.generate(11).to_dict()
	var bloomed := PonyInstance.new()
	bloomed.stock = GeneratorScript.generate(12, {"marked": true}).to_dict()
	var named := PonyInstance.new()
	named.data_id = &"fluttershy"
	var data := PonyData.new()
	data.display_name = "Fluttershy"
	assert_eq(RanchToolsScript.kind_word(blank, null), "Drifter")
	assert_eq(RanchToolsScript.kind_word(bloomed, null), "Bloomed Drifter")
	assert_eq(RanchToolsScript.kind_word(named, data), "Fluttershy")


func test_a_stallion_has_his_own_pronoun() -> void:
	var braeburn: PonyData = load("res://data/ponies/braeburn.tres")
	var fluttershy: PonyData = load("res://data/ponies/fluttershy.tres")
	assert_eq(PonyData.pronoun_of(braeburn), &"he")
	assert_eq(PonyData.word(braeburn, "her"), "him")
	assert_eq(PonyData.pronoun_of(fluttershy), &"she")
	assert_eq(PonyData.pronoun_of(null), &"she", "a Drifter is she")
	for id in ["drwhooves", "shiningarmor", "soarin", "caramel", "nightlight", "pokeypierce"]:
		assert_eq(PonyData.pronoun_of(load("res://data/ponies/%s.tres" % id)), &"he", id)
