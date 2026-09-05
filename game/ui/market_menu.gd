class_name MarketMenu
extends CanvasLayer
## THE MARKET. Two tabs: SELL turns the gems in your pouch into bits, BUY turns bits into
## food for the pens or gear for the hunt. Phase 2 slice 1.
##
## Built on the same rules as game/ui/build_menu.gd, and its class comment is the
## reference for all of them: navigable without a mouse on the engine's ui_* actions;
## this node runs PROCESS_MODE_ALWAYS while game/world/ranch.gd pauses the tree and frees
## the cursor; and it never touches the wallet. It reads from a Shop to draw and emits
## `sell_requested` / `sell_all_requested` / `buy_requested`; ranch.gd calls Shop.
##
## Left and right change tab, up and down change row, accept confirms, cancel closes. The
## first row of SELL is "Sell everything", because that is what most visits are for.

const ShopRegistryScript := preload("res://systems/shop_registry.gd")
const ShopItemScript := preload("res://systems/shop_item.gd")
const PonyDataScript := preload("res://systems/pony_data.gd")
const MenuStyleScript := preload("res://ui/menu_style.gd")

enum Tab { SELL, BUY }

## Rarity names for the Sell tab, in enum order. Prose, and PonyData.Rarity is the list it
## is prose about: see _rarity_name() for what happens when the two disagree.
const RARITY_NAMES := ["Common", "Uncommon", "Rare", "Legendary"]

@onready var _title: Label = $Centre/Panel/Margin/Column/Title
@onready var _wallet: Label = $Centre/Panel/Margin/Column/Wallet
@onready var _gems: Label = $Centre/Panel/Margin/Column/Gems
@onready var _sell_tab: Label = $Centre/Panel/Margin/Column/Tabs/SellTab
@onready var _buy_tab: Label = $Centre/Panel/Margin/Column/Tabs/BuyTab
@onready var _rows: VBoxContainer = $Centre/Panel/Margin/Column/Rows
@onready var _footer: Label = $Centre/Panel/Margin/Column/Footer

signal opened()
signal closed()
signal sell_requested(rarity: int, count: int)
signal sell_all_requested()
signal buy_requested(item: ShopItem)

## The Shop this menu reads from. Set by ranch.gd before open(); never mutated here.
var shop: Shop = null

## `func() -> bool`. Invalid means "always allowed".
##
## How the ranch says "another menu is up", the same guard pause_menu.gd carries and for
## the same reason: every menu here pauses the tree and unpauses it on close, so a Market
## opened over an already-open pause menu would unpause the world underneath it the moment
## the Market closed. ranch.gd's current_interaction() offers no candidate at all while
## another menu is up, so the key never reaches here in the first place, but a call-site
## guard only protects the call sites that remember it; this is the one the contract lives
## in.
var can_open := Callable()

var _catalogue: Array[ShopItem] = []
var _tab: int = Tab.SELL
var _selected := 0
var _open := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	MenuStyleScript.apply_panel($Centre/Panel as PanelContainer)
	var registry: ShopRegistry = ShopRegistryScript.new()
	registry.load_all(ShopRegistryScript.SHOP_DIR)
	_catalogue = registry.all()
	MenuStyleScript.style_label(_title, MenuStyleScript.TITLE_SIZE, MenuStyleScript.COLOR_TITLE)
	MenuStyleScript.style_label(_wallet, MenuStyleScript.ROW_SIZE, MenuStyleScript.COLOR_DIM)
	MenuStyleScript.style_label(_gems, MenuStyleScript.ROW_SIZE, MenuStyleScript.COLOR_DIM)
	MenuStyleScript.style_label(_sell_tab, 26, MenuStyleScript.COLOR_TAB_ON)
	MenuStyleScript.style_label(_buy_tab, 26, MenuStyleScript.COLOR_TAB_OFF)
	_title.text = "MARKET"
	_sell_tab.text = "SELL"
	_buy_tab.text = "BUY"
	visible = false


# --- opening and closing ------------------------------------------------------------------

## Returns whether the Market came up. Already open is a refusal, PauseMenu.open()'s rule
## and for the same reason: an open() that "succeeded" on a menu that was already up would
## announce a second `opened`, and ranch.gd pauses the tree on that signal and unpauses on
## the single `closed` that follows.
func open() -> bool:
	if _open:
		return false
	if shop == null:
		return false
	if can_open.is_valid() and not bool(can_open.call()):
		return false
	_tab = Tab.SELL
	_selected = 0
	_open = true
	visible = true
	refresh()
	opened.emit()
	MenuStyleScript.tick_open()
	return true


func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	closed.emit()
	MenuStyleScript.tick_back()


func is_open() -> bool:
	return _open


