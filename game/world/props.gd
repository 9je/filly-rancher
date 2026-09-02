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

## A PROP WIDER THAN THIS, STANDING OFF THE FLAT APRON, GETS A PLINTH OF ITS OWN.
##
## seat() puts the bottom of a model's AABB SINK_BIAS below the ground height at ONE point.
## That is right for a tree and wrong for a barn: the flattest 13 by 10 m rectangle anywhere
## on this map outside the homestead apron still has 0.366 m of relief across it, and the
## barn's own site has 0.643 m. Seated at one point, a wide model shows daylight under one
## corner and buries the other, and the terrain passes through its floor plane, which is a
## horizontal face and therefore z fights.
##
## game/world/building.gd solved exactly this for the procedural buildings on 2026-08-31
## (FLOOR_TOP, SKIRT_DEPTH, PLINTH_INSET). A mesh prop cannot use that answer, because a
## Building BUILDS its own plinth and a .glb's floor is whatever the modeller drew. So the
## prop gets a solid box under it instead: seated against the LOWEST of nine samples across
## its own footprint, deep enough to bridge the measured relief, inset on every side so its
## own outer face is never coplanar with the model's. The terrain then always passes through
## the SIDE of an opaque box, which is the property the Building plinth buys.
##
## SKIRT_INSET is PLINTH_INSET's number for PLINTH_INSET's reason. SKIRT_MIN_DEPTH is what
## the box has UNDER the relief it is bridging, so a 0.64 m dip gets a 1.54 m box.
## WIDE_FOOTPRINT is the longer side at which one point seating stops being good enough.
const SKIRT_INSET := 0.06
const SKIRT_MIN_DEPTH := 0.90
const WIDE_FOOTPRINT := 4.0

## Turned earth, and deliberately not a colour any of the models use: a skirt that reads as
## part of the building is a building with a strangely tall base, while a skirt that reads
## as ground the building is standing in is what it actually is.
const SKIRT_COLOUR := Color(0.21, 0.17, 0.13)

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

## THE MLP FAMILY'S OWN BASE SCALE, and it REPLACES BASE_SCALE rather than multiplying it.
## BASE_SCALE is a Kenney kit number (docs/pipeline.md section 4 derives it from a 2 unit
## Kenney door module); a Source engine model converted by tools/convert_props.sh arrives
## with the inch to metre conversion already baked into its vertex data by SourceIO, at
## whatever size a 2015 SFM modeller drew it. Those are two unrelated conventions and
## multiplying one by the other has no meaning.
##
## MEASURED, NOT CHOSEN. scenes/test/model_gallery.tscn -- --props loads every converted
## prop and prints the world AABB of each; MLP_SCALE is MLP_TARGET_BARN_RIDGE divided by
## the native height that gate reported for saa_barn.glb. ranch.gd then measures the
## seated barn and fails if it does not stand at the target, so the number below and the
## barn on the map cannot drift apart silently.
const MLP_TARGET_BARN_RIDGE := 7.0

## From the run above: scenes/test/model_gallery.tscn -- --props reported saa_barn.glb at
## 13.479 m tall as converted, so MLP_TARGET_BARN_RIDGE / 13.479 = 0.5193. Re-run
## that gate and redo this division if tools/convert_props.sh's export ever changes shape.
const MLP_SCALE := 0.5193

## THE FAMILY A LAYOUT ENTRY BELONGS TO, and the base scale each family is built at.
##
## Three, and they are three different measuring conventions rather than three tastes:
## a Kenney kit piece (BASE_SCALE, derived from a 2 unit door module), a Kenney Nature Kit
## tree (BASE_SCALE again, then TREE_SCALE on top, because the kit's trees are stylised
## shorter than a pony), and an MLP prop converted out of a Source model (MLP_SCALE, which
## replaces BASE_SCALE outright: see its own comment).
##
## An entry may name its family explicitly. An entry that does not is a Kenney piece,
## unless its file begins with "kenney_tree", which is the rule the shipped treeline
## already follows and which is why 50 layout entries did not have to be edited to say so.
const FAMILY_KENNEY := &"kenney"
const FAMILY_TREE := &"tree"
const FAMILY_MLP := &"mlp"

