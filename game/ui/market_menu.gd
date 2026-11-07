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
##
## TILES, NOT TEXT ROWS (overnight bot review, 2026-10-26). The rows were a dark list of
## words, and at 1280 x 720 the BUY tab ran off the top and the bottom of the screen, so the
## first and last things for sale could not be seen. Every row is now a tile in the casino
## lobby's look (plum, a gold edge, gold when it is the pick), with its own drawn picture
## (game/ui/shop_icon.gd) on a cream disc: SELL is a column of wide tiles, BUY a grid of
## three, both in a scroll area that never grows past SCROLL_MAX. The tabs are buttons. Row
## order, indices, signals and row_price_text() are unchanged.

const ShopRegistryScript := preload("res://systems/shop_registry.gd")
const ShopItemScript := preload("res://systems/shop_item.gd")
const PonyDataScript := preload("res://systems/pony_data.gd")
const MenuStyleScript := preload("res://ui/menu_style.gd")
const MouseRowsScript := preload("res://ui/mouse_rows.gd")
const ShopIconScript := preload("res://ui/shop_icon.gd")
const PaintScript := preload("res://ui/casino_paint.gd")
const TileStyleScript := preload("res://ui/tile_style.gd")
const RarityGlyphScript := preload("res://ui/rarity_glyph.gd")
const HoursIconScript := preload("res://ui/hours_icon.gd")
const PonyInstanceScript := preload("res://systems/pony_instance.gd")
const TileEntranceScript := preload("res://ui/tile_entrance.gd")

## The scroll area's tallest, in 1920 x 1080 base pixels: what is left of the screen once the
## title, the tabs, the footer and the Close button have theirs.
const SCROLL_MAX := 640.0
const SCROLL_MAX_BUY := 400.0
const BUY_COLUMNS := 3
const BUY_TILE := Vector2(360.0, 128.0)
const SELL_TILE := Vector2(1104.0, 84.0)
const ICON_SIZE := 56.0
const TAB_NAMES: Array[String] = ["Sell", "Buy"]

enum Tab { SELL, BUY }

## Rarity names for the Sell tab, in enum order. Prose, and PonyData.Rarity is the list it
## is prose about: see _rarity_name() for what happens when the two disagree.
const RARITY_NAMES := ["Common", "Uncommon", "Rare", "Legendary"]

@onready var _title: Label = $Centre/Panel/Margin/Column/Title
@onready var _wallet: Label = $Centre/Panel/Margin/Column/Wallet
@onready var _gems: Label = $Centre/Panel/Margin/Column/Gems
@onready var _tabs: HBoxContainer = $Centre/Panel/Margin/Column/Tabs
@onready var _scroll: ScrollContainer = $Centre/Panel/Margin/Column/Scroll
@onready var _rows: GridContainer = $Centre/Panel/Margin/Column/Scroll/Rows
@onready var _footer: Label = $Centre/Panel/Margin/Column/Footer

signal opened()
signal closed()
signal sell_requested(rarity: int, count: int)
signal sell_all_requested()
signal buy_requested(item: ShopItem)
## A buy went through: the Shop took her bits for `item` (PS10, G6). Emitted after
## buy_requested's handler has run, when the wallet shows the price was paid.
signal purchased(item: ShopItem)

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
## Everything in data/shop; _catalogue is what this shop lists right now (Shop.listed).
var _all_items: Array[ShopItem] = []
var _tab: int = Tab.SELL
var _selected := 0
var _open := false

