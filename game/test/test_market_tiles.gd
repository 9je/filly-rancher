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
