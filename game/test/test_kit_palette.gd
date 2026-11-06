extends GutTest
## ONE PALETTE FOR THE KIT (FS2.3; gap list item 2: "the art reads as a kit-bash"). Every model
## family the valley places (world/props.gd), its source materials' mean albedo brightness
## (texture mean times colour) times ToonStyler's FAMILY_LIFT for it, sits inside the band:
## nothing painted near black beside the show's bright palette, nothing blown out.

const RanchScene := preload("res://world/ranch.tscn")
const ToonStylerScript := preload("res://systems/toon_styler.gd")

var _tex_mean := {}


func _mean_of(t: Texture2D) -> Color:
	var key := t.get_rid().get_id()
	if not _tex_mean.has(key):
		var img := t.get_image()
		var acc := Vector3.ONE
		if img != null:
			if img.is_compressed():
				img.decompress()
			img.resize(16, 16, Image.INTERPOLATE_BILINEAR)
			acc = Vector3.ZERO
			for y in 16:
				for x in 16:
					var p := img.get_pixel(x, y)
					acc += Vector3(p.r, p.g, p.b) / 256.0
		_tex_mean[key] = Color(acc.x, acc.y, acc.z)
	return _tex_mean[key]


func test_every_placed_family_sits_in_the_kit_band() -> void:
	var ranch = RanchScene.instantiate()
	add_child_autofree(ranch)
	await wait_physics_frames(2)
	var fam := {}
	for inst: Node in ranch.get_node(^"Props").get_children():
		if inst.scene_file_path == "":
			continue
		var family := inst.scene_file_path.get_file()
		for n in inst.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			if mi.mesh == null:
				continue
			for i in mi.mesh.get_surface_count():
				var m := mi.mesh.surface_get_material(i) as StandardMaterial3D
				if m == null:
					continue
				var c := m.albedo_color
				if m.albedo_texture != null:
					c = c * _mean_of(m.albedo_texture)
				if not fam.has(family):
					fam[family] = [0.0, 0]
				fam[family][0] += c.v
				fam[family][1] += 1
	assert_gt(fam.size(), 15, "the valley's families were found")
	for family: String in fam:
		var v: float = fam[family][0] / float(fam[family][1]) * ToonStylerScript.lift_for(family)
		assert_between(v, ToonStylerScript.KIT_VALUE_MIN, ToonStylerScript.KIT_VALUE_MAX,
			"%s: mean brightness %.2f (lift %.2f)" % [family, v, ToonStylerScript.lift_for(family)])


func test_a_lift_reaches_the_material_it_makes() -> void:
	ToonStylerScript.shading_enabled = true
	var mi := MeshInstance3D.new()
	mi.mesh = BoxMesh.new()
	var src := StandardMaterial3D.new()
	src.albedo_color = Color(0.2, 0.1, 0.1)
	mi.mesh.surface_set_material(0, src)
	add_child_autofree(mi)
	ToonStylerScript.style(mi, &"prop", {}, 2.0)
	var out := mi.get_surface_override_material(0) as ShaderMaterial
	var c: Color = out.get_shader_parameter(&"albedo")
	assert_almost_eq(c.r, 0.4, 0.001)
	var bare: Variant = out.get_meta(ToonStylerScript.BARE_META, null)
	if bare is ShaderMaterial:
		assert_almost_eq((bare.get_shader_parameter(&"albedo") as Color).r, 0.4, 0.001,
			"the far twin too")
	ToonStylerScript.shading_enabled = DisplayServer.get_name() != "headless"
	assert_almost_eq(ToonStylerScript.lift_for("saa_tree_dead_wide.glb"), 1.6, 0.001)
	assert_almost_eq(ToonStylerScript.lift_for("saa_tree_wide.glb"), 1.0, 0.001)