const FAMILY_SCALE := {
	&"kenney": BASE_SCALE,
	&"tree": BASE_SCALE * TREE_SCALE,
	&"mlp": MLP_SCALE,
}

## Node name prefixes that are foliage rather than structure. ranch.gd frames its shots and
## runs its camera-against-a-wall probe against "every prop that is not one of these": a
## canopy is a bad obstacle to prove a camera with, because the arm may be stopping on a
## leaf a player would walk straight under.
const FOLIAGE_PREFIXES := ["kenney_tree", "mlp_apple_tree"]

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
	# --- the regions -------------------------------------------------------------
	# Slice 3's four regions (game/data/regions/*.tres) are 60 m and more from the
	# homestead, and the treeline above stops at about 45 m: without these, a region
	# read as a coloured patch of grass with a fence round it and nothing else on the
	# horizon. Each region gets the planting its name promises, and each species is the
	# one whose silhouette says the name: orchard oaks and fats, everfree pines, willowy
	# defaults by the lake, a thin line of pines along the night meadow.
	#
	# EVERY ONE OF THEM STANDS OUTSIDE ITS REGION'S FENCE, by at least 4 m past the ring
	# (RegionFence.RING_MARGIN puts that at radius + 3), and outside every ZoneMarker
	# disc on the map. Both matter: a trunk inside the ring is a trunk a resident can
	# spawn inside of (the spawner's prop reroll only fires when her ground ray HITS the
	# prop, which a canopy edge does not), and a trunk ON the ring is a tree growing
	# through a fence rail. Planted outside, they read as the country the fence is the
	# edge of, which is the whole job a boundary fence has on a map this size.
	# The Orchard, (72, 40) r 22: apples on the high ground, none across the west gate.
	{"file": "kenney_tree_oak.glb", "at": Vector2(101.1, 50.6), "yaw": 25.0, "s": 1.20},
	{"file": "kenney_tree_fat.glb", "at": Vector2(87.5, 66.8), "yaw": 140.0, "s": 1.10},
	{"file": "kenney_tree_oak.glb", "at": Vector2(66.6, 70.5), "yaw": 265.0, "s": 1.25},
	{"file": "kenney_tree_fat.glb", "at": Vector2(48.3, 59.9), "yaw": 60.0, "s": 1.05},
	{"file": "kenney_tree_oak.glb", "at": Vector2(87.5, 13.2), "yaw": 195.0, "s": 1.15},
	{"file": "kenney_tree_fat.glb", "at": Vector2(98.8, 24.5), "yaw": 310.0, "s": 1.20},
	# The Everfree Edge, (-74, -49) r 24: the densest planting on the map, and the
	# darkest, so the corner of the world the palette already made gloomy also LOOKS
	# like woodland rather than like a lawn at dusk.
	{"file": "kenney_tree_pine.glb", "at": Vector2(-62.7, -18.0), "yaw": 15.0, "s": 1.30},
	{"file": "kenney_tree_pine.glb", "at": Vector2(-79.7, -16.5), "yaw": 105.0, "s": 1.20},
	{"file": "kenney_tree_pine.glb", "at": Vector2(-95.2, -23.7), "yaw": 200.0, "s": 1.35},
	{"file": "kenney_tree_pine.glb", "at": Vector2(-105.0, -37.7), "yaw": 285.0, "s": 1.15},
	{"file": "kenney_tree_pine.glb", "at": Vector2(-105.9, -57.5), "yaw": 40.0, "s": 1.30},
	{"file": "kenney_tree_pine.glb", "at": Vector2(-95.2, -74.3), "yaw": 150.0, "s": 1.25},
	{"file": "kenney_tree_pine.glb", "at": Vector2(-76.9, -81.9), "yaw": 230.0, "s": 1.35},
	{"file": "kenney_tree_pine.glb", "at": Vector2(-57.5, -77.6), "yaw": 320.0, "s": 1.20},
	# The Lake, (60, -62) r 24: four only, and spread wide. The water is the thing to
	# look at there, and a ring of trunks around it would be a hedge round a pond.
	{"file": "kenney_tree_default.glb", "at": Vector2(90.1, -51.1), "yaw": 70.0, "s": 1.15},
	{"file": "kenney_tree_default.glb", "at": Vector2(29.9, -72.9), "yaw": 185.0, "s": 1.25},
	{"file": "kenney_tree_default.glb", "at": Vector2(49.1, -92.1), "yaw": 250.0, "s": 1.10},
	{"file": "kenney_tree_default.glb", "at": Vector2(76.0, -89.7), "yaw": 330.0, "s": 1.20},
	# The Night Meadow, (-61, 69) r 24: a windbreak along the far side, leaving the
	# south-east open toward the homestead so the walk out to it has a view.
	{"file": "kenney_tree_pine.glb", "at": Vector2(-33.3, 85.0), "yaw": 50.0, "s": 1.15},
	{"file": "kenney_tree_pine.glb", "at": Vector2(-55.4, 100.5), "yaw": 125.0, "s": 1.30},
	{"file": "kenney_tree_pine.glb", "at": Vector2(-81.6, 93.5), "yaw": 210.0, "s": 1.20},
	{"file": "kenney_tree_pine.glb", "at": Vector2(-93.0, 69.0), "yaw": 285.0, "s": 1.25},
	{"file": "kenney_tree_pine.glb", "at": Vector2(-81.6, 44.5), "yaw": 355.0, "s": 1.15},
]

