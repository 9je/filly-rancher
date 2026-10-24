class_name RegionFence
extends Node3D
## THE RING AROUND A LOCKED REGION. A regular polygon of rails and posts standing
## RING_MARGIN outside the region's own radius, with one segment carrying a gate whose leaf
## is the only collider a permit removes. Built from primitives the way game/world/pen.gd
## builds a paddock, and for the same reason: nothing under game/assets/converted/ is in
## git, so a fence made of models would not exist on a CI checkout (docs/ci.md section 4).
##
## LAYERS, AND WHY THIS IS NOT A PADDOCK GATE. Rails and posts are PROPS, so the player,
## every pony and the camera's spring arm all see them. The leaf is PROPS *and* PEN_GATE
## while shut and nothing at all while open, which is deliberately the opposite policy to
## game/world/pen.gd's gateway. A paddock's leaf is PEN_GATE alone because it has to be a
## wall to a pony and a doorway to a farmer forever. A region's leaf is a LOCK: shut, it
## must stop everybody, including the player, because stopping HER is the entire point of a
## permit; open, it must stop nobody, because the ponies who live inside are held there by
## game/scripts/pony_leash.gd and a border that kept turning them back would be doing the
## leash's job badly and invisibly.
##
## THE COLLIDER DOES NOT SWING. The leaf's bars hang under a hinge that rotates, so the gate
## visibly opens; its collision shape is a child of a body that never moves, and set_open()
## changes that body's LAYER instead. game/test/test_pen_gate.gd learned this the hard way
## for paddocks: a collider parented to the thing it is drawn on turns every animation frame
## into a hole in the fence.
##
## Preloaded BY PATH by its consumers, never by this `class_name`, per the convention
## documented at the top of game/scripts/pony_rig.gd.

const LayersScript := preload("res://world/collision_layers.gd")
const PenScript := preload("res://world/pen.gd")

## How many sides the ring is drawn with. 28 is enough that the polygon reads as a circle
## from inside it and few enough that a big region does not cost hundreds of boxes.
const SEGMENTS := 28
## How far outside the region's radius the fence stands. The rim of a region is where its
## grass blends and where a ZoneMarker drops ponies; a fence post landing in that band would
## put timber in the middle of the meadow it is supposed to edge.
const RING_MARGIN := 3.0
## The clear width of the gateway. A segment of a big region's ring is far wider than a gate
## has any business being, so the leaf is capped at this and the rest of that segment is
## ordinary rail.
const GATE_WIDTH := 4.0
## How far the leaf swings, and how fast. Only the bars move; see the header.
const GATE_OPEN_DEGREES := 95.0
const GATE_SWING_DEGREES_PER_SECOND := 140.0

var _region: RegionData
var _ground := Callable()
var _rails: StaticBody3D
## Every post and rail of the ring, gathered into one mesh (see _commit_mesh).
var _post_st: SurfaceTool
var _rail_st: SurfaceTool
var _gate: StaticBody3D
var _hinge: Node3D
var _open := false
## Degrees the leaf is currently swung open by, walked toward its target in _process().
var _angle := 0.0
## The bearing of the gate segment, kept so the swing does not have to re-derive it.
var _gate_yaw := 0.0
## The middle of the gateway, in this node's own space.
var _gate_local := Vector3.ZERO


func configure(region: RegionData, ground_sampler: Callable) -> void:
	_region = region
	_ground = ground_sampler


func region() -> RegionData:
	return _region


## Ground height under an XZ point, or the y = 0 plane when nobody handed us a sampler (which
## is what game/test/test_region_fence.gd does, and what a fence built before the terrain
## would see).
func _y(x: float, z: float) -> float:
	return float(_ground.call(x, z)) if _ground.is_valid() else 0.0


