extends GutTest
## THE PLAYTEST LEDGER (PLAN.md PS0): docs/playtest-2026-11-05-ledger.md holds one row per item
## of the owner's 2026-11-05 playtest. Every number from 1 to 70 has a row, every row has a
## state, and no row is MET without evidence (the 2026-11-06 lesson: ticks from commit
## citations were wrong).

const LEDGER := "res://../docs/playtest-2026-11-05-ledger.md"
const STATES := ["OPEN", "FIXED-UNREVIEWED", "MET", "NOT-MET"]


## Each table row as {id, state, evidence}. Columns: item | owner's words | screenshot | task |
## state | evidence | commit | judged by.
func _rows() -> Array:
	var rows: Array = []
	var f := FileAccess.open(ProjectSettings.globalize_path(LEDGER), FileAccess.READ)
	if f == null:
		return rows
	for line in f.get_as_text().split("\n"):
		if not line.begins_with("| ") or line.begins_with("| Item") or line.begins_with("|---"):
			continue
		var cells := line.split("|")
		if cells.size() < 9:
			continue
		rows.append({
			"id": cells[1].strip_edges(),
			"state": cells[5].strip_edges(),
			"evidence": cells[6].strip_edges(),
		})
	return rows


func test_the_ledger_exists() -> void:
	assert_gt(_rows().size(), 0, "docs/playtest-2026-11-05-ledger.md has rows")


func test_every_item_from_1_to_70_has_a_row() -> void:
	var seen := {}
	for r: Dictionary in _rows():
		for part in str(r.id).split("/"):
			var digits := ""
			for ch in part:
				if ch >= "0" and ch <= "9":
					digits += ch
				else:
					break
			if digits != "":
				seen[int(digits)] = true
	for n in range(1, 71):
		assert_true(seen.has(n), "item %d has a ledger row" % n)


func test_every_row_has_a_known_state() -> void:
	for r: Dictionary in _rows():
		assert_true(STATES.has(r.state), "row %s has state '%s'" % [r.id, r.state])


func test_no_row_is_met_or_fixed_without_evidence() -> void:
	var ticked := 0
	for r: Dictionary in _rows():
		if r.state == "MET" or r.state == "FIXED-UNREVIEWED":
			ticked += 1
			assert_ne(r.evidence, "", "row %s is %s with no evidence" % [r.id, r.state])
	if ticked == 0:
		pass_test("no row ticked yet")
