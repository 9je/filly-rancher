extends GutTest
## Tests for game/ui/market_menu.gd. Driven through the methods ui_* route into, never
## a mouse, for the reason test_build_menu.gd gives. And the menu never moves a bit: it
## emits, ranch.gd calls Shop.

const MarketMenuScene := preload("res://ui/market_menu.tscn")
const ShopScript := preload("res://systems/shop.gd")
const EconomyScript := preload("res://systems/economy.gd")
const GemPouchScript := preload("res://systems/gem_pouch.gd")
const InventoryScript := preload("res://systems/inventory.gd")
const ShopRegistryScript := preload("res://systems/shop_registry.gd")
const ShopItemScript := preload("res://systems/shop_item.gd")
const PonyDataScript := preload("res://systems/pony_data.gd")

var _menu: MarketMenu
var _econ: Economy
var _pouch: GemPouch
var _shop: Shop


func before_each() -> void:
	_econ = EconomyScript.new(0)
	_pouch = GemPouchScript.new()
	_shop = ShopScript.new(_econ, _pouch, InventoryScript.new(), [])
	_menu = MarketMenuScene.instantiate()
	add_child_autofree(_menu)
	_menu.shop = _shop


func test_it_will_not_open_without_a_shop() -> void:
	_menu.shop = null
	assert_false(_menu.open())
	assert_false(_menu.is_open())


func test_can_open_callable_can_refuse() -> void:
	_menu.can_open = func() -> bool: return false
	assert_false(_menu.open())
	assert_false(_menu.is_open())


func test_open_and_close_signal_and_start_on_the_sell_tab() -> void:
	watch_signals(_menu)
	assert_true(_menu.open())
	assert_true(_menu.is_open())
	# PT9: with gems to sell it opens on Sell; with an empty pouch, on Buy.
	assert_eq(_menu.tab(), MarketMenu.Tab.SELL if _menu.call("_pouch_total") > 0 else MarketMenu.Tab.BUY)
	assert_signal_emitted(_menu, "opened")
	_menu.close()
	assert_false(_menu.is_open())
	assert_signal_emitted(_menu, "closed")


func test_the_sell_tab_lists_every_rarity_in_order_after_a_sell_all_row() -> void:
	_menu.open()
	assert_eq(_menu.sell_rows(), PonyDataScript.Rarity.values())
	assert_eq(_menu.selected_index(), 0, "row 0 is Sell everything")


func test_confirm_on_the_sell_all_row_asks_to_sell_everything() -> void:
	_pouch.add(PonyDataScript.Rarity.COMMON, 2)
	_menu.open()
	watch_signals(_menu)
	assert_true(_menu.confirm())
	assert_signal_emitted(_menu, "sell_all_requested")
	assert_eq(_econ.bits, 0, "the menu did not sell anything itself")


func test_confirm_on_a_rarity_row_asks_to_sell_that_tier() -> void:
	_pouch.add(PonyDataScript.Rarity.RARE, 3)
	_menu.open()
	# rows: 0 sell all, 1 common, 2 uncommon, 3 rare, 4 legendary
	_menu.move_selection(3)
	watch_signals(_menu)
	assert_true(_menu.confirm())
	assert_signal_emitted_with_parameters(_menu, "sell_requested", [PonyDataScript.Rarity.RARE, 3])


func test_confirm_on_an_empty_tier_is_refused_and_does_not_signal() -> void:
	_menu.open()
	_menu.move_selection(1)
	watch_signals(_menu)
	assert_false(_menu.confirm())
	assert_signal_not_emitted(_menu, "sell_requested")


func test_left_and_right_switch_tabs_and_reset_the_cursor() -> void:
	_menu.open()
	_menu.move_selection(2)
	_menu.set_tab(MarketMenu.Tab.BUY)
	assert_eq(_menu.tab(), MarketMenu.Tab.BUY)
	assert_eq(_menu.selected_index(), 0)


func test_the_buy_tab_lists_the_catalogue_cheapest_first() -> void:
	var reg: ShopRegistry = ShopRegistryScript.new()
	reg.load_all(ShopRegistryScript.SHOP_DIR)
	_menu.open()
	_menu.set_tab(MarketMenu.Tab.BUY)
	var rows := _menu.buy_rows()
	# Off the Factory path the Supply Desk's gear is not on the shelf (ShopItem.requires_path).
	var shelf: Array = reg.all().filter(func(it: ShopItem) -> bool: return it.requires_path.is_empty())
	assert_eq(rows.size(), shelf.size())
	for i in range(rows.size()):
		assert_eq(rows[i].id, shelf[i].id)


## v1: a Senior Steward sees the Cloudsdale Supply Desk's gear too.
func test_the_factory_path_puts_the_supply_desk_on_the_shelf() -> void:
	var reg: ShopRegistry = ShopRegistryScript.new()
	reg.load_all(ShopRegistryScript.SHOP_DIR)
	_menu.shop.path_provider = func() -> String: return "factory"
	_menu.open()
	_menu.set_tab(MarketMenu.Tab.BUY)
	var ids: Array = _menu.buy_rows().map(func(it: ShopItem) -> StringName: return it.id)
	assert_eq(ids.size(), reg.all().size())
	for g in [&"calm_lamp", &"express_chute", &"yield_lens", &"lure_post"]:
		assert_has(ids, g)