## Where the pointer is resting, or -1. Not the cursor: see game/ui/table_menu.gd's own
## comment on the same pair of fields.
var _hovered := -1
var _close: Button = null
## THE PICK, IN FULL (overnight review 2026-10-26: the owner found the upgrades unclear, and a
## tile's two lines cut "Six more pockets. Carry eighteen ponies before you" off mid
## sentence). Under the BUY grid: the pick's big icon, its whole description, its price and
## a Buy button. Built once; refresh() fills it.
var _detail: PanelContainer = null
var _detail_icon: Control = null
var _detail_name: Label = null
var _detail_text: Label = null
var _detail_kind: Label = null
var _detail_buy: Button = null
## The permit's ponies (PS9 item 55); hidden for anything that is not a permit.
var _detail_ponies: HFlowContainer = null
## The deal-in clock for the tiles (PS10, G6; game/ui/tile_entrance.gd).
var _entrance = TileEntranceScript.new()
## Where the coins fly and the pops rise (PS10, G6): over the panel, never laid out by it.
var _fx: Control = null
## The coin at the head of the wallet line, which is where the coins land.
var _purse_coin: TextureRect = null
## The process frame the tiles were last built on. A tile built this frame already has its
## minimum size but no place yet (the grid sorts at the end of the frame), so its rect lies.
var _built_frame := -1
## How long a pop over the wallet waits, unseen, for the coin flying to it.
var _pop_delay := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	MenuStyleScript.apply_panel($Centre/Panel as PanelContainer)
	var registry: ShopRegistry = ShopRegistryScript.new()
	registry.load_all(ShopRegistryScript.SHOP_DIR)
	_all_items = registry.all()
	_catalogue = _all_items.duplicate()
	MenuStyleScript.style_label(_title, MenuStyleScript.TITLE_SIZE, MenuStyleScript.COLOR_TITLE)
	MenuStyleScript.style_label(_wallet, MenuStyleScript.ROW_SIZE, MenuStyleScript.COLOR_DIM)
	MenuStyleScript.style_label(_gems, MenuStyleScript.ROW_SIZE, MenuStyleScript.COLOR_DIM)
	_title.text = "MARKET"
	var dim := get_node_or_null(^"Dim") as Control
	if dim != null:
		dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_close = MouseRowsScript.close_button(MouseRowsScript.CLOSE_TEXT,
		func(_index: int) -> void: close())
	_build_detail()
	$Centre/Panel/Margin/Column.add_child(_close)
	_build_purse()
	_fx = MenuStyleScript.effects_layer(self)
	visible = false


## THE WALLET IS A PURSE, NOT A DIM LINE (PS10, G6): the bits coin, her bits in gold, and the
## pouch beside them, so a coin flying from a tile has somewhere to land.
func _build_purse() -> void:
	var column := $Centre/Panel/Margin/Column as VBoxContainer
	var purse := HBoxContainer.new()
	purse.name = "Purse"
	purse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	purse.add_theme_constant_override(&"separation", 10)
	column.add_child(purse)
	column.move_child(purse, _wallet.get_index())
	_purse_coin = MenuStyleScript.coin_icon(34.0)
	purse.add_child(_purse_coin)
	_wallet.reparent(purse)
	_wallet.add_theme_font_override(&"font", MenuStyleScript.numeral_font())
	MenuStyleScript.style_label(_wallet, 26, MenuStyleScript.COLOR_VALUE)
	_wallet.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(22, 0)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	purse.add_child(gap)
	_gems.reparent(purse)
	_gems.size_flags_vertical = Control.SIZE_SHRINK_CENTER


## Where a coin lands: the middle of the purse's coin, in the menu's canvas.
func wallet_target() -> Vector2:
	if _purse_coin == null:
		return Vector2.ZERO
	return _purse_coin.get_global_rect().get_center()


