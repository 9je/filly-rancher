class_name Terrain
extends StaticBody3D
## The ranch's ground: a procedurally-built, gently rolling heightfield with a
## trimesh collider, a grass material, and a flat apron where the homestead sits.
##
## WHY THE MESH IS GENERATED IN CODE rather than authored and imported. Everything
## under game/assets/converted/ is gitignored and regenerated per machine
## (docs/ci.md section 4), so a terrain shipped as a .glb would be missing from a
## fresh clone and from every CI checkout -- and the ranch is the MAIN SCENE, so a
## missing terrain is a game that boots into the void. A few dozen lines of
## deterministic arithmetic are in git, are identical on every machine, and cost about a
## quarter of a second at startup on this machine, nearly all of it in create_trimesh_shape()
## rather than in the arithmetic, paid once while the main scene loads. It also means
## height_at() is available as a plain function, which is what lets props sit exactly on
## the ground instead of being nudged by hand until they stop floating.
##
## SCULPTED, NOT FLAT, ON PURPOSE. A flat plane would have made the spawner's
## raycast-down placement (game/world/spawner.gd) vacuous: every random point would
## have landed at y=0 whether the ray hit anything or not, so a broken raycast
## would have looked exactly like a working one. The zone markers are deliberately
## placed OUT ON THE ROLLING GROUND, past the flat apron, so that check has real
## work to do.
##
## SCALE. 1 unit = 1 metre (docs/pipeline.md section 3). The relief is deliberately
## gentle -- about +/-2.4 m over ~50 m wavelengths, max slope ~20 degrees, well
## inside CharacterBody3D's default 45-degree floor limit -- because this is a
## place to walk a 1.16 m pony around, not a mountain.

const LayersScript := preload("res://world/collision_layers.gd")
const RegionRegistryScript := preload("res://systems/region_registry.gd")
const RegionDataScript := preload("res://systems/region_data.gd")
const GroundShader := preload("res://world/terrain.gdshader")
const WaterShader := preload("res://shaders/water.gdshader")

## Half-width of the map, in metres. The ground spans [-HALF, HALF] on both X and Z.
##
## 110 rather than the original 70 because the four regions (game/data/regions/) live out
## past the homestead, the furthest of them reaching z = 93 with its fence ring on. The
## apron constants below are deliberately NOT retuned with it: the homestead, its props,
## its plots and the five ranch zone markers all sit inside 44 m of the middle and keep
## exactly the ground they had.
const HALF := 110.0
## Metres per grid cell. 2 m gives a 110x110 quad grid (24,200 triangles), fine enough
## that the relief reads as smooth, coarse enough to build and collide against
## cheaply.
const CELL := 2.0

## Inside this radius of ORIGIN the ground is exactly flat (y = 0), so the buildings
## have somewhere honest to stand: a barn with one corner in the air is the single
## most obvious way for a hand-placed prop set to look broken.
## It is wide enough to hold the whole homestead AND the clearing reserved for
## Phase 1B's pen plots (game/world/props.gd) -- a pen plot pitched on a hillside is
## a problem for a later task that costs nothing to avoid now.
const FLAT_RADIUS := 30.0
## ...and the flattening eases out to full relief by here. The gap between the two
## is the apron: walkable, visibly sloped, no hard crease.
const BLEND_RADIUS := 44.0
## Centre of the flat apron, in XZ. The homestead is composed around this point.
const HOMESTEAD_CENTRE := Vector2(0.0, -4.0)
## YARDS LEVELLED OUT PAST THE APRON (P8 S7, playtest 2026-11-08 items 42 and 52: the town was
## crowded into the apron while the map round it stood empty, and the house sat crooked on the
## slope). The plaza keeps the apron; the homestead and the pens now stand further out, each on
## its own pad: [centre, flat radius, blend metres]. Inside a pad the relief is levelled to the
## apron's own y = 0, easing back to the hills over the blend, so a building or a pen out there
## stands on ground as level as the plaza's and joins it without a step.
const YARD_PADS: Array = [
	[Vector2(1.5, -35.0), 13.0, 9.0],
	[Vector2(-21.0, -30.0), 13.0, 9.0],
	[Vector2(-29.0, 16.0), 14.0, 9.0],
]

## Invisible perimeter walls, so walking to the edge of the world is a wall rather
## than a fall.
##
## 16 m, NOT THE 6 m THEY WERE: TALL ENOUGH FOR THE CAMERA, NOT JUST FOR HER. They reach
## from 3 m under the map to 13 m over it. At 6 m the top stood at y = 3, and on the edge's
## high ground (1.9 m on the east side) her head is already above that, so the camera arm
## swung out over the top and the lens hung outside the map with no ground under it at all
## (game/test_input/test_camera_terrain.gd's map_edge stop: 344 frames outside the map).
## The highest the lens can get is about 9.5 m (2.4 m of relief, the 1.45 m pivot, 6.5 m of
## arm at 60 degrees), so 13 m keeps the whole arm inside the walls with room to spare.
const BOUNDARY_HEIGHT := 16.0
const BOUNDARY_THICKNESS := 2.0

