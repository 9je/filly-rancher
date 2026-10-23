class_name RegionDressing
extends Node3D
## THE REGIONS, DRESSED (MISSION.md: "never ship primitive environments"; the visual review
## of 2026-10-23 found each region was a fenced disc of tinted grass with a few ponies in
## it). Each region gets the scenery its name promises, scattered from a fixed seed so every
## machine and every save sees the same valley:
##
##   The Everfree Edge   a dark wood: tall pines and dark oaks thick round the rim, a few in
##                       the clearing, toadstools, fallen logs, stumps, mossy rocks
##   The Night Meadow    a moonflower field (the purple ones glow a little), long grass, a
##                       ring of standing stones in the middle
##   The Lake            lily pads on the water, reeds and flat stones round the shore, a
##                       canoe pulled up on the bank, a jetty of planks
##   The Orchard         rows of apple trees with lanes between, baskets, crates, hay
##
## Kenney's Nature Kit (CC0, game/assets/models/nature/) plus the project's own converted
## Sweet Apple Acres props, all restyled through ToonStyler with the leaves recoloured from
## Kenney's teal to the show's greens. Small things go in MultiMeshes (one draw per kind, not
## one per flower); trunks and big stones get a collider so nopony walks through them.

const ToonStylerScript := preload("res://systems/toon_styler.gd")
const LayersScript := preload("res://world/collision_layers.gd")
const NATURE := "res://assets/models/nature/"

## Leaf and grass greens, by how dark the source material was meant to be.
const GREEN := Color(0.42, 0.66, 0.3)
const GREEN_DARK := Color(0.2, 0.36, 0.2)
const GREEN_EVERFREE := Color(0.16, 0.3, 0.2)
const WOOD := Color(0.4, 0.27, 0.18)
const STONE := Color(0.55, 0.57, 0.62)

var height_at: Callable = func(_x: float, _z: float) -> float: return 0.0
## A lake's water height, by region id (the ranch knows it from Terrain.build_water).
var water_y: Dictionary = {}

var _meshes: Dictionary = {}
var _batches: Dictionary = {}
var _rng := RandomNumberGenerator.new()


## Dress every region in `regions` (RegionData).
func dress(regions: Array) -> void:
	for r: RegionData in regions:
		_rng.seed = hash(String(r.id)) * 7 + 11
		match r.id:
			&"everfree":
				_everfree(r)
			&"nightmeadow":
				_night_meadow(r)
			&"lake":
				_lake(r)
			&"orchard":
				_orchard(r)
	_flush()


# --- the regions ----------------------------------------------------------------------

func _everfree(r: RegionData) -> void:
	var trees := ["tree_pineTallA_detailed", "tree_pineTallB_detailed", "tree_pineTallC_detailed",
		"tree_oak_dark", "tree_default_dark", "tree_fat_darkh", "tree_thin_dark", "tree_pineRoundC"]
	# Thick round the rim (the wood the clearing is cut out of), thinner inside.
	for i in 54:
		var a := TAU * float(i) / 54.0 + _rng.randf_range(-0.05, 0.05)
		var d := r.radius * _rng.randf_range(0.78, 1.3)
		_tree(r, trees[_rng.randi() % trees.size()], a, d, _rng.randf_range(4.2, 6.2), GREEN_EVERFREE)
	for i in 40:
		var a2 := TAU * float(i) / 40.0 + 0.07
		_tree(r, trees[_rng.randi() % trees.size()], a2, r.radius * _rng.randf_range(1.3, 1.7), _rng.randf_range(4.5, 6.8), GREEN_EVERFREE)
	for i in 14:
		_tree(r, trees[_rng.randi() % trees.size()], _rng.randf() * TAU, r.radius * _rng.randf_range(0.3, 0.72),
			_rng.randf_range(3.6, 5.2), GREEN_EVERFREE)
	_scatter(r, ["mushroom_redGroup", "mushroom_tanGroup", "mushroom_red", "mushroom_redTall"], 34, 0.1, 0.95, Vector2(2.6, 4.0))
	_scatter(r, ["log", "log_large", "stump_old", "stump_oldTall"], 12, 0.25, 0.9, Vector2(2.6, 3.6), true)
	_scatter(r, ["rock_largeA", "rock_largeC", "rock_tallB"], 8, 0.3, 0.95, Vector2(2.2, 3.4), true)
	_scatter(r, ["plant_bushLarge", "plant_bushDetailed", "grass_large"], 50, 0.2, 1.05, Vector2(2.6, 4.2), false, GREEN_EVERFREE)


