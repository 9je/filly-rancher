class_name Props
extends Node3D
## The homestead: every static prop on the ranch, placed to scale, sat on the
## ground, and given collision.
##
## LOADED AT RUNTIME, NOT REFERENCED FROM THE SCENE FILE -- and that is a
## deliberate CI decision, not laziness. game/assets/converted/ is gitignored, so a
## CI checkout and a fresh clone have no props at all. The export-error gate in
## .github/workflows/build-and-smoke.yml fails the build if a scene statically
## references a resource that cannot be resolved, and ranch.tscn is now the MAIN
## SCENE, so a `[ext_resource path="res://assets/converted/props/..."]` line in it
## would break every CI run. Scanning PROP_DIR at runtime and skipping what is not
## there is docs/ci.md section 4's option (a): the ranch degrades gracefully to bare
## terrain instead of failing to export. ranch.gd then reports `assets=absent`
## explicitly, so a contentless ranch announces itself rather than passing silently.
##
## SCALE IS 1.5x AND THAT NUMBER IS NOT NEGOTIABLE HERE. docs/pipeline.md section 4
## derives it: Task 8 validated 3.0x against the old 4.28-unit ponies, and the
## Phase 1A metric rescale halved the pony side, so 3.0 * 2.138 / 4.276 = 1.5
## reproduces exactly the prop/pony relationship that was already judged to read
## correctly on screen. At 1.5x a Kenney 2-unit door module is 3 m, which clears the
## 2.14 m a pony actually needs (measured to the horn tip, NOT to the 1.16 m
## withers -- sizing anything pass-through off the withers figure produces doorways
## she cannot walk through).
##
## TREES ARE THE ONE CATEGORY-WIDE EXCEPTION, via TREE_SCALE below. Task 7's own
## renders showed the Nature Kit trees at BASE_SCALE alone standing 1.7-3.2 m --
## several of them visibly SHORTER than a 1.16 m pony, and next to the ranch's 5 m
## barn every one of them reads as a shrub. docs/pipeline.md section 4 recommended
## "roughly 2x" on top of BASE_SCALE as a starting point, not a settled answer; a 2x
## tree still tops out below the barn's eave. TREE_SCALE is 3x, confirmed from a
## render against both the barn and a pony -- see the fix report for what it showed.
##
## ...WITH ONE PER-PROP EXCEPTION, and it is a documented defect, not a fudge.
## kenney_survival_structure.glb came through the FBX branch of the pipeline, and
## Blender's automatic FBX unit conversion is not reliable for this pack: the same
## model measures 2.0 units as Kenney's own GLB and 0.50 units after the FBX
## round-trip -- 4x undersized (docs/pipeline.md section 4, quirk 4). It ships at
## its native broken scale on purpose (that doc records quirks rather than papering
## over them), so the correction has to happen at map-build time, here, exactly
## once, next to the reason.
##
## PROPS ARE SEATED BY THEIR OWN BOUNDING BOX, NOT BY THEIR ORIGIN, because the
## Kenney kits do not agree with each other about where a model's origin is. Measured
## on this exact prop set: kenney_survival_structure and kenney_market_stall have
## their origin at the base, while kenney_windmill and kenney_watermill have theirs at
## the CENTRE of the model -- so dropping each prop at `y = ground` buried the
## windmill 2.34 m and the watermill 1.35 m, exactly half their height each, and left
## the other two correct. It looked like a layout mistake and was actually an asset
## convention mismatch, which is why the fix is a measurement (shift each prop until
## its AABB floor meets the terrain) rather than a per-prop y offset typed in by hand.
## ranch.gd then asserts the seating held, so "nothing floats and nothing sinks" is a
## checked claim rather than a hopeful one.
##
## EVERY PROP GETS COLLISION. Generated per-MeshInstance3D as a trimesh, because
## these are static, concave, and the player must not walk through a barn. Convex
## hulls would have sealed the windmill's arches and a box would have made every
## tree a crate.

const LayersScript := preload("res://world/collision_layers.gd")

const PROP_DIR := "res://assets/converted/props/"

## docs/pipeline.md section 4. See the class comment.
const BASE_SCALE := 1.5

