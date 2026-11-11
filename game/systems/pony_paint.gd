class_name PonyPaint
extends RefCounted
## PUTS A PonyLook ON A DONOR BODY. One path for every pony in the game (the player, the
## Drifters, the townsfolk, the story cast): race by hiding horn and wing meshes, canon
## accessories hidden, every surface given a toon material by its role, the iris replaced,
## and the mark applied.
##
## Roles come from the donor table (game/data/donors.tres) for the mane and tail surfaces,
## whose names vary model to model, and from the fixed SFM vocabulary for everything else:
## body (coat, ears, hooves), wings, horn, eyebrow, eyelashes, eyeball_l/_r, teeth, tongue.
##
## Overrides only: the imported materials are never edited, so two ponies built from the
## same donor never share a color.

const ToonStylerScript := preload("res://systems/toon_styler.gd")
const PonyLookScript := preload("res://systems/pony_look.gd")
const DonorTableScript := preload("res://systems/donor_table.gd")
const CutieMarkScript := preload("res://systems/cutie_mark.gd")
const MarkComposerScript := preload("res://systems/mark_composer.gd")
const AccessoriesScript := preload("res://systems/accessories.gd")
const TOON := preload("res://shaders/toon.gdshader")
const EYE := preload("res://shaders/pony_eye.gdshader")
const HIDDEN := preload("res://shaders/hidden.gdshader")

enum Role { NONE, COAT, MANE, MANE2, TAIL, BROW, LASH, EYE, MOUTH, HIDE }

const COAT_NAMES: Array[String] = ["body", "wings", "horn"]
const FOAL_SCALE := 0.78
## How far a hair card's normal bends toward the hair's rounded mass (hair.gdshaderinc).
const HAIR_ROUND := 0.6

## Line weight per role, in pixels before ToonStyler.outline_scale. Faces get none: an
## outline round an eyeball reads as a monocle.
const OUTLINE_PX := {Role.COAT: 2.6, Role.MANE: 2.3, Role.MANE2: 2.3, Role.TAIL: 2.3}
## ToonStyler's pony preset, the one source of a pony's cel.
const PONY: Dictionary = ToonStylerScript.PRESETS[&"pony"]


## Role of material `name` on donor row `donor`.
static func role_of(name: String, donor: Dictionary) -> int:
	if name in (donor.get("hide", PackedStringArray()) as PackedStringArray):
		return Role.HIDE
	if name in (donor.get("mane2", PackedStringArray()) as PackedStringArray):
		return Role.MANE2
	if name in (donor.get("mane", PackedStringArray()) as PackedStringArray):
		return Role.MANE
	if name in (donor.get("tail", PackedStringArray()) as PackedStringArray):
		return Role.TAIL
	if name in COAT_NAMES:
		return Role.COAT
	match name:
		"eyebrow":
			return Role.BROW
		"eyelashes":
			return Role.LASH
		"eyeball_l", "eyeball_r":
			return Role.EYE
		"teeth", "tongue":
			return Role.MOUTH
	return Role.NONE


