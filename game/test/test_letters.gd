extends GutTest
## The Company's stub sender: fixed, cheerful, corporate text with the player's name in it.

const LettersScript := preload("res://systems/letters.gd")

## A name of exactly MAX_NAME_LENGTH characters, in the widest glyph a name box will accept.
func _longest_legal_name() -> String:
	return "W".repeat(LettersScript.MAX_NAME_LENGTH)


func test_every_template_renders_with_the_longest_legal_name_without_overflow() -> void:
	var params := {"name": _longest_legal_name(), "count": 12, "credit": 4000,
		"pony": "Wwwwwwwwwwwwwwww", "quota": 2, "balance": 25000, "upkeep": 3150,
		"punishment": "a fee of 500 bits"}
	for id: int in LettersScript.ids():
		var letter: Dictionary = LettersScript.render(id, params)
		assert_false(String(letter["title"]).is_empty(), "letter %d has a title" % id)
		var body: Array = letter["body"]
		assert_gt(body.size(), 0, "letter %d has a body" % id)
		for line in body:
			assert_lte(String(line).length(), LettersScript.LINE_WIDTH,
				"letter %d overflows on line '%s'" % [id, line])


func test_no_letter_carries_a_dash_of_any_kind() -> void:
	var params := {"name": "Moonbeam", "count": 3, "credit": 300, "pony": "Trixie",
		"quota": 2, "balance": 25000, "upkeep": 3150, "punishment": "a fee of 500 bits"}
	for id: int in LettersScript.ids():
		var letter: Dictionary = LettersScript.render(id, params)
		var joined: String = String(letter["title"]) + "\n" + "\n".join(letter["body"])
		assert_false(joined.contains("--"), "letter %d carries a double hyphen" % id)
		assert_false(joined.contains(char(0x2014)), "letter %d carries an em dash" % id)


func test_a_receipt_names_the_player_and_the_shipment_number() -> void:
	var letter: Dictionary = LettersScript.render(LettersScript.Id.RECEIPT_STOCK,
		{"name": "Moonbeam", "count": 3, "credit": 300})
	var joined: String = "\n".join(letter["body"])
	assert_true(joined.contains("Moonbeam"))
	assert_true(joined.contains("3rd"), "the receipt counts her shipments for her")
	assert_true(joined.contains("300"))


func test_the_ordinal_suffixes_are_right_where_english_is_odd() -> void:
	assert_eq(LettersScript.ordinal(1), "1st")
	assert_eq(LettersScript.ordinal(2), "2nd")
	assert_eq(LettersScript.ordinal(3), "3rd")
	assert_eq(LettersScript.ordinal(4), "4th")
	assert_eq(LettersScript.ordinal(11), "11th")
	assert_eq(LettersScript.ordinal(12), "12th")
	assert_eq(LettersScript.ordinal(13), "13th")
	assert_eq(LettersScript.ordinal(21), "21st")
	assert_eq(LettersScript.ordinal(112), "112th")


func test_an_unknown_id_answers_an_empty_letter_rather_than_crashing() -> void:
	var letter: Dictionary = LettersScript.render(999, {})
	assert_eq(letter["body"], [])


# --- the welcome letter, reworked as the one screen explainer -----------------------------

## THE ONE SCREEN EXPLAINER. The owner, 2026-08-31: "rework the WELCOME letter into a one
## screen explainer (catch, pen, gems, sell at the Market; quota and balance in one
## sentence each)". The shipped welcome said "Catch ponies, keep them happy, and bring us
## stock", which names none of the four steps and neither of the two numbers.
func test_the_welcome_letter_names_every_step_of_the_money_loop() -> void:
	var letter: Dictionary = LettersScript.render(LettersScript.Id.WELCOME,
		{"name": "Twilight", "balance": 25000, "quota": 2})
	var body: String = "\n".join(letter["body"]).to_lower()
	for step: String in ["catch", "pen", "gem", "market"]:
		assert_true(body.contains(step), "the welcome must name '%s': %s" % [step, body])


## WHAT THIS TEST CANNOT SEE, and did not: it hands the template a quota and checks the
## template prints it. ranch.gd's one production call passed no quota at all, so the shipped
## letter said "0 ponies" while this passed. The CALLER seam is pinned in
## game/test/test_ranch_creation.gd, which drives _on_creation_confirmed() and reads the
## page the player is actually shown. Both are needed; only the second one bites.
func test_the_welcome_letter_states_the_balance_and_the_quota_once_each() -> void:
	var letter: Dictionary = LettersScript.render(LettersScript.Id.WELCOME,
		{"name": "Twilight", "balance": 25000, "quota": 2})
	var body: String = "\n".join(letter["body"])
	assert_true(body.contains("25000") or body.contains("25,000"), body)
	assert_true(body.contains("2 ponies") or body.contains("2 pony"), body)


func test_the_welcome_letter_still_fits_the_panel_at_the_longest_legal_name() -> void:
	var letter: Dictionary = LettersScript.render(LettersScript.Id.WELCOME,
		{"name": "M".repeat(LettersScript.MAX_NAME_LENGTH), "balance": 25000, "quota": 2})
	for line: String in letter["body"]:
		assert_lte(line.length(), LettersScript.LINE_WIDTH, line)
