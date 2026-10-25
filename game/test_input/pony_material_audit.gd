extends RefCounted
## WHAT "A BROKEN PONY MATERIAL" MEANS, written down once (playtest note "bad textures on some
## pony models and weird eyes on others", docs/playtest_fixes/ponies.md). Read-only: it looks
## at what every MeshInstance3D under an actor is drawing RIGHT NOW (its active material, which
## is the far-tier twin when she is far off) and names every surface that is wrong:
##
##   * a toon or outline pass with use_texture on and no albedo_texture
##   * an eye shader with no eye_texture
##   * a texture that failed to load (null image size) or is the converter's placeholder for
##     a texture it could not find (SourceIO writes `<id>_missing_white.png`): a placeholder
##     is a missing texture that happens to have pixels in it
##   * a surface whose IMPORTED material carried a texture the active material dropped
##     (a twin or a recolour built without the albedo texture renders a pony untextured)
##   * a StandardMaterial3D that expects a texture (its imported twin had one) and has none
##   * an eye surface (eyeball, iris, Base_Eyes...) with no material at all
##   * a visible mesh with no surfaces left (its geometry was lost after import)
##   * a material's outline-free twin (ToonStyler.BARE_META) that has lost the texture
##
## Each problem is one line: "<actor> <mesh>#<surface> <material>: <what>".

const ToonStylerScript := preload("res://systems/toon_styler.gd")
const TOON := preload("res://shaders/toon.gdshader")
const OUTLINE := preload("res://shaders/outline.gdshader")
const EYE := preload("res://shaders/pony_eye.gdshader")

const EYE_WORDS: Array[String] = ["eyeball", "iris", "pupil", "sclera", "base_eyes"]
const PLACEHOLDER_WORDS: Array[String] = ["missing_white", "missing_black", "_missing"]


## Every problem on `actor`, labelled `label`.
static func audit(actor: Node, label: String) -> PackedStringArray:
	var out := PackedStringArray()
	if actor == null:
		return out
	var meshes: Array[Node] = actor.find_children("*", "MeshInstance3D", true, false)
	if actor is MeshInstance3D:
		meshes.append(actor)
	for node in meshes:
		var mi := node as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		if mi.mesh.get_surface_count() == 0:
			# Geometry lost on the way in (PonyLod once rebuilt Applejack's body as this).
			out.append("%s %s: visible mesh with no surfaces (her geometry was lost)" % [label, mi.name])
			continue
		for s in mi.mesh.get_surface_count():
			var src: Material = mi.mesh.surface_get_material(s)
			var active: Material = mi.get_active_material(s)
			var where := "%s %s#%d %s" % [label, mi.name, s, src.resource_name if src != null else "<none>"]
			if active == null:
				if _is_eye_name(src.resource_name if src != null else String(mi.name)):
					out.append(where + ": eye surface has no material")
				else:
					out.append(where + ": no material")
				continue
			if active is ShaderMaterial and (active as ShaderMaterial).shader == preload("res://shaders/hidden.gdshader"):
				continue
			var src_tex: Texture2D = (src as StandardMaterial3D).albedo_texture if src is StandardMaterial3D else null
			var src_real := src_tex != null and _texture_problem(src_tex) == ""
			_check(active, where, src_real, out, 0)
	return out


## The whole chain: the material, its next_pass(es) and its far-off twin.
static func _check(m: Material, where: String, src_real: bool, out: PackedStringArray, depth: int) -> void:
	if m == null or depth > 4:
		return
	var tag := where if depth == 0 else where + " (pass %d)" % depth
	if m is ShaderMaterial:
		var sm := m as ShaderMaterial
		if sm.shader == TOON or sm.shader == OUTLINE:
			var use: bool = sm.get_shader_parameter(&"use_texture") == true
			var tex := sm.get_shader_parameter(&"albedo_texture") as Texture2D
			if use and tex == null:
				out.append(tag + ": use_texture on but no albedo_texture")
			elif tex != null and _texture_problem(tex) != "":
				out.append(tag + ": " + _texture_problem(tex))
			elif src_real and not use and sm.shader == TOON and not bool(sm.get_meta(&"recolored", false)):
				out.append(tag + ": the imported material had a texture this one dropped")
		elif sm.shader == EYE:
			var et := sm.get_shader_parameter(&"eye_texture") as Texture2D
			if et == null:
				out.append(tag + ": eye shader with no eye_texture")
			elif _texture_problem(et) != "":
				out.append(tag + ": " + _texture_problem(et))
	elif m is BaseMaterial3D:
		var bm := m as BaseMaterial3D
		if bm.albedo_texture != null and _texture_problem(bm.albedo_texture) != "":
			out.append(tag + ": " + _texture_problem(bm.albedo_texture))
		elif bm.albedo_texture == null and src_real:
			out.append(tag + ": StandardMaterial3D expects a texture and has none")
	if m.next_pass != null:
		_check(m.next_pass, where, false, out, depth + 1)
	var bare: Material = m.get_meta(ToonStylerScript.BARE_META, null)
	if bare != null:
		_check(bare, where + " [far twin]", src_real, out, depth + 1)
		# A twin must draw what its original draws: the same texture, or none on both.
		if m is ShaderMaterial and bare is ShaderMaterial:
			var a: Variant = (m as ShaderMaterial).get_shader_parameter(&"albedo_texture")
			var b: Variant = (bare as ShaderMaterial).get_shader_parameter(&"albedo_texture")
			if a != b:
				out.append(where + " [far twin]: twin's albedo_texture differs from the original's")


## "" for a usable texture, else what is wrong with it.
static func _texture_problem(t: Texture2D) -> String:
	if t == null:
		return "null texture"
	var path := t.resource_path.to_lower()
	for w in PLACEHOLDER_WORDS:
		if w in path or w in t.resource_name.to_lower():
			return "placeholder texture '%s' (the converter could not find the real one)" % t.resource_path.get_file()
	if t.get_width() <= 0 or t.get_height() <= 0:
		return "texture '%s' failed to load (0 x 0)" % t.resource_path
	return ""


static func _is_eye_name(n: String) -> bool:
	var l := n.to_lower()
	for w in EYE_WORDS:
		if w in l:
			return true
	return false