## Paint `body` (a donor instance) with `look`. Returns surfaces painted.
static func apply(body: Node3D, look: PonyLook) -> int:
	if body == null or look == null:
		return 0
	var donor: Dictionary = DonorTableScript.load_table().find(look.donor)
	var painted := 0
	for node: Node in body.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node
		if mi.mesh == null:
			continue
		# A COAT MARKING NEEDS HER REST POSE (PS7 item 6): the coat meshes wear a copy that
		# carries each vertex's rest position in CUSTOM0, so the toon shader's mask stays put
		# on her face and legs however the rig moves them.
		if look.marking != PonyLookScript.Marking.NONE and mi.mesh is ArrayMesh \
				and _has_coat(mi.mesh, donor):
			mi.mesh = rest_baked(mi.mesh as ArrayMesh)
		# Race: a whole mesh that is only horn (or only wings) is shown or hidden.
		var names: Array[String] = []
		for i in range(mi.mesh.get_surface_count()):
			var m: Material = mi.mesh.surface_get_material(i)
			names.append(m.resource_name if m != null else "")
		if names.size() == 1:
			if names[0] == "horn":
				mi.visible = look.race == &"unicorn"
				if mi.visible and mi.mesh is ArrayMesh and look.donor not in HORN_NATIVE:
					mi.mesh = long_horn(mi.mesh as ArrayMesh)
			elif names[0] == "wings":
				mi.visible = look.race == &"pegasus"
		# A mesh that is only hair shades as one rounded mass (P8 item 34; hair.gdshaderinc).
		var all_hair := not names.is_empty()
		for n: String in names:
			if not (role_of(n, donor) in [Role.MANE, Role.MANE2, Role.TAIL, Role.HIDE]):
				all_hair = false
		if all_hair:
			var mid := mi.get_aabb().get_center()
			mi.set_instance_shader_parameter(&"hair_center", Vector4(mid.x, mid.y, mid.z, HAIR_ROUND))
		for i in range(names.size()):
			var r: int = role_of(names[i], donor)
			if not ToonStylerScript.shading_enabled:
				continue
			if r == Role.HIDE:
				mi.set_surface_override_material(i, hidden_material())
				continue
			var src: Material = mi.mesh.surface_get_material(i)
			var mat: Material = _material_for(r, src, look, donor, names[i] in ["wings", "horn"])
			if mat != null:
				mi.set_surface_override_material(i, mat)
				painted += 1
	_apply_mark(body, look)
	var piece: Node3D = AccessoriesScript.wear(body, look.accessory)
	if piece != null and ToonStylerScript.shading_enabled:
		paint_piece(piece)
	return painted


## A worn piece in her own toon, each surface its model colour with her coat's outline: the
## props' style bleached a leather bag to cream beside her coat (render, 2026-11-07).
static func paint_piece(piece: Node3D) -> void:
	for node: Node in piece.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i) as BaseMaterial3D
			# The importer hands back the file's linear colour as sRGB; her toon takes it as made.
			var c: Color = src.albedo_color.srgb_to_linear() if src != null else Color.WHITE
			mi.set_surface_override_material(i, _toon(c, Role.COAT))


static var _baked: Dictionary = {}
static var _horns: Dictionary = {}

## P9 item 56 ("the horn shows in one shot and not another"): on the bodies whose forelock is
## thick (pokeypierce, the default unicorn, among them) the stock horn is shorter than the hair
## piled over the brow, so from most of the turntable it was buried. Every player and Drifter
## unicorn's horn is drawn this much longer from its base, so it clears any forelock. A canon
## unicorn wears her own model, never PonyPaint, so her look is untouched.
const HORN_LENGTH := 1.3
## Donors whose horn already stands clear of the hair (left exactly as modelled).
const HORN_NATIVE: Array[StringName] = []


## `mesh` (a horn on its own) stretched HORN_LENGTH times along its own axis, from its base:
## the axis runs from the mesh's middle to its highest point (the tip) in model space, where
## up is +Y. Bone weights are untouched, so it still rides the head. One copy per mesh.
static func long_horn(mesh: ArrayMesh) -> ArrayMesh:
	if mesh.has_meta(&"long_horn"):
		return mesh
	var key := mesh.get_instance_id()
	if _horns.has(key) and is_instance_valid(_horns[key]):
		return _horns[key]
	var all := PackedVector3Array()
	for si in mesh.get_surface_count():
		all.append_array(mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX])
	if all.is_empty():
		return mesh
	var mid := Vector3.ZERO
	var tip := all[0]
	for v in all:
		mid += v
		if v.y > tip.y:
			tip = v
	mid /= float(all.size())
	var axis := (tip - mid).normalized()
	if axis.is_zero_approx():
		return mesh
	var base := INF
	for v in all:
		base = minf(base, v.dot(axis))
	var out := ArrayMesh.new()
	for si in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(si)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in verts.size():
			var along := verts[i].dot(axis) - base
			verts[i] += axis * along * (HORN_LENGTH - 1.0)
		arrays[Mesh.ARRAY_VERTEX] = verts
		var flags: int = mesh.surface_get_format(si) & (Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS \
			| (7 << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT))
		out.add_surface_from_arrays(mesh.surface_get_primitive_type(si), arrays, [], {}, flags)
		out.surface_set_material(si, mesh.surface_get_material(si))
		out.surface_set_name(si, mesh.surface_get_name(si))
	out.resource_name = mesh.resource_name
	out.set_meta(&"long_horn", true)
	_horns[key] = out
	return out


