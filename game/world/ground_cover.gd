extends Node3D
## GRASS TUFTS AND FLOWERS (Fable AAA round 1, #6: "the path is a flat tan shape with a blurred
## gradient edge into flat green; no tufts, no decals, no edging"). Clumps of three blades in
## the ground's own green, thicker along the edges of the dirt paths so a path has a verge, and
## a sprinkle of the show's little five-petal flowers. One MultiMesh per kind per chunk of
## ground, each chunk dropped past VISIBLE_METRES, so the whole meadow is a few dozen draws.
##
## NEVER ON ANYTHING BUT BARE GROUND. A clump goes down only where a ray from above meets the
## terrain itself first (not a floor, a fence or a building), outside the plaza, the street,
## the Strip, the pen plots and the lakes, and off the dirt paths' core.

const TerrainScript := preload("res://world/terrain.gd")
const StreetScript := preload("res://world/street.gd")
const PropsScript := preload("res://world/props.gd")

const STEP := 1.15
const CHUNK := 27.5
const VISIBLE_METRES := 62.0
## Chance of a clump in open meadow, and along a path's verge.
const MEADOW := 0.45
const VERGE := 0.95
const FLOWERS := 0.05
const FLOWER_COLOURS: Array[Color] = [Color(1.0, 1.0, 0.97), Color(1.0, 0.72, 0.84),
	Color(1.0, 0.86, 0.36), Color(0.80, 0.70, 1.0)]

var _rng := RandomNumberGenerator.new()


func build(terrain: Node, region_list: Array) -> int:
	_rng.seed = 20261109
	var space := get_world_3d().direct_space_state
	var tufts := {}
	var flowers := {}
	var placed := 0
	var half := float(TerrainScript.HALF) - 4.0
	var x := -half
	while x < half:
		var z := -half
		while z < half:
			var px := x + _rng.randf_range(-0.45, 0.45) * STEP
			var pz := z + _rng.randf_range(-0.45, 0.45) * STEP
			z += STEP
			var p := Vector2(px, pz)
			var path := TerrainScript.path_distance(p)
			if path < 1.25 or _excluded(p, region_list):
				continue
			var verge := path < 2.6
			var roll := _rng.randf()
			var is_flower := roll < FLOWERS
			if not is_flower and roll > (VERGE if verge else MEADOW):
				continue
			var y := float(terrain.call("height_at", px, pz))
			var q := PhysicsRayQueryParameters3D.create(Vector3(px, y + 6.0, pz), Vector3(px, y - 1.0, pz))
			var hit := space.intersect_ray(q)
			if hit.is_empty() or hit.collider != terrain:
				continue
			var key := Vector2i(floori(px / CHUNK), floori(pz / CHUNK))
			var grass: Color = terrain.call("grass_at", px, pz)
			var xf := Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), Vector3(px, y - 0.02, pz))
			if is_flower:
				xf = xf.scaled_local(Vector3.ONE * _rng.randf_range(0.8, 1.2))
				_add(flowers, key, xf, FLOWER_COLOURS[_rng.randi() % FLOWER_COLOURS.size()])
			else:
				var s := _rng.randf_range(0.75, 1.25) * (1.15 if verge else 1.0)
				xf = xf.scaled_local(Vector3(s, s * _rng.randf_range(0.85, 1.2), s))
				# A shade darker and warmer than the ground under it, so a clump reads as a clump.
				_add(tufts, key, xf, grass.darkened(0.10).lerp(Color(0.30, 0.62, 0.20), 0.25))
			placed += 1
		x += STEP
	var tuft_mesh := _tuft_mesh()
	var flower_mesh := _flower_mesh()
	for key: Vector2i in tufts:
		_chunk(tuft_mesh, tufts[key])
	for key: Vector2i in flowers:
		_chunk(flower_mesh, flowers[key])
	return placed