func tab() -> int:
	return _tab


func set_tab(next: int) -> void:
	if next != Tab.SELL and next != Tab.BUY:
		return
	_tab = next
	_selected = 0
	refresh()
	MenuStyleScript.tick_page()


func selected_index() -> int:
	return _selected


func footer_text() -> String:
	return _footer.text


## The Sell tab's rarity rows, in enum order. Row 0 on screen is "Sell everything" and is
## NOT in this list; selected_index() 1..N maps to this list's 0..N-1.
func sell_rows() -> Array[int]:
	var out: Array[int] = []
	for rarity in PonyDataScript.Rarity.values():
		out.append(rarity)
	return out


func buy_rows() -> Array[ShopItem]:
	return _catalogue.duplicate()


## The price drawn on row `index` of whichever tab is up, or "" for a row that is not
## there.
##
## READ OFF THE LIVE LABEL, not recomputed. What a row COSTS is already answerable from the
## Shop; the only thing worth asserting from outside is what this screen actually put in
## front of the player, and a helper that recalculated the string would agree with itself
## while the panel drew something else.
func row_price_text(index: int) -> String:
	if index < 0 or index >= _rows.get_child_count():
		return ""
	var heads: Array = _rows.get_child(index).find_children("*", "HBoxContainer", true, false)
	if heads.is_empty() or (heads[0] as HBoxContainer).get_child_count() < 2:
		return ""
	var cost := (heads[0] as HBoxContainer).get_child(1) as Label
	return cost.text if cost != null else ""


func _row_count() -> int:
	# Parenthesised because the +1 belongs to the SELL branch (the "Sell everything" row),
	# not to the whole ternary, and GDScript's precedence here is worth nobody's second
	# reading.
	return (sell_rows().size() + 1) if _tab == Tab.SELL else _catalogue.size()


# --- input ----------------------------------------------------------------------------------

func move_selection(step: int) -> void:
	var n := _row_count()
	if n == 0:
		return
	_selected = posmod(_selected + step, n)
	refresh()
	MenuStyleScript.tick_move()


## Confirm the row under the cursor. Emits a request; returns false and explains in the
## footer when there is nothing to do.
func confirm() -> bool:
	if shop == null:
		return false
	if _tab == Tab.SELL:
		if _selected == 0:
			if _pouch_total() <= 0:
				_refuse("You have no gems to sell.")
				return false
			sell_all_requested.emit()
			refresh()
			return true
		var rarity: int = sell_rows()[_selected - 1]
		var count := shop.gem_count(rarity)
		if count <= 0:
			_refuse("No %s gems to sell." % _rarity_name(rarity).to_lower())
			return false
		sell_requested.emit(rarity, count)
		refresh()
		return true
	var item := _selected_item()
	if item == null:
		# An empty BUY catalogue, or a cursor that has fallen off the end of one. Every
		# other dead end on this screen explains itself in the footer; a keypress that
		# vanished without a word would read as a broken button. Shop owns the wording of
		# every refusal, this one included.
		_refuse(shop.refusal(null))
		return false
	var why := shop.refusal(item)
	if not why.is_empty():
		_refuse(why)
		return false
	buy_requested.emit(item)
	refresh()
	return true


func sell_everything() -> bool:
	if shop == null or _pouch_total() <= 0:
		return false
	sell_all_requested.emit()
	refresh()
	return true


## The label for one PonyData.Rarity.
##
## RARITY_NAMES is hand-written and the enum is what it describes, so a fifth rarity added
## to PonyData would index past the end of the array and take the whole Sell tab down with
## it. Anything the array does not cover is named from the enum's own key instead: uglier
## than the written word, which is the point, because ugly is a reminder and a crash is a
## lost afternoon.
func _rarity_name(rarity: int) -> String:
	if rarity >= 0 and rarity < RARITY_NAMES.size():
		return String(RARITY_NAMES[rarity])
	var keys: Array = PonyDataScript.Rarity.keys()
	if rarity >= 0 and rarity < keys.size():
		return String(keys[rarity]).capitalize()
	return "Unknown"


func _selected_item() -> ShopItem:
	if _tab != Tab.BUY or _selected < 0 or _selected >= _catalogue.size():
		return null
	return _catalogue[_selected]


