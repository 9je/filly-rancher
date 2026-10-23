extends GutTest
## The generator v2 stack: PonyLook round trips, PonyGenerator determinism and harmony,
## the donor table, MarkComposer output, and PonyPaint on a real donor body.

const PonyLookScript := preload("res://systems/pony_look.gd")
const GeneratorScript := preload("res://systems/pony_generator.gd")
const DonorTableScript := preload("res://systems/donor_table.gd")
const MarkComposerScript := preload("res://systems/mark_composer.gd")
const PonyPaintScript := preload("res://systems/pony_paint.gd")
const EYE := preload("res://shaders/pony_eye.gdshader")
const TOON := preload("res://shaders/toon.gdshader")
const ToonStylerScript := preload("res://systems/toon_styler.gd")

var _shading_was := true


func before_each() -> void:
	# The material checks below need the real shader swap even in a headless run.
	_shading_was = ToonStylerScript.shading_enabled
	ToonStylerScript.shading_enabled = true


func after_each() -> void:
	ToonStylerScript.shading_enabled = _shading_was


func test_the_donor_table_covers_all_three_races_and_foals() -> void:
	var t := DonorTableScript.load_table()
	assert_eq(t.donors.size(), 38)
	assert_gt(t.for_race(&"earth").size(), 15)
	assert_gt(t.for_race(&"pegasus").size(), 5)
	assert_gt(t.for_race(&"unicorn").size(), 5)
	for race: StringName in [&"earth", &"pegasus", &"unicorn"]:
		assert_gt(t.for_race(race, true).size(), 0, "a %s foal donor" % race)


func test_no_tier_a_model_is_a_donor() -> void:
	var ids := DonorTableScript.load_table().ids()
	for canon: StringName in [&"twilight", &"rainbowdash", &"fluttershy", &"applejack", &"rarity"]:
		assert_false(canon in ids, "%s must not be a donor" % canon)


func test_the_same_seed_gives_the_same_pony() -> void:
	var a := GeneratorScript.generate(12345)
	var b := GeneratorScript.generate(12345)
	assert_eq(a.to_dict(), b.to_dict())
	var c := GeneratorScript.generate(12346)
	assert_ne(a.to_dict(), c.to_dict())


func test_a_look_round_trips_through_a_dictionary() -> void:
	var a := GeneratorScript.generate(777, {"marked": true})
	var b := PonyLookScript.from_dict(a.to_dict())
	assert_eq(b.to_dict(), a.to_dict())
	assert_true(b.has_mark())
	# And through JSON, which is what a save does to it.
	var c := PonyLookScript.from_dict(JSON.parse_string(JSON.stringify(a.to_dict())))
	assert_eq(c.to_dict(), a.to_dict())


func test_pinned_race_and_foal_pick_a_donor_that_can_wear_them() -> void:
	var t := DonorTableScript.load_table()
	for i in range(30):
		var p := GeneratorScript.generate(1000 + i, {"race": &"pegasus"})
		assert_eq(p.race, &"pegasus")
		assert_eq(StringName(t.find(p.donor).get("race", "")), &"pegasus")
		var f := GeneratorScript.generate(2000 + i, {"foal": true})
		assert_true(bool(t.find(f.donor).get("foal", false)))


func test_a_hundred_ponies_use_many_donors_and_many_coats() -> void:
	var donors := {}
	var coats := {}
	var races := {}
	for i in range(100):
		var p := GeneratorScript.generate(i * 7919)
		donors[p.donor] = true
		coats[p.coat.to_html()] = true
		races[p.race] = true
	assert_gt(donors.size(), 20)
	assert_gt(coats.size(), 15)
	assert_eq(races.size(), 3)


func test_manes_are_more_saturated_than_coats_on_average() -> void:
	var gap := 0.0
	for i in range(200):
		var p := GeneratorScript.generate(i)
		gap += p.mane.s - p.coat.s
	assert_gt(gap / 200.0, 0.2, "the show's manes are punchier than its coats")


func test_drifters_are_blank_flanked_until_they_bloom() -> void:
	var p := GeneratorScript.generate(42)
	assert_false(p.has_mark())
	GeneratorScript.bloom(p)
	assert_true(p.has_mark())
	assert_true(MarkComposerScript.TALENTS.has(p.mark.talent))
	# Blooming is deterministic per pony.
	var q := GeneratorScript.generate(42)
	GeneratorScript.bloom(q)
	assert_eq(q.to_dict(), p.to_dict())


