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
## deterministic arithmetic are in git, are identical on every machine, and cost
## about a millisecond at startup. It also means height_at() is available as a
## plain function, which is what lets props sit exactly on the ground instead of
## being nudged by hand until they stop floating.
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

## Half-width of the map, in metres. The ground spans [-HALF, HALF] on both X and Z.
const HALF := 70.0
## Metres per grid cell. 2 m gives a 70x70 quad grid (9800 triangles) -- fine enough
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
const GRASS_LOW := Color(0.239, 0.408, 0.196)
const GRASS_HIGH := Color(0.443, 0.541, 0.271)

var _mesh_instance: MeshInstance3D
var _collision: CollisionShape3D


func _ready() -> void:
	collision_layer = LayersScript.TERRAIN
	# A StaticBody3D never initiates a collision query of its own; leaving a mask on
	# it costs broadphase work and buys nothing.
	collision_mask = 0

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
## Deterministic and stateless: no RNG, no noise texture, no per-machine anything.
func height_at(x: float, z: float) -> float:
	return _raw_height(x, z) * _relief_weight(x, z)


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
			# size rather than being stretched across 140 m.
			uvs.append(Vector2(x, z) * 0.25)
			# Higher, drier ground reads a shade lighter and yellower; hollows stay
			# a deeper green, and a fine patchwork on top keeps even the perfectly
			# flat homestead apron from rendering as one uniform sheet. Deliberately
			# driven by the UNflattened relief, so the yard is tinted like the land it
			# was levelled out of.
			var tone := 0.5 + _raw_height(x, z) * 0.16 \
				+ sin(x * 0.31) * cos(z * 0.27) * 0.11 \
				+ sin((x - z) * 0.13 + 2.1) * 0.07
			colors.append(GRASS_LOW.lerp(GRASS_HIGH, clampf(tone, 0.0, 1.0)))

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

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.WHITE
	mat.vertex_color_use_as_albedo = true
	# NOT optional. Godot renders in linear space and treats vertex colours as
	# ALREADY linear unless told otherwise, so the sRGB-looking constants above come
	# out roughly twice as bright as authored: the first render of this terrain was a
	# pale mint sheet, not grass. Every colour a human picks by eye is an sRGB
	# colour, so this flag is what makes GRASS_LOW/GRASS_HIGH mean what they say.
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.95
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mesh.surface_set_material(0, mat)
	return mesh


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