## Grass. Slightly desaturated and very rough -- a shiny lawn under a directional
## sun reads as plastic.
##
## TUNED AGAINST THE PONYSFM PALETTE, NOT PICKED BY EYE A SECOND TIME. The foliage the map
## is full of now measures hue 0.265 at saturation 0.358 (HLS, averaged across
## mlp_apple_tree_leaves.png and mlp_bush_leaves.png, 64x64 downsample); the shipped grass sat
## at hue 0.300 / saturation 0.351 for GRASS_LOW and hue 0.227 / saturation 0.333 for
## GRASS_HIGH, which is why the ground read as a different production's grass under an MLP
## tree. Value is deliberately held within 0.03 of the shipped numbers (0.408 -> 0.410 and
## 0.541 -> 0.551, both Color.v): what was wrong was the hue and the saturation, and moving
## the brightness as well would change how the map reads at dusk for a reason that has
## nothing to do with the palette.
const GRASS_LOW := Color(0.283, 0.410, 0.194)
const GRASS_HIGH := Color(0.381, 0.551, 0.261)

## What a hillside is made of. Turned earth, and deliberately not any green: the point of the
## slope mask is that a slope reads as a different SURFACE rather than as darker grass.
##
## TUNED AGAINST THE PONYSFM PALETTE. mlp_apple_tree_tree_wood.png measures hue 0.121 at
## saturation 0.430 (HLS, 64x64 downsample); the shipped dirt sat at hue 0.088 / saturation
## 0.309, paler and greyer than the bark the ground is meant to read next to. Hue stays under
## 0.14 either way, so this was never at risk of reading as another green -- it just wasn't
## earth-coloured enough to read as bark's own colour rather than a generic brown.
const DIRT := Color(0.8, 0.72, 0.6)

## THE NORTH ROAD, PAINTED INTO THE GROUND RATHER THAN LAID ON TOP OF IT.
##
## THE BUG THIS CLOSES. `game/world/props.gd` used to stand sixteen `saa_dirt_road.glb`
## plates along this same line, each a rigid 10.52 x 2.28 m slab. The ground climbs about
## 0.70 m across the run (`FLAT_RADIUS` to `BLEND_RADIUS` and beyond), a flat plate cannot
## bend to follow it, and sixteen of them in a row read as a ladder of half-buried planks
## with grass showing through every seam -- the exact defect its own fix wave's re-review
## caught in the rendered screenshot after tightening the tile spacing did not close it.
## A road painted onto the terrain's own surface conforms to whatever that surface does, by
## construction: there is no plate to bury, no seam to gap, no step between neighbours.
##
## THE ROUTE. Straight along x = 1.5, the same centreline the tiles stood on, from inside
## the homestead's own flat apron (z = 10, comfortably short of `FLAT_RADIUS` from
## `HOMESTEAD_CENTRE`) up through the town row's own corridor (the buildings flank it at
## x = 15 and x = -12, more than 10 m clear on either side) to the Strip's paving
## (STRIP_EDGE_Z), where the grey of the paved region takes over from the dirt.
##
## A STRAIGHT TWO-POINT POLYLINE IS STILL A POLYLINE. The shader (`terrain.gdshader`) walks
## an arbitrary vertex list, so a future road that bends only has to add points here; nothing
## about the mask assumes two. Padded out to the shader's fixed-size uniform array by
## `_path_uniform()` below, repeating this array's own last point (a zero-length segment the
## shader's own distance walk treats as inert, not as a divide-by-zero).
## SEVERAL ROADS, ONE LIST (owner playtest 2026-10-25: "i cant find the market ... the
## important buildings are too close and not easy to navigate between"). PATH_BREAK between
## two points ends one road and starts the next; the shader and path_distance() skip any
## segment that touches it. The main street runs from the Farmhouse door down through the
## plaza to the Strip; the cross street joins the Depot door to the Market door across the
## plaza; the spur leaves the main street for the pen yard.
const PATH_BREAK := Vector2(100000.0, 100000.0)
## THE DIRT ROAD STOPS WHERE THE PAVING STARTS (PT7; playtest 2026-11-05: on the Strip "the
## dirt road is painted straight across the grey pavement"). The Strip is the region at
## (0, 74) with a 26 m radius, so its paving begins near z = 48 and is solid by 51; the
## road ran on to 58. It stops at 50.5, past the town row, where the blend still hides the end.
const STRIP_EDGE_Z := 50.5
## P8 S7, THE PLAZA PLAN: the main street runs from the Farmhouse door, 25 m out on its own
## yard, down through the plaza (paved over it, game/world/street.gd's plaza) to the Strip;
## the barn lane joins it from the Barn door; the pen lane leaves it south of the plaza for
## the pen yard to the south-west.
const PATH_POINTS: Array[Vector2] = [
	Vector2(1.5, -29.5), Vector2(1.5, 10.0), Vector2(1.5, STRIP_EDGE_Z),
	PATH_BREAK,
	Vector2(-19.0, -25.0), Vector2(0.0, -25.0),
	PATH_BREAK,
	Vector2(1.5, 7.5), Vector2(-17.0, 14.5),
]