var _placed: Array[Node3D] = []
var _shape_count := 0
var _missing: Array[String] = []
var _entries: Array[Dictionary] = []
var _skirts: Array[MeshInstance3D] = []
var _seat_grounds: Dictionary = {}


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
		inst.name = "%s_%d" % [file.get_basename(), _placed.size()]
		inst.scale = Vector3.ONE * scale_for(entry)
		inst.rotation.y = deg_to_rad(float(entry["yaw"]))
		var ground := _ground_height(at.x, at.y)
		inst.position = Vector3(at.x, ground, at.y)
		add_child(inst)

		# Measured AFTER the scale and the yaw are applied and the node is in the tree:
		# world_aabb() is a world space measurement, and a footprint is the footprint of
		# the model as it will actually stand.
		var box := world_aabb(inst)
		var centre := Vector2(box.get_center().x, box.get_center().z)
		var half := Vector2(box.size.x * 0.5, box.size.z * 0.5)
		var relief := Vector2(ground, ground)
		var skirted: bool = bool(entry.get("skirt", false))
		if skirted:
			relief = footprint_relief(centre, half, Callable(self, "_ground_height"))
			ground = relief.x

		seat(inst, ground)
		_seat_grounds[inst] = ground

		if skirted:
			_add_skirt(inst, centre, half, relief.y - relief.x, ground)

		_shape_count += _add_collision(inst)
		_placed.append(inst)
		_entries.append(entry)

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


## The LAYOUT entry a placed prop came from, or {} for anything Props did not place.
func entry_of(node: Node3D) -> Dictionary:
	var index := _placed.find(node)
	return _entries[index] if index >= 0 else {}


## True if Props seated `node` and recorded the height it used.
func has_seat_ground(node: Node3D) -> bool:
	return _seat_grounds.has(node)


## The ground height `node` was actually seated against: the height under its origin for
## an ordinary prop, the lowest of nine footprint samples for a skirted one. ranch.gd's
## seating check reads this rather than re-deriving it, for the same reason it reads
## Building.seat_ground() for a building: the number a prop was seated by and the number
## the gate checks it against must not be able to drift apart.
func seat_ground_of(node: Node3D) -> float:
	return float(_seat_grounds.get(node, 0.0))


## Every skirt box standing under a wide prop. Not props, not in the census; ranch.gd
## checks their collision layer alongside the props' own.
func get_skirts() -> Array[MeshInstance3D]:
	return _skirts


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


