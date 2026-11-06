extends GutTest
## THE RECEIPT SAYS WHERE THE BITS WENT. A delivery used to toast "4th shipment received,
## 300 bits credited." while the wallet on screen did not move: the 300 come off the
## sponsorship balance, not into the purse. A player watching her purse read that as a bug
## (the overnight bot review, 2026-10-26). Now the line says it is the balance, and how much
## of it is left.

const RanchScript := preload("res://world/ranch.gd")


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
