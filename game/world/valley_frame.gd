class_name ValleyFrame
extends Node3D
## THE EDGES OF HAYBROOK VALE: the ring of green hills around the playable square, the
## Rainbow Factory on its cloud above the northern ridge, and the Rainbow pouring out
## of it across the sky (STORY.md section 1). All three are seen from everywhere and none
## can be reached on foot; the Works is visited only through its lift.
##
## `set_brightness` is the delivery feedback (clue 1): each pony sent up makes it a little
## brighter. `set_bands` is the Rescue path's progress bar: each pylon cut takes one away.

const RIM := "res://assets/models/valley_rim.glb"
const WORKS := "res://assets/models/prism_works.glb"
const RAINBOW_SHADER := preload("res://shaders/rainbow.gdshader")
const ToonStylerScript := preload("res://systems/toon_styler.gd")

## Where the Works floats (ranch space) and how big.
const WORKS_AT := Vector3(34.0, 58.0, -236.0)
const WORKS_SCALE := 1.5
## The rainbow's two feet: the Works' spout, and the north-western hills, so it stands as one
## great arch across the northern sky from wherever you are in the valley.
const RAINBOW_FROM := Vector3(52.0, 92.0, -228.0)
const RAINBOW_TO := Vector3(-215.0, -8.0, -110.0)
const RAINBOW_LIFT := 95.0
const RAINBOW_WIDTH := 36.0
const RAINBOW_SEGMENTS := 96

var rainbow: MeshInstance3D
var _rainbow_mat: ShaderMaterial


func _ready() -> void:
	_stand(RIM, Vector3(0, -3.0, 0), 1.0, &"building")
	_stand(WORKS, WORKS_AT, WORKS_SCALE, &"building")
	_build_rainbow()
	_plant_ridges()


## TREE LINES ON THE RIDGES (Fable AAA round 3, #2 and #10: "the far hills are bald pale
## domes"). The show's round puffy trees, in clumps along the upper slopes of the rim hills:
## one MultiMesh, placed on the rim mesh's own up-facing vertices, seeded so it never moves.
const RIDGE_GREENS: Array[Color] = [Color(0.26, 0.62, 0.20), Color(0.34, 0.72, 0.24),
	Color(0.20, 0.54, 0.22), Color(0.44, 0.76, 0.28)]


func _plant_ridges() -> void:
	var rim: Node3D = get_node_or_null(^"Rim") as Node3D
	if rim == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261109
	# Random points over the rim's up-facing triangles, as many per triangle as its area
	# earns (the rim is low-poly: its vertices alone were a handful of spots).
	var picks: Array[Vector3] = []
	for mi: MeshInstance3D in rim.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for si in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(si)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null \
				else PackedInt32Array()
			var tri_count := idx.size() / 3 if idx.size() > 0 else verts.size() / 3
			for t in tri_count:
				var i0 := idx[t * 3] if idx.size() > 0 else t * 3
				var i1 := idx[t * 3 + 1] if idx.size() > 0 else t * 3 + 1
				var i2 := idx[t * 3 + 2] if idx.size() > 0 else t * 3 + 2
				var a := mi.global_transform * verts[i0]
				var b := mi.global_transform * verts[i1]
				var c := mi.global_transform * verts[i2]
				var cross := (b - a).cross(c - a)
				var area := cross.length() * 0.5
				var n := cross.normalized()
				if absf(n.y) < 0.55:
					continue
				var mid := (a + b + c) / 3.0
				if mid.y < 3.0 or maxf(absf(mid.x), absf(mid.z)) < 114.0:
					continue
				var want := area / 260.0
				var count := int(want) + (1 if rng.randf() < fmod(want, 1.0) else 0)
				for k in count:
					var u := rng.randf()
					var v := rng.randf()
					if u + v > 1.0:
						u = 1.0 - u
						v = 1.0 - v
					var base := a + (b - a) * u + (c - a) * v
					# A clump of one to three round the spot.
					for j in rng.randi_range(1, 3):
						picks.append(base + Vector3(rng.randf_range(-3.0, 3.0), -0.4, rng.randf_range(-3.0, 3.0)))
	if picks.is_empty():
		return
	# THREE SHAPES, NOT ONE (Fable AAA round 4, #6: "one lollipop tree duplicated across every
	# hill"): round puffs, tall cone pines (the darker greens) and double-puff broadleaves,
	# one MultiMesh per shape.
	var kinds: Array = [[_ridge_tree_mesh(), []], [_ridge_pine_mesh(), []], [_ridge_double_mesh(), []]]
	for p in picks:
		var k := 0 if rng.randf() < 0.45 else (1 if rng.randf() < 0.55 else 2)
		(kinds[k][1] as Array).append(p)
	for k in kinds.size():
		var spots: Array = kinds[k][1]
		if spots.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = kinds[k][0]
		mm.instance_count = spots.size()
		for i in spots.size():
			var sz := rng.randf_range(3.2, 5.6)
			var tall := rng.randf_range(0.9, 1.25) * (1.5 if k == 1 else 1.0)
			var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sz, sz * tall, sz)), spots[i])
			mm.set_instance_transform(i, xf)
			var green: Color = RIDGE_GREENS[rng.randi() % RIDGE_GREENS.size()]
			mm.set_instance_color(i, green.darkened(0.22) if k == 1 else green)
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "RidgeTrees%d" % k
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)


