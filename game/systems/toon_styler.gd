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

## Outline width is multiplied by this; the graphics settings set it (0 disables lines).
static var outline_scale: float = 1.0

static var _shared: Dictionary = {}


## Style every surface under `root`. Returns the number of surfaces converted.
## `category` picks a preset; `cache` is the material cache to use (pass {} for a private
## one, or omit for the process-wide shared cache).
static func style(root: Node, category: StringName = &"prop", cache: Variant = null) -> int:
	if root == null:
		return 0
	var store: Dictionary = _shared if cache == null else cache
	var preset: Dictionary = PRESETS.get(category, PRESETS[&"prop"])
	var touched := 0
	var meshes: Array[Node] = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		meshes.append(root)
	for node: Node in meshes:
		var mi: MeshInstance3D = node
		if mi.mesh == null:
			continue
		for i in range(mi.mesh.get_surface_count()):
			var src: Material = mi.get_active_material(i)
			if src is StandardMaterial3D:
				var key := "%d:%s" % [src.get_instance_id(), category]
				var out: ShaderMaterial = store.get(key)
				if out == null:
					out = to_toon(src as StandardMaterial3D, preset)
					store[key] = out
				mi.set_surface_override_material(i, out)
				touched += 1
	return touched


## One StandardMaterial3D as a toon ShaderMaterial (plus its outline pass).
static func to_toon(src: StandardMaterial3D, preset: Dictionary) -> ShaderMaterial:
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
	var px: float = float(preset.get("outline_px", 0.0)) * outline_scale
	if px > 0.0 and src.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
		m.next_pass = make_outline(src.albedo_color, tex, px, float(preset.get("fade_end", 42.0)))
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


## True when `mi` surface `i` carries a toon material (for tests and gates).
static func is_toon(mi: MeshInstance3D, i: int) -> bool:
	var m: Material = mi.get_active_material(i)
	return m is ShaderMaterial and (m as ShaderMaterial).shader == TOON


static func clear_cache() -> void:
	_shared.clear()
