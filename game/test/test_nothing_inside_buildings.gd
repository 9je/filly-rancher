extends GutTest
## NOTHING STANDS INSIDE A BUILDING (PS4 item 29). The buildings grew two to almost three
## times so their doors fit a pony; everything placed by fixed coordinates round them -- the
## yard props, the townsponies' spots, the decorations, the signposts, the mailbox, Spike, the
## pen plots -- must still stand outside every model's footprint, and the buildings must keep
## clear of each other. Footprints are the worn models' own world boxes on the booted ranch.

const RanchScene := preload("res://world/ranch.tscn")
const PropsScript := preload("res://world/props.gd")
const PeopleScript := preload("res://world/people.gd")
const DecorScript := preload("res://systems/decor.gd")
const RanchScript := preload("res://world/ranch.gd")

## A building's box is a box round a roof's overhang; a thing may stand under the eave edge.
const EAVE := 0.4
## Two buildings this close read as one block.
const BETWEEN := 1.0

var _ranch: Node = null


func before_all() -> void:
	_ranch = RanchScene.instantiate()
	add_child(_ranch)
	await wait_for_signal(_ranch.gate_report_finished, 180.0)


func after_all() -> void:
	if _ranch != null:
		_ranch.free()
		_ranch = null


func _footprints() -> Dictionary:
	var out := {}
	for b: Node in _ranch.get_node(^"Buildings").get_children():
		var model := b.get_node_or_null(^"Model") as Node3D
		if model == null:
			continue
		var box: AABB = PropsScript.world_aabb(model)
		out[b.name] = Rect2(box.position.x, box.position.z, box.size.x, box.size.z)
	# The town row's houses are props (Props.LAYOUT), but they are buildings to a pony.
	for p: Node3D in _ranch.get("props").call("get_placed"):
		if String(p.name).begins_with("pv_"):
			var pb: AABB = PropsScript.world_aabb(p)
			out[p.name] = Rect2(pb.position.x, pb.position.z, pb.size.x, pb.size.z)
	return out


func _inside(p: Vector2, r: Rect2, margin: float) -> bool:
	return r.grow(-EAVE + margin).has_point(p)


func _spots() -> Dictionary:
	var s := {}
	for e: Dictionary in PropsScript.LAYOUT:
		if String(e.file).begins_with("pv_"):
			continue  # a town row house is itself one of the buildings
		s["prop %s at %s" % [e.file, str(e.at)]] = [e.at, 0.8]
	for who: StringName in PeopleScript.SPOTS:
		var h: Vector3 = PeopleScript.SPOTS[who][0]
		s["%s's spot" % who] = [Vector2(h.x, h.z), 0.8]
	for d: Dictionary in DecorScript.CATALOGUE:
		s["decor %s" % d.id] = [Vector2(d.at.x, d.at.z), float(d.get("clear", 1.5))]
	s["the signpost"] = [Vector2(RanchScript.SIGNPOST_AT.x, RanchScript.SIGNPOST_AT.z), 0.5]
	s["the yard sign"] = [Vector2(RanchScript.YARD_SIGN_AT.x, RanchScript.YARD_SIGN_AT.z), 0.5]
	s["Spike"] = [Vector2(RanchScript.SPIKE_AT.x, RanchScript.SPIKE_AT.z), 0.8]
	for slot: Node3D in _ranch.call("plot_slots"):
		s["plot %s" % slot.name] = [Vector2(slot.global_position.x, slot.global_position.z), 4.5]
	var mb := _ranch.get_node_or_null(^"Buildings/Mailbox") as Node3D
	if mb != null:
		s["the mailbox"] = [Vector2(mb.global_position.x, mb.global_position.z), 0.6]
	return s


func test_nothing_placed_by_coordinates_stands_inside_a_building() -> void:
	var feet := _footprints()
	assert_gt(feet.size(), 4)
	var bad: Array[String] = []
	var spots := _spots()
	for what: String in spots:
		var p: Vector2 = spots[what][0]
		var r: float = spots[what][1]
		for b: String in feet:
			if b == "Mailbox":
				continue
			if _inside(p, feet[b], r):
				bad.append("%s inside the %s" % [what, b])
	assert_true(bad.is_empty(), "got " + " | ".join(bad))


func test_the_buildings_keep_clear_of_each_other() -> void:
	var feet := _footprints()
	var names := feet.keys()
	var bad: Array[String] = []
	for i in names.size():
		for j in range(i + 1, names.size()):
			var a: Rect2 = feet[names[i]].grow(-EAVE)
			var b: Rect2 = feet[names[j]].grow(-EAVE)
			if a.grow(BETWEEN * 0.5).intersects(b.grow(BETWEEN * 0.5)):
				bad.append("%s and %s" % [names[i], names[j]])
	assert_true(bad.is_empty(), "got " + " | ".join(bad))


## AT THE DOOR IS AT THE BUILDING. The Market and the Depot opened within a radius of their
## CENTRES; grown, the Market's door stood 6.9 m from a 6 m radius and could not be opened.
## Standing a pace and a half in front of each door opens it; standing round the back does not.
func test_the_market_and_the_depot_open_from_their_doors() -> void:
	var player: Node3D = _ranch.get("player")
	for row in [["Market", "is_near_market"], ["Depot", "is_near_depot"]]:
		var b: Node3D = _ranch.get_node(NodePath("Buildings/" + String(row[0])))
		var out_dir: Vector3 = b.global_transform.basis.z
		var door: Vector3 = b.global_position + out_dir * (float(b.get("depth")) * 0.5)
		player.global_position = door + out_dir * 1.5
		assert_true(bool(_ranch.call(row[1])), "a pace and a half from the %s door opens it" % row[0])
		player.global_position = b.global_position - out_dir * (float(b.get("depth")) * 0.5 + 1.5)
		assert_false(bool(_ranch.call(row[1])), "round the back of the %s does not" % row[0])
