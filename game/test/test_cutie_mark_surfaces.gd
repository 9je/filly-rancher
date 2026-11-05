extends GutTest
## A CUTIE MARK BELONGS ON HER FLANK, NOTHING ELSE. The Mane Six's exports bake the mark into
## the body's texture and hand that same material to other meshes (the folded wings, a
## "Circle"), which read it at their own UVs: slivers of the mark showed on Rainbow Dash's
## wing and the back of her rump (owner 2026-11-05: "Make sure this cutie mark bug doesn't
## happen anywhere"). ToonStyler gives every mesh but the body a plain coat in its place.

const IDS := ["fluttershy", "rainbowdash", "twilight", "rarity", "applejack", "pinkiepie"]


func _mark_textured(m: Material) -> bool:
	if m is ShaderMaterial:
		var t: Variant = (m as ShaderMaterial).get_shader_parameter(&"albedo_texture")
		var on: Variant = (m as ShaderMaterial).get_shader_parameter(&"use_texture")
		return t is Texture2D and bool(on) and ToonStyler.is_mark_texture(t)
	if m is StandardMaterial3D:
		return ToonStyler.is_mark_texture((m as StandardMaterial3D).albedo_texture)
	return false


func test_only_her_body_wears_the_mark() -> void:
	var was := ToonStyler.shading_enabled
	ToonStyler.shading_enabled = true
	for id: String in IDS:
		var body: Node3D = PonyVisuals.build(load("res://data/ponies/%s.tres" % id))
		add_child_autofree(body)
		ToonStyler.style(body, &"pony", {})
		var wearers: Array[String] = []
		for mi: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
			for i in mi.mesh.get_surface_count():
				if _mark_textured(mi.get_active_material(i)):
					wearers.append(String(mi.name))
		assert_lte(wearers.size(), 1, "%s: the mark on %s" % [id, wearers])
	ToonStyler.shading_enabled = was


func test_a_mark_texture_is_told_from_a_plain_one() -> void:
	var t := ImageTexture.new()
	t.resource_name = "CutieMark_baked"
	assert_true(ToonStyler.is_mark_texture(t))
	var plain := ImageTexture.new()
	plain.resource_name = "Hair_R"
	assert_false(ToonStyler.is_mark_texture(plain))
	assert_false(ToonStyler.is_mark_texture(null))


func test_on_her_body_the_mark_shows_only_on_her_flanks() -> void:
	# The export stretched the mark over the whole texture, so the back of Rainbow Dash's rump
	# (whose UVs land on the bolt) wore a red sliver. The body draws its texture only where it
	# faces her side.
	var was := ToonStyler.shading_enabled
	ToonStyler.shading_enabled = true
	var body: Node3D = PonyVisuals.build(load("res://data/ponies/rainbowdash.tres"))
	add_child_autofree(body)
	ToonStyler.style(body, &"pony", {})
	var found := false
	for mi: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var m := mi.get_active_material(i) as ShaderMaterial
			if m != null and _mark_textured(m):
				found = true
				assert_true(bool(m.get_shader_parameter(&"mark_sides_only")), "%s" % mi.name)
	assert_true(found, "her body still wears her mark")
	ToonStyler.shading_enabled = was


func test_a_folded_wing_leaves_her_mark_in_view() -> void:
	# As exported, the Mane Six pegasi's folded wings reached back over the whole flank and hid
	# the mark but for slivers around it. A folded wing is drawn smaller, kept at its root.
	for id: String in ["rainbowdash", "fluttershy", "twilight"]:
		var body: Node3D = PonyVisuals.build(load("res://data/ponies/%s.tres" % id))
		add_child_autofree(body)
		var wings := body.find_children("Base_Wings_Folded*", "MeshInstance3D", true, false)
		assert_false(wings.is_empty(), "%s has folded wings" % id)
		if wings.is_empty():
			continue
		var w: MeshInstance3D = wings[0]
		assert_almost_eq(w.transform.basis.get_scale().x, PonyVisuals.FOLDED_WING_SCALE, 0.001)
		var box := w.mesh.get_aabb()
		var root := Vector3(0.0, box.end.y, box.end.z)
		assert_almost_eq((w.transform * root).distance_to(root), 0.0, 0.0001, "pinned at its root")
