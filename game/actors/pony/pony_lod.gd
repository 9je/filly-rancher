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
##
## THE CHAINS ARE BUILT OFF THE MAIN THREAD (docs/playtest_fixes/loading.md). Measured on the
## owner's machine, generate_lods() on one pony is 0.4 to 1.2 s, and it ran on the main thread
## inside every spawn: the herd's part of the boot was 20 to 60 s of a frozen window. Two
## causes, both fixed here. The cache was keyed by the mesh's instance id, and a donor scene
## is loaded afresh once the last pony holding its original meshes has swapped them for LOD'd
## copies, so the ids never repeated and EVERY pony rebuilt her chain; it is keyed by the
## mesh's resource path now ("res://...::ArrayMesh_x"), which a reload keeps. And a mesh not
## yet in the cache goes to the WorkerThreadPool: the pony is drawn at full detail until her
## chain is ready, a frame or so later, and is then moved onto it.

const KEEP_FULL: Array[String] = ["eye", "iris", "pupil", "sclera", "lash", "lid", "brow", "teeth", "tongue"]

## Finished LOD'd meshes, by _key().
static var _cache: Dictionary = {}
## Chains being built on a worker, by _key(): {task, mesh, arrays, keep, result, users}.
static var _pending: Dictionary = {}
static var enabled := DisplayServer.get_name() != "headless"
static var _polling := false


static func apply(root: Node) -> int:
	if not enabled or root == null:
		return 0
	var n := 0
	for m in root.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if not (mi.mesh is ArrayMesh):
			continue
		var mesh := mi.mesh as ArrayMesh
		var key := _key(mesh)
		if _cache.has(key):
			var out: ArrayMesh = _cache[key]
			if out != mi.mesh:
				mi.mesh = out
				n += 1
			continue
		_request(key, mesh, mi)
		n += 1
	return n


## The same chain, built here and now on the calling thread (the probes, which want it at
## once).
static func lodded(mesh: ArrayMesh) -> ArrayMesh:
	var key := _key(mesh)
	if _cache.has(key):
		return _cache[key]
	var arrays := _surface_arrays(mesh)
	var out := _assemble(mesh, arrays, _lod_indices(_shape_of(mesh), arrays))
	_cache[key] = out
	return out


static func _key(mesh: ArrayMesh) -> String:
	return mesh.resource_path if mesh.resource_path != "" else "id:%d" % mesh.get_instance_id()


## Queue `mesh`'s chain on a worker (once per key) and remember `mi` to receive it.
static func _request(key: String, mesh: ArrayMesh, mi: MeshInstance3D) -> void:
	if not _pending.has(key):
		var job := {"mesh": mesh, "arrays": [], "shape": _shape_of(mesh), "result": {},
			"users": []}
		job["task"] = WorkerThreadPool.add_task(_work.bind(job), false, "PonyLod")
		_pending[key] = job
	(_pending[key].users as Array).append(weakref(mi))
	if not _polling:
		var tree := Engine.get_main_loop() as SceneTree
		if tree != null:
			tree.process_frame.connect(_poll)
			_polling = true


## WORKER THREAD: the arrays are read here too (a read off the render thread's copy, which
## on the main thread stalls it once per surface), then decimated.
static func _work(job: Dictionary) -> void:
	job["arrays"] = _surface_arrays(job.mesh)
	job["result"] = _lod_indices(job.shape, job.arrays)


## MAIN THREAD, once a frame while anything is pending: a finished chain becomes a mesh and
## the ponies waiting on it are moved onto it.
static func _poll() -> void:
	for key: String in _pending.keys():
		var job: Dictionary = _pending[key]
		if not WorkerThreadPool.is_task_completed(job.task):
			continue
		WorkerThreadPool.wait_for_task_completion(job.task)
		var out := _assemble(job.mesh, job.arrays, job.result)
		_cache[key] = out
		for ref: WeakRef in job.users:
			var mi := ref.get_ref() as MeshInstance3D
			if mi != null and mi.mesh == job.mesh:
				mi.mesh = out
		_pending.erase(key)
	if _pending.is_empty() and _polling:
		var tree := Engine.get_main_loop() as SceneTree
		if tree != null and tree.process_frame.is_connected(_poll):
			tree.process_frame.disconnect(_poll)
		_polling = false


## Every surface's vertex and blend shape arrays, read off the mesh.
static func _surface_arrays(mesh: ArrayMesh) -> Array:
	var out: Array = []
	for s in mesh.get_surface_count():
		out.append([mesh.surface_get_arrays(s), mesh.surface_get_blend_shape_arrays(s)])
	return out


## What the decimation needs to know about the mesh besides its arrays, as plain data.
static func _shape_of(mesh: ArrayMesh) -> Dictionary:
	var shapes: Array[String] = []
	for b in mesh.get_blend_shape_count():
		shapes.append(mesh.get_blend_shape_name(b))
	var surfaces: Array = []
	for s in mesh.get_surface_count():
		surfaces.append({"primitive": mesh.surface_get_primitive_type(s),
			"name": mesh.surface_get_name(s),
			"flags": _keep_bits(mesh.surface_get_format(s)),
			"keep": _keep_full(mesh, s)})
	return {"shapes": shapes, "mode": mesh.blend_shape_mode, "surfaces": surfaces}


## {surface index: {lod size: indices}}, nothing for an eye surface (any thread).
static func _lod_indices(shape: Dictionary, arrays: Array) -> Dictionary:
	var im := ImporterMesh.new()
	for b: String in shape.shapes:
		im.add_blend_shape(b)
	im.set_blend_shape_mode(shape.mode)
	var surfaces: Array = shape.surfaces
	for s in surfaces.size():
		im.add_surface(surfaces[s].primitive, arrays[s][0], arrays[s][1], {}, null,
			surfaces[s].name, surfaces[s].flags)
	im.generate_lods(25.0, 60.0, [])
	var out := {}
	for s in surfaces.size():
		var lods := {}
		if not bool(surfaces[s].keep):
			for l in im.get_surface_lod_count(s):
				lods[im.get_surface_lod_size(s, l)] = im.get_surface_lod_indices(s, l)
		out[s] = lods
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


## The LOD'd copy of `mesh` (main thread).
static func _assemble(mesh: ArrayMesh, arrays: Array, lods: Dictionary) -> ArrayMesh:
	var out := ArrayMesh.new()
	for b in mesh.get_blend_shape_count():
		out.add_blend_shape(mesh.get_blend_shape_name(b))
	out.blend_shape_mode = mesh.blend_shape_mode
	for s in mesh.get_surface_count():
		out.add_surface_from_arrays(mesh.surface_get_primitive_type(s), arrays[s][0],
			arrays[s][1], lods.get(s, {}), _keep_bits(mesh.surface_get_format(s)))
		if out.get_surface_count() != s + 1:
			# The server refused this surface. A mesh without its LODs costs some triangles; a
			# mesh missing a surface is a pony missing her body. Keep the original.
			push_warning("PonyLod: surface %d of '%s' would not rebuild; keeping the mesh unLODded" % [s, mesh.resource_name])
			return mesh
		out.surface_set_material(s, mesh.surface_get_material(s))
		out.surface_set_name(s, mesh.surface_get_name(s))
	out.custom_aabb = mesh.custom_aabb
	return out