func _night_meadow(r: RegionData) -> void:
	_scatter(r, ["flower_purpleA", "flower_purpleB", "flower_purpleC"], 150, 0.05, 0.98, Vector2(2.8, 4.2), false, GREEN_DARK, true)
	_scatter(r, ["flower_yellowA", "flower_yellowB", "flower_redA"], 60, 0.05, 0.98, Vector2(2.6, 3.8), false, GREEN_DARK)
	_scatter(r, ["grass", "grass_leafs", "grass_large"], 110, 0.0, 1.0, Vector2(2.8, 4.6), false, GREEN_DARK)
	# The standing stones, in a ring round the middle of the meadow.
	var stones := ["stone_tallA", "stone_tallB", "stone_tallC", "stone_tallD", "stone_tallE"]
	for i in 9:
		var a := TAU * float(i) / 9.0
		_place(r, stones[i % stones.size()], a, 5.5, Vector2(2.6, 3.4), true, Color(), false, true)
	for i in 22:
		_tree(r, ["tree_pineRoundC", "tree_pineTallB_detailed"][_rng.randi() % 2], _rng.randf() * TAU, r.radius * _rng.randf_range(0.95, 1.4), _rng.randf_range(4.0, 5.6), GREEN_DARK)


func _lake(r: RegionData) -> void:
	var wy: float = water_y.get(r.id, height_at.call(r.centre.x, r.centre.y))
	var water_r := r.radius * 0.7
	# Lily pads ON the water, so they sit at its height rather than on the basin floor.
	for i in 26:
		var a := _rng.randf() * TAU
		var d := water_r * sqrt(_rng.randf_range(0.05, 0.85))
		var at := Vector3(r.centre.x + cos(a) * d, wy + 0.03, r.centre.y + sin(a) * d)
		_add(["lily_large", "lily_small"][_rng.randi() % 2], Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(1.8, 2.8)), at), false, GREEN)
	# Reeds and flat stones along the shore.
	for i in 70:
		var a := _rng.randf() * TAU
		var d := water_r * _rng.randf_range(0.92, 1.12)
		_place(r, ["plant_flatTall", "plant_flatShort", "grass_leafsLarge"][_rng.randi() % 3], a, d, Vector2(3.0, 4.6), false, GREEN)
	for i in 18:
		_place(r, ["rock_smallFlatA", "rock_smallFlatB", "rock_smallA"][_rng.randi() % 3], _rng.randf() * TAU,
			water_r * _rng.randf_range(0.95, 1.25), Vector2(1.4, 2.2))
	# A canoe on the bank, and a short jetty of planks out over the water.
	var jetty_a := 0.6
	_place(r, "canoe", jetty_a + 0.35, water_r * 1.08, Vector2(3.2, 3.2), true)
	for k in 5:
		var d := water_r * 1.04 - float(k) * 1.1
		var at := Vector3(r.centre.x + cos(jetty_a) * d, maxf(wy + 0.12, float(height_at.call(r.centre.x + cos(jetty_a) * d, r.centre.y + sin(jetty_a) * d)) + 0.05), r.centre.y + sin(jetty_a) * d)
		_add("path_wood", Transform3D(Basis(Vector3.UP, -jetty_a).scaled(Vector3(2.0, 1.6, 2.0)), at), true)
	for i in 8:
		_tree(r, ["tree_default_dark", "tree_oak_dark", "tree_fat_darkh"][_rng.randi() % 3], _rng.randf() * TAU,
			r.radius * _rng.randf_range(1.0, 1.3), _rng.randf_range(3.8, 5.0), GREEN)


func _orchard(r: RegionData) -> void:
	var tree := "res://assets/converted/props/mlp_apple_tree.glb"
	if not ResourceLoader.exists(tree):
		return
	# Rows across the orchard, a lane down the middle for the ponies.
	for row in range(-2, 3):
		for col in range(-3, 4):
			if col == 0:
				continue
			var x := r.centre.x + float(col) * 5.2 + _rng.randf_range(-0.4, 0.4)
			var z := r.centre.y + float(row) * 6.0 + _rng.randf_range(-0.4, 0.4)
			if Vector2(x - r.centre.x, z - r.centre.y).length() > r.radius * 0.86:
				continue
			_scene(tree, Vector3(x, float(height_at.call(x, z)), z), _rng.randf() * TAU, 1.0, true)
	for p in ["res://assets/converted/props/mlp_basket.glb", "res://assets/converted/props/mlp_crate.glb",
			"res://assets/converted/props/saa_hay_pile.glb"]:
		if not ResourceLoader.exists(p):
			continue
		for i in 3:
			var a := _rng.randf() * TAU
			var d := r.radius * _rng.randf_range(0.25, 0.8)
			var x := r.centre.x + cos(a) * d
			var z := r.centre.y + sin(a) * d
			_scene(p, Vector3(x, float(height_at.call(x, z)), z), _rng.randf() * TAU, 1.0, false)


# --- placing ---------------------------------------------------------------------------

func _tree(r: RegionData, model: String, a: float, d: float, s: float, leaves: Color) -> void:
	_place(r, model, a, d, Vector2(s, s), true, leaves)


func _scatter(r: RegionData, models: Array, n: int, inner: float, outer: float, scale: Vector2,
		solid: bool = false, leaves: Color = Color(), glow: bool = false) -> void:
	for i in n:
		var a := _rng.randf() * TAU
		var d := r.radius * sqrt(_rng.randf_range(inner * inner, outer * outer))
		_place(r, models[_rng.randi() % models.size()], a, d, scale, solid, leaves, glow)