static func _has_coat(mesh: Mesh, donor: Dictionary) -> bool:
	for i in mesh.get_surface_count():
		var m: Material = mesh.surface_get_material(i)
		if role_of(m.resource_name if m != null else "", donor) == Role.COAT:
			return true
	return false


## `mesh` with each vertex's own position copied into CUSTOM0 (RGBA float), every surface and
## material kept. One copy per donor mesh, shared: the marking itself is a shader parameter.
static func rest_baked(mesh: ArrayMesh) -> ArrayMesh:
	if mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_CUSTOM0 != 0:
		return mesh
	var key := mesh.get_instance_id()
	if _baked.has(key) and is_instance_valid(_baked[key]):
		return _baked[key]
	var out := ArrayMesh.new()
	for s in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var custom := PackedFloat32Array()
		custom.resize(verts.size() * 4)
		for i in verts.size():
			custom[i * 4] = verts[i].x
			custom[i * 4 + 1] = verts[i].y
			custom[i * 4 + 2] = verts[i].z
			custom[i * 4 + 3] = 1.0
		arrays[Mesh.ARRAY_CUSTOM0] = custom
		var flags: int = (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) \
			| (mesh.surface_get_format(s) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
		out.add_surface_from_arrays(mesh.surface_get_primitive_type(s), arrays, [], {}, flags)
		out.surface_set_material(s, mesh.surface_get_material(s))
		out.surface_set_name(s, mesh.surface_get_name(s))
	out.resource_name = mesh.resource_name
	if mesh.has_meta(&"long_horn"):
		out.set_meta(&"long_horn", true)
	_baked[key] = out
	return out


static var _hidden: ShaderMaterial


## The one shared material that hides a single surface.
static func hidden_material() -> ShaderMaterial:
	if _hidden == null:
		_hidden = ShaderMaterial.new()
		_hidden.shader = HIDDEN
	return _hidden


## The visuals node's scale for this look (foals are smaller). The caller applies it to the
## node that holds the body, so colliders and AI distances stay the caller's business.
static func body_scale(look: PonyLook) -> float:
	return FOAL_SCALE if look != null and look.foal else 1.0


## `bare_part`: a wing or a horn wears her coat but never her marking (P9 item 54: the freckles,
## masked by height and depth alone, spilled across a folded wing as white blobs).
static func _material_for(r: int, src: Material, look: PonyLook, donor: Dictionary,
		bare_part := false) -> Material:
	match r:
		Role.COAT:
			var coat := _toon(look.coat, r)
			if look.marking != PonyLookScript.Marking.NONE and not bare_part:
				coat.set_shader_parameter(&"marking", look.marking)
				coat.set_shader_parameter(&"marking_color", look.marking_color)
				var bare: Variant = coat.get_meta(ToonStylerScript.BARE_META, null)
				if bare is ShaderMaterial:
					(bare as ShaderMaterial).set_shader_parameter(&"marking", look.marking)
					(bare as ShaderMaterial).set_shader_parameter(&"marking_color", look.marking_color)
			return coat
		Role.MANE:
			return _toon(look.mane, r)
		Role.MANE2:
			return _toon(look.mane2, r)
		Role.TAIL:
			return _toon(look.tail, r)
		Role.BROW:
			return _toon(_darker(look.coat, 0.62), r)
		Role.LASH:
			return _toon(Color(0.08, 0.06, 0.1), r)
		Role.EYE:
			return _eye(src, look, donor)
		Role.MOUTH, Role.NONE:
			if src is StandardMaterial3D:
				return ToonStylerScript.to_toon(src as StandardMaterial3D,
					ToonStylerScript.PRESETS[&"flat"])
	return null


static func _toon(c: Color, r: int) -> ShaderMaterial:
	var m := _flat_toon(c, r)
	var px: float = float(OUTLINE_PX.get(r, 0.0)) * ToonStylerScript.outline_scale
	if px > 0.0:
		m.next_pass = ToonStylerScript.make_outline(c, null, px, 42.0)
		(m.next_pass as ShaderMaterial).set_shader_parameter(&"darken",
			float(PONY.get("line_value", 0.45)))
		# Her far-off twin, without the pass (ToonStyler.BARE_META).
		m.set_meta(ToonStylerScript.BARE_META, _flat_toon(c, r))
	return m


static func _flat_toon(c: Color, r: int) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = TOON
	m.set_shader_parameter(&"albedo", c)
	# The same cel as every other pony (ToonStyler's pony preset; Fable round 4 zoom: the
	# player and the crowd, painted here, kept the soft band, the stair-stepped self-shadow
	# and the faint line after the canon ponies had lost them).
	m.set_shader_parameter(&"shadow_fill", float(PONY.get("shadow_fill", 0.38)))
	m.set_shader_parameter(&"band_softness", float(PONY.get("band_softness", 0.035)))
	m.set_shader_parameter(&"cast_shadow", float(PONY.get("cast_shadow", 1.0)))
	m.set_shader_parameter(&"rim_strength", float(PONY.get("rim", 0.16)) if r == Role.COAT else 0.0)

	# A flat recolour by design (her look replaces the donor's own texture), so an audit
	# does not read the dropped donor texture as a lost one (test_input/pony_material_audit.gd).
	m.set_meta(&"recolored", true)
	return m


static func _eye(src: Material, look: PonyLook, donor: Dictionary) -> ShaderMaterial:
	var tex: Texture2D = null
	if src is StandardMaterial3D:
		tex = (src as StandardMaterial3D).albedo_texture
	var borrow: String = str(donor.get("eye_from", ""))
	if not borrow.is_empty() and src != null:
		var side := "r" if src.resource_name.ends_with("_r") else "l"
		var path := "res://assets/converted/ponies/%s_pupil_%s.png" % [borrow, side]
		if ResourceLoader.exists(path):
			tex = load(path)
	var m := ShaderMaterial.new()
	m.shader = EYE
	if tex != null:
		m.set_shader_parameter(&"eye_texture", tex)
	m.set_shader_parameter(&"iris", look.eyes)
	m.set_shader_parameter(&"lid_color", look.coat)
	# The same Source iris size the canon cast gets (ToonStyler.sfm_eye), so a Drifter's eyes
	# match the roster's instead of being all pupil.
	m.set_shader_parameter(&"iris_scale", ToonStylerScript.SFM_IRIS_SCALE)
	# HER EYE SHAPE (PS7 item 6): a sleepy eye rests with its lid partly down, an almond eye
	# has a lower lid too; the blink and the moods still draw over either.
	match look.eye_shape:
		PonyLookScript.EyeShape.SLEEPY:
			m.set_shader_parameter(&"rest_lid", 0.34)
		PonyLookScript.EyeShape.ALMOND:
			m.set_shader_parameter(&"rest_lid", 0.16)
			m.set_shader_parameter(&"lower_lid", 0.26)
	return m


static func _apply_mark(body: Node3D, look: PonyLook) -> void:
	var img: Image = null
	if not look.mark_png.is_empty():
		img = MarkComposerScript.image_from_png64(look.mark_png)
	elif not look.mark.is_empty():
		img = MarkComposerScript.compose(look.mark)
	CutieMarkScript.apply(body, img)


static func _darker(c: Color, k: float) -> Color:
	return Color(c.r * k, c.g * k, c.b * k, 1.0)


## Role of every visible painted surface on `body`, for tests: {material_name: role}.
static func survey(body: Node3D, look: PonyLook) -> Dictionary:
	var donor: Dictionary = DonorTableScript.load_table().find(look.donor)
	var out := {}
	for node: Node in body.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node
		if mi.mesh == null:
			continue
		for i in range(mi.mesh.get_surface_count()):
			var m: Material = mi.mesh.surface_get_material(i)
			if m != null:
				out[m.resource_name] = role_of(m.resource_name, donor)
	return out
