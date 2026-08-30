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
