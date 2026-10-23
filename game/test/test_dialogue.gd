extends GutTest
## The talk system's logic: Dialogue resources compiled by tools/make_dialogue.py, the
## runner's line/choice/effect flow, the library's pick rules, and the shipped Act One
## script being coherent (every speaker is a real character, every line ends somewhere).

const RunnerScript := preload("res://systems/dialogue_runner.gd")
const LibraryScript := preload("res://systems/talk_library.gd")
const DialogueScript := preload("res://systems/dialogue.gd")


func _ctx(chapter := 0, flags := {}, counts := {}) -> Dictionary:
	return {"chapter": chapter, "path": "", "flags": flags, "counts": counts,
		"name": "Juniper", "tumble": "Tumble"}


func _conv() -> Dialogue:
	var d: Dialogue = DialogueScript.new()
	d.id = &"t"
	d.speaker = &"fennel"
	d.nodes = [
		{"id": "a", "text": "Hello {name}.", "next": "b", "flag": "said_hi"},
		{"id": "b", "text": "Pick.", "choices": [
			{"text": "Yes", "next": "c", "flag": "chose_yes"},
			{"text": "No", "next": ""}]},
		{"id": "c", "text": "Good.", "event": "reward"},
	]
	return d


func test_lines_fill_the_players_name_and_advance() -> void:
	var r := RunnerScript.new()
	var line := r.start(_conv(), _ctx())
	assert_eq(line.text, "Hello Juniper.")
	assert_eq(line.who, &"fennel")
	line = r.advance()
	assert_eq(line.choices, ["Yes", "No"] as Array[String])


func test_a_choice_routes_and_records_its_flag_and_the_nodes_effects() -> void:
	var r := RunnerScript.new()
	r.start(_conv(), _ctx())
	r.advance()
	var line := r.choose(0)
	assert_eq(line.text, "Good.")
	var flags := r.effects.filter(func(e: Dictionary) -> bool: return e.has("flag")).map(
		func(e: Dictionary) -> String: return e.flag)
	assert_eq(flags, ["said_hi", "chose_yes"])
	assert_true(r.effects.any(func(e: Dictionary) -> bool: return e.get("event", "") == "reward"))
	watch_signals(r)
	r.advance()
	assert_false(r.is_running())
	assert_signal_emitted(r, "finished")


func test_an_empty_next_ends_the_conversation() -> void:
	var r := RunnerScript.new()
	r.start(_conv(), _ctx())
	r.advance()
	r.choose(1)
	assert_false(r.is_running())


func test_conditions_gate_on_chapter_flags_and_counts() -> void:
	var d := _conv()
	d.when = {"chapters": [0], "flags_none": ["x"], "flags_all": ["y"], "min": {"pens": 1}, "max": {"blooms": 0}}
	assert_true(RunnerScript.matches(d, _ctx(0, {"y": true}, {"pens": 1})))
	assert_false(RunnerScript.matches(d, _ctx(1, {"y": true}, {"pens": 1})), "wrong chapter")
	assert_false(RunnerScript.matches(d, _ctx(0, {"y": true, "x": true}, {"pens": 1})), "flag set")
	assert_false(RunnerScript.matches(d, _ctx(0, {}, {"pens": 1})), "flag missing")
	assert_false(RunnerScript.matches(d, _ctx(0, {"y": true}, {"pens": 0})), "below min")
	assert_false(RunnerScript.matches(d, _ctx(0, {"y": true}, {"pens": 1, "blooms": 1})), "above max")


func test_the_library_offers_news_before_barks_and_once_means_once() -> void:
	var lib := LibraryScript.new()
	lib.load_all()
	var ctx := _ctx(0, {}, {})
	var first := lib.pick(&"marigold", ctx)
	assert_eq(first.id, &"marigold_arrival")
	assert_true(lib.has_news(&"marigold", ctx))
	lib.mark_seen(first.id)
	ctx.flags["has_scoop"] = true
	var next := lib.pick(&"marigold", ctx)
	assert_not_null(next)
	assert_true(next.bark, "with nothing new to say, she barks")
	assert_false(lib.has_news(&"marigold", ctx))


func test_every_shipped_conversation_has_a_real_speaker_and_ends() -> void:
	var lib := LibraryScript.new()
	assert_gt(lib.load_all(), 10)
	var cast := {}
	var d := DirAccess.open("res://data/characters")
	for f in d.get_files():
		cast[f.trim_suffix(".remap").trim_suffix(".tres")] = true
	for conv in lib.all:
		assert_true(cast.has(String(conv.speaker)), "%s speaker %s is a character" % [conv.id, conv.speaker])
		for n: Dictionary in conv.nodes:
			if n.has("who"):
				assert_true(cast.has(str(n.who)), "%s line by %s" % [conv.id, n.who])
		# Walk every path; it must terminate within the node count.
		var r := RunnerScript.new()
		r.start(conv, _ctx())
		var steps := 0
		while r.is_running() and steps < 200:
			if r.has_choices():
				r.choose(0)
			else:
				r.advance()
			steps += 1
		assert_false(r.is_running(), "%s ends" % conv.id)


func test_the_cast_are_generated_ponies_on_real_donors() -> void:
	for id in ["tumble", "marigold", "fennel", "pip", "bramble", "static", "clover"]:
		var def: CharacterDef = load("res://data/characters/%s.tres" % id)
		assert_not_null(def, id)
		var look := def.build_look()
		assert_ne(DonorTable.load_table().find(look.donor), {}, "%s donor %s exists" % [id, look.donor])
		assert_eq(look.to_dict(), def.build_look().to_dict(), "%s is the same pony every time" % id)
	var tumble: CharacterDef = load("res://data/characters/tumble.tres")
	assert_true(tumble.build_look().foal)
	assert_false(tumble.build_look().has_mark(), "Tumble is a Drifter")