## Metres a seated prop's bottom is pushed below the terrain surface. Small and
## deliberate: the ground is a 2 m-cell heightfield, so a prop with any footprint
## sits across a slightly curved surface, and a base seated at exactly y=ground
## shows a hairline of daylight under its uphill edge.
const SINK_BIAS := 0.05

## Per-file multiplier ON TOP of BASE_SCALE. Only ever for a prop whose shipped
## asset is at a known-wrong scale.
const SCALE_FIX := {
	"kenney_survival_structure.glb": 4.0,  # FBX unit-conversion defect, quirk 4.
}

## Category-wide multiplier ON TOP of BASE_SCALE, applied to every "kenney_tree_*"
## entry in LAYOUT. Not a per-prop scale defect like SCALE_FIX above -- the Nature
## Kit trees are shipped at their intended scale, they are just stylised too small to
## read as trees once ponies and a real barn are standing next to them. See the class
## comment.
const TREE_SCALE := 3.0

## THE OPEN GROUND, reserved for Phase 1B's pen plots. Centre and half-extent in
## metres, on XZ. Nothing is placed here, no pony spawns here, and ranch.gd asserts
## both -- an "open area" that quietly grew a tree in it is exactly the kind of
## layout regression nobody notices until the feature that needed the space lands.
const PEN_PLOTS_CENTRE := Vector2(-14.0, 13.0)
const PEN_PLOTS_HALF_EXTENT := 9.0

## The homestead layout, hand-composed rather than scattered randomly.
##
## Read as a picture: the windmill is the tall thing you see from anywhere on the
## map and steer by; the watermill is the farmhouse you spawn facing; the survival
## structure is the barn beside the yard; the stall is the clutter that makes a yard
## look lived in. Trees ring the open country and thin out toward the buildings, so
## the homestead reads as a clearing somebody made rather than a field with objects
## dropped on it. `y` is never specified -- every prop is sat on height_at() so
## nothing floats and nothing sinks.
##
## `s` is an optional per-entry size jitter, applied on top of BASE_SCALE (and of
## SCALE_FIX). Fixed values rather than an RNG draw: a hand-varied treeline is
## reproducible, and reproducibility is what makes a screenshot regression legible.
## Note what is NOT here: a house or a barn. The kit has none -- see
## game/world/building.gd, which is why the ranch's two actual buildings are
## assembled from primitives instead. The Kenney pieces below are yard fixtures.
const LAYOUT := [
	# --- yard fixtures, all inside Terrain's flat apron ---------------------------
	{"file": "kenney_windmill.glb", "at": Vector2(3.5, -17.5), "yaw": 10.0},
	{"file": "kenney_watermill.glb", "at": Vector2(-17.0, -4.0), "yaw": 90.0},
	{"file": "kenney_survival_structure.glb", "at": Vector2(14.0, 2.0), "yaw": 90.0},
	{"file": "kenney_market_stall.glb", "at": Vector2(2.0, 3.0), "yaw": 200.0},
	# --- treeline ----------------------------------------------------------------
	{"file": "kenney_tree_oak.glb", "at": Vector2(-19.0, -19.0), "yaw": 0.0, "s": 1.15},
	{"file": "kenney_tree_pine.glb", "at": Vector2(-26.0, -8.0), "yaw": 40.0, "s": 1.25},
	{"file": "kenney_tree_default.glb", "at": Vector2(-22.0, 27.0), "yaw": 120.0, "s": 1.05},
	{"file": "kenney_tree_fat.glb", "at": Vector2(-5.0, -27.0), "yaw": 200.0, "s": 1.20},
	{"file": "kenney_tree_oak.glb", "at": Vector2(8.0, -28.0), "yaw": 75.0, "s": 0.95},
	{"file": "kenney_tree_pine.glb", "at": Vector2(24.0, -20.0), "yaw": 150.0, "s": 1.30},
	{"file": "kenney_tree_default.glb", "at": Vector2(31.0, -2.0), "yaw": 20.0, "s": 1.10},
	{"file": "kenney_tree_fat.glb", "at": Vector2(26.0, 14.0), "yaw": 260.0, "s": 1.00},
	{"file": "kenney_tree_oak.glb", "at": Vector2(14.0, 27.0), "yaw": 300.0, "s": 1.20},
	{"file": "kenney_tree_pine.glb", "at": Vector2(-2.0, 31.0), "yaw": 90.0, "s": 1.15},
	{"file": "kenney_tree_default.glb", "at": Vector2(-33.0, 10.0), "yaw": 210.0, "s": 1.25},
	{"file": "kenney_tree_fat.glb", "at": Vector2(-31.0, -25.0), "yaw": 15.0, "s": 1.10},
	{"file": "kenney_tree_oak.glb", "at": Vector2(37.0, -31.0), "yaw": 130.0, "s": 1.05},
	{"file": "kenney_tree_pine.glb", "at": Vector2(21.0, 36.0), "yaw": 55.0, "s": 1.20},
	{"file": "kenney_tree_default.glb", "at": Vector2(-17.0, -32.0), "yaw": 245.0, "s": 0.95},
	# Copses rather than an even scatter: two or three trunks together read as
	# woodland, evenly-spaced singles read as a car park.
	{"file": "kenney_tree_pine.glb", "at": Vector2(-27.0, -14.0), "yaw": 60.0, "s": 1.20},
	{"file": "kenney_tree_oak.glb", "at": Vector2(-24.0, -17.0), "yaw": 190.0, "s": 0.95},
	{"file": "kenney_tree_default.glb", "at": Vector2(30.0, 18.0), "yaw": 100.0, "s": 1.10},
	{"file": "kenney_tree_pine.glb", "at": Vector2(33.0, 22.0), "yaw": 25.0, "s": 1.25},
	{"file": "kenney_tree_fat.glb", "at": Vector2(-12.0, -36.0), "yaw": 140.0, "s": 1.15},
	{"file": "kenney_tree_oak.glb", "at": Vector2(45.0, -12.0), "yaw": 310.0, "s": 1.20},
	{"file": "kenney_tree_pine.glb", "at": Vector2(-42.0, -6.0), "yaw": 80.0, "s": 1.30},
	{"file": "kenney_tree_default.glb", "at": Vector2(12.0, 42.0), "yaw": 200.0, "s": 1.10},
	{"file": "kenney_tree_fat.glb", "at": Vector2(-40.0, 24.0), "yaw": 45.0, "s": 1.20},
	{"file": "kenney_tree_oak.glb", "at": Vector2(-43.0, 20.0), "yaw": 260.0, "s": 1.00},
	# Two inside the clearing, for shade and to break up the yard.
	{"file": "kenney_tree_fat.glb", "at": Vector2(17.0, 7.5), "yaw": 35.0, "s": 1.05},
	{"file": "kenney_tree_oak.glb", "at": Vector2(-20.0, 1.0), "yaw": 165.0, "s": 1.10},
]

