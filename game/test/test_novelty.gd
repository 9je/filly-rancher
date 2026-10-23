extends GutTest
## The novelty log and the pacing rules (game/systems/novelty.gd, MISSION.md fun rules).

const NoveltyScript := preload("res://systems/novelty.gd")


func _e(t: float, kind: String = "event", id: String = "") -> Dictionary:
	return {"t": t, "kind": kind, "id": id if id != "" else "x%d" % int(t), "label": "at %d" % int(t)}


func test_a_note_is_once_per_id() -> void:
	var n := NoveltyScript.new()
	assert_true(n.note(10.0, "pony", "race_earth", "First earth Drifter"))
	assert_false(n.note(20.0, "pony", "race_earth", "again"))
	assert_eq(n.entries.size(), 1)
	var back := NoveltyScript.from_array(n.to_array())
	assert_true(back.has("race_earth"))


func test_steady_cadence_passes() -> void:
	var list: Array = [_e(60.0, "clue")]
	var t := 60.0
	while t < 5400.0:
		t += 300.0
		list.append(_e(t))
	var a := NoveltyScript.analyse(list, t + 60.0)
	assert_true(a.ok, str(a.failures))


func test_an_early_gap_over_eight_minutes_fails() -> void:
	var list: Array = [_e(60.0, "clue"), _e(120.0), _e(120.0 + 9.0 * 60.0)]
	var a := NoveltyScript.analyse(list, 120.0 + 9.0 * 60.0 + 30.0)
	assert_false(a.ok)
	assert_true(str(a.failures).contains("early gap"))


func test_a_late_gap_may_run_to_fifteen() -> void:
	var list: Array = [_e(60.0, "clue")]
	var t := 60.0
	while t < 3600.0:
		t += 400.0
		list.append(_e(t))
	list.append(_e(t + 14.0 * 60.0))
	var a := NoveltyScript.analyse(list, t + 14.0 * 60.0 + 10.0)
	assert_true(a.ok, str(a.failures))


func test_the_end_of_the_run_counts_as_a_gap() -> void:
	var list: Array = [_e(60.0, "clue"), _e(200.0)]
	var a := NoveltyScript.analyse(list, 200.0 + 10.0 * 60.0)
	assert_false(a.ok, "nothing new for the last ten minutes is a failure")


func test_a_late_clue_fails() -> void:
	var list: Array = []
	var t := 0.0
	while t < 1800.0:
		t += 200.0
		list.append(_e(t, "story"))
	list.append(_e(1000.0, "clue", "late"))
	var a := NoveltyScript.analyse(list, t)
	assert_false(a.clue_ok)


func test_markdown_has_the_verdict_and_tables() -> void:
	var md := NoveltyScript.markdown([_e(30.0, "clue")], 200.0, {"seed": 7})
	assert_true(md.contains("Verdict: PASS"))
	assert_true(md.contains("| Time | Kind | What |"))
	assert_false(md.contains("—"))
