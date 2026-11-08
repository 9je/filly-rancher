extends GutTest
## NO STORY TALK CAN STRAND HER (P8, playtest 2026-11-08 item 1). A static walk of every
## compiled conversation: one the player can finish only once (`once` true) and that moves
## the story (it fires an event or sets a flag somewhere) must do that on every way out.
## Otherwise a branch like Marigold's "Give me a minute" ends the talk, marks it finished, and
## the step it gated never comes back. A talk that is offered again (`once` false) is fine,
## since the player can take the other branch next time. No game launch: data only.

const DIALOGUE_DIR := "res://data/dialogue/"


func _all() -> Array[Dialogue]:
	var out: Array[Dialogue] = []
	for f: String in DirAccess.get_files_at(DIALOGUE_DIR):
		if f.ends_with(".tres"):
			out.append(load(DIALOGUE_DIR + f) as Dialogue)
	return out


func _moves_story(d: Dialogue) -> bool:
	for n: Dictionary in d.nodes:
		if str(n.get("event", "")) != "" or str(n.get("flag", "")) != "":
			return true
		for c: Dictionary in n.get("choices", []):
			if str(c.get("flag", "")) != "":
				return true
	return false


## The ids of the nodes that end the talk on a path from the start with no event or flag on it.
func _silent_endings(d: Dialogue) -> Array[String]:
	var out: Array[String] = []
	var seen := {}
	var stack: Array = [[str(d.start_node().get("id", "")), false]]
	while not stack.is_empty():
		var top: Array = stack.pop_back()
		var id: String = top[0]
		var n := d.node(id)
		if n.is_empty():
			continue
		var acted: bool = top[1] or str(n.get("event", "")) != "" or str(n.get("flag", "")) != ""
		var key := "%s/%s" % [id, acted]
		if seen.has(key):
			continue
		seen[key] = true
		var choices: Array = n.get("choices", [])
		var nxt := str(n.get("next", ""))
		if choices.is_empty() and nxt == "":
			if not acted:
				out.append(id)
			continue
		if nxt != "":
			stack.append([nxt, acted])
		for c: Dictionary in choices:
			var c_acted: bool = acted or str(c.get("flag", "")) != ""
			var c_next := str(c.get("next", ""))
			if c_next == "":
				if not c_acted:
					out.append("%s (choice '%s')" % [id, c.get("text", "")])
			else:
				stack.append([c_next, c_acted])
	return out


func test_every_once_only_story_talk_acts_on_every_branch() -> void:
	var bad: Array[String] = []
	for d in _all():
		if d.bark or not d.once or not _moves_story(d):
			continue
		for e in _silent_endings(d):
			bad.append("%s ends at %s with no event or flag" % [d.id, e])
	assert_eq(bad, [] as Array[String], "\n".join(bad))


func test_the_color_day_lift_is_offered_again_after_a_minute() -> void:
	var d := load(DIALOGUE_DIR + "marigold_color_day.tres") as Dialogue
	assert_false(d.once, "Give me a minute must leave the lift to ask for again")


func test_the_walk_finds_a_silent_branch() -> void:
	var d := Dialogue.new()
	d.id = &"t"
	d.once = true
	d.nodes = [
		{"id": "a", "text": "Go?", "choices": [
			{"text": "Yes", "next": "go"}, {"text": "Wait", "next": "wait"}]},
		{"id": "go", "text": "Off we go.", "event": "ride_lift"},
		{"id": "wait", "text": "Of course."},
	]
	assert_eq(_silent_endings(d), ["wait"] as Array[String])


func test_marigold_asks_again_in_the_owners_situation() -> void:
	# The owner's save (2026-11-08 14:58): Color Day, the talk already finished once on "Give
	# me a minute", so it is in `seen`. She must still offer the lift, not her bark.
	var lib := TalkLibrary.new()
	lib.load_all()
	lib.seen = {"marigold_color_day": true}
	var flags := {"invited": true, "color_day": true, "has_scoop": true, "depot_explained": true}
	var ctx := {"chapter": 1, "path": "", "flags": flags, "counts": {}, "name": "Juniper",
		"tumble": "Tumble"}
	var d := lib.pick(&"marigold", ctx)
	assert_not_null(d)
	assert_eq(d.id, &"marigold_color_day")


## P8, playtest 2026-11-08 item 16: on Color Day morning Bramble still said the Dye was flying
## off the shelf. The town has its own Color Day lines, and the cheerful ones are put away.
func test_on_color_day_the_town_says_its_color_day_lines() -> void:
	var lib := TalkLibrary.new()
	lib.load_all()
	var ctx := {"chapter": 1, "path": "", "counts": {}, "name": "Juniper", "tumble": "Tumble",
		"flags": {"invited": true, "color_day": true, "has_scoop": true}}
	for who: StringName in [&"bramble", &"fennel", &"pip"]:
		var d := lib.pick(who, ctx)
		assert_not_null(d)
		assert_eq(String(d.id), "%s_bark_colorday" % who)
