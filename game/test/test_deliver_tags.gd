extends GutTest
## PLAYTEST 2026-11-05 ITEM 63, in the owner's words: 'Duplicates and everyone tagged "one of
## a kind" in the Deliver list [51].'
##
## [51] shows two Sweetie Belles and two Scootaloos, each tagged "one of a kind: she asks
## before she goes". The duplicates themselves were the spawner's (items 39 and 70, see
## test_no_duplicate_ponies.gd); a save made before that fix still holds them, and nobody
## owned is ever deleted, so the list has to stay honest about them: "one of a kind" only on
## a pony who is, and a pony with a twin in the pens says so.

const DepotMenuScene := preload("res://ui/depot_menu.tscn")

var _menu: DepotMenu = null


func before_each() -> void:
	_menu = DepotMenuScene.instantiate()
	add_child_autofree(_menu)
	_menu.can_open = func() -> bool: return true
	_menu.bits_provider = func() -> int: return 0
	_menu.statement_provider = func() -> Array[String]: return []
	_menu.rows_provider = func() -> Array[Dictionary]:
		var rows: Array[Dictionary] = []
		rows.append({"uid": &"stock_shy#000001", "name": "Pony", "stock": true, "credit": 200,
			"kind": "stock_shy"})
		rows.append({"uid": &"sweetiebelle#000020", "name": "Sweetie Belle", "stock": false,
			"credit": 480, "kind": "sweetiebelle"})
		rows.append({"uid": &"sweetiebelle#000021", "name": "Sweetie Belle", "stock": false,
			"credit": 480, "kind": "sweetiebelle"})
		rows.append({"uid": &"rarity#000014", "name": "Rarity", "stock": false, "credit": 1200,
			"kind": "rarity"})
		return rows


## The tag under each pony's name, keyed by the name shown, in row order.
func _tags() -> Array:
	var out: Array = []
	for label: Label in _menu.find_children("*", "Label", true, false):
		var t := label.text
		if t.begins_with("one of a kind") or t.begins_with("from the crowd") \
				or t.contains("of her here"):
			out.append(t)
	return out


func test_only_a_pony_who_is_one_of_a_kind_is_tagged_so() -> void:
	assert_true(_menu.open())
	await wait_frames(1)
	var tags := _tags()
	assert_eq(tags.size(), 4, "a tag under each of the four: %s" % [tags])
	var one_of_a_kind := 0
	for t: String in tags:
		if t.begins_with("one of a kind"):
			one_of_a_kind += 1
	assert_eq(one_of_a_kind, 1, "Rarity is one of a kind; the two Sweetie Belles are not: %s" % [tags])
	var twins := 0
	for t: String in tags:
		if t.contains("two of her here"):
			twins += 1
	assert_eq(twins, 2, "each Sweetie Belle says she has a twin here: %s" % [tags])


func test_the_ranch_rows_carry_her_kind() -> void:
	# The Depot reads the kind off the rows the ranch hands it (Ranch._penned_rows()).
	var src := FileAccess.get_file_as_string("res://world/ranch.gd")
	var at := src.find("func _penned_rows()")
	assert_gt(at, -1)
	var body := src.substr(at, src.find("\nfunc ", at + 10) - at)
	assert_true(body.contains("\"kind\""), "each row says which character she is")
