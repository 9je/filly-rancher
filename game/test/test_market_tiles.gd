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
## decoration's is a picture of the thing from the icon set (tools/make_icons.py), not empty.
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
			assert_not_null(tex, "%s has a picture in the set" % item.display_name)
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
	var view := (_menu.get_node(^"Centre/Panel/Margin/Column/Stall/Scroll") as Control).get_global_rect()
	assert_true(view.grow(2.0).encloses(last.get_global_rect()), "the last tile scrolled into view")


## G6 (playtest ledger), FS6.1: "tiles stagger in 30 ms apart". On opening, tile i starts its
## scale-and-fade 0.03 s * i after the first, so the grid deals itself in rather than the whole
## panel fading as one sheet; a cursor move afterwards does not deal it again.
func test_the_tiles_stagger_in_30_ms_apart() -> void:
	_menu.open()
	var tiles := _menu.row_nodes()
	assert_gt(tiles.size(), 6, "a full BUY grid")
	for t: Control in tiles:
		assert_eq(t.modulate.a, 0.0, "%s waits for the clock" % t.name)
	var now := 0.0
	for k in 6:
		var at := 0.03 * k + 0.01
		_menu.advance_entrance(at - now)
		now = at
		assert_gt((tiles[k] as Control).modulate.a, 0.0, "tile %d is on its way at %.2f s" % [k, at])
		assert_eq((tiles[k + 1] as Control).modulate.a, 0.0, "tile %d not yet at %.2f s" % [k + 1, at])
		assert_lt((tiles[k] as Control).scale.x, 1.0, "tile %d grows in" % k)
	_menu.advance_entrance(2.0)
	for t: Control in tiles:
		assert_almost_eq(t.modulate.a, 1.0, 0.001, "%s is in" % t.name)
		assert_almost_eq(t.scale.x, 1.0, 0.001, "%s at full size" % t.name)
	_menu.move_selection(1)
	for t: Control in _menu.row_nodes():
		assert_almost_eq(t.modulate.a, 1.0, 0.001, "a cursor move does not deal the grid again")


## G6 (playtest ledger), FS6.1: "a purchase flies a coin to the wallet". A buy that goes
## through emits `purchased`, and a coin leaves the tile and ends on the wallet.
func test_a_purchase_flies_a_coin_to_the_wallet() -> void:
	_menu.buy_requested.connect(func(item: ShopItem) -> void:
		_shop.buy(item)
		_menu.refresh())
	_menu.open()
	_menu.advance_entrance(2.0)
	await wait_frames(3)
	var pick := -1
	var rows := _menu.buy_rows()
	for i in rows.size():
		if _shop.can_buy(rows[i]) and rows[i].cost > 0:
			pick = i
			break
	assert_gt(pick, -1, "something she can afford")
	watch_signals(_menu)
	_menu.take_row(pick)
	assert_signal_emitted(_menu, "purchased")
	# The coin leaves on the next frame, from the tile where the grid has settled it.
	await wait_process_frames(3)
	var tile := (_menu.row_nodes()[pick] as Control).get_global_rect()
	var coins := _menu.find_children("Coin", "", true, false)
	assert_eq(coins.size(), 1, "one coin")
	if coins.size() != 1:
		return
	var coin := coins[0] as Control
	assert_true(tile.grow(8.0).has_point(coin.get_global_rect().get_center()), "it leaves from the tile")
	# Followed frame by frame to the end of its flight: where it was last seen is where it ended.
	var last := coin.get_global_rect().get_center()
	var waited := 0
	while is_instance_valid(coin) and waited < 300:
		last = coin.get_global_rect().get_center()
		await wait_process_frames(1)
		waited += 1
	assert_false(is_instance_valid(coin), "it lands and goes")
	assert_almost_eq(last.distance_to(_menu.wallet_target()), 0.0, 6.0, "and it ends on the wallet")


## A purchase the Shop refuses moves no money, so no coin flies.
func test_a_refused_purchase_flies_nothing() -> void:
	_menu.open()
	watch_signals(_menu)
	var rows := _menu.buy_rows()
	for i in rows.size():
		if not _shop.can_buy(rows[i]):
			_menu.take_row(i)
			break
	assert_eq(_menu.find_children("Coin", "", true, false).size(), 0)


## THE BUY TAB OPENS AT ITS TOP (PS10 gap G17, found rendering G6): the pick was Hay, row 0,
## but the grid opened scrolled to Gallop Shoes' row, Hay out of view.
func test_the_buy_tab_opens_with_its_first_row_in_view() -> void:
	_menu.open()
	_menu.set_tab(MarketMenu.Tab.BUY)
	for i in 30:
		await wait_frames(1)
	var scroll := _menu.get_node(^"Centre/Panel/Margin/Column/Stall/Scroll") as ScrollContainer
	assert_eq(_menu.selected_index(), 0)
	var rows := scroll.get_child(0) as Control
	var first := rows.get_child(0) as Control
	var view := scroll.get_global_rect()
	var r := first.get_global_rect()
	assert_true(r.position.y >= view.position.y - 1.0 and r.end.y <= view.end.y + 1.0,
		"row 0 (the pick) is in view: tile %s, view %s, scrolled %d" % [r, view, scroll.scroll_vertical])