func _build_detail() -> void:
	var column := $Centre/Panel/Margin/Column as VBoxContainer
	_detail = PanelContainer.new()
	_detail.name = "Detail"
	_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := TileStyleScript.box(true, false)
	box.bg_color = PaintScript.PLUM.darkened(0.15)
	_detail.add_theme_stylebox_override(&"panel", box)
	column.add_child(_detail)
	column.move_child(_detail, _scroll.get_index() + 1)
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override(&"separation", 18)
	_detail.add_child(line)
	var plate := TileStyleScript.disc(84.0)
	line.add_child(plate)
	_detail_icon = ShopIconScript.new()
	_detail_icon.custom_minimum_size = Vector2(84, 84)
	_detail_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(_detail_icon)
	var words := VBoxContainer.new()
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	line.add_child(words)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override(&"separation", 14)
	words.add_child(head)
	_detail_name = Label.new()
	_detail_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	MenuStyleScript.style_label(_detail_name, 28, MenuStyleScript.COLOR_TITLE)
	_detail_name.add_theme_font_override(&"font", MenuStyleScript.title_font())
	head.add_child(_detail_name)
	_detail_kind = Label.new()
	_detail_kind.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_kind.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	MenuStyleScript.style_label(_detail_kind, 16, PaintScript.GOLD)
	head.add_child(_detail_kind)
	_detail_text = Label.new()
	_detail_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_text.custom_minimum_size = Vector2(700, 0)
	MenuStyleScript.style_label(_detail_text, 19, MenuStyleScript.COLOR_NAME)
	words.add_child(_detail_text)
	_detail_ponies = HFlowContainer.new()
	_detail_ponies.name = "Ponies"
	_detail_ponies.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_ponies.add_theme_constant_override(&"h_separation", 8)
	_detail_ponies.add_theme_constant_override(&"v_separation", 6)
	words.add_child(_detail_ponies)
	_detail_buy = Button.new()
	_detail_buy.name = "Buy"
	_detail_buy.custom_minimum_size = Vector2(190, 64)
	_detail_buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_detail_buy.focus_mode = Control.FOCUS_NONE
	_detail_buy.add_theme_font_override(&"font", MenuStyleScript.title_font())
	_detail_buy.add_theme_font_size_override(&"font_size", MenuStyle.font_px(24))
	for state: StringName in [&"normal", &"hover", &"pressed", &"disabled"]:
		var b := StyleBoxFlat.new()
		b.bg_color = PaintScript.GOLD if state != &"disabled" else PaintScript.GOLD_DIM.darkened(0.4)
		if state == &"hover":
			b.bg_color = PaintScript.GOLD.lightened(0.15)
		elif state == &"pressed":
			b.bg_color = PaintScript.GOLD.darkened(0.12)
		b.set_corner_radius_all(18)
		b.border_color = PaintScript.PLUM_DARK
		b.set_border_width_all(2)
		_detail_buy.add_theme_stylebox_override(state, b)
	for c: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color"]:
		_detail_buy.add_theme_color_override(c, PaintScript.CARD_INK)
	_detail_buy.add_theme_color_override(&"font_disabled_color", Color(1, 1, 1, 0.45))
	_detail_buy.pressed.connect(func() -> void: take_row(_selected))
	line.add_child(_detail_buy)


## What kind of thing an item is, in a word, for its tile and the detail strip.
static func kind_word(item: ShopItem) -> String:
	match item.kind:
		ShopItemScript.Kind.CARE:
			return "FOOD"
		ShopItemScript.Kind.PERMIT:
			return "NEW PLACE"
		ShopItemScript.Kind.BUILD:
			return "BUILDING"
		ShopItemScript.Kind.DECOR:
			return "DECOR"
	return "GEAR"


## The detail strip's words, for the suite: {name, text, kind, buy, can}.
func detail_state() -> Dictionary:
	if _detail == null or not _detail.visible:
		return {}
	var ponies: Array = []
	for chip: Control in preview_chips():
		ponies.append(str(chip.get_meta(&"pony")))
	return {"name": _detail_name.text, "text": _detail_text.text, "kind": _detail_kind.text,
		"buy": _detail_buy.text, "can": not _detail_buy.disabled, "ponies": ponies}


## A PERMIT SHOWS ITS PONIES BEFORE YOU BUY IT (PS9, playtest 2026-11-05 item 55: "Each area
## should show its ponies and their times before you buy"). The chips on the detail strip,
## rarest first; each carries metas `pony`, `rarity` and `hours`.
func preview_chips() -> Array[Control]:
	var out: Array[Control] = []
	if _detail_ponies != null and _detail_ponies.visible:
		for c in _detail_ponies.get_children():
			if not c.is_queued_for_deletion():
				out.append(c as Control)
	return out