func test_every_talent_draws_a_visible_mark_in_every_arrangement() -> void:
	for talent: StringName in MarkComposerScript.talent_ids():
		for motif in range(3):
			var img := MarkComposerScript.compose({"talent": talent, "motif": motif,
				"a": Color(0.9, 0.3, 0.4), "b": Color(1, 0.9, 0.5)})
			assert_not_null(img)
			var covered := 0
			for y in range(0, img.get_height(), 4):
				for x in range(0, img.get_width(), 4):
					if img.get_pixel(x, y).a > 0.5:
						covered += 1
			# 1024 samples; a mark should cover a real part of its square but not all of it.
			assert_between(covered, 40, 900, "%s motif %d coverage" % [talent, motif])


func test_names_are_two_words_and_deterministic() -> void:
	var n := GeneratorScript.make_name(99)
	assert_eq(n, GeneratorScript.make_name(99))
	assert_eq(n.split(" ").size(), 2)


func test_paint_puts_toon_on_every_visible_surface_of_every_donor() -> void:
	var t := DonorTableScript.load_table()
	for id: StringName in t.ids():
		var path := DonorTableScript.model_path(id)
		if not ResourceLoader.exists(path):
			pending("assets absent: %s" % path)
			return
		var body: Node3D = (load(path) as PackedScene).instantiate()
		add_child_autofree(body)
		var look := GeneratorScript.generate(id.hash())
		look.donor = id
		look.race = StringName(t.find(id).get("race", "earth"))
		var n := PonyPaintScript.apply(body, look)
		assert_gt(n, 6, "%s painted surfaces" % id)
		for node: Node in body.find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = node
			if not mi.visible or mi.mesh == null:
				continue
			for i in range(mi.mesh.get_surface_count()):
				var m: Material = mi.get_active_material(i)
				assert_true(m is ShaderMaterial, "%s/%s surface %d is not toon" % [id, mi.name, i])
				if m is ShaderMaterial and m != PonyPaintScript.hidden_material():
					var sh: Shader = (m as ShaderMaterial).shader
					assert_true(sh == TOON or sh == EYE, "%s/%s unknown shader" % [id, mi.name])


func test_an_earth_pony_from_a_unicorn_donor_hides_the_horn() -> void:
	var path := DonorTableScript.model_path(&"pokeypierce")
	if not ResourceLoader.exists(path):
		pending("assets absent")
		return
	var body: Node3D = (load(path) as PackedScene).instantiate()
	add_child_autofree(body)
	var look := GeneratorScript.generate(5, {"race": &"earth"})
	look.donor = &"pokeypierce"
	look.race = &"earth"
	PonyPaintScript.apply(body, look)
	var horn_visible := false
	for node: Node in body.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node
		if mi.mesh != null and mi.mesh.get_surface_count() == 1:
			var m := mi.mesh.surface_get_material(0)
			if m != null and m.resource_name == "horn" and mi.visible:
				horn_visible = true
	assert_false(horn_visible)


func test_canon_accessories_are_hidden() -> void:
	for id: StringName in [&"cocopommel", &"kerfuffle"]:
		var path := DonorTableScript.model_path(id)
		if not ResourceLoader.exists(path):
			pending("assets absent")
			return
		var body: Node3D = (load(path) as PackedScene).instantiate()
		add_child_autofree(body)
		var look := GeneratorScript.generate(9)
		look.donor = id
		PonyPaintScript.apply(body, look)
		for node: Node in body.find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = node
			if mi.mesh == null:
				continue
			for i in range(mi.mesh.get_surface_count()):
				var m := mi.mesh.surface_get_material(i)
				if m != null and m.resource_name in ["hair_clip", "clothes"]:
					assert_eq(mi.get_active_material(i), PonyPaintScript.hidden_material(),
						"%s %s must be hidden" % [id, m.resource_name])
					assert_true(mi.visible, "%s: the hair sharing the mesh stays" % id)


func test_shade_names_read_like_a_dye_label() -> void:
	var n := GeneratorScript.shade_name(Color(1.0, 0.8, 0.6), 4)
	assert_string_ends_with(n, "No. 4")
	assert_eq(n.split(" ").size(), 4)


func test_no_generated_pony_wears_a_canon_characters_colors() -> void:
	for i in range(400):
		var p := GeneratorScript.generate(i * 31 + 7)
		assert_false(GeneratorScript.reads_as_canon(p.coat, p.mane),
			"seed %d drew a canon signature (%s on %s)" % [i * 31 + 7, p.mane.to_html(), p.coat.to_html()])
	# And the check itself recognises the signature it exists for.
	assert_true(GeneratorScript.reads_as_canon(Color(0.78, 0.79, 0.84), Color(0.98, 0.93, 0.62)))