func _excluded(p: Vector2, region_list: Array) -> bool:
	if p.distance_to(StreetScript.PLAZA_CENTRE) < StreetScript.PLAZA_RADIUS + 0.8:
		return true
	if absf(p.x - StreetScript.CENTRE_X) < StreetScript.HALF_WIDTH + 0.8 \
			and p.y > StreetScript.FROM_Z - 1.0 and p.y < StreetScript.TO_Z + 1.0:
		return true
	if PropsScript.is_in_pen_plots(p.x, p.y):
		return true
	for r: Variant in region_list:
		var region := r as RegionData
		if region == null:
			continue
		if region.lake_depth > 0.0 \
				and p.distance_to(region.centre) < TerrainScript.shore_radius(region) + 0.6:
			return true
		if String(region.id) == "strip" and p.distance_to(region.centre) < region.radius:
			return true
	return false


func _add(bucket: Dictionary, key: Vector2i, xf: Transform3D, colour: Color) -> void:
	if not bucket.has(key):
		bucket[key] = []
	(bucket[key] as Array).append([xf, colour])


func _chunk(mesh: Mesh, items: Array) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = items.size()
	for i in items.size():
		mm.set_instance_transform(i, items[i][0])
		mm.set_instance_color(i, items[i][1])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = VISIBLE_METRES
	mmi.visibility_range_end_margin = 8.0
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(mmi)


static func _material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.roughness = 1.0
	return m


## Five blades leaning out from one root, dark at the foot and light at the tip.
static func _tuft_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 5:
		var a := TAU * float(k) / 5.0 + 0.4
		var out := Vector3(cos(a), 0.0, sin(a))
		var side := Vector3(-out.z, 0.0, out.x) * 0.065
		var tip := out * 0.13 + Vector3.UP * (0.23 + 0.07 * float(k % 3))
		var n := (out + Vector3.UP * 0.8).normalized()
		st.set_normal(n)
		st.set_color(Color(0.82, 0.82, 0.82))
		st.add_vertex(-side + out * 0.03)
		st.set_normal(n)
		st.set_color(Color(0.82, 0.82, 0.82))
		st.add_vertex(side + out * 0.03)
		st.set_normal(n)
		st.set_color(Color(1.15, 1.15, 0.95))
		st.add_vertex(tip)
	var mesh := st.commit()
	mesh.surface_set_material(0, _material())
	return mesh


## Five round petals and a gold eye, flat on a short stem, facing the sky.
static func _flower_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := 0.16
	var stem := Color(0.35, 0.55, 0.25)
	# The stem: one thin upright blade.
	for v: Vector3 in [Vector3(-0.012, 0, 0), Vector3(0.012, 0, 0), Vector3(0, h, 0)]:
		st.set_normal(Vector3.BACK)
		st.set_color(stem)
		st.add_vertex(v)
	for k in 5:
		var a := TAU * float(k) / 5.0
		var c := Vector3(cos(a), 0.0, sin(a)) * 0.045 + Vector3.UP * h
		for j in 6:
			var b0 := TAU * float(j) / 6.0
			var b1 := TAU * float(j + 1) / 6.0
			for v: Vector3 in [c, c + Vector3(cos(b0), 0, sin(b0)) * 0.035, c + Vector3(cos(b1), 0, sin(b1)) * 0.035]:
				st.set_normal(Vector3.UP)
				st.set_color(Color.WHITE)
				st.add_vertex(v)
	for j in 6:
		var b0 := TAU * float(j) / 6.0
		var b1 := TAU * float(j + 1) / 6.0
		var c := Vector3.UP * (h + 0.004)
		# The instance colour tints the whole flower, so the eye is a warm tint over the petals.
		for v: Vector3 in [c, c + Vector3(cos(b0), 0, sin(b0)) * 0.025, c + Vector3(cos(b1), 0, sin(b1)) * 0.025]:
			st.set_normal(Vector3.UP)
			st.set_color(Color(1.0, 0.75, 0.2))
			st.add_vertex(v)
	var mesh := st.commit()
	mesh.surface_set_material(0, _material())
	return mesh
