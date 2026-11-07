class_name Street
extends Node3D
## THE TOWN ROW'S STREET AND ITS YARDS (PS4 item 36; playtest 2026-11-05: "Ponyville row: houses
## lean and sink into the slope, lamp posts lean, no streets or yards, grey road meets dirt road
## badly" [33]). The dirt road ran between the houses as a painted stripe and stopped against the
## Strip's paving. Now, from a kerb across the road at FROM_Z, the road through the row is paved
## in the Strip's own flagstones, kerbed both sides, and runs on into the Strip's paving; each
## house has a low picket fence across its front with a gate at its door and a paved path from
## the gate to the door. Laid over the ground a few centimetres up and following it, like the
## Strip's paving: drawing, except the fences, which are solid.

const LayersScript := preload("res://world/collision_layers.gd")
const ToonStylerScript := preload("res://systems/toon_styler.gd")

## Where the paving starts, at the kerb, and where it ends, under the Strip's own paving.
const FROM_Z := 26.5
const TO_Z := 50.0
## The road's centre line through the row (Terrain.PATH_POINTS) and the paved width.
const CENTRE_X := 1.5
const HALF_WIDTH := 3.25
const LIFT := 0.03
const STEP := 1.0
const KERB_WIDTH := 0.3
const KERB_LIFT := 0.08
## The yard: its fence stands this far out from the kerb, and is this tall.
const FENCE_OFF_KERB := 0.8
const FENCE_HEIGHT := 0.95
const POST_EVERY := 1.2
const GATE_WIDTH := 1.8
const PATH_HALF := 0.7
const FENCE_COLOUR := Color(0.96, 0.93, 0.86)
## The yards stop short of the Strip's paving (its rim crosses the row near z 48.8).
const YARD_END_Z := 48.3

var _height: Callable
## Each yard as {"house": name, "door": Vector2, "front_x": float, "z0": float, "z1": float,
## "side": +1 east of the street or -1 west, "runs": Array of [Vector2, Vector2]}.
var _yards: Array[Dictionary] = []


func yards() -> Array[Dictionary]:
	return _yards


## Lay the street and fence the yards of `houses` (the town row's placed nodes). `door_offset`
## maps a model file name to its door's offset from the model's middle along the model's own
## x axis, in metres at the placed scale.
func build(height_at: Callable, houses: Array[Node3D], door_offset: Dictionary) -> void:
	_height = height_at
	var paving := SurfaceTool.new()
	paving.begin(Mesh.PRIMITIVE_TRIANGLES)
	var kerb := SurfaceTool.new()
	kerb.begin(Mesh.PRIMITIVE_TRIANGLES)
	var fence := SurfaceTool.new()
	fence.begin(Mesh.PRIMITIVE_TRIANGLES)
	var body := StaticBody3D.new()
	body.name = "FenceBody"
	body.collision_layer = LayersScript.PROPS
	body.collision_mask = 0

	# The street, kerb to kerb.
	_ribbon(paving, Vector2(CENTRE_X - HALF_WIDTH, FROM_Z), Vector2(CENTRE_X + HALF_WIDTH, TO_Z), LIFT)
	# The kerb across the road where the dirt meets the paving: the join, said out loud.
	_ribbon(kerb, Vector2(CENTRE_X - HALF_WIDTH - KERB_WIDTH, FROM_Z - KERB_WIDTH),
		Vector2(CENTRE_X + HALF_WIDTH + KERB_WIDTH, FROM_Z), KERB_LIFT)

	var gates_by_side := {-1: [], 1: []}
	for h: Node3D in houses:
		var yard := _yard_for(h, door_offset)
		if yard.is_empty():
			continue
		_yards.append(yard)
		(gates_by_side[int(yard.side)] as Array).append(float((yard.door as Vector2).y))
		# The path from the gate to the door.
		var kerb_x: float = CENTRE_X + float(yard.side) * HALF_WIDTH
		var door: Vector2 = yard.door
		var x0 := minf(kerb_x, float(yard.front_x))
		var x1 := maxf(kerb_x, float(yard.front_x))
		_ribbon(paving, Vector2(x0, door.y - PATH_HALF), Vector2(x1, door.y + PATH_HALF), LIFT + 0.005)
		for run: Array in yard.runs:
			_fence_run(fence, body, run[0], run[1])

	# The kerbs along both sides, open where a garden path meets the street.
	for side: int in [-1, 1]:
		var x: float = CENTRE_X + float(side) * (HALF_WIDTH + KERB_WIDTH * 0.5)
		var z := FROM_Z
		var gates: Array = (gates_by_side[side] as Array).duplicate()
		gates.sort()
		for g: float in gates:
			if g - PATH_HALF > z:
				_ribbon(kerb, Vector2(x - KERB_WIDTH * 0.5, z), Vector2(x + KERB_WIDTH * 0.5, g - PATH_HALF), KERB_LIFT)
			z = g + PATH_HALF
		if TO_Z - 1.0 > z:
			_ribbon(kerb, Vector2(x - KERB_WIDTH * 0.5, z), Vector2(x + KERB_WIDTH * 0.5, TO_Z - 1.0), KERB_LIFT)

	_commit(paving, "Paving", _stone(Color(0.76, 0.69, 0.62), Color(0.55, 0.48, 0.44)))
	_commit(kerb, "Kerb", _stone(Color(0.58, 0.53, 0.5), Color(0.42, 0.38, 0.36)))
	var fence_mat := StandardMaterial3D.new()
	fence_mat.albedo_color = FENCE_COLOUR
	fence_mat.roughness = 0.8
	var fences := _commit(fence, "YardFences", fence_mat)
	# Lit like every other prop on the map (systems/toon_styler.gd), not as a plain material.
	ToonStylerScript.style(fences, &"prop")
	add_child(body)