## A PERMIT SHE HAS ALREADY BOUGHT MUST NOT GO ON SHOWING ITS PRICE. Shop.refusal() turns
## a second purchase down, so a row that still says "700 bits" is a row advertising a
## refusal, and it is the most expensive row on the screen. Asserted on the drawn label
## rather than on the flag behind it: the flag was already correct for gear and wrong for
## permits, and only the label says which of the two the player is looking at.
func test_a_permit_in_the_unlocks_reads_as_owned_and_the_others_still_show_a_price() -> void:
	_menu.shop = ShopScript.new(_econ, _pouch, InventoryScript.new(), ["permit_lake"])
	_menu.open()
	_menu.set_tab(MarketMenu.Tab.BUY)
	var rows := _menu.buy_rows()
	var lake := -1
	var unowned := -1
	for i in range(rows.size()):
		if rows[i].id == &"permit_lake":
			lake = i
		elif rows[i].kind == ShopItemScript.Kind.PERMIT:
			unowned = i
	assert_gt(lake, -1, "the catalogue carries a lake permit")
	assert_gt(unowned, -1, "and at least one permit she has not bought")
	assert_eq(_menu.row_price_text(lake), "OWNED")
	assert_string_contains(_menu.row_price_text(unowned), "bits",
		"a permit she does not own still costs what it costs")


func test_confirm_on_an_affordable_item_asks_to_buy_it() -> void:
	_econ.grant(100)
	_menu.open()
	_menu.set_tab(MarketMenu.Tab.BUY)
	var cheapest := _menu.buy_rows()[0]
	watch_signals(_menu)
	assert_true(_menu.confirm())
	assert_signal_emitted_with_parameters(_menu, "buy_requested", [cheapest])
	assert_eq(_econ.bits, 100, "the menu did not spend")


func test_confirm_on_an_unaffordable_item_is_refused_with_a_reason() -> void:
	_menu.open()
	_menu.set_tab(MarketMenu.Tab.BUY)
	watch_signals(_menu)
	assert_false(_menu.confirm())
	assert_signal_not_emitted(_menu, "buy_requested")
	assert_string_contains(_menu.footer_text(), "bits")


func test_the_market_refuses_to_open_twice() -> void:
	# PauseMenu's rule. ranch.gd pauses the tree on `opened` and unpauses on the one
	# `closed` that follows, so a second `opened` would leave the world stopped behind a
	# menu that had already been shut.
	assert_true(_menu.open())
	watch_signals(_menu)
	assert_false(_menu.open(), "it is already up")
	assert_signal_not_emitted(_menu, "opened", "and it did not announce itself again")
	assert_true(_menu.is_open(), "...nor did the refusal close it")


func test_confirm_on_a_buy_tab_with_nothing_under_the_cursor_says_so() -> void:
	# Reachable with an empty catalogue, or a cursor left past the end of one. A keypress
	# that vanished without a word reads as a broken button, so this refuses out loud like
	# every other dead end on this screen. The wording is Shop's, not the menu's.
	_menu.open()
	_menu.set_tab(MarketMenu.Tab.BUY)
	_menu._selected = _menu.buy_rows().size() + 5
	watch_signals(_menu)
	assert_false(_menu.confirm())
	assert_signal_not_emitted(_menu, "buy_requested")
	assert_string_contains(_menu.footer_text(), _shop.refusal(null),
		"the footer carries Shop's own wording for it")


func test_every_rarity_the_enum_carries_has_a_name_and_an_unknown_one_still_has_a_label() -> void:
	# RARITY_NAMES is hand-written prose about PonyData.Rarity. While they agree, the prose
	# is used; when a fifth rarity is added and this assertion goes red, the fallback below
	# is what keeps the Sell tab drawing instead of indexing off the end of the array.
	assert_eq(MarketMenu.RARITY_NAMES.size(), PonyDataScript.Rarity.size(),
		"every rarity in the enum has a written name")
	for rarity in PonyDataScript.Rarity.values():
		assert_eq(_menu._rarity_name(rarity), MarketMenu.RARITY_NAMES[rarity])
	assert_false(_menu._rarity_name(PonyDataScript.Rarity.size() + 3).is_empty(),
		"a rarity nobody has written a word for still gets a label rather than a crash")


func test_selection_wraps() -> void:
	_menu.open()
	_menu.set_tab(MarketMenu.Tab.SELL)
	_menu.move_selection(-1)
	assert_eq(_menu.selected_index(), _menu.sell_rows().size(), "wrapped to the last row")


## FS6.2: when her bits change the wallet says so with a pop, a sale up and a purchase down.
func test_a_change_in_her_bits_pops_over_the_wallet() -> void:
	assert_true(_menu.open())
	assert_true(_menu.find_children("Payout", "", true, false).is_empty(), "nothing on opening")
	_econ.grant(120)
	_menu.refresh()
	var pops := _menu.find_children("Payout", "", true, false)
	assert_eq(pops.size(), 1)
	assert_eq((pops[0] as Label).text, "+120 bits")