## The hours a pony keeps, in words, from her PonyData.phases (WorldState.Phase values).
static func hours_word(phases: Array) -> String:
	if phases.is_empty():
		return "any time"
	var names := ["dawn", "day", "dusk", "night"]
	var words: Array[String] = []
	for p in phases:
		if int(p) >= 0 and int(p) < names.size():
			words.append(names[int(p)])
	if words.size() <= 1:
		return "".join(words)
	return ", ".join(words.slice(0, words.size() - 1)) + " and " + words[-1]


func _fill_ponies(item: ShopItem) -> void:
	for c in _detail_ponies.get_children():
		c.queue_free()
	var zone: StringName = item.permit_zone if item.kind == ShopItemScript.Kind.PERMIT else &""
	_detail_ponies.visible = zone != &""
	if zone == &"":
		return
	var ponies := PonyInstanceScript.get_registry().by_zone(zone)
	ponies.sort_custom(func(a: PonyData, b: PonyData) -> bool:
		return a.rarity > b.rarity if a.rarity != b.rarity else a.display_name < b.display_name)
	for data: PonyData in ponies:
		_detail_ponies.add_child(_pony_chip(data))


func _pony_chip(data: PonyData) -> Control:
	var chip := PanelContainer.new()
	chip.name = String(data.id)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hours := hours_word(data.phases)
	chip.set_meta(&"pony", data.display_name)
	chip.set_meta(&"rarity", data.rarity)
	chip.set_meta(&"hours", hours)
	var box := StyleBoxFlat.new()
	box.bg_color = PaintScript.PLUM_DARK
	box.set_corner_radius_all(14)
	box.content_margin_left = 8
	box.content_margin_right = 12
	box.content_margin_top = 3
	box.content_margin_bottom = 3
	if data.rarity >= PonyDataScript.Rarity.RARE:
		box.border_color = PaintScript.GOLD
		box.set_border_width_all(2)
	chip.add_theme_stylebox_override(&"panel", box)
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override(&"separation", 6)
	chip.add_child(line)
	var glyph := RarityGlyphScript.new()
	glyph.rarity = data.rarity
	glyph.colour = PaintScript.GOLD if data.rarity >= PonyDataScript.Rarity.RARE \
		else MenuStyleScript.COLOR_NAME
	line.add_child(glyph)
	var name_label := Label.new()
	name_label.text = data.display_name
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	MenuStyleScript.style_label(name_label, 18, MenuStyleScript.COLOR_NAME)
	line.add_child(name_label)
	var when := HoursIconScript.new()
	when.phases = data.phases
	line.add_child(when)
	return chip


func _fill_detail() -> void:
	var item := _selected_item() if _tab == Tab.BUY else null
	_detail.visible = item != null
	if item == null:
		return
	var owned := _owned(item)
	(_detail_icon as Control).set(&"kind", ShopIconScript.kind_for(item))
	_detail_icon.queue_redraw()
	_detail_name.text = item.display_name
	_detail_kind.text = kind_word(item)
	_detail_text.text = item.description
	_fill_ponies(item)
	var why := shop.refusal(item)
	_detail_buy.disabled = owned or not why.is_empty()
	if owned:
		_detail_buy.text = "Owned"
	elif item.cost == 0:
		_detail_buy.text = "Take it"
	else:
		_detail_buy.text = "Buy  %d" % item.cost


# --- opening and closing ------------------------------------------------------------------

## Returns whether the Market came up. Already open is a refusal, PauseMenu.open()'s rule
## and for the same reason: an open() that "succeeded" on a menu that was already up would
## announce a second `opened`, and ranch.gd pauses the tree on that signal and unpauses on
## the single `closed` that follows.
## Her bits at the last redraw, so a change can pop (-1: none yet this opening).
var _last_bits := -1