## Metres from `p` to the nearest painted road (PATH_POINTS, its breaks skipped).
static func path_distance(p: Vector2) -> float:
	var best := INF
	for i in PATH_POINTS.size() - 1:
		var a: Vector2 = PATH_POINTS[i]
		var b: Vector2 = PATH_POINTS[i + 1]
		if a == PATH_BREAK or b == PATH_BREAK:
			continue
		best = minf(best, Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p))
	return best

## Half the path's full-strength core width, in metres -- "a couple of metres wide" per the
## ruling that replaced the tiled road. `PATH_EDGE_SOFTNESS` is how far past that the dirt
## fades back to grass, and `PATH_EDGE_NOISE` is how many metres the edge itself wanders by,
## sampled through the shader's own `value_noise()`, so the border reads as worn rather than
## as a UI decal with a hard edge. All three are also the ShaderMaterial's own uniforms
## (`terrain.gdshader`) and are set from here, the one place, in `_build_mesh()`.
## 2026-10-26: a wider core with a short edge (was 1.1 m, a 1.3 m fade and 0.5 m of wander).
## The old edge was as wide as the road, so from the player's eye every road was a brown
## smear; the show paints its paths with a clean edge. Same overall width.
const PATH_HALF_WIDTH := 1.5
const PATH_EDGE_SOFTNESS := 0.12
const PATH_EDGE_NOISE := 0.55

## HOW MUCH OF DIRT COMES BACK AS AN AMBIENT-INDEPENDENT EMISSION FLOOR ON THE PATH. Measured
## against the shipped dawn render: this route runs through the long shadow of the trees and
## fence posts that line it for most of its length, and DIRT's own albedo (about a fifth of
## GRASS_HIGH's) crushes toward black under ambient-only light (sRGB (19, 5, 0), against
## grass two metres away at (92, 123, 32)) -- a scorch mark, not a track. See
## terrain.gdshader's own fragment() comment for the full account.
const PATH_GLOW := 0.08

## The shader array uniform's own fixed length. Matches `PATH_MAX_POINTS` in
## `terrain.gdshader` -- game/test/test_terrain.gd pins both numbers so the two files cannot
## drift apart silently.
const PATH_SHADER_SLOTS := 12

## When true this node builds NOTHING in _ready() beyond its collision layers, and the
## ground is shaped by an explicit build() instead.
##
## WHY IT EXISTS. The regions have to be known before the first vertex is placed: the lake
## is a hole in the heightfield, so a terrain that shaped itself and was told about the
## lake afterwards would have a mesh and a collider that disagree with height_at(), which
## is the one thing this file exists to prevent. A child readies before its parent, so
## Ranch._ready() has no moment early enough to hand the registry over. ranch.tscn
## therefore sets this, and ranch.gd assigns `regions` and calls build() as its first act.
## Every other scene, and every test that wants the plain map, leaves it false.
@export var defer_build := false

## The region catalogue this map is shaped and painted by, or NULL for the plain map (no
## tints, no basin), which is what scenes/test/ and the unit suite get. Set by the owner
## BEFORE build() runs; see defer_build.
##
## Assigning it caches the lake regions, because height_at() is called about 62,000 times
## while the mesh is built (once per vertex, four more per vertex for the analytic normal)
## and asking the registry for a fresh copy of its catalogue each time would turn a
## millisecond of arithmetic into tens of them.
var regions: RegionRegistryScript = null:
	set(value):
		regions = value
		_lakes.clear()
		_bank_tops.clear()
		if value != null:
			for region in value.all():
				if region.has_lake:
					_lakes.append(region)
					_bank_tops.append(_mean_relief_round(region.centre, shore_radius(region) + LAKE_BANK_OUT))

var _mesh_instance: MeshInstance3D
var _collision: CollisionShape3D

## The subset of `regions` that carries a lake, in registry order. See the setter above.
var _lakes: Array[RegionDataScript] = []
## The height of each lake's level ring of grass, the top of its bank, in _lakes' order: the
## mean of the relief round the bank's top edge, so the levelling moves the ground as little as
## it can. Worked out once in the setter, read 62,000 times by height_at().
var _bank_tops: Array[float] = []


func _ready() -> void:
	collision_layer = LayersScript.TERRAIN
	# The camera rig finds the ground by this group, to keep its lens above it (camera_rig.gd,
	# _keep_above_ground()).
	add_to_group(&"terrain")
	# A StaticBody3D never initiates a collision query of its own; leaving a mask on
	# it costs broadphase work and buys nothing.
	collision_mask = 0

	if not defer_build:
		build()


## Shapes the ground: the mesh, its trimesh collider, and the four boundary walls. Called
## by _ready() unless defer_build is set, in which case the owner calls it once `regions`
## has been handed over. A second call is ignored rather than building a second mesh on top
## of the first.
func build() -> void:
	if _mesh_instance != null:
		push_error("Terrain.build() called twice")
		return

	var mesh := _build_mesh()

	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "Mesh"
	_mesh_instance.mesh = mesh
	add_child(_mesh_instance)

	_collision = CollisionShape3D.new()
	_collision.name = "CollisionShape3D"
	_collision.shape = mesh.create_trimesh_shape()
	add_child(_collision)

	_build_boundary()


