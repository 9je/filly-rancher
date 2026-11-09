class_name ToonStyler
extends RefCounted
## CONVERTS ANYTHING IMPORTED INTO THE SHOW'S LOOK. Every mesh in the game comes from
## somewhere else (SFM pony ports, PonySFM prop ports, Kenney packs, our own Blender
## scripts) with its own PBR material, and those materials are why the owner's
## 2026-09-04 playtest read the world as clashing. This walks a node tree and swaps every
## StandardMaterial3D for the one toon light model (game/shaders/toon.gdshader), keeping
## the albedo color and texture and dropping everything PBR.
##
## Materials are shared through a cache keyed by the source material, so fifty fence posts
## that shared one imported material still share one converted material and still batch.
## Ponies pass their own cache (or none) because each pony's colors are her own.
##
## Overrides, never edits: the imported resource is left untouched.

const TOON := preload("res://shaders/toon.gdshader")
const OUTLINE := preload("res://shaders/outline.gdshader")

## Per-category defaults. `outline_px` 0 means no outline pass at all.
const PRESETS := {
	&"pony": {"outline_px": 1.7, "rim": 0.18, "shadow_fill": 0.36, "fade_end": 42.0},
	&"prop": {"outline_px": 1.1, "rim": 0.0, "shadow_fill": 0.34, "fade_end": 60.0},
	&"building": {"outline_px": 1.3, "rim": 0.0, "shadow_fill": 0.34, "fade_end": 90.0},
	&"foliage": {"outline_px": 0.9, "rim": 0.0, "shadow_fill": 0.42, "fade_end": 50.0},
	&"flat": {"outline_px": 0.0, "rim": 0.0, "shadow_fill": 0.38, "fade_end": 0.0},
}

## ONE PALETTE FOR THE KIT (FS2.3; gap list item 2, "the art reads as a kit-bash"). Measured
## 2026-11-06 (test/test_kit_palette.gd): a few families are painted far darker than the rest
## of the valley, mean brightness 0.15 to 0.33 against 0.4 to 0.9 for the rest, and read as
## black blobs under the toon shadow. Each is lifted (albedo times this) into the band, by
## file name prefix, longest first.
const FAMILY_LIFT := {
	"saa_corn_plant": 2.6, "saa_dead_tree_large": 2.2, "saa_tree_dead": 1.6,
	"school_swingframe": 2.3, "school_picnic_table": 1.4, "mlp_apple_tree_bare": 1.35,
	"mlp_bush": 1.25,
}
## The band every family's lifted mean albedo brightness must sit in.
const KIT_VALUE_MIN := 0.36
const KIT_VALUE_MAX := 0.95


## The lift for a model file (or its basename), 1.0 for most.
static func lift_for(file: String) -> float:
	var f := file.get_file().to_lower()
	var best := ""
	for k: String in FAMILY_LIFT:
		if f.begins_with(k) and k.length() > best.length():
			best = k
	return float(FAMILY_LIFT[best]) if best != "" else 1.0


## Outline width is multiplied by this; the graphics settings set it (0 disables lines).
static var outline_scale: float = 1.0

## FALSE UNDER THE HEADLESS DUMMY RENDERER, which cannot host a ShaderMaterial on a skinned
## body that is built and freed within a frame or two (it logs "material is null" from its
## material storage, measured on Godot 4.7.2; the Forward+ renderer is fine). Headless runs
## are logic runs: every non-visual step (race parts, hidden accessories, marks) still
## happens, only the shader swap is skipped. Tests that check the materials themselves set
## this true for their own scope.
static var shading_enabled: bool = DisplayServer.get_name() != "headless"

static var _shared: Dictionary = {}