var _placed: Array[Node3D] = []
var _shape_count := 0
var _missing: Array[String] = []


## True if ANY prop in the layout has a converted asset on this machine.
##
## Asked before building rather than inferred from a zero count afterwards: "no
## props were placed" and "this checkout has no props to place" are different facts,
## and collapsing them is how a broken layout would come to look like an expected
## CI result.
static func has_assets() -> bool:
	for entry: Dictionary in LAYOUT:
		if ResourceLoader.exists(PROP_DIR + String(entry["file"])):
			return true
	return false


## The number of layout entries whose asset IS present on this machine -- what
## build() is expected to place. Anything less than this is a real failure.
static func expected_count() -> int:
	var n := 0
	for entry: Dictionary in LAYOUT:
		if ResourceLoader.exists(PROP_DIR + String(entry["file"])):
			n += 1
	return n


## Build the homestead. Returns the number of props actually placed -- 0 on an
## assetless checkout, which is a reported state and not an error.
func build() -> int:
	if not has_assets():
		# No converted props on this machine at all (CI, or a clone that has not run
		# the pipeline yet). Bare terrain, reported by ranch.gd -- and reported as a
		# distinct `assets=absent` state rather than as a zero that looks like a pass.
		return 0

	for entry: Dictionary in LAYOUT:
		var file: String = entry["file"]
		var path := PROP_DIR + file
		if not ResourceLoader.exists(path):
			if not file in _missing:
				_missing.append(file)
			continue

		var scene: Resource = load(path)
		if scene == null or not (scene is PackedScene):
			push_error("Props: '%s' did not load as a PackedScene" % path)
			continue

		var inst: Node3D = (scene as PackedScene).instantiate()
		if inst == null:
			push_error("Props: '%s' failed to instantiate" % path)
			continue

		var at: Vector2 = entry["at"]
		var scale_factor: float = BASE_SCALE * float(SCALE_FIX.get(file, 1.0)) \
			* float(entry.get("s", 1.0))
		if file.begins_with("kenney_tree"):
			scale_factor *= TREE_SCALE

		inst.name = "%s_%d" % [file.get_basename(), _placed.size()]
		inst.scale = Vector3.ONE * scale_factor
		inst.rotation.y = deg_to_rad(float(entry["yaw"]))
		var ground := _ground_height(at.x, at.y)
		inst.position = Vector3(at.x, ground, at.y)
		add_child(inst)

		seat(inst, ground)

		_shape_count += _add_collision(inst)
		_placed.append(inst)

	if not _missing.is_empty():
		push_warning("Props: %d layout entries have no converted asset: %s"
			% [_missing.size(), ", ".join(_missing)])

	return _placed.size()