func _pouch_total() -> int:
	var sum := 0
	for rarity in sell_rows():
		sum += shop.gem_count(rarity)
	return sum


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_down"):
		move_selection(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_up"):
		move_selection(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_left") or event.is_action_pressed(&"ui_right"):
		set_tab(Tab.BUY if _tab == Tab.SELL else Tab.SELL)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_accept"):
		confirm()
		get_viewport().set_input_as_handled()


# --- drawing ----------------------------------------------------------------------------------

## Rebuild the rows for the current tab from the Shop's current numbers. Called on open,
## on every cursor move, and by ranch.gd after a sale or purchase lands, so the counts on
## screen are never a frame behind the pouch.
func refresh() -> void:
	if shop == null:
		return
	_footer.text = MenuStyleScript.footer_tabs_and_rows("confirm", "back")
	MenuStyleScript.style_label(_footer, MenuStyleScript.FOOTER_SIZE, MenuStyleScript.COLOR_DIM)
	_wallet.text = "%d bits" % shop.bits()
	_gems.text = "%d gems in your pouch" % _pouch_total()
	MenuStyleScript.style_label(_sell_tab, 26,
		MenuStyleScript.COLOR_TAB_ON if _tab == Tab.SELL else MenuStyleScript.COLOR_TAB_OFF)
	MenuStyleScript.style_label(_buy_tab, 26,
		MenuStyleScript.COLOR_TAB_ON if _tab == Tab.BUY else MenuStyleScript.COLOR_TAB_OFF)
	# remove_child BEFORE queue_free: a queued node is still a child until the end of the
	# frame, so freeing alone would leave the old rows laid out underneath the new ones for
	# one frame every time the cursor moves.
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	if _tab == Tab.SELL:
		_add_row(0, "Sell everything", "", "%d bits" % _sell_all_value(), _pouch_total() > 0)
		for i in range(sell_rows().size()):
			var rarity: int = sell_rows()[i]
			var count := shop.gem_count(rarity)
			_add_row(i + 1, "%s gems" % _rarity_name(rarity), "you have %d" % count,
				"%d bits each" % shop.gem_price(rarity), count > 0)
	else:
		for i in range(_catalogue.size()):
			var item := _catalogue[i]
			# A PERMIT ALREADY IN THE UNLOCKS READS OWNED, exactly as held gear does. Shop
			# refuses to sell either of them twice (shop.gd's refusal()), so a permit row
			# still showing its price was a row offering something that could not be
			# bought, on the most expensive line on the screen: 1200 bits displayed next
			# to a gate that is already standing open.
			var owned := false
			if item.kind == ShopItemScript.Kind.GEAR:
				owned = shop.owns_gear(item.gear_id)
			elif item.kind == ShopItemScript.Kind.PERMIT:
				owned = shop.owns_permit(item.permit_zone)
			var price := "OWNED" if owned else ("FREE" if item.cost == 0 else "%d bits" % item.cost)
			_add_row(i, item.display_name, item.description, price, shop.can_buy(item))


func _sell_all_value() -> int:
	var total := 0
	for rarity in sell_rows():
		total += shop.gem_count(rarity) * shop.gem_price(rarity)
	return total


func _add_row(index: int, row_name: String, blurb: String, price: String, enabled: bool) -> void:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override(&"panel", _row_style(index == _selected))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override(&"margin_left", 18)
	margin.add_theme_constant_override(&"margin_right", 18)
	margin.add_theme_constant_override(&"margin_top", 10)
	margin.add_theme_constant_override(&"margin_bottom", 10)
	row.add_child(margin)
	var column := VBoxContainer.new()
	margin.add_child(column)
	var head := HBoxContainer.new()
	head.add_theme_constant_override(&"separation", 24)
	column.add_child(head)
	var title := Label.new()
	title.text = row_name
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	MenuStyleScript.style_label(title, 26,
		MenuStyleScript.COLOR_NAME if enabled else MenuStyleScript.COLOR_DIM)
	head.add_child(title)
	var cost := Label.new()
	cost.text = price
	MenuStyleScript.style_label(cost, 23,
		MenuStyleScript.COLOR_VALUE if enabled else MenuStyleScript.COLOR_UNAFFORDABLE)
	head.add_child(cost)
	if not blurb.is_empty():
		var sub := Label.new()
		sub.text = blurb
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub.custom_minimum_size = Vector2(720.0, 0.0)
		MenuStyleScript.style_label(sub, 19, MenuStyleScript.COLOR_DIM)
		column.add_child(sub)
	_rows.add_child(row)


func _refuse(text: String) -> void:
	_footer.text = "  " + text
	MenuStyleScript.style_label(_footer, MenuStyleScript.FOOTER_SIZE,
		MenuStyleScript.COLOR_UNAFFORDABLE)


func _row_style(selected: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = MenuStyleScript.ROW_SELECTED_BG if selected else MenuStyleScript.ROW_IDLE_BG
	box.border_color = MenuStyleScript.ROW_SELECTED_BORDER if selected \
		else MenuStyleScript.ROW_IDLE_BORDER
	box.set_border_width_all(2 if selected else 1)
	box.set_corner_radius_all(8)
	return box
