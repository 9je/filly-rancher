extends GutTest
## The Depot menu draws and emits. It never touches the ledger, the wallet or the state.

const DepotMenuScene := preload("res://ui/depot_menu.tscn")
const LedgerScript := preload("res://systems/ledger.gd")

var _menu: DepotMenu = null


func before_each() -> void:
	_menu = DepotMenuScene.instantiate()
	add_child_autofree(_menu)
	_menu.can_open = func() -> bool: return true
	_menu.bits_provider = func() -> int: return 900
	_menu.rows_provider = func() -> Array[Dictionary]:
		var rows: Array[Dictionary] = []
		rows.append({"uid": &"stock_shy#000001", "name": "Pony", "stock": true, "credit": 300})
		rows.append({"uid": &"trixie#000002", "name": "Trixie", "stock": false, "credit": 4000})
		return rows
	_menu.statement_provider = func() -> Array[String]:
		return LedgerScript.new().statement_lines("Moonbeam", 1, 0, 2)


func test_it_opens_and_closes_and_reports_which_it_is() -> void:
	assert_false(_menu.is_open())
	assert_true(_menu.open())
	assert_true(_menu.is_open())
	_menu.close()
	assert_false(_menu.is_open())


func test_it_refuses_to_open_over_another_menu() -> void:
	_menu.can_open = func() -> bool: return false
	assert_false(_menu.open())
	assert_false(_menu.is_open())


func test_the_deliver_tab_lists_stock_first_then_named_with_their_credit() -> void:
	_menu.open()
	var rows: Array[Dictionary] = _menu.deliver_rows()
	assert_eq(rows.size(), 2)
	assert_true(bool(rows[0]["stock"]), "the crowd is offered first")
	assert_eq(int(rows[1]["credit"]), 4000)


func test_confirming_a_row_emits_the_uid_and_pays_for_nothing_itself() -> void:
	_menu.open()
	watch_signals(_menu)
	_menu.confirm()
	assert_signal_emitted_with_parameters(_menu, "deliver_requested", [&"stock_shy#000001"])


func test_the_pay_tab_offers_amounts_the_wallet_can_actually_cover() -> void:
	_menu.open()
	_menu.switch_tab(1)
	assert_eq(_menu.tab(), DepotMenu.Tab.PAY)
	for amount in _menu.pay_amounts():
		assert_lte(amount, 900, "the menu never offers to spend bits she does not have")
	assert_gt(_menu.pay_amounts().size(), 0)


func test_confirming_a_pay_row_emits_the_amount() -> void:
	_menu.open()
	_menu.switch_tab(1)
	watch_signals(_menu)
	var first: int = _menu.pay_amounts()[0]
	_menu.confirm()
	assert_signal_emitted_with_parameters(_menu, "pay_requested", [first])


func test_the_statement_tab_repeats_the_ledger_without_editing_it() -> void:
	_menu.open()
	_menu.switch_tab(2)
	assert_eq(_menu.tab(), DepotMenu.Tab.STATEMENT)
	var lines: Array[String] = _menu.statement_provider.call()
	assert_true("\n".join(lines).contains("Sponsorship balance"))


func test_no_string_the_menu_draws_carries_a_dash() -> void:
	_menu.open()
	for tab in [DepotMenu.Tab.DELIVER, DepotMenu.Tab.PAY, DepotMenu.Tab.STATEMENT]:
		_menu.set_tab(tab)
		for line in _menu.drawn_lines():
			assert_false(line.contains("--"), "'%s' carries a double hyphen" % line)
			assert_false(line.contains(char(0x2014)), "'%s' carries an em dash" % line)


func test_an_empty_pen_shows_a_note_rather_than_an_empty_box() -> void:
	_menu.rows_provider = func() -> Array[Dictionary]: return []
	_menu.open()
	assert_eq(_menu.deliver_rows().size(), 0)
	assert_true("\n".join(_menu.drawn_lines()).contains(DepotMenu.EMPTY_TEXT))


# --- Ruling 9: a named pony costs a second press -------------------------------------------

func test_a_named_pony_asks_before_she_is_handed_over() -> void:
	_menu.open()
	watch_signals(_menu)
	_menu.move_selection(1)
	assert_false(bool(_menu.deliver_rows()[_menu.selected_index()]["stock"]),
		"sanity: the cursor is on the named row")
	assert_true(_menu.confirm(), "the press does something")
	assert_true(_menu.is_confirming(), "...and what it does is ask")
	assert_signal_not_emitted(_menu, "deliver_requested",
		"nobody is handed over on the first press")
	var lines: Array[String] = _menu.drawn_lines()
	assert_eq(lines.size(), 2, "the question is the only thing on screen")
	assert_true(lines[0].contains("Trixie"), "and it says who it is about")


func test_the_cursor_starts_on_no_so_a_double_press_keeps_her() -> void:
	_menu.open()
	watch_signals(_menu)
	_menu.move_selection(1)
	_menu.confirm()
	assert_eq(_menu.selected_index(), 1, "the refusal is what is under the cursor")
	_menu.confirm()
	assert_false(_menu.is_confirming(), "the question is answered")
	assert_signal_not_emitted(_menu, "deliver_requested",
		"a second press on the heels of the first keeps her, which is the point")


func test_answering_yes_hands_her_over() -> void:
	_menu.open()
	watch_signals(_menu)
	_menu.move_selection(1)
	_menu.confirm()
	_menu.move_selection(-1)
	assert_eq(_menu.selected_index(), 0, "up moves onto the yes row")
	assert_true(_menu.confirm())
	assert_false(_menu.is_confirming())
	assert_signal_emitted_with_parameters(_menu, "deliver_requested", [&"trixie#000002"])