## Ground height in metres at world XZ. The one source of truth for the shape of the
## ranch -- the mesh, the collider, the prop placement and the gate's "is this thing
## actually on the ground" checks all read this same function, so they cannot drift
## apart from each other.
##
## Deterministic: no RNG, no noise texture, no per-machine anything. The only input beyond
## XZ is `regions`, which is assigned once, before the ground is built, and never again.
##
## A region with a lake in it is a POND: the rolling relief is levelled round it to one
## height (the top of its bank), so its water, which is flat, meets the ground at the same
## radius on every heading; then a bank falls from that level ring down through the waterline
## to a bed a wading depth under the water. See _lake_ground(). It is done here, in the one
## function everything else reads, so the mesh, the collider, the props, the ponies' feet and
## the water all agree about where the ground is.
func height_at(x: float, z: float) -> float:
	var h := _raw_height(x, z) * _relief_weight(x, z)
	for i in _lakes.size():
		h = _lake_ground(_lakes[i], _bank_tops[i], Vector2(x, z), h)
	return h


## The height the ground is DRAWN at, world XZ: the mesh's own triangle there, which is also
## its collider's (both are built from the same vertices by _build_mesh()). Between two grid
## vertices this is not height_at(): the smooth function bulges above or sags below the flat
## triangle by up to a few centimetres. The camera rig keeps its lens above THIS, because this
## is what the eye sees. Outside the map it answers for the nearest edge.
##
## The grid and the diagonal split are _build_mesh()'s: vertices every CELL from -HALF, each
## quad cut along the (x0, z1)-(x1, z0) diagonal into [i01, i00, i10] and [i11, i01, i10].
func surface_height_at(x: float, z: float) -> float:
	var gx := (clampf(x, -HALF, HALF) + HALF) / CELL
	var gz := (clampf(z, -HALF, HALF) + HALF) / CELL
	var last := int(round((HALF * 2.0) / CELL)) - 1
	var ix := clampi(floori(gx), 0, last)
	var iz := clampi(floori(gz), 0, last)
	var fx := gx - ix
	var fz := gz - iz
	var x0 := -HALF + ix * CELL
	var z0 := -HALF + iz * CELL
	var h00 := height_at(x0, z0)
	var h10 := height_at(x0 + CELL, z0)
	var h01 := height_at(x0, z0 + CELL)
	var h11 := height_at(x0 + CELL, z0 + CELL)
	if fx + fz <= 1.0:
		return h00 + fx * (h10 - h00) + fz * (h01 - h00)
	return h11 + (1.0 - fx) * (h01 - h11) + (1.0 - fz) * (h10 - h11)


## The relief before the homestead apron flattens it. Used for the grass tinting, so
## that the flat yard still has tonal variation instead of being one dead flat green
## -- the first render's homestead read as a snooker table for exactly that reason.
func _raw_height(x: float, z: float) -> float:
	var h := 0.0
	h += sin(x * 0.055) * cos(z * 0.045) * 1.60
	h += sin((x + z) * 0.021 + 0.6) * 0.90
	h += cos(x * 0.130 + 1.7) * sin(z * 0.110 - 0.4) * 0.35
	return h


## Unit surface normal at world XZ, from a central difference of height_at(). Used
## for the mesh's shading normals -- computed analytically rather than averaged from
## triangle faces so the lighting matches the true surface, not the tessellation.
func normal_at(x: float, z: float) -> Vector3:
	const E := 0.5
	var dx := height_at(x + E, z) - height_at(x - E, z)
	var dz := height_at(x, z + E) - height_at(x, z - E)
	return Vector3(-dx, 2.0 * E, -dz).normalized()


## True if XZ is inside the flat apron the homestead is built on.
func is_flat_at(x: float, z: float) -> bool:
	if Vector2(x, z).distance_to(HOMESTEAD_CENTRE) <= FLAT_RADIUS:
		return true
	for pad: Array in YARD_PADS:
		if Vector2(x, z).distance_to(pad[0]) <= float(pad[1]):
			return true
	return false


