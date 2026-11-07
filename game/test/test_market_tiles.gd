extends GutTest
## THE MARKET AS TILES (overnight bot review, 2026-10-26). The Market was a dark list of text
## rows. At 1280 x 720 its BUY tab ran off the top and the bottom of the screen, so the first
## and last things for sale could not be seen at all, and the SELL / BUY tabs were words a
## mouse could not click. Now: a grid of tiles in the casino's style, each with a drawn icon,
## in a scroll area that always fits, with tabs that are buttons.

const MarketMenuScene := preload("res://ui/market_menu.tscn")
const ShopScript := preload("res://systems/shop.gd")
const EconomyScript := preload("res://systems/economy.gd")
const GemPouchScript := preload("res://systems/gem_pouch.gd")
const InventoryScript := preload("res://systems/inventory.gd")
const ShopIconScript := preload("res://ui/shop_icon.gd")

var _menu: MarketMenu
var _shop: Shop


func before_each() -> void:
	_shop = ShopScript.new(EconomyScript.new(500), GemPouchScript.new(), InventoryScript.new(), [])
	_menu = MarketMenuScene.instantiate()
	add_child_autofree(_menu)
	_menu.shop = _shop


func _panel() -> Control:
	return _menu.get_node(^"Centre/Panel") as Control


func test_the_buy_tab_fits_the_screen() -> void:
	_menu.open()
	_menu.set_tab(MarketMenu.Tab.BUY)
	await wait_frames(3)
	var screen := _menu.get_viewport().get_visible_rect()
	var r := _panel().get_global_rect()
	assert_gt(_menu.buy_rows().size(), 8, "a full catalogue, the case that overflowed")
	assert_true(screen.encloses(r), "panel %s inside the screen %s" % [r, screen])


func test_every_tile_has_its_own_icon() -> void:
	_menu.open()
	for t in [MarketMenu.Tab.SELL, MarketMenu.Tab.BUY]:
		_menu.set_tab(t)
		var kinds := {}
		for row in _menu.row_nodes():
			var icons := (row as Node).find_children("*", "Control", true, false).filter(
				func(n: Node) -> bool: return n.get_script() == ShopIconScript)
			assert_eq(icons.size(), 1, "one icon on %s" % row.name)
			if icons.size() == 1:
				var k: StringName = icons[0].kind
				assert_ne(k, &"", "an icon with something to draw")
				kinds[k] = true
		assert_eq(kinds.size(), _menu.row_nodes().size(), "no two tiles share a picture")


func test_every_icon_kind_draws_something() -> void:
	for k in ShopIconScript.KINDS:
		assert_true(ShopIconScript.draws(k), "%s has a drawing" % k)


## G14 (batch check of PS6, build/ps_evidence/batch/ui/market_open.png): "several Market decor
## tiles show blank grey icons". Every tile the Buy tab shows has a picture to draw, and a
## decoration's is a real picture of the thing: a baked image with something on it.
func test_every_thing_for_sale_has_a_picture_not_a_blank_disc() -> void:
	_menu.open()
	_menu.set_tab(MarketMenu.Tab.BUY)
	var decor := 0
	for item: ShopItem in _menu.buy_rows():
		var k: StringName = ShopIconScript.kind_for(item)
		assert_true(ShopIconScript.draws(k), "%s (%s) has a picture" % [item.display_name, k])
		if item.decor_id != &"":
			decor += 1
			var tex: Texture2D = ShopIconScript.picture(k)
			assert_not_null(tex, "%s has a baked picture" % item.display_name)
			if tex != null:
				var img := tex.get_image()
				var solid := 0
				for y in range(0, img.get_height(), 4):
					for x in range(0, img.get_width(), 4):
						if img.get_pixel(x, y).a > 0.5:
							solid += 1
				var cells := (img.get_height() / 4) * (img.get_width() / 4)
				assert_gt(solid, cells / 10, "%s's picture shows something" % item.display_name)
				assert_lt(solid, cells * 9 / 10, "%s's picture is cut out, not a box" % item.display_name)
	assert_eq(decor, 12, "all twelve decorations are on sale in this catalogue")


func _click(c: Control) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	c.gui_input.emit(e)


func test_the_tabs_are_buttons_a_mouse_can_press() -> void:
	_menu.open()
	var buy := _menu.tab_button(MarketMenu.Tab.BUY)
	assert_not_null(buy)
	_click(buy)
	assert_eq(_menu.tab(), MarketMenu.Tab.BUY)
	await wait_frames(1)
	_click(_menu.tab_button(MarketMenu.Tab.SELL))
	assert_eq(_menu.tab(), MarketMenu.Tab.SELL)


func test_the_selected_tile_is_scrolled_into_view() -> void:
	_menu.open()
	_menu.set_tab(MarketMenu.Tab.BUY)
	for i in _menu.buy_rows().size() - 1:
		_menu.move_selection(1)
	await wait_frames(3)
	var last: Control = _menu.row_nodes()[_menu.selected_index()]
	var view := (_menu.get_node(^"Centre/Panel/Margin/Column/Scroll") as Control).get_global_rect()
	assert_true(view.grow(2.0).encloses(last.get_global_rect()), "the last tile scrolled into view")
