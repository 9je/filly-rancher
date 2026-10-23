extends GutTest
## The regions' scenery (game/world/region_dressing.gd): every dressed region gets its props,
## from a fixed seed (the same valley on every machine), batched into MultiMeshes.

const DressingScript := preload("res://world/region_dressing.gd")


func _regions() -> Array:
	var reg = load("res://systems/region_registry.gd").new()
	reg.load_all()
	return reg.all()


func _count(d: Node) -> Dictionary:
	var out := {"batches": 0, "instances": 0, "colliders": 0}
	for c in d.get_children():
		if c is MultiMeshInstance3D:
			out.batches += 1
			out.instances += (c as MultiMeshInstance3D).multimesh.instance_count
		elif c is StaticBody3D:
			out.colliders += 1
	return out


func test_every_region_is_dressed_and_the_same_every_time() -> void:
	var a: Node3D = DressingScript.new()
	add_child_autofree(a)
	a.dress(_regions())
	var b: Node3D = DressingScript.new()
	add_child_autofree(b)
	b.dress(_regions())
	var ca := _count(a)
	var cb := _count(b)
	assert_gt(ca.instances, 600, "hundreds of plants, stones and trees: %s" % ca)
	assert_gt(ca.colliders, 50, "trunks and stones are solid")
	assert_eq(ca, cb, "a fixed seed: the same valley twice")
	assert_lt(ca.batches, 120, "batched: one draw per kind, not one per flower")
