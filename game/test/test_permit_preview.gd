extends GutTest
## A PERMIT SHOWS ITS PONIES BEFORE YOU BUY IT (PS9, playtest 2026-11-05 item 55: "Buying the
## Orchard felt pointless (no rares seen). Each area should show its ponies and their times
## before you buy"). The Market's detail strip for a permit lists everypony who lives there,
## rarest first, each with her rarity shape and the hours she keeps.

const MarketMenuScene := preload("res://ui/market_menu.tscn")
const ShopScript := preload("res://systems/shop.gd")
const EconomyScript := preload("res://systems/economy.gd")
const GemPouchScript := preload("res://systems/gem_pouch.gd")
const InventoryScript := preload("res://systems/inventory.gd")
const PonyInstanceScript := preload("res://systems/pony_instance.gd")
const RarityGlyphScript := preload("res://ui/rarity_glyph.gd")

var _menu: MarketMenu


func before_each() -> void:
	var shop := ShopScript.new(EconomyScript.new(5000), GemPouchScript.new(), InventoryScript.new(), [])
	_menu = MarketMenuScene.instantiate()
	add_child_autofree(_menu)
	_menu.shop = shop


func _select(id: StringName) -> void:
	_menu.open()
	_menu.set_tab(MarketMenu.Tab.BUY)
	var rows := _menu.buy_rows()
	for i in rows.size():
		if rows[i].id == id:
			_menu.point_at_row(i)
			return
	fail_test("no %s row" % id)


func test_the_orchard_permit_lists_everypony_who_lives_there() -> void:
	_select(&"permit_orchard")
	await wait_frames(2)
	var shown: Array = _menu.detail_state().get("ponies", [])
	var want := PonyInstanceScript.get_registry().by_zone(&"orchard")
	assert_gt(want.size(), 0)
	assert_eq(shown.size(), want.size(), "one chip each: %s" % str(shown))
	for data: PonyData in want:
		assert_true(data.display_name in shown, "%s is shown" % data.display_name)


func test_each_chip_carries_her_rarity_shape_and_her_hours() -> void:
	_select(&"permit_orchard")
	await wait_frames(2)
	var chips: Array[Control] = _menu.preview_chips()
	assert_gt(chips.size(), 0)
	var last_rarity := 99
	for chip: Control in chips:
		var glyphs := chip.find_children("*", "Control", true, false).filter(
			func(n: Node) -> bool: return n.get_script() == RarityGlyphScript)
		assert_eq(glyphs.size(), 1, "a rarity shape on %s" % chip.name)
		var r: int = int(chip.get_meta(&"rarity"))
		assert_lte(r, last_rarity, "rarest first")
		last_rarity = r
		assert_ne(str(chip.get_meta(&"hours")), "", "her hours on %s" % chip.name)


func test_a_pony_who_keeps_night_hours_says_so() -> void:
	assert_eq(MarketMenu.hours_word([3]), "night")
	assert_eq(MarketMenu.hours_word([]), "any time")
	assert_eq(MarketMenu.hours_word([0, 2]), "dawn and dusk")


func test_a_tile_that_is_not_a_permit_shows_no_ponies() -> void:
	_select(&"long_beam")
	await wait_frames(2)
	assert_eq(_menu.detail_state().get("ponies", []), [])
	assert_eq(_menu.preview_chips().size(), 0)