## A tall cone pine: two stacked cones on a stub of trunk.
static func _ridge_pine_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tier: Array in [[0.5, 0.75, 0.45], [0.36, 0.62, 0.95]]:
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = tier[0]
		cone.height = tier[1]
		cone.radial_segments = 10
		st.append_from(_tinted(cone, Color.WHITE), 0, Transform3D(Basis(), Vector3(0, tier[2], 0)))
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.06
	trunk.bottom_radius = 0.09
	trunk.height = 0.3
	trunk.radial_segments = 6
	st.append_from(_tinted(trunk, Color(0.55, 0.38, 0.28)), 0, Transform3D(Basis(), Vector3(0, 0.15, 0)))
	return _ridge_finish(st)


## A broadleaf: two overlapping puffs, one higher and smaller, on a trunk.
static func _ridge_double_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for puff: Array in [[0.5, Vector3(-0.18, 0.85, 0.0)], [0.4, Vector3(0.22, 1.12, 0.05)]]:
		var sph := SphereMesh.new()
		sph.radius = puff[0]
		sph.height = float(puff[0]) * 1.8
		sph.radial_segments = 12
		sph.rings = 6
		st.append_from(_tinted(sph, Color.WHITE), 0, Transform3D(Basis(), puff[1]))
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.07
	trunk.bottom_radius = 0.1
	trunk.height = 0.6
	trunk.radial_segments = 6
	st.append_from(_tinted(trunk, Color(0.55, 0.38, 0.28)), 0, Transform3D(Basis(), Vector3(0, 0.3, 0)))
	return _ridge_finish(st)


