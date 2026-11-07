extends GutTest
## THE FACTORY HINTS ARE SUBTLE AND LATE (PS8, playtest 2026-11-05 item 50: "The Rainbow
## Factory hints (the yield letter, the Mayor) are too on the nose, too early"). Nothing the
## Corporation mails you, and nothing the first hour's happenings say, talks about "yield":
## the word belongs to the Factory and to the chapters after it.

const LettersScript := preload("res://systems/letters.gd")


func test_no_letter_mentions_yield() -> void:
	var params := {"name": "Twilight", "count": 3, "credit": 120, "pony": "Sweetie Belle",
		"quota": 2, "balance": 25000, "upkeep": 1800, "punishment": "one pony"}
	for id: int in LettersScript.ids():
		var l: Dictionary = LettersScript.render(id, params)
		var text := String(l.get("title", "")) + " " + " ".join(l.get("body", []))
		assert_false(text.containsn("yield"), "letter %d says nothing of yield: %s" % [id, text])


func test_the_first_hours_happenings_say_nothing_of_yield() -> void:
	var src := FileAccess.get_file_as_string("res://world/happenings.gd")
	for line in src.split("\n"):
		if line.contains("_toast\"") or line.contains("\"_toast\","):
			assert_false(line.containsn("yield"), "a happening's toast names the yield: %s" % line.strip_edges())