## 0 inside the flat apron or a yard pad, 1 out in open country, smooth in between.
func _relief_weight(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var w := smoothstep(FLAT_RADIUS, BLEND_RADIUS, p.distance_to(HOMESTEAD_CENTRE))
	for pad: Array in YARD_PADS:
		var r: float = pad[1]
		w = minf(w, smoothstep(r, r + float(pad[2]), p.distance_to(pad[0])))
	return w


## The colour of the grass at world XZ, one vertex of the mesh's worth.
##
## Higher, drier ground reads a shade lighter and yellower; hollows stay a deeper green,
## and a fine patchwork on top keeps even the perfectly flat homestead apron from
## rendering as one uniform sheet. Deliberately driven by the UNflattened relief, so the
## yard is tinted like the land it was levelled out of.
##
## Inside a region the same tone is taken through THAT region's palette instead, faded in
## by the region's own edge weight so the orchard's green and the night meadow's silver
## arrive over a few metres rather than at a hard circle. This is the only thing that tells
## a player, from across the map, that the far side of the fence is somewhere else.
func grass_at(x: float, z: float) -> Color:
	var tone := clampf(0.5 + _raw_height(x, z) * 0.16
		+ sin(x * 0.31) * cos(z * 0.27) * 0.11
		+ sin((x - z) * 0.13 + 2.1) * 0.07, 0.0, 1.0)
	var color := GRASS_LOW.lerp(GRASS_HIGH, tone)
	if regions == null:
		return color
	var point := Vector2(x, z)
	var region: RegionDataScript = regions.region_at(point)
	if region == null:
		return color
	return color.lerp(region.grass_low.lerp(region.grass_high, tone), region.weight_at(point))


## A POND, NOT A DISC LAID ON THE HILLS (playtest 2026-11-05 item 61: "ponies and the player
## walk under the water; ponies half sunk; grass shows through; no banks"; the PS batch check
## after the first try: "a flat disc with a lip, no bank, and black wedges by the shore").
##
## The lake used to be a 2.2 m bowl SUBTRACTED from the rolling relief, with a flat disc laid
## over it at one height. The relief runs 3 m from one side of the lake to the other, so where
## it ran high the bank stood over the water and cut wedges out of it, where it ran low the
## disc's rim stood in the air over dry ground, and nowhere did the two meet at a shore. And the
## ponies stand on height_at(), the bowl, under a wading shelf only the player's collider knew
## about: sunk to the withers.
##
## So the ground is shaped round the water instead. Inside LAKE_BANK_OUT of the shore the
## relief is levelled to one height (the bank's top), easing back to the hills by
## LAKE_LEVEL_OUT past the fence. Across the bank the ground falls on one smooth curve from that
## level, through the waterline at the shore radius, to a flat bed `lake_depth` under the water
## LAKE_BED_IN inside it. The pond is a wading pond (DECISIONS.md, item 61): knee deep all the
## way across, so the player walks in to the Lake pylon and nobody is ever under it.
##
## The shoreline: SHORE_FRACTION of the region's radius, where the dressing's lily pads, reeds
## and jetty already stand.
const SHORE_FRACTION := 0.7
## Metres inside the shore where the bed levels out.
const LAKE_BED_IN := 3.0
## Metres outside the shore where the bank reaches its top.
const LAKE_BANK_OUT := 4.0
## Metres past the region's own radius by which the levelled ground is back to the hills.
const LAKE_LEVEL_OUT := 6.0
## How far the water sheet runs on under the bank past the shore, so its edge is buried in the
## ground everywhere rather than ending exactly where the ground meets it.
const WATER_TUCK := 1.0
## Metres outside the shore at which a pony is turned back: a one-way fence she cannot see.
const PONY_SHORE_OUT := 0.5


## The shoreline's radius, from the lake's middle.
static func shore_radius(region: RegionDataScript) -> float:
	return region.radius * SHORE_FRACTION


## The height of the lake's water: on the bank's curve at the shore radius.
func water_level(region: RegionDataScript) -> float:
	var i := _lakes.find(region)
	var top: float = _bank_tops[i] if i >= 0 else height_at(region.centre.x, region.centre.y)
	return top - _lake_drop(region) * (1.0 - _bank_curve(shore_radius(region), region))


## Bed to bank top, metres: the drop that puts the water `lake_depth` over the bed at the shore.
static func _lake_drop(region: RegionDataScript) -> float:
	var at_shore := smoothstep(0.0, 1.0, LAKE_BED_IN / (LAKE_BED_IN + LAKE_BANK_OUT))
	return region.lake_depth / maxf(at_shore, 0.01)


## 0 on the bed, 1 at the bank's top, smooth between: one curve through the waterline, so the
## ground crosses the water at a slope (a crisp shore) rather than running along under it.
static func _bank_curve(d: float, region: RegionDataScript) -> float:
	var s := shore_radius(region)
	return smoothstep(s - LAKE_BED_IN, s + LAKE_BANK_OUT, d)


## The ground at `point` given the relief `h` there, shaped round one lake.
func _lake_ground(region: RegionDataScript, top: float, point: Vector2, h: float) -> float:
	var d := point.distance_to(region.centre)
	if d >= region.radius + LAKE_LEVEL_OUT:
		return h
	var s := shore_radius(region)
	var level := 1.0 - smoothstep(s + LAKE_BANK_OUT, region.radius + LAKE_LEVEL_OUT, d)
	return lerpf(h, top, level) - _lake_drop(region) * (1.0 - _bank_curve(d, region))


## The mean of the relief on a circle: the height a lake's bank top is levelled to.
func _mean_relief_round(centre: Vector2, radius: float) -> float:
	const N := 48
	var sum := 0.0
	for k in N:
		var a := TAU * float(k) / float(N)
		var x := centre.x + cos(a) * radius
		var z := centre.y + sin(a) * radius
		sum += _raw_height(x, z) * _relief_weight(x, z)
	return sum / float(N)


## The water for a region that has a lake, ready for the caller to parent wherever it keeps
## its regional scenery (ranch.gd puts it under $Regions): a flat sheet at water_level(), no
## thicker than paint, running WATER_TUCK on under the bank so its rim is in the ground, and a
## one-way fence at the shore that turns ponies back (see _pony_shore()). Opaque: nothing on
## the bed shows through. In the "lake_water" group with its keep-out radius as the meta
## "pony_keep_out", which the spawner reads so no pony is set down in it.
func build_water(region: RegionDataScript) -> MeshInstance3D:
	var shore := shore_radius(region)
	# The show's water (shaders/water.gdshader): shallows, a foam line at the shore, sparkle.
	var mat := ShaderMaterial.new()
	mat.shader = WaterShader
	mat.set_shader_parameter(&"radius", shore)
	var node := MeshInstance3D.new()
	node.name = "Water_" + String(region.id)
	node.mesh = _water_sheet(shore + WATER_TUCK, 96)
	node.mesh.surface_set_material(0, mat)
	node.position = Vector3(region.centre.x, water_level(region), region.centre.y)
	mat.set_shader_parameter(&"centre", node.position)
	mat.set_shader_parameter(&"opacity", 1.0)
	node.add_to_group(&"lake_water")
	node.set_meta(&"pony_keep_out", shore + PONY_SHORE_OUT)
	node.add_child(_pony_shore(shore + PONY_SHORE_OUT))
	return node


## A flat disc of `radius` in the node's own XZ plane, facing up: a fan of `segments`.
static func _water_sheet(radius: float, segments: int) -> ArrayMesh:
	var verts := PackedVector3Array([Vector3.ZERO])
	var normals := PackedVector3Array([Vector3.UP])
	for k in segments:
		var a := TAU * float(k) / float(segments)
		verts.append(Vector3(cos(a), 0.0, sin(a)) * radius)
		normals.append(Vector3.UP)
	var indices := PackedInt32Array()
	# Centre, then the rim in increasing angle: a right-hand normal pointing DOWN, which is a
	# Godot front face pointing up (see _build_mesh()'s winding note).
	for k in segments:
		indices.append_array([0, 1 + k, 1 + (k + 1) % segments])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## A ring of wall at `radius` round the water, on PEN_GATE (in a pony's mask, not the
## player's: CollisionLayers), FACING OUT. A one-sided concave shape only stops what meets its
## front, so a pony walking down to the water is stopped on the bank, and a pony that is in the
## water anyway (dropped there from the beam) walks out through its back. The player and the
## camera never meet it.
static func _pony_shore(radius: float) -> StaticBody3D:
	const SEGMENTS := 72
	const BELOW := 1.5
	const ABOVE := 3.0
	var faces := PackedVector3Array()
	for k in SEGMENTS:
		var a0 := TAU * float(k) / float(SEGMENTS)
		var a1 := TAU * float(k + 1) / float(SEGMENTS)
		var p0 := Vector3(cos(a0), 0.0, sin(a0)) * radius
		var p1 := Vector3(cos(a1), 0.0, sin(a1)) * radius
		var lo0 := p0 + Vector3.DOWN * BELOW
		var lo1 := p1 + Vector3.DOWN * BELOW
		var hi0 := p0 + Vector3.UP * ABOVE
		var hi1 := p1 + Vector3.UP * ABOVE
		# Right-hand normal inward, so the Godot front face looks out at the bank.
		faces.append_array([lo0, lo1, hi0, lo1, hi1, hi0])
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = false
	var body := StaticBody3D.new()
	body.name = "PonyShore"
	body.collision_layer = LayersScript.PEN_GATE
	body.collision_mask = 0
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	return body


## Where a hoof lands, world XZ. In the water that is the pond's bed, the same ground everybody
## stands on: kept as its own name for Act Three's Lake pylon, which stands in the water.
func walk_height_at(x: float, z: float) -> float:
	return height_at(x, z)


## The heightfield as an ArrayMesh.
##
## WINDING IS NOT COSMETIC HERE -- IT DECIDES WHETHER THE GROUND IS SOLID.
## Godot's front-face convention is CLOCKWISE, and its Plane(p1, p2, p3) constructor
## implements that as `(p1 - p3).cross(p1 - p2)` -- the NEGATIVE of the familiar
## right-hand-rule normal `(p2 - p1).cross(p3 - p1)`. ConcavePolygonShape3D builds
## each face's plane with exactly that constructor and, with `backface_collision`
## off (the default), only reports contacts and ray hits on the front side. So a
## heightfield wound "normally" by the right-hand rule produces a terrain whose
## collision faces point DOWN: bodies sink slowly through it while sliding sideways
## on inverted floor normals, `is_on_floor()` never becomes true, and every downward
## raycast misses. That is precisely what the first run of this file did -- the
## player at y=-0.45 and not on the floor, five of eight ponies falling, and every
## spawner ray falling back. The order below is therefore the one that gives a
## DOWNWARD right-hand-rule normal, i.e. an UPWARD Godot front face.
##
## Do not "fix" this by enabling backface_collision or by disabling culling; both
## paper over an inside-out mesh rather than not building one.
func _build_mesh() -> ArrayMesh:
	var steps := int(round((HALF * 2.0) / CELL))
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	for iz in range(steps + 1):
		for ix in range(steps + 1):
			var x := -HALF + float(ix) * CELL
			var z := -HALF + float(iz) * CELL
			var y := height_at(x, z)
			verts.append(Vector3(x, y, z))
			normals.append(normal_at(x, z))
			# 1 UV tile per 4 m, so a future grass texture repeats at a believable
			# size rather than being stretched across the whole 220 m.
			uvs.append(Vector2(x, z) * 0.25)
			# The tint, and inside a region its regional palette, live in grass_at()
			# so a caller can ask what colour the ground is at a point without
			# rebuilding the mesh to find out.
			colors.append(grass_at(x, z))

	var row := steps + 1
	for iz in range(steps):
		for ix in range(steps):
			var i00 := iz * row + ix
			var i10 := i00 + 1
			var i01 := i00 + row
			var i11 := i01 + 1
			indices.append_array([i01, i00, i10])
			indices.append_array([i11, i01, i10])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	# THE GROUND WEARS A SHADER, AND THE VERTEX COLOURS STILL DECIDE ITS COLOUR. grass_at() and
	# every region palette are unchanged and are still the single authority on what colour the
	# ground is at a point; world/terrain.gdshader adds the break up, the slope mask and the
	# ridge lift on top of what this mesh already carries.
	#
	# vertex_color_is_srgb HAS NO SHADER EQUIVALENT, so the conversion moved INTO the shader.
	# See its srgb_to_linear() and the comment above it; game/test/test_terrain.gd asserts the
	# function is in there by name, because dropping it renders a pale mint sheet and nothing
	# headless can see that.
	var mat := ShaderMaterial.new()
	mat.shader = GroundShader
	mat.set_shader_parameter(&"grass_high", GRASS_HIGH)
	mat.set_shader_parameter(&"dirt_color", DIRT)
	mat.set_shader_parameter(&"path_points", _path_uniform())
	mat.set_shader_parameter(&"path_point_count", PATH_POINTS.size())
	mat.set_shader_parameter(&"path_half_width", PATH_HALF_WIDTH)
	mat.set_shader_parameter(&"path_edge_softness", PATH_EDGE_SOFTNESS)
	mat.set_shader_parameter(&"path_edge_noise", PATH_EDGE_NOISE)
	mat.set_shader_parameter(&"path_glow", PATH_GLOW)
	mat.set_shader_parameter(&"grain_amount", GRAIN_AMOUNT)
	mat.set_shader_parameter(&"contact_dark", CONTACT_DARK)
	mesh.surface_set_material(0, mat)
	return mesh


# --- the grass at things' feet (PS10 gap G2; FS2.2) ---------------------------------------

## A brushed grain finer than the 0.9 m noise, and darker grass round everything that stands on
## the ground: a contact mask painted from every solid prop's footprint once the ranch stands
## (paint_contact), sampled by terrain.gdshader.
const GRAIN_AMOUNT := 0.05
const CONTACT_DARK := 0.32
## Metres per texel of the mask, and how far past a footprint's edge the shade fades out.
const CONTACT_TEXEL := 0.5
const CONTACT_FALLOFF := 0.7
var _contact: Image = null


## The ground's ShaderMaterial.
func ground_material() -> ShaderMaterial:
	if _mesh_instance == null or _mesh_instance.mesh == null:
		return null
	return _mesh_instance.mesh.surface_get_material(0) as ShaderMaterial


## Paint the contact mask from every solid prop under `root` (StaticBody3D on the PROPS layer:
## props, trees, stones, fence rails and posts), and hand it to the ground shader. A box is
## painted as a band along its long side, anything else as a disc; a shape whose bottom is
## more than a metre off the ground (a canopy) is not at its foot.
func paint_contact(root: Node) -> void:
	var n := int(HALF * 2.0 / CONTACT_TEXEL)
	_contact = Image.create(n, n, false, Image.FORMAT_R8)
	for body: Node in root.find_children("*", "StaticBody3D", true, false):
		if not (body as StaticBody3D).collision_layer & LayersScript.PROPS:
			continue
		for shape: CollisionShape3D in body.find_children("*", "CollisionShape3D", false, false):
			if shape.shape == null or shape.disabled:
				continue
			_paint_shape(shape)
	var mat := ground_material()
	if mat != null:
		mat.set_shader_parameter(&"contact_mask", ImageTexture.create_from_image(_contact))
		mat.set_shader_parameter(&"contact_origin", Vector2(-HALF, -HALF))
		mat.set_shader_parameter(&"contact_size", Vector2(HALF * 2.0, HALF * 2.0))


func _paint_shape(cs: CollisionShape3D) -> void:
	var xf := cs.global_transform
	var aabb := xf * cs.shape.get_debug_mesh().get_aabb()
	if aabb.position.y > height_at(aabb.get_center().x, aabb.get_center().z) + 1.0:
		return
	if cs.shape is BoxShape3D:
		var half: Vector3 = (cs.shape as BoxShape3D).size * 0.5
		var ax := Vector3(xf.basis.x.x, 0.0, xf.basis.x.z) * half.x
		var az := Vector3(xf.basis.z.x, 0.0, xf.basis.z.z) * half.z
		var along := ax if ax.length() >= az.length() else az
		var across := az.length() if ax.length() >= az.length() else ax.length()
		var c := xf.origin
		var steps := maxi(1, int(along.length() * 2.0 / CONTACT_TEXEL))
		for i in steps + 1:
			var p := c + along * (float(i) / float(steps) * 2.0 - 1.0)
			_paint_disc(p.x, p.z, across)
		return
	var r := maxf(aabb.size.x, aabb.size.z) * 0.5
	_paint_disc(aabb.get_center().x, aabb.get_center().z, r)


func _paint_disc(x: float, z: float, r: float) -> void:
	var n := _contact.get_width()
	var reach := r + CONTACT_FALLOFF
	var cx := (x + HALF) / CONTACT_TEXEL
	var cz := (z + HALF) / CONTACT_TEXEL
	var span := int(ceil(reach / CONTACT_TEXEL))
	for iz in range(maxi(0, int(cz) - span), mini(n, int(cz) + span + 1)):
		for ix in range(maxi(0, int(cx) - span), mini(n, int(cx) + span + 1)):
			var d := Vector2((ix + 0.5 - cx) * CONTACT_TEXEL, (iz + 0.5 - cz) * CONTACT_TEXEL).length()
			var v := 1.0 - smoothstep(r * 0.7, reach, d)
			if v > _contact.get_pixel(ix, iz).r:
				_contact.set_pixel(ix, iz, Color(v, v, v))


## How dark the grass is at (x, z) from things standing there, 0 (open) to 1 (at a base).
func contact_at(x: float, z: float) -> float:
	if _contact == null:
		return 0.0
	var ix := clampi(int((x + HALF) / CONTACT_TEXEL), 0, _contact.get_width() - 1)
	var iz := clampi(int((z + HALF) / CONTACT_TEXEL), 0, _contact.get_height() - 1)
	return _contact.get_pixel(ix, iz).r


## The mask's mean over the whole map (most ground should be open).
func contact_mean() -> float:
	if _contact == null:
		return 0.0
	var total := 0.0
	var n := _contact.get_width()
	for iz in range(0, n, 4):
		for ix in range(0, n, 4):
			total += _contact.get_pixel(ix, iz).r
	return total / pow(ceil(float(n) / 4.0), 2.0)


## PATH_POINTS, padded out to PATH_SHADER_SLOTS by repeating its own last entry -- the fixed
## length terrain.gdshader's `path_points` array uniform declares. An empty PATH_POINTS
## (no road at all) pads with the origin; `path_point_count` staying 0 is what keeps the
## shader from drawing anything with it, per its own `if (path_point_count > 1)` guard.
func _path_uniform() -> PackedVector2Array:
	var out := PackedVector2Array()
	var last := Vector2.ZERO
	for i in range(PATH_SHADER_SLOTS):
		if i < PATH_POINTS.size():
			last = PATH_POINTS[i]
		out.append(last)
	return out


## Four invisible slabs standing just outside the mesh edge. On TERRAIN rather than
## PROPS so the camera treats the edge of the world the same way it treats the
## ground: something to stop against, not something to frame a shot through.
func _build_boundary() -> void:
	var offsets := [
		Vector3(0.0, 0.0, -HALF - BOUNDARY_THICKNESS * 0.5),
		Vector3(0.0, 0.0, HALF + BOUNDARY_THICKNESS * 0.5),
		Vector3(-HALF - BOUNDARY_THICKNESS * 0.5, 0.0, 0.0),
		Vector3(HALF + BOUNDARY_THICKNESS * 0.5, 0.0, 0.0),
	]
	var sizes := [
		Vector3(HALF * 2.0 + BOUNDARY_THICKNESS * 2.0, BOUNDARY_HEIGHT, BOUNDARY_THICKNESS),
		Vector3(HALF * 2.0 + BOUNDARY_THICKNESS * 2.0, BOUNDARY_HEIGHT, BOUNDARY_THICKNESS),
		Vector3(BOUNDARY_THICKNESS, BOUNDARY_HEIGHT, HALF * 2.0 + BOUNDARY_THICKNESS * 2.0),
		Vector3(BOUNDARY_THICKNESS, BOUNDARY_HEIGHT, HALF * 2.0 + BOUNDARY_THICKNESS * 2.0),
	]
	for i in range(offsets.size()):
		var shape := BoxShape3D.new()
		shape.size = sizes[i]
		var node := CollisionShape3D.new()
		node.name = "Boundary%d" % i
		node.shape = shape
		# Straddles the deepest hollow and rises well above the highest rise.
		node.position = offsets[i] + Vector3(0.0, BOUNDARY_HEIGHT * 0.5 - 3.0, 0.0)
		add_child(node)
