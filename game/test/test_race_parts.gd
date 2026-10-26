extends GutTest
## THE RACE YOU READ IS THE RACE YOU SEE. A stock pony's catch card said "Unicorn" while
## her body still wore wings: PonyPaint hid a wing (or horn) only when it was a whole mesh
## of exactly one surface named "wings" (or "horn"). Every donor, in every race it can wear:
## no wing is drawn on a pony who is not a pegasus, no horn on one who is not a unicorn.

const DonorTableScript := preload("res://systems/donor_table.gd")
const PonyPaintScript := preload("res://systems/pony_paint.gd")


## Surfaces of `body` that are drawn and whose material is a wing (or horn) part.
func _drawn_parts(body: Node3D, part: String) -> Array[String]:
	var out: Array[String] = []
	for node: Node in body.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		for i in range(mi.mesh.get_surface_count()):
			var m: Material = mi.mesh.surface_get_material(i)
			var nm := m.resource_name.to_lower() if m != null else ""
			if part not in nm:
				continue
			if mi.get_surface_override_material(i) == PonyPaintScript.hidden_material():
				continue
			out.append("%s/%s" % [mi.name, nm])
	return out


func test_no_donor_shows_parts_its_race_lacks() -> void:
	var table := DonorTableScript.load_table()
	var wrong: Array[String] = []
	for id: StringName in table.ids():
		var scene: PackedScene = load(DonorTableScript.model_path(id))
		if scene == null:
			continue
		var native := StringName(table.find(id).get("race", "earth"))
		var races: Array[StringName] = [&"earth"]
		if native != &"earth":
			races.append(native)
		for race: StringName in races:
			var body: Node3D = scene.instantiate()
			add_child(body)
			var look := PonyLook.new()
			look.donor = id
			look.race = race
			PonyPaintScript.apply(body, look)
			if race != &"pegasus":
				for s in _drawn_parts(body, "wing"):
					wrong.append("%s as %s shows %s" % [id, race, s])
			if race != &"unicorn":
				for s in _drawn_parts(body, "horn"):
					wrong.append("%s as %s shows %s" % [id, race, s])
			body.free()
	assert_eq(wrong, [] as Array[String], "\n".join(wrong))


func test_a_pegasus_keeps_her_wings_and_a_unicorn_her_horn() -> void:
	var table := DonorTableScript.load_table()
	for pair: Array in [[&"pegasus", "wing"], [&"unicorn", "horn"]]:
		var ids: Array[StringName] = table.for_race(pair[0])
		assert_gt(ids.size(), 0)
		for id: StringName in ids:
			var body: Node3D = (load(DonorTableScript.model_path(id)) as PackedScene).instantiate()
			add_child(body)
			var look := PonyLook.new()
			look.donor = id
			look.race = pair[0]
			PonyPaintScript.apply(body, look)
			assert_gt(_drawn_parts(body, pair[1]).size(), 0, "%s lost her %s" % [id, pair[1]])
			body.free()