## Style every surface under `root`. Returns the number of surfaces converted.
## `category` picks a preset; `cache` is the material cache to use (pass {} for a private
## one, or omit for the process-wide shared cache).
## `lift` brightens the albedo (FAMILY_LIFT); left below zero it is the model's own, from the
## scene file `root` was instanced from, so no caller can miss it (the bought decorations did).
static func style(root: Node, category: StringName = &"prop", cache: Variant = null,
		lift: float = -1.0) -> int:
	if root == null or not shading_enabled:
		return 0
	if lift < 0.0:
		lift = lift_for(root.scene_file_path) if root.scene_file_path != "" else 1.0
	var store: Dictionary = _shared if cache == null else cache
	var preset: Dictionary = PRESETS.get(category, PRESETS[&"prop"])
	var touched := 0
	var meshes: Array[Node] = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		meshes.append(root)
	var mark_body := _mark_body(meshes) if category == &"pony" else null
	for node: Node in meshes:
		var mi: MeshInstance3D = node
		if mi.mesh == null:
			continue
		for i in range(mi.mesh.get_surface_count()):
			var src: Material = mi.get_active_material(i)
			if src is StandardMaterial3D:
				var key := "%d:%s" % [src.get_instance_id(), category]
				if lift != 1.0:
					key += ":lift%.2f" % lift
				# The mark is her body's; a wing or a "Circle" handed the body's material gets
				# its plain coat (see is_mark_texture).
				if mark_body != null and mi != mark_body \
						and is_mark_texture((src as StandardMaterial3D).albedo_texture):
					key += ":plain"
					if not store.has(key):
						store[key] = to_toon(_plain_coat(src as StandardMaterial3D), preset)
						# Its texture dropped ON PURPOSE (the mark is the body's alone), which
						# the material audit (test_input/pony_material_audit.gd) is told.
						(store[key] as Material).set_meta(&"plain_coat", true)
						var twin: Variant = (store[key] as Material).get_meta(BARE_META, null)
						if twin is Material:
							(twin as Material).set_meta(&"plain_coat", true)
				elif mark_body != null and mi == mark_body \
						and is_mark_texture((src as StandardMaterial3D).albedo_texture):
					key += ":mark"
					if not store.has(key):
						var body_mat := to_toon(src as StandardMaterial3D, preset)
						body_mat.set_shader_parameter(&"mark_sides_only", true)
						body_mat.set_shader_parameter(&"mark_coat", _plain_coat(src as StandardMaterial3D).albedo_color)
						store[key] = body_mat
				var out: ShaderMaterial = store.get(key)
				if out == null and category == &"pony" and src.resource_name.begins_with("eyeball") \
						and (src as StandardMaterial3D).albedo_texture != null:
					out = sfm_eye((src as StandardMaterial3D).albedo_texture)
					store[key] = out
				if out == null and category == &"pony" and is_face_line(src as StandardMaterial3D):
					out = _face_line(src.resource_name, root)
					store[key] = out
				if out == null and category == &"pony" \
						and is_placeholder((src as StandardMaterial3D).albedo_texture):
					out = to_toon(_with_sibling_texture(src as StandardMaterial3D, root), preset)
					store[key] = out
				var ao: Texture2D = baked_ao(mi) if category != &"pony" else null
				if out == null and ao != null:
					key += ":ao"
					out = store.get(key)
				if out == null:
					out = to_toon(src as StandardMaterial3D, preset)
					if lift != 1.0:
						_lift(out, lift)
					if ao != null:
						_wear_ao(out, ao)
					store[key] = out
				mi.set_surface_override_material(i, out)
				touched += 1
	return touched


## THE MODEL'S BAKED AMBIENT OCCLUSION (P8; tools/blender_props/bake_ao.py): <model>_ao.png
## beside the nearest .glb this mesh came out of, or null. Read once per model and remembered.
static var _ao_maps := {}


## Off only for a before-and-after render (look_world.gd --no-ao).
static var ao_enabled := true


static func baked_ao(mi: Node) -> Texture2D:
	if not ao_enabled:
		return null
	var n: Node = mi
	while n != null and not n.scene_file_path.ends_with(".glb"):
		n = n.get_parent()
	if n == null:
		return null
	var path := n.scene_file_path.get_basename() + "_ao.png"
	if not _ao_maps.has(path):
		_ao_maps[path] = load(path) if ResourceLoader.exists(path) else null
	return _ao_maps[path]


static func _wear_ao(m: ShaderMaterial, ao: Texture2D) -> void:
	for each: Variant in [m, m.get_meta(BARE_META, null)]:
		if each is ShaderMaterial:
			(each as ShaderMaterial).set_shader_parameter(&"use_ao", true)
			(each as ShaderMaterial).set_shader_parameter(&"ao_texture", ao)


## A TEXTURE WITH HER CUTIE MARK BAKED IN (the Mane Six's exports: CutieMark_baked). Those
## exports hand the body's material to other meshes too (the folded wings, a "Circle"), which
## read the texture at their own UVs and wore slivers of the mark (owner 2026-11-05, Rainbow
## Dash's wing: "Make sure this cutie mark bug doesn't happen anywhere").
static func is_mark_texture(tex: Texture2D) -> bool:
	if tex == null:
		return false
	var p := (tex.resource_path + " " + tex.resource_name).to_lower().replace("_", "")
	return p.contains("cutiemark")


