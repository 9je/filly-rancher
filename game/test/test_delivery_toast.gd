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
	assert_false("credited" in line, "never 'credited': nothing reaches the purse")


func test_a_paid_off_balance_says_so() -> void:
	var line: String = RanchScript.delivery_toast("Cloudsdale Weather Corporation", 9, 1200, 0)
	assert_string_contains(line, "paid off")


func test_thousands_are_grouped() -> void:
	assert_eq(RanchScript.group_thousands(1234567), "1,234,567")
	assert_eq(RanchScript.group_thousands(999), "999")
	assert_eq(RanchScript.group_thousands(0), "0")