## Ground height at the four corners, the four edge midpoints and the centre of the
## rectangle `centre` plus or minus `half`, sampled through `ground_sampler`. Returns
## (lowest, highest).
##
## Nine points and not one, for the reason game/world/building.gd's footprint_relief() takes
## nine: the height under a wide model's ORIGIN says nothing about the corner that is going
## to hang in the air. Deliberately the same shape as that function, so a reviewer reading
## one has read both; it is a free function here because a prop has no footprint of its own
## to ask, only the AABB of whatever the modeller drew.
static func footprint_relief(centre: Vector2, half: Vector2, ground_sampler: Callable) -> Vector2:
	var lowest := INF
	var highest := -INF
	for dx: float in [-half.x, 0.0, half.x]:
		for dz: float in [-half.y, 0.0, half.y]:
			var h: float = float(ground_sampler.call(centre.x + dx, centre.y + dz))
			lowest = minf(lowest, h)
			highest = maxf(highest, h)
	return Vector2(lowest, highest)


## True if a prop with this world AABB, standing on ground that is `flat` or not, has to be
## seated by its footprint and given a skirt. ranch.gd asks this of every LIVE placed prop
## and fails the gate if an entry that needs one does not carry `"skirt": true`, so the rule
## is checked against measurements rather than remembered.
static func needs_skirt(box: AABB, flat: bool) -> bool:
	return not flat and maxf(box.size.x, box.size.z) > WIDE_FOOTPRINT


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


## The family `entry` belongs to. See FAMILY_SCALE.
static func family_of(entry: Dictionary) -> StringName:
	if entry.has("family"):
		return StringName(entry["family"])
	var file: String = entry["file"]
	if file.begins_with("kenney_tree"):
		return FAMILY_TREE
	return FAMILY_KENNEY


## The uniform scale `entry` is built at: its family's base, times any per-file correction
## in SCALE_FIX, times the entry's own `s` jitter. The one place these three multiply, so
## nothing can apply two of them and forget the third.
static func scale_for(entry: Dictionary) -> float:
	var file: String = entry["file"]
	var base: float = float(FAMILY_SCALE.get(family_of(entry), BASE_SCALE))
	return base * float(SCALE_FIX.get(file, 1.0)) * float(entry.get("s", 1.0))


## True if `node_name` is one of the foliage families. See FOLIAGE_PREFIXES.
static func is_foliage(node_name: String) -> bool:
	for prefix: String in FOLIAGE_PREFIXES:
		if node_name.begins_with(prefix):
			return true
	return false


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


## A solid box under a wide prop, so the terrain always passes through the SIDE of
## something opaque instead of through a horizontal face. See SKIRT_INSET above for the
## whole argument, and game/world/building.gd's PLINTH_INSET for the same fix on the
## procedural buildings.
##
## PARENTED TO Props, NOT TO THE PROP, and that is load bearing. world_aabb() is what
## seat() and ranch.gd's seating check both measure, and a box hanging below the model
## would move the bottom they read: every skirted prop would report itself sunk by the
## skirt's whole depth and the gate would go red on a correctly placed barn. As a sibling
## it is collided and layered like any prop and is deliberately absent from _placed, so it
## never enters the census either.
func _add_skirt(inst: Node3D, centre: Vector2, half: Vector2, relief: float,
		top: float) -> MeshInstance3D:
	var depth: float = relief + SKIRT_MIN_DEPTH
	var mesh := BoxMesh.new()
	mesh.size = Vector3(maxf(0.2, (half.x - SKIRT_INSET) * 2.0), depth,
		maxf(0.2, (half.y - SKIRT_INSET) * 2.0))
	var material := StandardMaterial3D.new()
	material.albedo_color = SKIRT_COLOUR
	material.roughness = 0.95
	mesh.material = material

	var skirt := MeshInstance3D.new()
	skirt.name = "%s_skirt" % inst.name
	skirt.mesh = mesh
	add_child(skirt)
	# Its top face meets the model's own floor, which seat() has just put SINK_BIAS below
	# the lowest footprint sample.
	skirt.global_position = Vector3(centre.x, top - SINK_BIAS - depth * 0.5, centre.y)
	_shape_count += _add_collision(skirt)
	_skirts.append(skirt)
	return skirt