func open() -> bool:
	if _open:
		return false
	if shop == null:
		return false
	if can_open.is_valid() and not bool(can_open.call()):
		return false
	# NOTHING TO SELL, STRAIGHT TO THE SHELVES (PT9; playtest 2026-11-05: the buy screen was
	# easy to miss). With gems in the pouch it opens on Sell, as it always has.
	_tab = Tab.SELL if _pouch_total() > 0 else Tab.BUY
	_selected = 0
	_hovered = -1
	_open = true
	_catalogue.assign(_all_items.filter(func(it: ShopItem) -> bool: return shop.listed(it)))
	_last_bits = -1
	visible = true
	_entrance.restart()
	refresh()
	opened.emit()
	MenuStyleScript.tick_open()
	MenuStyleScript.pop_in(get_node_or_null(^"Centre/Panel") as Control)
	return true


func close() -> void:
	if not _open:
		return
	_open = false
	_hovered = -1
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
	_entrance.restart()
	refresh()
	MenuStyleScript.tick_page()


func selected_index() -> int:
	return _selected


func footer_text() -> String:
	return _footer.text


## The tiles on screen, in row order.
func row_nodes() -> Array[Node]:
	return _rows.get_children()


## The button for tab `t`, or null.
func tab_button(t: int) -> Button:
	if _tabs == null or t < 0 or t >= _tabs.get_child_count():
		return null
	return _tabs.get_child(t) as Button


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
			_paying(func() -> void: sell_all_requested.emit())
			return true
		var rarity: int = sell_rows()[_selected - 1]
		var count := shop.gem_count(rarity)
		if count <= 0:
			_refuse("No %s gems to sell." % _rarity_name(rarity).to_lower())
			return false
		_paying(func() -> void: sell_requested.emit(rarity, count))
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
	if _paying(func() -> void: buy_requested.emit(item)) < 0:
		purchased.emit(item)
	return true


## MONEY THAT MOVES FLIES (PS10, G6). Runs `request` (one of the signals ranch.gd answers by
## calling Shop), and if her bits changed, a coin leaves the picked tile for the purse (a
## sale sends a little shower of them), and the wallet's pop waits for it to land. Returns
## the change in bits; a refusal moves none and flies nothing.
##
## THE COINS LEAVE ON THE NEXT FRAME. The press rebuilds the grid, and picking a tile can
## scroll it into view, so this frame the tile has no place yet; next frame it is where the
## player sees it, and that is where the coins start.
func _paying(request: Callable) -> int:
	var before := shop.bits()
	_pop_delay = MenuStyleScript.COIN_SECONDS
	request.call()
	var moved := shop.bits() - before
	if moved != 0 and _open:
		_coins_due = {"index": _selected, "count": 1 if moved < 0 else clampi(1 + moved / 60, 1, 4)}
	refresh()
	_pop_delay = 0.0
	return moved


## Coins waiting for the grid to settle: {index, count}, or empty.
var _coins_due := {}


func _launch_coins() -> void:
	var index := int(_coins_due["index"])
	var count := int(_coins_due["count"])
	_coins_due = {}
	if index < 0 or index >= _rows.get_child_count() or _fx == null:
		return
	var from := (_rows.get_child(index) as Control).get_global_rect().get_center()
	for k in count:
		MenuStyleScript.fly_coin(_fx, from + Vector2(k * 9.0 - 13.0, 0.0), wallet_target(), k * 0.07)


