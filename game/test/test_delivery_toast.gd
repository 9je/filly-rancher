extends GutTest
## THE RECEIPT SAYS WHERE THE BITS WENT. A delivery used to toast "4th shipment received,
## 300 bits credited." while the wallet on screen did not move: the 300 come off the
## sponsorship balance, not into the purse. A player watching her purse read that as a bug
## (the overnight bot review, 2026-10-26). Now the line says it is the balance, and how much
## of it is left.

const RanchScript := preload("res://world/ranch.gd")
const LedgerScript := preload("res://systems/ledger.gd")


func test_the_receipt_names_the_balance_and_what_is_left() -> void:
	var line: String = RanchScript.delivery_toast("Cloudsdale Weather Corporation", 4, 300, 24100)
	assert_string_contains(line, "4th shipment")
	assert_string_contains(line, "300 bits off your balance")
	assert_string_contains(line, "24,100 to go")
	assert_false("credited" in line, "never 'credited': the balance and the purse are told apart")


func test_a_paid_off_balance_says_so() -> void:
	var line: String = RanchScript.delivery_toast("Cloudsdale Weather Corporation", 9, 1200, 0)
	assert_string_contains(line, "paid off")


func test_thousands_are_grouped() -> void:
	assert_eq(RanchScript.group_thousands(1234567), "1,234,567")
	assert_eq(RanchScript.group_thousands(999), "999")
	assert_eq(RanchScript.group_thousands(0), "0")


## PT9 (playtest 2026-11-05: "i thought i was gonna get paid but it went to debt"): a delivery
## also pays a handler's share into the purse, ON TOP of what comes off the balance (so the
## story's pace of paying the debt is unchanged), and the line says both.
func test_a_delivery_pays_a_handlers_share_on_top() -> void:
	assert_eq(RanchScript.handler_share(200), 50)
	assert_eq(RanchScript.handler_share(1200), 300)
	assert_eq(RanchScript.handler_share(0), 0)
	var line: String = RanchScript.delivery_toast("Cloudsdale Weather Corporation", 4, 200, 24100, 50)
	assert_string_contains(line, "200 bits off your balance")
	assert_string_contains(line, "+50 bits for you")


# --- P8: one toast and one card per Depot batch (playtest 2026-11-08 items 20, 21) ---------

func test_a_batch_of_deliveries_is_told_once() -> void:
	var ranch: Node = RanchScript.new()
	autofree(ranch)
	ranch.begin_delivery_batch()
	ranch._note_shipment("Intake", 1, 300, 75, false)
	ranch._note_shipment("Intake", 2, 300, 75, false)
	ranch._note_shipment("Intake", 3, 0, 30, true)
	var line: String = ranch.end_delivery_batch()
	assert_string_contains(line, "3 ponies shipped (1 blank)")
	assert_string_contains(line, "600 bits off your balance")
	assert_string_contains(line, "+180 bits for you")
	assert_eq(ranch.end_delivery_batch(), "", "and told only once")


func test_a_delivery_outside_a_batch_is_its_own_batch_of_one() -> void:
	var line: String = RanchScript.batch_toast({"count": 1, "blanks": 0, "credit": 300, "paid": 75,
		"sender": "Intake", "shipments": 4}, 24100)
	assert_string_contains(line, "4th shipment")
	var blank: String = RanchScript.batch_toast({"count": 1, "blanks": 1, "credit": 0, "paid": 30,
		"sender": "Intake", "shipments": 5}, 24100)
	assert_string_contains(blank, "blank Drifter")
	assert_false(blank.contains("--"))


func test_a_dawns_postcards_come_as_one_card() -> void:
	assert_eq(RanchScript.postcard_signature(["Butter Pony"]), "Butter Pony")
	var many: String = RanchScript.postcard_signature(["Butter Pony", "Sky Pony", "Rose Pony"])
	assert_true(many.begins_with("Butter Pony"))
	assert_string_contains(many, "2 more cards in the envelope")


func test_a_bloomed_drifter_is_priced_by_her_talent() -> void:
	var gen: Script = load("res://systems/pony_generator.gd")
	var a := PonyInstance.new()
	a.stock = gen.generate(5, {"marked": true}).to_dict()
	var blank := PonyInstance.new()
	blank.stock = gen.generate(6).to_dict()
	assert_eq(RanchScript._delivery_kind(blank), LedgerScript.DRIFTER_KIND)
	assert_true(RanchScript._is_blank(blank))
	assert_false(RanchScript._is_blank(a))
	assert_true(String(RanchScript._delivery_kind(a)).begins_with("bloomed_"),
		"a Bloomed Drifter repeats by talent, not as one big crowd")