## Build the ring. The gate goes on the segment whose midpoint bearing is closest to the
## region's gate_yaw_degrees, so a region can point its entrance at the road.
##
## A REBUILD DOES NOT RE-LOCK A BOUGHT REGION. Whether the gate is open is a fact about the
## save file, not about the geometry, so it is captured here and restored at the end; a ring
## rebuilt because the terrain under it changed would otherwise take the player's permit
## away, and the toast that sells it would be the only clue.
func build() -> void:
	var was_open := _open
	# Not move_toward()'s starting point but its finishing one: a gate that was already open
	# must come back open, not play a closing swing it never earned.
	_angle = GATE_OPEN_DEGREES if was_open else 0.0
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_rails = StaticBody3D.new()
	_rails.name = "Rails"
	_rails.collision_layer = LayersScript.PROPS
	_rails.collision_mask = 0
	add_child(_rails)
	_gate = StaticBody3D.new()
	_gate.name = "Gate"
	_gate.collision_mask = 0
	add_child(_gate)
	_hinge = Node3D.new()
	_hinge.name = "GateHinge"
	add_child(_hinge)

	var ring: float = _region.radius + RING_MARGIN
	var centre := Vector3(_region.centre.x, 0.0, _region.centre.y)
	var gate_bearing := deg_to_rad(_region.gate_yaw_degrees)
	var gate_index := 0
	var best := TAU
	for i in range(SEGMENTS):
		var mid := (float(i) + 0.5) * TAU / float(SEGMENTS)
		var diff: float = absf(angle_difference(mid, gate_bearing))
		if diff < best:
			best = diff
			gate_index = i

	var post_mat := PenScript._material_static(PenScript.POST_COLOR)
	var rail_mat := PenScript._material_static(PenScript.RAIL_COLOR)
	_post_st = SurfaceTool.new()
	_post_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_rail_st = SurfaceTool.new()
	_rail_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(SEGMENTS):
		var a0 := float(i) * TAU / float(SEGMENTS)
		var a1 := float(i + 1) * TAU / float(SEGMENTS)
		var p0 := centre + Vector3(cos(a0), 0.0, -sin(a0)) * ring
		var p1 := centre + Vector3(cos(a1), 0.0, -sin(a1)) * ring
		p0.y = _y(p0.x, p0.z)
		p1.y = _y(p1.x, p1.z)
		_post(p0, post_mat)
		if i == gate_index:
			_gate_segment(p0, p1, rail_mat, post_mat)
		else:
			_rail_segment(p0, p1, rail_mat)
	_commit_mesh(post_mat, rail_mat)
	set_open(was_open)


## ONE MESH FOR THE RING, not one per post and rail: a ring was 113 meshes, and the four rings
## were 452 shadow casters, a third of every frame's draw calls (scenes/test/perf.gd
## exp=casters). The colliders stay one box apiece; only the drawing is merged.
func _commit_mesh(post_mat: StandardMaterial3D, rail_mat: StandardMaterial3D) -> void:
	var mesh := ArrayMesh.new()
	_post_st.commit(mesh)
	mesh.surface_set_material(mesh.get_surface_count() - 1, post_mat)
	_rail_st.commit(mesh)
	mesh.surface_set_material(mesh.get_surface_count() - 1, rail_mat)
	var mi := MeshInstance3D.new()
	mi.name = "RingMesh"
	mi.mesh = mesh
	_rails.add_child(mi)
	_post_st = null
	_rail_st = null


## One post, sunk POST_BURY into the ground so a slope never shows daylight under it, the
## same trick game/world/pen.gd's posts use.
func _post(at: Vector3, mat: StandardMaterial3D) -> void:
	var box := BoxMesh.new()
	box.size = Vector3(PenScript.POST_SIZE, PenScript.FENCE_HEIGHT + PenScript.POST_BURY,
		PenScript.POST_SIZE)
	var pos := at + Vector3(0.0, (PenScript.FENCE_HEIGHT - PenScript.POST_BURY) * 0.5, 0.0)
	_post_st.append_from(box, 0, Transform3D(Basis(), pos))
	var shape := CollisionShape3D.new()
	var col := BoxShape3D.new()
	col.size = box.size
	shape.shape = col
	shape.position = pos
	_rails.add_child(shape)


## Three rails from `p0` to `p1`, drawn and made solid on the PROPS body. They follow the
## ground by tilting between the two posts rather than by stepping, so a ring crossing a
## hillside stays a fence rather than a row of gaps.
func _rail_segment(p0: Vector3, p1: Vector3, mat: StandardMaterial3D) -> void:
	var span := p1 - p0
	var length := span.length()
	var mid := (p0 + p1) * 0.5
	var yaw := atan2(-span.z, span.x)
	var pitch := -atan2(span.y, Vector2(span.x, span.z).length())
	for h: float in PenScript.RAIL_HEIGHTS:
		var box := BoxMesh.new()
		box.size = Vector3(length, PenScript.RAIL_THICKNESS, PenScript.RAIL_DEPTH)
		var xf := Transform3D(Basis.from_euler(Vector3(0.0, yaw, pitch)), mid + Vector3(0.0, h, 0.0))
		_rail_st.append_from(box, 0, xf)
		var shape := CollisionShape3D.new()
		var col := BoxShape3D.new()
		col.size = box.size
		shape.shape = col
		shape.transform = xf
		_rails.add_child(shape)