func sell_everything() -> bool:
	if shop == null or _pouch_total() <= 0:
		return false
	_paying(func() -> void: sell_all_requested.emit())
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
	# Money moving is a moment (FS6.2): a sale or a purchase pops over the wallet, once the
	# coin flying to it has landed (PS10, G6).
	var now := shop.bits()
	if _last_bits >= 0 and now != _last_bits and _open and _fx != null:
		# Beside the purse line, clear of its words, rising into the empty top right.
		var beside := Vector2(_gems.get_global_rect().end.x + 110.0, wallet_target().y)
		MenuStyleScript.payout_pop(_fx, beside, now - _last_bits, _pop_delay)
	_last_bits = now
	_gems.text = "%d gems in your pouch" % _pouch_total()
	MouseRowsScript.tab_strip(_tabs, TAB_NAMES, _tab, Callable(),
		func(i: int) -> void:
			if i != _tab:
				set_tab(i))
	for i in _tabs.get_child_count():
		var b := _tabs.get_child(i) as Button
		b.add_theme_font_size_override(&"font_size", MenuStyle.font_px(26))
		b.add_theme_font_override(&"font", MenuStyleScript.title_font())
		var on := MenuStyleScript.COLOR_TAB_ON if i == _tab else MenuStyleScript.COLOR_TAB_OFF
		for state in [&"font_color", &"font_hover_color", &"font_pressed_color"]:
			b.add_theme_color_override(state, on)
	_rows.columns = 1 if _tab == Tab.SELL else BUY_COLUMNS
	# remove_child BEFORE queue_free: a queued node is still a child until the end of the
	# frame, so freeing alone would leave the old rows laid out underneath the new ones for
	# one frame every time the cursor moves.
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_built_frame = Engine.get_process_frames()
	if _tab == Tab.SELL:
		_add_row(0, "Sell everything", "every gem in your pouch, in one go",
			"%d bits" % _sell_all_value(), _pouch_total() > 0, &"sell_all")
		for i in range(sell_rows().size()):
			var rarity: int = sell_rows()[i]
			var count := shop.gem_count(rarity)
			_add_row(i + 1, "%s gems" % _rarity_name(rarity), "you have %d" % count,
				"%d bits each" % shop.gem_price(rarity), count > 0,
				StringName("gem_%d" % clampi(rarity, 0, 3)))
	else:
		for i in range(_catalogue.size()):
			var item := _catalogue[i]
			# A PERMIT ALREADY IN THE UNLOCKS READS OWNED, exactly as held gear does. Shop
			# refuses to sell either of them twice (shop.gd's refusal()), so a permit row
			# still showing its price was a row offering something that could not be
			# bought, on the most expensive line on the screen: 1200 bits displayed next
			# to a gate that is already standing open.
			var owned := _owned(item)
			var price := "OWNED" if owned else ("FREE" if item.cost == 0 else "%d bits" % item.cost)
			_add_row(i, item.display_name, item.description, price, shop.can_buy(item),
				ShopIconScript.kind_for(item), kind_word(item))
	_fill_detail()
	_entrance.apply(_rows.get_children())
	_fit_scroll.call_deferred()


func _process(delta: float) -> void:
	if not _open:
		_coins_due = {}
		return
	if _entrance.running(_rows.get_child_count()):
		_entrance.advance(delta, _rows.get_children())
	if not _coins_due.is_empty() and _built_frame != Engine.get_process_frames():
		_launch_coins()


## Step the tiles' deal-in by `dt` seconds, as a frame would (the suite drives it so).
func advance_entrance(dt: float) -> void:
	_entrance.advance(dt, _rows.get_children())


func _owned(item: ShopItem) -> bool:
	if item.kind == ShopItemScript.Kind.GEAR:
		return shop.owns_gear(item.gear_id)
	if item.kind == ShopItemScript.Kind.PERMIT:
		return shop.owns_permit(item.permit_zone)
	return false


func _sell_all_value() -> int:
	var total := 0
	for rarity in sell_rows():
		total += shop.gem_count(rarity) * shop.gem_price(rarity)
	return total


## THE SCROLL AREA IS AS TALL AS ITS TILES, UP TO SCROLL_MAX, and the pick is always in it.
## Deferred: the grid only knows its height once the frame's layout has run.
func _fit_scroll() -> void:
	if _scroll == null or not _open:
		return
	# The BUY tab gives the detail strip its room, so the whole panel fits a 720 p screen.
	var cap := SCROLL_MAX if _tab == Tab.SELL else SCROLL_MAX_BUY
	_scroll.custom_minimum_size.y = minf(_rows.get_combined_minimum_size().y, cap)
	# The first row is the top (PS10 gap G17): ensure_control_visible on a grid whose layout
	# had not settled scrolled the Buy tab 256 px past its pick, Hay out of view.
	if _selected == 0:
		_scroll.scroll_vertical = 0
	elif _selected > 0 and _selected < _rows.get_child_count():
		_scroll.ensure_control_visible(_rows.get_child(_selected) as Control)