func _place(r: RegionData, model: String, a: float, d: float, scale: Vector2, solid: bool = false,
		leaves: Color = Color(), glow: bool = false, face_centre: bool = false) -> void:
	var x := r.centre.x + cos(a) * d
	var z := r.centre.y + sin(a) * d
	var y := float(height_at.call(x, z))
	var s := _rng.randf_range(scale.x, scale.y)
	var yaw := -a + PI * 0.5 if face_centre else _rng.randf() * TAU
	_add(model, Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), Vector3(x, y - 0.03, z)), solid, leaves, glow)


func _add(model: String, xf: Transform3D, solid: bool, leaves: Color = Color(), glow: bool = false) -> void:
	var parts: Array = _parts(model, leaves, glow)
	for part: Array in parts:
		var key := "%s|%s|%s" % [model, str(leaves), str(glow)] + "|" + str(part[2])
		if not _batches.has(key):
			_batches[key] = {"mesh": part[0], "xf": [], "shadow": solid}
		(_batches[key].xf as Array).append(xf * (part[1] as Transform3D))
	if solid:
		_collider(xf)


## A model's meshes, toon-restyled once: [[mesh, local transform, index], ...].
func _parts(model: String, leaves: Color, glow: bool) -> Array:
	var key := "%s|%s|%s" % [model, str(leaves), str(glow)]
	if _meshes.has(key):
		return _meshes[key]
	var out: Array = []
	var path := NATURE + model + ".glb"
	if not ResourceLoader.exists(path):
		_meshes[key] = out
		return out
	var inst: Node3D = (load(path) as PackedScene).instantiate()
	var i := 0
	for m in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		var mesh := mi.mesh.duplicate() as Mesh
		for sidx in mesh.get_surface_count():
			var src := mesh.surface_get_material(sidx) as StandardMaterial3D
			if src == null:
				continue
			var mat := src.duplicate() as StandardMaterial3D
			var lname := String(src.resource_name).to_lower()
			if leaves.a > 0.0 and ("leaf" in lname or "grass" in lname or "green" in lname or "plant" in lname):
				mat.albedo_color = leaves.lerp(leaves * src.albedo_color.v * 1.4, 0.25)
			# Kenney's bark and stone are pale enough to read pink under the toon light: the
			# show's trunks are a warm brown, its rocks a cool grey.
			if "inner" in lname:
				mat.albedo_color = Color(0.8, 0.66, 0.48)
			elif "wood" in lname or "bark" in lname or "trunk" in lname or "log" in lname or "dirt" in lname:
				mat.albedo_color = WOOD.lerp(WOOD * 1.25, clampf(src.albedo_color.v - 0.5, 0.0, 1.0))
			elif "stone" in lname or "rock" in lname:
				mat.albedo_color = STONE * lerpf(0.85, 1.05, src.albedo_color.v)
			if glow and ("flower" in lname or "purple" in lname or "petal" in lname):
				mat.emission_enabled = true
				mat.emission = mat.albedo_color
				mat.emission_energy_multiplier = 0.6
			mesh.surface_set_material(sidx, ToonStylerScript.to_toon(mat, ToonStylerScript.PRESETS[&"foliage"])
				if ToonStylerScript.shading_enabled else mat)
		out.append([mesh, _relative(inst, mi), i])
		i += 1
	inst.free()
	_meshes[key] = out
	return out


func _relative(root: Node3D, n: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != root:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf


func _collider(xf: Transform3D) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = LayersScript.PROPS
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.16 * xf.basis.get_scale().x
	cyl.height = 2.4
	shape.shape = cyl
	shape.position = Vector3(0, 1.2, 0)
	body.add_child(shape)
	add_child(body)
	body.global_transform = Transform3D(Basis(), xf.origin)


## A whole converted scene (the Sweet Apple Acres props), styled the way props.gd styles them.
func _scene(path: String, at: Vector3, yaw: float, s: float, solid: bool) -> void:
	var n: Node3D = (load(path) as PackedScene).instantiate()
	add_child(n)
	n.global_position = at
	n.rotation.y = yaw
	n.scale = Vector3.ONE * s
	ToonStylerScript.style(n, &"foliage")
	if solid:
		_collider(Transform3D(Basis().scaled(Vector3.ONE * 1.6), at))


## One MultiMeshInstance3D per (model, mesh): a field of flowers is one draw, not a hundred.
func _flush() -> void:
	for key: String in _batches:
		var b: Dictionary = _batches[key]
		var xfs: Array = b.xf
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = b.mesh
		mm.instance_count = xfs.size()
		for i in xfs.size():
			mm.set_instance_transform(i, xfs[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.name = "Dress_" + key.get_slice("|", 0)
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if bool(b.shadow) \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if not bool(b.shadow):
			mmi.visibility_range_end = 110.0
		add_child(mmi)
	_batches.clear()
