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


## THE PACED DRESSING IS THE SAME VALLEY (docs/playtest_fixes/loading.md). Behind the loading
## screen the ranch dresses the regions a step at a time, with a dry run first to warm the
## models; the dry run must not move the seed, so every batch holds the same transforms.
func test_the_paced_dressing_builds_the_same_valley() -> void:
	var plain: Node3D = DressingScript.new()
	add_child_autofree(plain)
	plain.dress(_regions())
	var paced: Node3D = DressingScript.new()
	add_child_autofree(paced)
	var steps := [0]
	await paced.dress_paced(_regions(), func(_done: int, _total: int) -> void: steps[0] += 1)
	assert_gt(steps[0], 10, "it stepped")
	assert_eq(_count(paced), _count(plain), "the same counts")
	assert_eq(_transforms(paced), _transforms(plain), "the same placements")


func _transforms(d: Node) -> Dictionary:
	var out := {}
	for c in d.get_children():
		if c is MultiMeshInstance3D:
			var mm := (c as MultiMeshInstance3D).multimesh
			var key := "%s/%d" % [c.name.rstrip("0123456789"), mm.instance_count]
			var sum := Vector3.ZERO
			for i in mm.instance_count:
				sum += mm.get_instance_transform(i).origin
			out[key] = out.get(key, Vector3.ZERO) + sum
		elif c is StaticBody3D:
			out["colliders"] = out.get("colliders", Vector3.ZERO) + (c as StaticBody3D).global_position
	return out
