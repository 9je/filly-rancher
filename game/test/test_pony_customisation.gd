extends GutTest
## MORE CUSTOMISATION (PS7, playtest 2026-11-05 item 6: "More customisation"; owner-approved
## all three): coat markings (socks, a blaze, a star, dapples) in their own colour, eye shapes
## (round, almond, sleepy) and accessories. Each survives a save and a load, and each reaches
## the pony the game draws (PonyPaint, the one path the creator and the player both wear).

const PlayerLookScript := preload("res://systems/player_look.gd")
const PonyLookScript := preload("res://systems/pony_look.gd")
const PonyPaintScript := preload("res://systems/pony_paint.gd")
const PonyVisualsScript := preload("res://actors/pony/pony_visuals.gd")
const StockPaletteScript := preload("res://systems/stock_palette.gd")


func _round_trip(look: PlayerLook) -> PlayerLook:
	return PlayerLookScript.from_dict(JSON.parse_string(JSON.stringify(look.to_dict())))


func test_each_new_option_survives_a_save_and_a_load() -> void:
	var look: PlayerLook = PlayerLookScript.default_look()
	look.marking = PonyLookScript.Marking.BLAZE
	look.marking_colour = 2
	look.eye_shape = PonyLookScript.EyeShape.SLEEPY
	look.accessory = 3
	var back := _round_trip(look)
	assert_eq(back.marking, PonyLookScript.Marking.BLAZE)
	assert_eq(back.marking_colour, 2)
	assert_eq(back.eye_shape, PonyLookScript.EyeShape.SLEEPY)
	assert_eq(back.accessory, 3)


func test_an_old_save_has_none_of_them() -> void:
	var back: PlayerLook = PlayerLookScript.from_dict({"name": "Old", "coat": 1})
	assert_eq(back.marking, PonyLookScript.Marking.NONE)
	assert_eq(back.eye_shape, PonyLookScript.EyeShape.ROUND)
	assert_eq(back.accessory, -1)


func test_the_pony_look_carries_them_and_round_trips() -> void:
	var look: PlayerLook = PlayerLookScript.default_look()
	look.marking = PonyLookScript.Marking.SOCKS
	look.eye_shape = PonyLookScript.EyeShape.ALMOND
	look.accessory = 1
	var pl: PonyLook = look.to_pony_look(StockPaletteScript.load_player())
	assert_eq(pl.marking, PonyLookScript.Marking.SOCKS)
	assert_eq(pl.eye_shape, PonyLookScript.EyeShape.ALMOND)
	assert_eq(pl.accessory, 1)
	var copy: PonyLook = PonyLookScript.from_dict(pl.to_dict())
	assert_eq(copy.marking, PonyLookScript.Marking.SOCKS)
	assert_eq(copy.marking_color.to_html(false), pl.marking_color.to_html(false))


var _was_shading := true


## A shader parameter never set reads back as null; the shader's own default is 0 for these.
func _param(m: ShaderMaterial, key: StringName) -> float:
	var v: Variant = m.get_shader_parameter(key)
	return 0.0 if v == null else float(v)


func before_each() -> void:
	_was_shading = ToonStyler.shading_enabled
	ToonStyler.shading_enabled = true


func after_each() -> void:
	ToonStyler.shading_enabled = _was_shading


func _painted(pl: PonyLook) -> Node3D:
	var reg := preload("res://systems/pony_registry.gd").new()
	reg.load_all("res://data/ponies")
	var body: Node3D = PonyVisualsScript.build(reg.by_id(StockPaletteScript.IDS[0]), "")
	add_child_autofree(body)
	PonyPaintScript.apply(body, pl)
	return body


func test_a_marking_reaches_her_coat_with_her_rest_positions() -> void:
	var pl := PonyLookScript.new()
	pl.marking = PonyLookScript.Marking.SOCKS
	pl.marking_color = Color(0.98, 0.97, 0.94)
	var body := _painted(pl)
	var coats := 0
	for mi: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(i) as ShaderMaterial
			if m == null or int(_param(m, &"marking")) == 0:
				continue
			coats += 1
			assert_eq(int(_param(m, &"marking")), PonyLookScript.Marking.SOCKS)
			var fmt: int = (mi.mesh as ArrayMesh).surface_get_format(i)
			assert_true(fmt & Mesh.ARRAY_FORMAT_CUSTOM0 != 0, "%s carries her rest positions" % mi.name)
	assert_gte(coats, 3, "the body, the head and the legs")


