extends GutTest
## Pony traits (game/systems/pony_traits.gd): every Drifter has a favorite food and a quirk,
## the same ones every time (from her look's seed), and the quirks do what they say.

const Traits := preload("res://systems/pony_traits.gd")
const GeneratorScript := preload("res://systems/pony_generator.gd")


func _drifter(seed_value: int) -> PonyInstance:
	var inst := PonyInstance.create(&"stock_shy", 1000 + seed_value)
	inst.stock = GeneratorScript.generate(seed_value).to_dict()
	return inst


func test_traits_are_stable_and_varied() -> void:
	var quirks := {}
	var foods := {}
	for i in 120:
		var a := _drifter(5000 + i)
		var b := _drifter(5000 + i)
		assert_eq(Traits.quirk_of(a), Traits.quirk_of(b), "the same seed, the same quirk")
		assert_eq(Traits.favorite_of(a), Traits.favorite_of(b))
		quirks[Traits.quirk_of(a)] = true
		foods[Traits.favorite_of(a)] = true
	assert_eq(quirks.size(), Traits.QUIRK_ORDER.size(), "every quirk turns up in a herd of 120")
	assert_eq(foods.size(), Traits.FOODS.size(), "and every favorite food")


func test_a_drifters_favorite_is_hers_not_hay() -> void:
	var found := false
	for i in 40:
		var inst := _drifter(7000 + i)
		var fav := Traits.favorite_of(inst)
		assert_true(NeedsScript_is_favorite(inst, fav))
		if fav != &"hay":
			found = true
			assert_false(NeedsScript_is_favorite(inst, &"hay"), "hay is not every Drifter's favorite now")
	assert_true(found)


func NeedsScript_is_favorite(inst: PonyInstance, food: StringName) -> bool:
	return (load("res://systems/needs.gd") as Script).call("is_favorite", inst, food)


func test_the_rules() -> void:
	assert_eq(Traits.hunger_mult(&"glutton"), 2.0)
	assert_gt(Traits.gem_mult(&"glutton", false), 1.0)
	assert_gt(Traits.gem_mult(&"night_owl", true), Traits.gem_mult(&"night_owl", false))
	assert_gt(Traits.sparkle_chance(&"sparkler"), 0.0)
	assert_true(Traits.is_friend_to_all(&"social"))
	assert_gt(Traits.fret_per_second(&"loner", 3, false), 0.0)
	assert_eq(Traits.fret_per_second(&"loner", 2, false), 0.0)
	assert_gt(Traits.bloom_mult(&"loner", &"pegasus", 1), Traits.bloom_mult(&"loner", &"pegasus", 2))
	assert_lt(Traits.bloom_mult(&"sleepy", &"pegasus", 1), 1.0)
	assert_gt(Traits.bloom_mult(&"", &"earth", 2), Traits.bloom_mult(&"", &"unicorn", 2), "earth ponies Bloom faster")
	assert_true(Traits.escapes_from(&"escapee", &"pen_small", true))
	assert_false(Traits.escapes_from(&"escapee", &"pen_big", true), "a Big Pen holds her")
	assert_false(Traits.escapes_from(&"escapee", &"pen_small", false), "only at night")
	assert_gt(Traits.flee_mult(&"pegasus"), 1.0)
	assert_true(Traits.blinks(&"unicorn"))
	assert_gt(Traits.race_mult(&"showoff"), 1.0)
	assert_gt(Traits.notice_mult(&"skittish"), 1.0)
	assert_true(Traits.easy_hold(&"skittish"))


func test_canon_ponies_have_the_quirk_that_is_them() -> void:
	assert_eq(Traits.quirk_for({}, &"pinkiepie"), &"social")
	assert_eq(Traits.quirk_for({}, &"fluttershy"), &"skittish")
	assert_eq(Traits.quirk_for({}, &"rainbowdash"), &"showoff")


func test_describe_reads_like_a_sentence() -> void:
	var inst := _drifter(9001)
	var line := Traits.describe(inst)
	assert_true(line.contains("loves "), line)
	assert_false(line.contains("—"), "no em dashes")