func _add_row(index: int, row_name: String, blurb: String, price: String, enabled: bool,
		icon_kind: StringName = &"", tag := "") -> void:
	var row := MouseRowsScript.row(index, index == _selected, index == _hovered,
		point_at_row, take_row)
	TileStyleScript.dress(row, index == _selected, index == _hovered)
	row.custom_minimum_size = SELL_TILE if _tab == Tab.SELL else BUY_TILE
	# A GRID OF TWO, NOT AN HBOX: row_price_text() reads the first HBoxContainer in a tile as
	# its name-and-price line, so the icon and the text sit side by side in a GridContainer.
	var body := GridContainer.new()
	body.columns = 2
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_constant_override(&"h_separation", 14)
	row.add_child(body)
	var plate := TileStyleScript.disc(ICON_SIZE,
		PaintScript.CARD_FACE if enabled else PaintScript.CARD_FACE.darkened(0.35))
	body.add_child(plate)
	var icon: Control = ShopIconScript.new()
	icon.kind = icon_kind
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.modulate = Color(1, 1, 1) if enabled else Color(1, 1, 1, 0.55)
	plate.add_child(icon)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override(&"separation", 2)
	body.add_child(column)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override(&"separation", 24)
	column.add_child(head)
	var title := Label.new()
	title.text = row_name
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Wraps rather than clipping: "Permit: The Night Meadow" is the longest name in the shop.
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.max_lines_visible = 2
	title.custom_minimum_size = Vector2(140.0, 0.0)
	MenuStyleScript.style_label(title, 22,
		MenuStyleScript.COLOR_TITLE if enabled else MenuStyleScript.COLOR_DIM)
	title.add_theme_font_override(&"font", MenuStyleScript.title_font())
	head.add_child(title)
	var cost := Label.new()
	cost.text = price
	cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost.add_theme_font_override(&"font", MenuStyleScript.numeral_font())
	MenuStyleScript.style_label(cost, 22,
		MenuStyleScript.COLOR_VALUE if enabled else MenuStyleScript.COLOR_UNAFFORDABLE)
	head.add_child(cost)
	if not tag.is_empty():
		var chip := Label.new()
		chip.text = tag
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		MenuStyleScript.style_label(chip, 14, PaintScript.GOLD if enabled else PaintScript.GOLD_DIM)
		column.add_child(chip)
	if not blurb.is_empty():
		var sub := Label.new()
		sub.text = blurb
		sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# ONE LINE, ENDED PROPERLY: the whole of it is in the detail strip under the grid.
		sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_WORD_ELLIPSIS
		sub.clip_text = true
		sub.custom_minimum_size = Vector2(0.0, 0.0)
		MenuStyleScript.style_label(sub, 17, MenuStyleScript.COLOR_DIM)
		column.add_child(sub)
	_rows.add_child(row)


func _refuse(text: String) -> void:
	_footer.text = "  " + text
	MenuStyleScript.style_label(_footer, MenuStyleScript.FOOTER_SIZE,
		MenuStyleScript.COLOR_UNAFFORDABLE)


# --- the pointer ----------------------------------------------------------------------------


func hovered_index() -> int:
	return _hovered


func close_button_node() -> Button:
	return _close


## ONE CURSOR, TWO WAYS TO MOVE IT. Absolute where move_selection() is relative, and it makes
## the same sound, because both are the player choosing a row.
func point_at_row(index: int) -> void:
	if index < 0 or index >= _row_count():
		return
	if index == _selected and index == _hovered:
		return
	_hovered = index
	if index != _selected:
		_selected = index
		MenuStyleScript.tick_move()
	refresh()


func take_row(index: int) -> void:
	point_at_row(index)
	if _selected == index:
		confirm()
