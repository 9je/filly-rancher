extends GutTest
## THE GROUND WITH LIFE, FINISHED (PS10, known gap G2; FS2.2: "the ground's fine painted grain,
## darker grass at prop and fence bases"). After the ranch stands, the terrain holds a contact
## mask painted from every solid thing's footprint: dark under a fence post and round a tree or
## a stone, clear in open meadow; the ground shader darkens the grass by it, and carries a
## brushed grain finer than its 0.9 m noise.

const RanchScene := preload("res://world/ranch.tscn")


func test_the_grass_darkens_at_a_fence_base_and_not_in_the_open() -> void:
	var ranch = RanchScene.instantiate()
	add_child_autofree(ranch)
	await wait_frames(4)
	var terrain: Node = ranch.terrain
	var fences: Array = ranch.call("get_region_fences")
	assert_false(fences.is_empty(), "the ranch has its region fences")
	var post: Node3D = null
	for f: Node in fences:
		for body: Node in f.find_children("*", "StaticBody3D", true, false):
			post = body as Node3D
			break
		if post != null:
			break
	var shape: CollisionShape3D = post.find_children("*", "CollisionShape3D", true, false)[0]
	var at: Vector3 = shape.global_position
	assert_gt(float(terrain.call("contact_at", at.x, at.z)), 0.5, "dark under a fence base")
	# Most of the valley is open grass: the mask's mean stays low.
	assert_lt(float(terrain.call("contact_mean")), 0.12, "most ground is open")
	var mat: ShaderMaterial = terrain.call("ground_material")
	assert_not_null(mat.get_shader_parameter(&"contact_mask"), "the shader has the mask")
	assert_gt(float(mat.get_shader_parameter(&"contact_dark")), 0.15, "and darkens by it")
	assert_gt(float(mat.get_shader_parameter(&"grain_amount")), 0.0, "a brushed grain")


func test_the_shader_reads_the_mask_and_the_grain() -> void:
	var src := FileAccess.get_file_as_string("res://world/terrain.gdshader")
	assert_true(src.contains("contact_mask"), "samples the contact mask")
	assert_true(src.contains("grain_amount"), "draws the grain")
