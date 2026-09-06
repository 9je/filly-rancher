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

## Invisible perimeter walls, so walking to the edge of the world is a wall rather
## than a fall. Tall enough that the player (2.14 m to the horn) cannot see over the
## top of the collider from ground level, though nothing renders there anyway.
const BOUNDARY_HEIGHT := 6.0
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
const DIRT := Color(0.393, 0.329, 0.157)

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
## x = 15 and x = -12, more than 10 m clear on either side) to z = 58, where the boardwalk's
## own first plate stands at (2.5, 58.0) -- so a kept boardwalk tile sits on painted ground
## too, rather than the seam trading one visible edge for another.
##
## A STRAIGHT TWO-POINT POLYLINE IS STILL A POLYLINE. The shader (`terrain.gdshader`) walks
## an arbitrary vertex list, so a future road that bends only has to add points here; nothing
## about the mask assumes two. Padded out to the shader's fixed-size uniform array by
## `_path_uniform()` below, repeating this array's own last point (a zero-length segment the
## shader's own distance walk treats as inert, not as a divide-by-zero).
const PATH_POINTS: Array[Vector2] = [Vector2(1.5, 10.0), Vector2(1.5, 58.0)]

## Half the path's full-strength core width, in metres -- "a couple of metres wide" per the
## ruling that replaced the tiled road. `PATH_EDGE_SOFTNESS` is how far past that the dirt
## fades back to grass, and `PATH_EDGE_NOISE` is how many metres the edge itself wanders by,
## sampled through the shader's own `value_noise()`, so the border reads as worn rather than
## as a UI decal with a hard edge. All three are also the ShaderMaterial's own uniforms
## (`terrain.gdshader`) and are set from here, the one place, in `_build_mesh()`.
const PATH_HALF_WIDTH := 1.1
const PATH_EDGE_SOFTNESS := 1.3
const PATH_EDGE_NOISE := 0.5

## HOW MUCH OF DIRT COMES BACK AS AN AMBIENT-INDEPENDENT EMISSION FLOOR ON THE PATH. Measured
## against the shipped dawn render: this route runs through the long shadow of the trees and
## fence posts that line it for most of its length, and DIRT's own albedo (about a fifth of
## GRASS_HIGH's) crushes toward black under ambient-only light (sRGB (19, 5, 0), against
## grass two metres away at (92, 123, 32)) -- a scorch mark, not a track. See
## terrain.gdshader's own fragment() comment for the full account.
const PATH_GLOW := 5.0

## The shader array uniform's own fixed length. Matches `PATH_MAX_POINTS` in
## `terrain.gdshader` -- game/test/test_terrain.gd pins both numbers so the two files cannot
## drift apart silently.
const PATH_SHADER_SLOTS := 8

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
		if value != null:
			for region in value.all():
				if region.has_lake:
					_lakes.append(region)

var _mesh_instance: MeshInstance3D
var _collision: CollisionShape3D

## The subset of `regions` that carries a lake, in registry order. See the setter above.
var _lakes: Array[RegionDataScript] = []


func _ready() -> void:
	collision_layer = LayersScript.TERRAIN
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
## A region with a lake in it is a BASIN sunk into the relief: a smooth bowl reaching full
## depth in the middle and nothing at all by the rim, feathered over the OUTER half of the
## radius (from half radius out to the rim) so the ground walks down into the water instead
## of stepping off a shelf. It is
## subtracted here, in the one function everything else reads, so the mesh, the collider,
## the props and the water disc all agree about where the bottom is.
func height_at(x: float, z: float) -> float:
	var h := _raw_height(x, z) * _relief_weight(x, z)
	if not _lakes.is_empty():
		var point := Vector2(x, z)
		for region in _lakes:
			h -= region.lake_depth * region.weight_at(point, region.radius * 0.5)
	return h


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
	return Vector2(x, z).distance_to(HOMESTEAD_CENTRE) <= FLAT_RADIUS


## 0 inside the flat apron, 1 out in open country, smooth in between.
func _relief_weight(x: float, z: float) -> float:
	var d := Vector2(x, z).distance_to(HOMESTEAD_CENTRE)
	return smoothstep(FLAT_RADIUS, BLEND_RADIUS, d)


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


## A flat, translucent disc of water for a region that has a lake, ready for the caller to
## parent wherever it keeps its regional scenery (ranch.gd puts it under $Regions).
##
## NO COLLISION, deliberately: the ground under it is the terrain's own basin, which is
## walkable, so a pony or a player wading in is standing on real ground the whole way.
## Water that pushed bodies around would be a swimming mechanic, and there is not one.
func build_water(region: RegionDataScript) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	# The inner 70 percent of the region, so the shore is bare basin rather than the water
	# running straight up to the fence.
	mesh.top_radius = region.radius * 0.7
	mesh.bottom_radius = region.radius * 0.7
	mesh.height = 0.05

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.20, 0.42, 0.62, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.15
	mat.metallic = 0.1
	mesh.material = mat

	var node := MeshInstance3D.new()
	node.name = "Water_" + String(region.id)
	node.mesh = mesh
	# height_at() in the middle is the BOTTOM of the basin, so the surface is put back most
	# of the way up toward the rim: deep enough to read as water, shallow enough that the
	# basin's own shore is still visible around it.
	node.position = Vector3(
		region.centre.x,
		height_at(region.centre.x, region.centre.y) + region.lake_depth * 0.55 - 0.4,
		region.centre.y)
	return node


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
	mesh.surface_set_material(0, mat)
	return mesh


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