func test_a_stock_pony_still_goes_on_one_press() -> void:
	_menu.open()
	watch_signals(_menu)
	assert_true(_menu.confirm())
	assert_false(_menu.is_confirming(), "the crowd is not worth a second press")
	assert_signal_emitted_with_parameters(_menu, "deliver_requested", [&"stock_shy#000001"])


func test_changing_tab_drops_the_question() -> void:
	_menu.open()
	_menu.move_selection(1)
	_menu.confirm()
	assert_true(_menu.is_confirming())
	_menu.switch_tab(1)
	_menu.switch_tab(-1)
	assert_false(_menu.is_confirming(), "walking away from the counter is an answer too")


func test_the_confirm_rows_carry_no_dash() -> void:
	_menu.open()
	_menu.move_selection(1)
	_menu.confirm()
	for line in _menu.drawn_lines():
		assert_false(line.contains("--"), "'%s' carries a double hyphen" % line)
		assert_false(line.contains(char(0x2014)), "'%s' carries an em dash" % line)


# --- the cursor cannot address a row that is not there ---------------------------------------

## The row list is rebuilt from the pens on every refresh and it SHRINKS. Without the clamp
## in refresh(), delivering the last pony left _selected pointing past the end of the list
## and the next press read a row that was not there.
func test_the_cursor_is_clamped_back_onto_the_list_when_the_pens_empty() -> void:
	_menu.open()
	_menu.move_selection(1)
	assert_eq(_menu.selected_index(), 1)
	_menu.rows_provider = func() -> Array[Dictionary]:
		var rows: Array[Dictionary] = []
		rows.append({"uid": &"stock_shy#000001", "name": "Pony", "stock": true, "credit": 300})
		return rows
	_menu.refresh()
	assert_eq(_menu.selected_index(), 0, "the cursor comes back onto a row that exists")
	watch_signals(_menu)
	_menu.confirm()
	assert_signal_emitted_with_parameters(_menu, "deliver_requested", [&"stock_shy#000001"])


## Array.sort_custom() is not stable, so six stock ponies at one credit each could come back
## in a different order from one refresh to the next, and the cursor addresses a row by
## INDEX. The uid tiebreak makes the order total, so there is exactly one answer.
func test_rows_of_equal_credit_come_back_in_one_fixed_order() -> void:
	var uids: Array[StringName] = [&"stock_shy#000006", &"stock_bold#000002",
		&"stock_curious#000004", &"stock_shy#000001", &"stock_bold#000005",
		&"stock_curious#000003"]
	_menu.rows_provider = func() -> Array[Dictionary]:
		var rows: Array[Dictionary] = []
		for uid: StringName in uids:
			rows.append({"uid": uid, "name": "Pony", "stock": true, "credit": 300})
		return rows
	_menu.open()
	var first: Array[String] = []
	for row in _menu.deliver_rows():
		first.append(String(row["uid"]))
	var sorted_uids: Array[String] = first.duplicate()
	sorted_uids.sort()
	assert_eq(first, sorted_uids, "equal rows are ordered by the one thing that is unique")
	for i in 5:
		var again: Array[String] = []
		for row in _menu.deliver_rows():
			again.append(String(row["uid"]))
		assert_eq(again, first, "and the same list comes back every time it is asked for")


# --- what tells two members of the crowd apart -----------------------------------------------

func test_a_stock_row_draws_the_coat_word_the_provider_hands_over() -> void:
	_menu.rows_provider = func() -> Array[Dictionary]:
		var rows: Array[Dictionary] = []
		rows.append({"uid": &"stock_shy#000001", "name": "Pony", "stock": true,
			"coat": "Butter", "credit": 300})
		rows.append({"uid": &"stock_shy#000002", "name": "Pony", "stock": true,
			"coat": "Sky", "credit": 300})
		return rows
	_menu.open()
	var lines: Array[String] = _menu.drawn_lines()
	assert_eq(lines.size(), 2)
	assert_ne(lines[0], lines[1], "two members of the crowd are not two identical rows")
	assert_true(lines[0].contains("Butter Pony"))
	assert_true(lines[1].contains("Sky Pony"))


func test_a_provider_with_no_coat_word_draws_the_bare_name() -> void:
	_menu.open()
	assert_true(_menu.drawn_lines()[0].begins_with("Pony"),
		"no coat on the row is the name on its own, which is what it drew before")


# --- Ruling 12: the Pay tab honours what the ledger will accept -------------------------------

func test_the_pay_tab_never_offers_more_than_the_ledger_will_take() -> void:
	_menu.payable_provider = func() -> int: return 250
	_menu.open()
	_menu.switch_tab(1)
	var amounts: Array[int] = _menu.pay_amounts()
	assert_gt(amounts.size(), 0, "there is still something to pay")
	for amount in amounts:
		assert_lte(amount, 250,
			"the ledger caps every payment at payable(); a bigger row would be trimmed")
	assert_eq(amounts[amounts.size() - 1], 250, "and the last row is exactly what it will take")


func test_a_ledger_at_the_floor_offers_nothing_to_pay() -> void:
	_menu.payable_provider = func() -> int: return 0
	_menu.open()
	_menu.switch_tab(1)
	assert_eq(_menu.pay_amounts().size(), 0,
		"bits settle the service charges; at the floor there are none to settle")
	assert_true("\n".join(_menu.drawn_lines()).contains(DepotMenu.EMPTY_PAY_TEXT))