## The gateway. The leaf hangs on the hinge at `p0` and is GATE_WIDTH wide at most; whatever
## is left of the segment beyond it is ordinary rail, so the doorway is the same size at
## every region however big the ring around it is.
func _gate_segment(p0: Vector3, p1: Vector3, mat: StandardMaterial3D,
		post_mat: StandardMaterial3D) -> void:
	var span := p1 - p0
	var length := span.length()
	var leaf: float = minf(GATE_WIDTH, length)
	var yaw := atan2(-span.z, span.x)
	_gate_yaw = yaw
	_hinge.position = p0
	# Not simply `yaw`: build() may be restoring a gate that was already standing open, and
	# a leaf that snapped shut for one frame would read as the permit lapsing.
	_hinge.rotation.y = yaw + deg_to_rad(-_angle)

	var leaf_mat := PenScript._material_static(PenScript.GATE_COLOR)
	for h: float in PenScript.RAIL_HEIGHTS:
		var box := BoxMesh.new()
		box.size = Vector3(leaf, PenScript.RAIL_THICKNESS, PenScript.RAIL_DEPTH)
		box.material = leaf_mat
		var mesh := MeshInstance3D.new()
		mesh.mesh = box
		mesh.position = Vector3(leaf * 0.5, h, 0.0)
		_hinge.add_child(mesh)

	# ONE SOLID SLAB rather than three bars: the bars are what you look at, but a pony
	# nosing at a shut gate should meet a gate and not the gap between its rails.
	_gate_local = p0 + span.normalized() * (leaf * 0.5)
	var shape := CollisionShape3D.new()
	var col := BoxShape3D.new()
	col.size = Vector3(leaf, PenScript.FENCE_HEIGHT, PenScript.RAIL_DEPTH)
	shape.shape = col
	shape.position = _gate_local + Vector3(0.0, PenScript.FENCE_HEIGHT * 0.5, 0.0)
	shape.rotation.y = yaw
	_gate.add_child(shape)

	if length - leaf > 0.01:
		# The cap applied, so this segment is part gate and part fence. The junction gets a
		# post of its own: without one the leftover rail starts in mid-air, and the leaf has
		# nothing to shut against.
		var junction := p0 + span.normalized() * leaf
		_post(junction, post_mat)
		_rail_segment(junction, p1, mat)


## Unlock or lock the border. The layer IS the lock: see the header on why the collider does
## not move and why an open gate is open to ponies as well.
func set_open(open: bool) -> void:
	_open = open
	if _gate != null:
		_gate.collision_layer = 0 if open else (LayersScript.PEN_GATE | LayersScript.PROPS)
	# A swing just started (or the target moved out from under a finished one): wake
	# _process() back up. It puts itself back to sleep once the leaf settles.
	var target: float = GATE_OPEN_DEGREES if _open else 0.0
	if not is_equal_approx(_angle, target):
		set_process(true)


func is_open() -> bool:
	return _open


## The middle of the gateway in world space, for the toast that offers the permit and for
## the probe that decides whether the player is standing at it.
func gate_position() -> Vector3:
	return global_transform * _gate_local if is_inside_tree() else _gate_local


func gate_body() -> StaticBody3D:
	return _gate


func _process(delta: float) -> void:
	if _hinge == null:
		return
	var target: float = GATE_OPEN_DEGREES if _open else 0.0
	if is_equal_approx(_angle, target):
		# Settled: nothing left to animate, so stop paying for a per-frame callback on a
		# ring that just stands there most of the game. set_open() wakes this back up.
		set_process(false)
		return
	_angle = move_toward(_angle, target, GATE_SWING_DEGREES_PER_SECOND * delta)
	_hinge.rotation.y = _gate_yaw + deg_to_rad(-_angle)