func test_no_marking_leaves_the_coat_as_it_was() -> void:
	var body := _painted(PonyLookScript.new())
	for mi: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(i) as ShaderMaterial
			if m != null and m.shader != null and m.shader.resource_path.ends_with("toon.gdshader"):
				assert_eq(int(_param(m, &"marking")), 0)


func test_an_eye_shape_reaches_her_eyes() -> void:
	for shape: int in [PonyLookScript.EyeShape.ROUND, PonyLookScript.EyeShape.ALMOND, PonyLookScript.EyeShape.SLEEPY]:
		var pl := PonyLookScript.new()
		pl.eye_shape = shape
		var body := _painted(pl)
		var eyes := 0
		for mi: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
			for i in mi.mesh.get_surface_count():
				var m := mi.get_surface_override_material(i) as ShaderMaterial
				if m == null or m.shader == null or not m.shader.resource_path.ends_with("pony_eye.gdshader"):
					continue
				eyes += 1
				var rest: float = _param(m, &"rest_lid")
				var low: float = _param(m, &"lower_lid")
				match shape:
					PonyLookScript.EyeShape.ROUND:
						assert_eq(rest, 0.0)
						assert_eq(low, 0.0)
					PonyLookScript.EyeShape.ALMOND:
						assert_gt(low, 0.05, "an almond eye has a lower lid")
					PonyLookScript.EyeShape.SLEEPY:
						assert_gt(rest, 0.2, "a sleepy eye rests half shut")
		assert_eq(eyes, 2, "both eyes")


const AccessoriesScript := preload("res://systems/accessories.gd")


func _worn(body: Node3D) -> Node3D:
	var sk: Skeleton3D = body.find_children("*", "Skeleton3D", true, false)[0]
	var attach := sk.get_node_or_null(NodePath(AccessoriesScript.NODE_NAME)) as BoneAttachment3D
	return null if attach == null or attach.get_child_count() == 0 else attach.get_child(0)


func test_six_accessories_each_worn_on_its_bone_and_swapped_cleanly() -> void:
	assert_eq(AccessoriesScript.count(), 6)
	var pl := PonyLookScript.new()
	var body := _painted(pl)
	assert_null(_worn(body), "none by default")
	var sk: Skeleton3D = body.find_children("*", "Skeleton3D", true, false)[0]
	for i in AccessoriesScript.count():
		pl.accessory = i
		PonyPaintScript.apply(body, pl)
		var piece := _worn(body)
		assert_not_null(piece, "%s is worn" % AccessoriesScript.label(i))
		if piece == null:
			continue
		assert_eq(String(piece.name), String(AccessoriesScript.LIST[i].id))
		var attach := piece.get_parent() as BoneAttachment3D
		assert_eq(sk.get_bone_name(attach.bone_idx), String(AccessoriesScript.LIST[i].bone))
		var only_one := 0
		for c in sk.get_children():
			if c.name == AccessoriesScript.NODE_NAME:
				only_one += 1
		assert_eq(only_one, 1, "the last one was taken off")
	pl.accessory = -1
	PonyPaintScript.apply(body, pl)
	assert_null(_worn(body), "and -1 takes it off")


func test_a_piece_sits_where_its_list_says_on_her_rest_pose() -> void:
	var pl := PonyLookScript.new()
	pl.accessory = 0
	var body := _painted(pl)
	var piece := _worn(body)
	var sk: Skeleton3D = body.find_children("*", "Skeleton3D", true, false)[0]
	var bone := sk.find_bone(String(AccessoriesScript.LIST[0].bone))
	var at: Vector3 = (AccessoriesScript._relative(body, sk) * sk.get_bone_global_rest(bone) * piece.transform).origin
	assert_almost_eq(at.distance_to(AccessoriesScript.LIST[0].at as Vector3), 0.0, 0.01)