## A house's yard: its door, the front wall facing the street, and the fence runs (gated at the
## door). Empty for a house that does not face the street.
func _yard_for(h: Node3D, door_offset: Dictionary) -> Dictionary:
	var box := _box(h)
	if box.size == Vector3.ZERO:
		return {}
	var side := 1 if box.get_center().x > CENTRE_X else -1
	var front_x: float = box.position.x if side > 0 else box.end.x
	var fence_x: float = CENTRE_X + float(side) * (HALF_WIDTH + KERB_WIDTH + FENCE_OFF_KERB)
	var file := String(h.name).rsplit("_", true, 1)[0] + ".glb"
	var along: Vector3 = h.global_transform.basis.x.normalized()
	var off: float = float(door_offset.get(file, 0.0))
	var centre := Vector3(box.get_center().x, 0.0, box.get_center().z)
	var door3: Vector3 = centre + along * off
	var door := Vector2(front_x, door3.z)
	var z0 := box.position.z + 0.3
	# Not out onto the Strip's own paving, which begins about here on the street's line.
	var z1 := minf(box.end.z - 0.3, YARD_END_Z)
	var runs: Array = []
	if door.y - GATE_WIDTH * 0.5 > z0:
		runs.append([Vector2(fence_x, z0), Vector2(fence_x, door.y - GATE_WIDTH * 0.5)])
	if door.y + GATE_WIDTH * 0.5 < z1:
		runs.append([Vector2(fence_x, door.y + GATE_WIDTH * 0.5), Vector2(fence_x, z1)])
	runs.append([Vector2(fence_x, z0), Vector2(front_x, z0)])
	runs.append([Vector2(fence_x, z1), Vector2(front_x, z1)])
	return {"house": String(h.name), "door": door, "front_x": front_x, "z0": z0, "z1": z1,
		"side": side, "fence_x": fence_x, "runs": runs}


