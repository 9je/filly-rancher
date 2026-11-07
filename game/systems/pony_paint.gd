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

## Line weight per role, in pixels before ToonStyler.outline_scale. Faces get none: an
## outline round an eyeball reads as a monocle.
const OUTLINE_PX := {Role.COAT: 1.8, Role.MANE: 1.6, Role.MANE2: 1.6, Role.TAIL: 1.6}


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
			elif names[0] == "wings":
				mi.visible = look.race == &"pegasus"
		for i in range(names.size()):
			var r: int = role_of(names[i], donor)
			if not ToonStylerScript.shading_enabled:
				continue
			if r == Role.HIDE:
				mi.set_surface_override_material(i, hidden_material())
				continue
			var src: Material = mi.mesh.surface_get_material(i)
			var mat: Material = _material_for(r, src, look, donor)
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


static func _material_for(r: int, src: Material, look: PonyLook, donor: Dictionary) -> Material:
	match r:
		Role.COAT:
			var coat := _toon(look.coat, r)
			if look.marking != PonyLookScript.Marking.NONE:
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
		# Her far-off twin, without the pass (ToonStyler.BARE_META).
		m.set_meta(ToonStylerScript.BARE_META, _flat_toon(c, r))
	return m


static func _flat_toon(c: Color, r: int) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = TOON
	m.set_shader_parameter(&"albedo", c)
	m.set_shader_parameter(&"shadow_fill", 0.38)
	m.set_shader_parameter(&"rim_strength", 0.16 if r == Role.COAT else 0.0)
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
