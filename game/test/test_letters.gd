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
