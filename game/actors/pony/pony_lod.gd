class_name PonyLod
extends RefCounted
## MESH LODS FOR PONIES, WITHOUT THE PUPIL BUG (game/test/test_import_settings.gd says why the
## importer's own LODs are off: the generator decimated each iris cap by more than its 1.6 mm
## clearance over the eyeball, so a pupil vanished past 10 m). A pony is ~59k triangles and the
## 60-pony check (scenes/test/perf.gd) draws tens of millions of them, so the LODs are made
## here instead, once per mesh at runtime, with every EYE surface (sclera, iris, pupil, lids
## by material name) left at full detail and everything else (body, mane, tail, ears, hooves,
## the head's skin) given Godot's automatic LOD chain.
##
## Cached by mesh, so forty ponies on one donor body share one LOD'd mesh. Skipped under the
## headless dummy renderer, which draws nothing.

const KEEP_FULL: Array[String] = ["eye", "iris", "pupil", "sclera", "lash", "lid", "brow", "teeth", "tongue"]

static var _cache: Dictionary = {}
static var enabled := DisplayServer.get_name() != "headless"


static func apply(root: Node) -> int:
	if not enabled or root == null:
		return 0
	var n := 0
	for m in root.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh is ArrayMesh:
			var out := lodded(mi.mesh as ArrayMesh)
			if out != mi.mesh:
				mi.mesh = out
				n += 1
	return n


static func lodded(mesh: ArrayMesh) -> ArrayMesh:
	var key := mesh.get_instance_id()
	if _cache.has(key):
		return _cache[key]
	var out := _build(mesh)
	_cache[key] = out
	return out


static func _keep_full(mesh: ArrayMesh, s: int) -> bool:
	var names := mesh.surface_get_name(s).to_lower()
	var mat := mesh.surface_get_material(s)
	if mat != null:
		names += " " + mat.resource_name.to_lower()
	for k in KEEP_FULL:
		if k in names:
			return true
	return false


## The format bits a surface must be re-added with: 8 bone weights, and the CUSTOM0..3
## channel formats. Passing only the bone-weight bit (as this file once did) told the
## server that a surface carrying a custom channel had none, it refused the arrays
## ("Invalid array format for surface"), and Applejack's whole body -- coat, face, mouth,
## four surfaces -- came out as an empty mesh: an invisible pony with a hat, a mane and a
## pair of eyes floating over the grass (docs/playtest_fixes/ponies.md).
static func _keep_bits(format: int) -> int:
	var bits := Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
	for n in 4:
		bits |= Mesh.ARRAY_FORMAT_CUSTOM_MASK << (Mesh.ARRAY_FORMAT_CUSTOM_BASE + n * Mesh.ARRAY_FORMAT_CUSTOM_BITS)
	return format & bits


static func _build(mesh: ArrayMesh) -> ArrayMesh:
	var im := ImporterMesh.new()
	for b in mesh.get_blend_shape_count():
		im.add_blend_shape(mesh.get_blend_shape_name(b))
	im.set_blend_shape_mode(mesh.blend_shape_mode)
	for s in mesh.get_surface_count():
		im.add_surface(mesh.surface_get_primitive_type(s), mesh.surface_get_arrays(s),
			mesh.surface_get_blend_shape_arrays(s), {}, mesh.surface_get_material(s),
			mesh.surface_get_name(s), _keep_bits(mesh.surface_get_format(s)))
	im.generate_lods(25.0, 60.0, [])
	var out := ArrayMesh.new()
	for b in mesh.get_blend_shape_count():
		out.add_blend_shape(mesh.get_blend_shape_name(b))
	out.blend_shape_mode = mesh.blend_shape_mode
	for s in mesh.get_surface_count():
		var lods := {}
		if not _keep_full(mesh, s):
			for l in im.get_surface_lod_count(s):
				lods[im.get_surface_lod_size(s, l)] = im.get_surface_lod_indices(s, l)
		out.add_surface_from_arrays(mesh.surface_get_primitive_type(s), mesh.surface_get_arrays(s),
			mesh.surface_get_blend_shape_arrays(s), lods, _keep_bits(mesh.surface_get_format(s)))
		if out.get_surface_count() != s + 1:
			# The server refused this surface. A mesh without its LODs costs some triangles; a
			# mesh missing a surface is a pony missing her body. Keep the original.
			push_warning("PonyLod: surface %d of '%s' would not rebuild; keeping the mesh unLODded" % [s, mesh.resource_name])
			return mesh
		out.surface_set_material(s, mesh.surface_get_material(s))
		out.surface_set_name(s, mesh.surface_get_name(s))
	out.custom_aabb = mesh.custom_aabb
	return out