## Of `meshes`, the one that wears a mark texture over the most vertices: her body.
static func _mark_body(meshes: Array[Node]) -> MeshInstance3D:
	var best: MeshInstance3D = null
	var most := 0
	for node: Node in meshes:
		var mi := node as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var m := mi.get_active_material(i) as StandardMaterial3D
			if m != null and is_mark_texture(m.albedo_texture):
				var n: int = mi.mesh.surface_get_array_len(i)
				if n > most:
					most = n
					best = mi
	return best


## `src` without its texture, in the coat colour that texture is mostly painted.
static func _plain_coat(src: StandardMaterial3D) -> StandardMaterial3D:
	var out := src.duplicate() as StandardMaterial3D
	var tex := src.albedo_texture
	var key := tex.get_rid().get_id()
	if not _coat_cache.has(key):
		_coat_cache[key] = _dominant(tex, src.albedo_color)
	out.albedo_texture = null
	out.albedo_color = _coat_cache[key]
	return out


## THE CONVERTER'S MISSING-TEXTURE PLACEHOLDER (playtest note "weird eyes", 2026-10-24,
## docs/playtest_fixes/ponies.md). Every ReVAmped pony's eyebrow and eyelashes VMT is
## `$basetexture vgui/white` tinted by `$color2 {0 0 0}`; vgui/white is an engine texture no
## pony pack ships, so SourceIO wrote its magenta-and-black "missing" checker in its place
## (`<id>_missing_white.png`), and tools/sfm_rig.py wired that straight into the base colour.
## Thirty-seven canon ponies wore purple checkered brows and lashes. A placeholder is never
## drawn: the surface gets the flat colour Source meant instead (_face_line).
static func is_placeholder(tex: Texture2D) -> bool:
	if tex == null:
		return false
	var p := (tex.resource_path + " " + tex.resource_name).to_lower()
	return p.contains("_missing_") or p.contains("missing_white") or p.contains("missing_black")


## An SFM eyebrow or eyelashes surface that has no real colour of its own: the placeholder
## checker (a conversion from before tools/sfm_rig.py learned to drop it), or the flat black
## that conversion ships now. Either way the line is drawn by _face_line, so an old and a new
## conversion of one pony look the same.
static func is_face_line(src: StandardMaterial3D) -> bool:
	var n := src.resource_name.get_slice(".", 0).to_lower()
	if n != "eyebrow" and n != "eyelashes":
		return false
	if is_placeholder(src.albedo_texture):
		return true
	var c := src.albedo_color
	return src.albedo_texture == null and maxf(c.r, maxf(c.g, c.b)) < 0.02


## Lash and brow colours, the same ones PonyPaint gives a Drifter: lashes near black (Source's
## own $color2 {0 0 0}), brows her coat darkened, the way the show draws a brow line.
const LASH_COLOR := Color(0.08, 0.06, 0.1)
const BROW_DARKEN := 0.62


static func _face_line(name: String, root: Node) -> ShaderMaterial:
	var c := LASH_COLOR
	if name.to_lower().begins_with("eyebrow"):
		var coat := coat_color(root)
		c = Color(coat.r * BROW_DARKEN, coat.g * BROW_DARKEN, coat.b * BROW_DARKEN, 1.0)
	var m := ShaderMaterial.new()
	m.shader = TOON
	m.resource_name = name
	m.set_shader_parameter(&"albedo", c)
	m.set_shader_parameter(&"use_texture", false)
	m.set_shader_parameter(&"shadow_fill", 0.38)
	m.set_meta(&"recolored", true)
	return m


## A copy of `src` wearing the real texture of its nearest sibling instead of the placeholder.
## Marble Pie's VMT asks for `MarblePie/manetop`, a file her pack never shipped (it ships
## ManeFront and ManeSide), so her forelock came out as the magenta checker; ManeSide is the
## same grey hair painted the same way. The sibling is the material sharing the longest name
## prefix (mane* for a mane), else any hair, mane or tail texture; with none the surface is
## drawn flat in the colour the checker can never be.
static func _with_sibling_texture(src: StandardMaterial3D, root: Node) -> StandardMaterial3D:
	var want := src.resource_name.get_slice(".", 0).to_lower()
	var best: Texture2D = null
	var best_score := 0
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i) as StandardMaterial3D
			if m == null or m == src or m.albedo_texture == null or is_placeholder(m.albedo_texture):
				continue
			var n := m.resource_name.get_slice(".", 0).to_lower()
			var score := 0
			while score < mini(n.length(), want.length()) and n[score] == want[score]:
				score += 1
			for hair in ["mane", "hair", "tail"]:
				if n.contains(hair):
					score += 1
			if score > best_score:
				best_score = score
				best = m.albedo_texture
	var out := src.duplicate() as StandardMaterial3D
	out.albedo_texture = best
	if best == null:
		out.albedo_color = coat_color(root).darkened(0.3)
	return out