static func _tinted(prim: PrimitiveMesh, colour: Color) -> ArrayMesh:
	var arr := prim.get_mesh_arrays()
	var cols := PackedColorArray()
	cols.resize((arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
	cols.fill(colour)
	arr[Mesh.ARRAY_COLOR] = cols
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


static func _ridge_finish(st: SurfaceTool) -> Mesh:
	var mesh := st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.roughness = 1.0
	mesh.surface_set_material(0, m)
	return mesh


## One show tree: a short trunk under a round canopy, flat-shaded in the toon band.
static func _ridge_tree_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var canopy := SphereMesh.new()
	canopy.radius = 0.55
	canopy.height = 1.0
	canopy.radial_segments = 12
	canopy.rings = 6
	var canopy_mesh := ArrayMesh.new()
	var carr := canopy.get_mesh_arrays()
	var ccols := PackedColorArray()
	ccols.resize((carr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
	ccols.fill(Color.WHITE)
	carr[Mesh.ARRAY_COLOR] = ccols
	canopy_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, carr)
	st.append_from(canopy_mesh, 0, Transform3D(Basis(), Vector3(0, 1.0, 0)))
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.08
	trunk.bottom_radius = 0.11
	trunk.height = 0.6
	trunk.radial_segments = 6
	var trunk_mesh := ArrayMesh.new()
	var arr := trunk.get_mesh_arrays()
	var cols := PackedColorArray()
	cols.resize((arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
	cols.fill(Color(0.55, 0.38, 0.28))
	arr[Mesh.ARRAY_COLOR] = cols
	trunk_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	st.append_from(trunk_mesh, 0, Transform3D(Basis(), Vector3(0, 0.3, 0)))
	var mesh := st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.roughness = 1.0
	mesh.surface_set_material(0, m)
	return mesh


func _stand(path: String, at: Vector3, s: float, category: StringName) -> void:
	if not ResourceLoader.exists(path):
		return
	var inst: Node3D = (load(path) as PackedScene).instantiate()
	inst.position = at
	inst.scale = Vector3.ONE * s
	if path == RIM:
		inst.name = "Rim"
	add_child(inst)
	ToonStylerScript.style(inst, category)
	for node in inst.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## An arc through RAINBOW_FROM and RAINBOW_TO bulging RAINBOW_LIFT up at its middle, as a
## flat band facing the valley's centre.
func _build_rainbow() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var side := (RAINBOW_TO - RAINBOW_FROM).cross(Vector3.UP).normalized()
	for i in range(RAINBOW_SEGMENTS + 1):
		var t := float(i) / RAINBOW_SEGMENTS
		var p := _arc(t)
		var p2 := _arc(minf(t + 0.001, 1.0))
		var tangent := (p2 - p).normalized() if t < 1.0 else (p - _arc(t - 0.001)).normalized()
		var across := tangent.cross(side).normalized()
		var inner := p - across * RAINBOW_WIDTH * 0.5
		var outer := p + across * RAINBOW_WIDTH * 0.5
		st.set_uv(Vector2(t, 1.0))
		st.add_vertex(inner)
		st.set_uv(Vector2(t, 0.0))
		st.add_vertex(outer)
	for i in range(RAINBOW_SEGMENTS):
		var a := i * 2
		st.add_index(a)
		st.add_index(a + 1)
		st.add_index(a + 2)
		st.add_index(a + 1)
		st.add_index(a + 3)
		st.add_index(a + 2)
	rainbow = MeshInstance3D.new()
	rainbow.name = "Rainbow"
	rainbow.mesh = st.commit()
	rainbow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rainbow_mat = ShaderMaterial.new()
	_rainbow_mat.shader = RAINBOW_SHADER
	rainbow.material_override = _rainbow_mat
	rainbow.extra_cull_margin = 400.0
	add_child(rainbow)


func _arc(t: float) -> Vector3:
	var p := RAINBOW_FROM.lerp(RAINBOW_TO, t)
	p.y += sin(t * PI) * RAINBOW_LIFT
	return p


## 1.0 is the opening valley; every delivery nudges it up, capped well short of glare.
func set_brightness(b: float) -> void:
	if _rainbow_mat != null:
		_rainbow_mat.set_shader_parameter(&"brightness", clampf(b, 0.4, 2.2))


func set_bands(n: int) -> void:
	if _rainbow_mat != null:
		_rainbow_mat.set_shader_parameter(&"bands", clampi(n, 0, 7))
		rainbow.visible = n > 0


## Brightness for `deliveries` ponies sent up so far.
static func brightness_for(deliveries: int) -> float:
	return 1.0 + 0.06 * float(deliveries)


## A sparkle of `color` rises from `from` and flies into the rainbow's foot at the Works;
## when it lands the rainbow takes `brightness`.
func send_up(from: Vector3, color: Color, brightness: float) -> void:
	var orb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.35
	sphere.height = 0.7
	orb.mesh = sphere
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color.lightened(0.2)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 2.5
	orb.material_override = m
	add_child(orb)
	orb.global_position = from
	var trail := BloomCeremony.sparkles([color.lightened(0.3), color, Color(1, 1, 1)])
	trail.one_shot = false
	trail.amount = 24
	trail.lifetime = 0.9
	trail.explosiveness = 0.0
	(trail.process_material as ParticleProcessMaterial).initial_velocity_max = 0.6
	(trail.process_material as ParticleProcessMaterial).initial_velocity_min = 0.1
	orb.add_child(trail)
	trail.emitting = true
	var mid := from.lerp(RAINBOW_FROM, 0.5) + Vector3(0, 40, 0)
	var t := create_tween()
	t.tween_method(func(u: float) -> void:
		var a := from.lerp(mid, u)
		var b := mid.lerp(RAINBOW_FROM, u)
		orb.global_position = a.lerp(b, u)
		orb.scale = Vector3.ONE * lerpf(1.0, 3.0, u), 0.0, 1.0, 4.0).set_trans(Tween.TRANS_SINE)
	t.tween_callback(func() -> void:
		set_brightness(brightness)
		orb.queue_free())
