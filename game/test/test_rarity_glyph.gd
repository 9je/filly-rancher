extends GutTest
## RARITY IS NOT COLOUR ALONE (FS8.3). The saddlebag's slots and the compendium told rarity
## by tint only, which a colourblind player cannot read. Each rarity also has a shape: common
## a circle, uncommon a diamond, rare a star, legendary a crown.

const GlyphScript := preload("res://ui/rarity_glyph.gd")


func test_each_rarity_has_its_own_shape() -> void:
	var shapes := {}
	for r: int in [PonyData.Rarity.COMMON, PonyData.Rarity.UNCOMMON, PonyData.Rarity.RARE,
			PonyData.Rarity.LEGENDARY]:
		shapes[GlyphScript.shape_of(r)] = true
	assert_eq(shapes.size(), 4)
	assert_eq(GlyphScript.shape_of(PonyData.Rarity.RARE), &"star")


func test_each_shape_has_points_to_draw() -> void:
	for r: int in [PonyData.Rarity.COMMON, PonyData.Rarity.UNCOMMON, PonyData.Rarity.RARE,
			PonyData.Rarity.LEGENDARY]:
		assert_gt(GlyphScript.outline(r, Vector2(10, 10), 8.0).size(), 3)


func test_a_compendium_row_carries_its_ponys_glyph() -> void:
	var row := GlyphScript.new()
	row.rarity = PonyData.Rarity.LEGENDARY
	add_child_autofree(row)
	assert_eq(row.shape(), &"crown")
	assert_gt(row.custom_minimum_size.x, 0.0)



func test_the_saddlebag_slots_carry_their_ponys_shapes() -> void:
	var hud: Node = preload("res://ui/hud.tscn").instantiate()
	add_child_autofree(hud)
	hud.set("_rarities", [PonyData.Rarity.RARE, PonyData.Rarity.COMMON] as Array[int])
	assert_eq(hud.call("pip_shapes"), [&"star", &"circle"] as Array[StringName])