static var _coat_cache: Dictionary = {}


## Her coat colour: the commonest colour of her `body` texture (the barrel covers most of it),
## or the material's flat colour. Cached per texture.
static func coat_color(root: Node) -> Color:
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i) as StandardMaterial3D
			if m == null or m.resource_name.get_slice(".", 0) != "body":
				continue
			var tex := m.albedo_texture
			if tex == null:
				return m.albedo_color
			var key := tex.get_rid().get_id()
			if not _coat_cache.has(key):
				_coat_cache[key] = _dominant(tex, m.albedo_color)
			return _coat_cache[key]
	return Color(0.5, 0.45, 0.5)


static func _dominant(tex: Texture2D, fallback: Color) -> Color:
	var img := tex.get_image()
	if img == null or img.is_empty():
		return fallback
	if img.is_compressed():
		img.decompress()
	img = img.duplicate() as Image
	img.convert(Image.FORMAT_RGBA8)
	img.resize(32, 32, Image.INTERPOLATE_NEAREST)
	var counts := {}
	var sums := {}
	for y in 32:
		for x in 32:
			var px := img.get_pixel(x, y)
			if px.a < 0.5:
				continue
			var q := Vector3i(int(px.r * 12.0), int(px.g * 12.0), int(px.b * 12.0))
			counts[q] = int(counts.get(q, 0)) + 1
			sums[q] = (sums.get(q, Color(0, 0, 0, 0)) as Color) + px
	var best: Variant = null
	for q: Vector3i in counts:
		if best == null or int(counts[q]) > int(counts[best]):
			best = q
	if best == null:
		return fallback
	var s: Color = sums[best]
	var n := float(counts[best])
	return Color(s.r / n, s.g / n, s.b / n, 1.0)


## A canon PonySFM pony's eyeball: the eye shader with her own iris colours and the iris shrunk
## to the size Source drew it (shaders/pony_eye.gdshader, iris_scale).
const EYE_SHADER := preload("res://shaders/pony_eye.gdshader")
const SFM_IRIS_SCALE := 1.2


## DERPY'S EYES, each its own way (owner 2026-11-05: "make sure derpy has her silly crossed
## eyes"): the gaze of her eyeball_l and eyeball_r, in iris texture UV (shaders/pony_eye.gdshader).
const CROSS_EYED := {
	&"derpyhooves": {&"eyeball_l": Vector2(-0.02, 0.13), &"eyeball_r": Vector2(0.02, -0.13)},
}


## Roll a named pony's eyes the way CROSS_EYED has them; a no op for everyone else.
static func cross_eyes(body: Node, id: StringName) -> void:
	var sides: Dictionary = CROSS_EYED.get(id, {})
	if sides.is_empty() or body == null:
		return
	for node: Node in body.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			var m := mi.get_active_material(i) as ShaderMaterial
			if src == null or m == null or m.shader != EYE_SHADER:
				continue
			var side := StringName(src.resource_name.get_slice(".", 0))
			if sides.has(side):
				m.set_shader_parameter(&"gaze", sides[side])


static func sfm_eye(tex: Texture2D) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = EYE_SHADER
	m.set_shader_parameter(&"eye_texture", tex)
	m.set_shader_parameter(&"recolor", false)
	m.set_shader_parameter(&"iris_scale", SFM_IRIS_SCALE)
	return m


## One StandardMaterial3D as a toon ShaderMaterial (plus its outline pass, and its twin
## without one: see BARE_META).
static func to_toon(src: StandardMaterial3D, preset: Dictionary) -> ShaderMaterial:
	var m := _toon_from(src, preset)
	var px: float = float(preset.get("outline_px", 0.0)) * outline_scale
	if px > 0.0 and src.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
		m.next_pass = make_outline(src.albedo_color, src.albedo_texture, px, float(preset.get("fade_end", 42.0)))
		m.set_meta(BARE_META, _toon_from(src, preset))
	return m


