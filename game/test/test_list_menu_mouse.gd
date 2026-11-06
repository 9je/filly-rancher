extends GutTest
## THE FOUR LIST SCREENS, AND THE POINTER. Acceptance item 5: "Every menu usable by mouse
## alone and keyboard alone."
##
## ONE LOOP OVER FOUR MENUS, on purpose. These four grew up separately and were folded onto
## menu_style.gd's look but not onto its behaviour; a test that drove them one at a time is a
## test that would let the fourth one quietly not have been done. The names in the loop are
## the contract: hovered_index(), point_at_row(), take_row(), close_button_node().

const MouseRowsScript := preload("res://ui/mouse_rows.gd")
const ShopScript := preload("res://systems/shop.gd")
const EconomyScript := preload("res://systems/economy.gd")
const GemPouchScript := preload("res://systems/gem_pouch.gd")
const InventoryScript := preload("res://systems/inventory.gd")

const SCENES: Array[String] = ["res://ui/market_menu.tscn", "res://ui/depot_menu.tscn",
	"res://ui/build_menu.tscn", "res://ui/casino_menu.tscn"]


## THE MARKET REFUSES TO OPEN WITHOUT A SHOP (game/test/test_market_menu.gd's own
## test_it_will_not_open_without_a_shop, which stays true). Every test below that opens the
## Market hands it one built exactly the way that file's before_each() does.
func _shopped_market() -> MarketMenu:
	var menu: MarketMenu = preload("res://ui/market_menu.tscn").instantiate()
	add_child_autofree(menu)
	menu.shop = ShopScript.new(EconomyScript.new(0), GemPouchScript.new(),
		InventoryScript.new(), [])
	menu.can_open = func() -> bool: return true
	return menu


func _armed_rows(menu: CanvasLayer) -> Array[PanelContainer]:
	var out: Array[PanelContainer] = []
	# Found by name: the Market's rows sit in a scroll area since its tiles (2026-10-26).
	var column := menu.get_node_or_null(^"Centre/Panel/Margin/Column").find_child("Rows", true, false) \
		if menu.get_node_or_null(^"Centre/Panel/Margin/Column") != null else null
	if column == null:
		return out
	for child in column.get_children():
		var panel := child as PanelContainer
		if panel != null and MouseRowsScript.row_index(panel) >= 0:
			out.append(panel)
	return out


func test_every_list_menu_offers_the_same_four_pointer_methods() -> void:
	var checked := 0
	for path: String in SCENES:
		var menu: CanvasLayer = load(path).instantiate()
		add_child_autofree(menu)
		for method: String in ["hovered_index", "point_at_row", "take_row",
				"close_button_node"]:
			assert_true(menu.has_method(method), "%s has no %s()" % [path, method])
		checked += 1
	assert_eq(checked, SCENES.size(), "all four were actually reached")


func test_every_list_menu_gives_the_pointer_a_way_out() -> void:
	var checked := 0
	for path: String in SCENES:
		var menu: CanvasLayer = load(path).instantiate()
		add_child_autofree(menu)
		var button: Button = menu.close_button_node()
		assert_not_null(button, "%s has no close button" % path)
		assert_eq(button.text, MouseRowsScript.CLOSE_TEXT, path)
		assert_eq(button.focus_mode, Control.FOCUS_NONE, path)
		checked += 1
	assert_eq(checked, SCENES.size())


func test_every_list_menu_stops_the_mouse_at_its_dim() -> void:
	var checked := 0
	for path: String in SCENES:
		var menu: CanvasLayer = load(path).instantiate()
		add_child_autofree(menu)
		var dim := menu.get_node_or_null(^"Dim") as Control
		assert_not_null(dim, "%s has no Dim" % path)
		assert_eq(dim.mouse_filter, Control.MOUSE_FILTER_STOP, path)
		checked += 1
	assert_eq(checked, SCENES.size())


func test_the_market_arms_exactly_the_rows_the_keyboard_can_reach() -> void:
	var menu: MarketMenu = _shopped_market()
	menu.open()
	var armed: Array[PanelContainer] = _armed_rows(menu)
	var seen: Array[int] = []
	for holder: PanelContainer in armed:
		seen.append(MouseRowsScript.row_index(holder))
	seen.sort()
	assert_eq(seen, range(armed.size()) as Array[int], "row indices are dense from zero")
	assert_gt(armed.size(), 0, "the Market draws rows")


func test_pointing_moves_the_cursor_and_the_keys_still_work_afterwards() -> void:
	var menu: MarketMenu = _shopped_market()
	menu.open()
	menu.point_at_row(0)
	assert_eq(menu.selected_index(), 0)
	assert_eq(menu.hovered_index(), 0)
	menu.move_selection(1)
	assert_eq(menu.selected_index(), 1, "the mouse must never take the keyboard away")


func test_the_casino_lobby_tiles_are_clickable_and_map_to_its_rows() -> void:
	var menu: CasinoMenu = preload("res://ui/casino_menu.tscn").instantiate()
	add_child_autofree(menu)
	menu.can_open = func() -> bool: return true
	menu.open()
	menu.set_tab(CasinoMenu.Tab.LOBBY)
	var rects: Array[Rect2] = menu.stage_hit_rects()
	assert_gt(rects.size(), 0, "the lobby paints tiles worth clicking")
	watch_signals(menu)
	menu.on_stage_hit(0)
	assert_eq(menu.selected_index(), 0, "a click on a tile is a click on its row")


func test_a_left_click_on_a_row_holder_reaches_take_row() -> void:
	var menu: MarketMenu = _shopped_market()
	menu.open()
	var armed: Array[PanelContainer] = _armed_rows(menu)
	assert_gt(armed.size(), 1)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	armed[1].gui_input.emit(event)
	assert_eq(menu.selected_index(), MouseRowsScript.row_index(armed[1]))


func test_no_list_menu_prints_key_hints() -> void:
	# PT5 (owner, 2026-11-05): one Back button, no "Up Down scroll   Esc back" rows.
	var checked := 0
	for path: String in SCENES:
		var menu: CanvasLayer = load(path).instantiate()
		add_child_autofree(menu)
		var footer := menu.get_node_or_null(^"Centre/Panel/Margin/Column/Footer") as Label
		assert_not_null(footer, "%s has no footer" % path)
		if footer != null:
			assert_false(footer.visible, "%s shows no key hints" % path)
		checked += 1
	assert_eq(checked, SCENES.size())