## Number of props standing on the ranch right now.
func get_prop_count() -> int:
	return _placed.size()


## Number of collision shapes generated across all props. ranch.gd asserts this is
## at least one per prop: "every prop needs collision" is a claim that has to be
## measured, not assumed, because a prop whose .glb happens to contain no
## MeshInstance3D would silently get none.
func get_shape_count() -> int:
	return _shape_count


func get_placed() -> Array[Node3D]:
	return _placed


## Layout entries whose asset file is missing on this machine.
func get_missing() -> Array[String]:
	return _missing


## True world-space AABB over every MeshInstance3D under `root`. Same computation as
## game/scenes/test/terrain_probe.gd's -- kept local rather than shared because that
## file is a Phase 0 probe scene and this is shipping world code; the duplication is
## nine lines and the coupling would be worse.
static func world_aabb(root: Node3D) -> AABB:
	var meshes: Array = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		meshes.append(root)
	var result := AABB()
	var first := true
	for m: MeshInstance3D in meshes:
		var local_aabb: AABB = m.get_aabb()
		var xform: Transform3D = m.global_transform
		for i in range(8):
			var corner: Vector3 = xform * local_aabb.get_endpoint(i)
			if first:
				result = AABB(corner, Vector3.ZERO)
				first = false
			else:
				result = result.expand(corner)
	return result


## Shift `node` vertically until the bottom of what you can actually SEE sits
## SINK_BIAS below `ground`, whatever the asset thinks its own origin is. The one
## seating rule on the ranch -- ranch.gd applies it to the hand-built buildings too,
## and then asserts the result on everything.
##
## `node` must already be in the tree: the AABB is measured in world space.
static func seat(node: Node3D, ground: float) -> void:
	var box := world_aabb(node)
	if box.size == Vector3.ZERO:
		return
	node.global_position.y += (ground - SINK_BIAS) - box.position.y


## True if XZ falls inside the reserved pen-plot clearing.
static func is_in_pen_plots(x: float, z: float) -> bool:
	return absf(x - PEN_PLOTS_CENTRE.x) <= PEN_PLOTS_HALF_EXTENT \
		and absf(z - PEN_PLOTS_CENTRE.y) <= PEN_PLOTS_HALF_EXTENT


func _ground_height(x: float, z: float) -> float:
	var terrain := get_parent().get_node_or_null("Terrain")
	if terrain == null or not terrain.has_method("height_at"):
		push_error("Props: no sibling Terrain with height_at() -- props would float")
		return 0.0
	return terrain.height_at(x, z)


## Give `inst` collision. Godot's MeshInstance3D.create_trimesh_collision() adds a
## StaticBody3D child carrying a ConcavePolygonShape3D built from that mesh, which
## inherits the prop's scale through the transform chain -- so the collider is the
## shape you can see, at the size you can see it, with no second scale factor to
## keep in sync. Returns how many shapes were created.
func _add_collision(inst: Node3D) -> int:
	var meshes: Array = inst.find_children("*", "MeshInstance3D", true, false)
	if inst is MeshInstance3D:
		meshes.append(inst)

	var created := 0
	for m: MeshInstance3D in meshes:
		if m.mesh == null:
			continue
		m.create_trimesh_collision()
		created += 1

	for body: StaticBody3D in inst.find_children("*", "StaticBody3D", true, false):
		body.collision_layer = LayersScript.PROPS
		body.collision_mask = 0

	return created