## THE SAME MATERIAL WITHOUT ITS OUTLINE PASS, built beside it. A pony far off wears this
## (pony.gd _outline) so the pass costs no draw call at all; made here, at build time, because
## copying a material on the spot was 370 us a surface, a spike every time the camera turned.
const BARE_META := &"bare_of_outline"


## Wear or shed the outline pass on every surface of `meshes` (pony.gd's detail tiers, npc.gd
## off in the distance). Shedding swaps a surface to its BARE_META twin, so the pass costs no
## draw call; `worn` remembers each swap, so wearing it again restores exactly those, and a
## surface somebody else changed meanwhile keeps theirs. A material with no twin is left be.
static func wear_outline(meshes: Array, on: bool, worn: Dictionary) -> void:
	for node in meshes:
		var mi := node as MeshInstance3D
		if mi == null or not is_instance_valid(mi) or mi.mesh == null:
			continue
		for k in mi.mesh.get_surface_count():
			var key := mi.get_instance_id() * 64 + k
			if on:
				var pair: Array = worn.get(key, [])
				if not pair.is_empty():
					if mi.get_surface_override_material(k) == pair[1]:
						mi.set_surface_override_material(k, pair[0])
					worn.erase(key)
				continue
			var mat := mi.get_surface_override_material(k)
			if mat == null or mat.next_pass == null:
				continue
			var bare: Material = mat.get_meta(BARE_META, null)
			if bare == null:
				continue
			mi.set_surface_override_material(k, bare)
			worn[key] = [mat, bare]


static func _toon_from(src: StandardMaterial3D, preset: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = TOON
	m.resource_name = src.resource_name
	m.set_shader_parameter(&"albedo", src.albedo_color)
	var tex: Texture2D = src.albedo_texture
	m.set_shader_parameter(&"use_texture", tex != null)
	if tex != null:
		m.set_shader_parameter(&"albedo_texture", tex)
	m.set_shader_parameter(&"shadow_fill", float(preset.get("shadow_fill", 0.34)))
	m.set_shader_parameter(&"rim_strength", float(preset.get("rim", 0.0)))
	if src.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
		m.set_shader_parameter(&"alpha_scissor", src.alpha_scissor_threshold)
	elif src.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		# Hair cards and leaves imported as blended alpha read better cut than sorted.
		m.set_shader_parameter(&"alpha_scissor", 0.5)
	if src.emission_enabled:
		m.set_shader_parameter(&"emission", src.emission)
		m.set_shader_parameter(&"emission_energy", src.emission_energy_multiplier)
	return m


static func make_outline(color: Color, tex: Texture2D, px: float, fade_end: float) -> ShaderMaterial:
	var o := ShaderMaterial.new()
	o.shader = OUTLINE
	o.set_shader_parameter(&"albedo", color)
	o.set_shader_parameter(&"use_texture", tex != null)
	if tex != null:
		o.set_shader_parameter(&"albedo_texture", tex)
	o.set_shader_parameter(&"width_px", px)
	o.set_shader_parameter(&"fade_start", fade_end * 0.45)
	o.set_shader_parameter(&"fade_end", fade_end)
	return o


## The preset a prop file reads best with: soft thin lines for plants, the prop line for
## everything else.
## Brighten a toon material, its outline pass and its outline-free twin by `lift`.
static func _lift(m: ShaderMaterial, lift: float) -> void:
	for mat: Variant in [m, m.next_pass, m.get_meta(BARE_META, null)]:
		if mat is ShaderMaterial:
			var c: Color = (mat as ShaderMaterial).get_shader_parameter(&"albedo")
			(mat as ShaderMaterial).set_shader_parameter(&"albedo",
				Color(c.r * lift, c.g * lift, c.b * lift, c.a))


static func category_for(file: String) -> StringName:
	var f := file.to_lower()
	for k in ["tree", "bush", "grass", "flower", "leaf", "hedge", "plant"]:
		if f.contains(k):
			return &"foliage"
	return &"prop"


## True when `mi` surface `i` carries a toon material (for tests and gates).
static func is_toon(mi: MeshInstance3D, i: int) -> bool:
	var m: Material = mi.get_active_material(i)
	return m is ShaderMaterial and (m as ShaderMaterial).shader == TOON


static func clear_cache() -> void:
	_shared.clear()