func _box(h: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for m: MeshInstance3D in h.find_children("*", "MeshInstance3D", true, false):
		var a: AABB = m.global_transform * m.get_aabb()
		out = a if first else out.merge(a)
		first = false
	return out


func _y(x: float, z: float) -> float:
	return float(_height.call(x, z)) if _height.is_valid() else 0.0


## A flat strip from `a` to `b` (opposite corners, xz) laid over the ground at `lift`.
func _ribbon(st: SurfaceTool, a: Vector2, b: Vector2, lift: float) -> void:
	var nx := maxi(1, int(ceil(absf(b.x - a.x) / STEP)))
	var nz := maxi(1, int(ceil(absf(b.y - a.y) / STEP)))
	for ix in nx:
		for iz in nz:
			var x0 := lerpf(a.x, b.x, float(ix) / nx)
			var x1 := lerpf(a.x, b.x, float(ix + 1) / nx)
			var z0 := lerpf(a.y, b.y, float(iz) / nz)
			var z1 := lerpf(a.y, b.y, float(iz + 1) / nz)
			var q: Array[Vector3] = []
			for c: Vector2 in [Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z1), Vector2(x0, z1)]:
				q.append(Vector3(c.x, _y(c.x, c.y) + lift, c.y))
			# The Strip's own winding for the same corner order (strip.gd _paving), which faces up;
			# callers give a and b with a.x < b.x and a.y < b.y.
			for i: int in [0, 1, 2, 0, 2, 3]:
				st.set_normal(Vector3.UP)
				st.add_vertex(q[i])


## A picket fence from `a` to `b`: posts every POST_EVERY, two rails, solid.
func _fence_run(st: SurfaceTool, body: StaticBody3D, a: Vector2, b: Vector2) -> void:
	var length := a.distance_to(b)
	if length < 0.2:
		return
	var dir := (b - a) / length
	var n := maxi(1, int(ceil(length / POST_EVERY)))
	for i in n + 1:
		var p := a + dir * (length * float(i) / n)
		var y := _y(p.x, p.y)
		_box_mesh(st, Vector3(p.x, y + FENCE_HEIGHT * 0.5, p.y), Vector3(0.1, FENCE_HEIGHT, 0.1), dir)
	var mid := (a + b) * 0.5
	var ym := _y(mid.x, mid.y)
	for rail_y: float in [0.35, 0.8]:
		_box_mesh(st, Vector3(mid.x, ym + rail_y, mid.y), Vector3(0.05, 0.09, length), dir)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.12, FENCE_HEIGHT, length)
	shape.shape = box
	shape.transform = Transform3D(Basis(Vector3.UP, atan2(dir.x, dir.y)), Vector3(mid.x, ym + FENCE_HEIGHT * 0.5, mid.y))
	body.add_child(shape)


## A box of `size` (x across, z along `dir`) centred at `c`.
func _box_mesh(st: SurfaceTool, c: Vector3, size: Vector3, dir: Vector2) -> void:
	var basis := Basis(Vector3.UP, atan2(dir.x, dir.y))
	var h := size * 0.5
	var corners: Array[Vector3] = []
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				corners.append(c + basis * Vector3(sx * h.x, sy * h.y, sz * h.z))
	# Faces as corner indices (x bit 4, y bit 2, z bit 1). Each is turned to face out of the box
	# (its right-hand normal pointing away from the centre) and then emitted the other way round,
	# since Godot's front faces are clockwise.
	for f: Array in [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]:
		var q: Array[Vector3] = [corners[f[0]], corners[f[1]], corners[f[2]], corners[f[3]]]
		var normal := (q[1] - q[0]).cross(q[2] - q[0]).normalized()
		var face_centre := (q[0] + q[1] + q[2] + q[3]) * 0.25
		if normal.dot(face_centre - c) < 0.0:
			q.reverse()
			normal = -normal
		for i: int in [0, 2, 1, 0, 3, 2]:
			st.set_normal(normal)
			st.add_vertex(q[i])


func _stone(base: Color, joint: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/stonework.gdshader")
	mat.set_shader_parameter(&"pattern", 0)
	mat.set_shader_parameter(&"base", base)
	mat.set_shader_parameter(&"joint", joint)
	mat.set_shader_parameter(&"block_w", 1.1)
	mat.set_shader_parameter(&"block_h", 0.55)
	return mat


func _commit(st: SurfaceTool, node_name: String, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = st.commit()
	# On the surface, not as material_override: the toon styler swaps surface materials, and
	# an override would outrank what it puts there.
	if mi.mesh.get_surface_count() > 0:
		mi.mesh.surface_set_material(0, mat)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if node_name != "YardFences" \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mi)
	return mi
