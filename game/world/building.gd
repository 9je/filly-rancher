class_name Building
extends StaticBody3D
## A gabled farm building -- walls, a doorway you can actually walk through, a
## pitched roof -- assembled from primitives at load time.
##
## WHY THIS EXISTS: THE PROP KIT HAS NO BUILDINGS IN IT. That was not obvious from
## the pipeline's own measurements and it is worth writing down. docs/pipeline.md
## section 4 lists `kenney_windmill.glb` (3.11 units) and `kenney_watermill.glb`
## (1.80) under "buildings/structures", and every structural gate agreed: they
## import, they validate, they measure, they collide. The first rendered frame of the
## ranch showed what they actually are -- the Fantasy Town Kit's modular ATTACHMENT
## pieces. `windmill.glb` is a bare X of sails with no tower behind it.
## `watermill.glb` is a bare waterwheel with no mill. `kenney_survival_structure.glb`
## is an open timber frame. There is no house, no barn, no wall with a door in it
## anywhere in game/assets/converted/props/. A "homestead" composed from them reads
## as farm equipment abandoned in a field, which is exactly what the render showed.
##
## Converting the pack's complete building modules is the real fix and it belongs in
## an asset task (this one is forbidden from touching game/assets/). In the meantime
## a barn made of boxes is a better visual anchor than a windmill with no windmill,
## and it buys two things a converted prop could not:
##
##   1. IT IS IN GIT. Everything under game/assets/converted/ is gitignored, so a CI
##      checkout and a fresh clone have no props at all (docs/ci.md section 4). These
##      buildings are code, so the ranch has a skyline on every machine -- including
##      the CI runner, which means the camera-versus-a-real-wall check that this
##      task exists to fix runs in CI too instead of only on the owner's box.
##   2. IT HAS A DOORWAY SIZED FROM THE MEASUREMENT THAT MATTERS. A pony is 1.163 m
##      at the withers and 2.138 m to the top of her horn (docs/pipeline.md section
##      3). Anything you can walk through has to clear the SECOND number; sizing a
##      door off "how tall is a pony" and reaching for the withers figure produces a
##      door she heads straight into. `door_height` is asserted against
##      MIN_DOOR_CLEARANCE below so that mistake cannot be made silently here.
##
## SCALE. Deliberately kept in the Kenney kits' family rather than at real-world barn
## proportions: those kits are stylised small (their trees top out around 3 m at the
## project's 1.5x prop factor), and a photoreal 8 m barn dropped next to them would
## make the rest of the map look like a model railway. Consistency reads as a place;
## one correctly-scaled object among stylised ones does not.

const LayersScript := preload("res://world/collision_layers.gd")

## Metres of headroom a doorway must offer. The pony's full 2.138 m plus a hand's
## width, so the number in this file is recognisably the horn-tip measurement and not
## the withers one.
const MIN_DOOR_CLEARANCE := 2.25

@export_group("Shell")
## Footprint along X, in metres.
@export var width := 9.0
## Footprint along Z. The roof ridge runs along Z, so the gable ends -- and the door
## -- face +/-Z.
@export var depth := 6.5
## Height of the eaves.
@export var wall_height := 3.4
## Height of the ridge. Must exceed wall_height or the roof is inside out.
@export var ridge_height := 4.8
@export var wall_thickness := 0.28
## How far the roof oversails the walls.
@export var eave_overhang := 0.45

@export_group("Doorway")
## Clear opening in the +Z gable end. Checked against MIN_DOOR_CLEARANCE.
@export var door_width := 2.8
@export var door_height := 2.8

@export_group("Colour")
@export var wall_color := Color(0.556863, 0.231373, 0.192157)
@export var roof_color := Color(0.278431, 0.243137, 0.223529)
## The door lintel and the interior floor. Dark timber by default: a pale lintel
## reads as a gap in the wall rather than as a beam over a door -- which is exactly
## how the first render of the barn looked.
@export var trim_color := Color(0.309804, 0.219608, 0.176471)

var _built := false


func _ready() -> void:
	collision_layer = LayersScript.PROPS
	collision_mask = 0


## Assemble the building. Idempotent; called by ranch.gd so that seating against the
## terrain can happen immediately afterwards, in one place, by the same rule props
## are seated by.
func build() -> void:
	if _built:
		return
	_built = true

	if door_height < MIN_DOOR_CLEARANCE:
		push_error(("Building '%s': door_height %.2f m does not clear a pony's %.2f m " +
			"horn tip -- see MIN_DOOR_CLEARANCE") % [name, door_height, MIN_DOOR_CLEARANCE])
	if ridge_height <= wall_height:
		push_error("Building '%s': ridge_height must exceed wall_height" % name)

	var wall_mat := _material(wall_color)
	var roof_mat := _material(roof_color)
	var trim_mat := _material(trim_color)

	var half_w := width * 0.5
	var half_d := depth * 0.5
	var t := wall_thickness

	# --- floor -------------------------------------------------------------------
	# A boarded floor rather than grass showing through the doorway: without it the
	# opening reads as a hole punched in the wall instead of as a way in.
	_slab("Floor", Vector3(width, 0.14, depth), Vector3(0.0, 0.07, 0.0), trim_mat)

	# --- walls -------------------------------------------------------------------
	_slab("WallBack", Vector3(width, wall_height, t),
		Vector3(0.0, wall_height * 0.5, -half_d + t * 0.5), wall_mat)
	_slab("WallLeft", Vector3(t, wall_height, depth - t * 2.0),
		Vector3(-half_w + t * 0.5, wall_height * 0.5, 0.0), wall_mat)
	_slab("WallRight", Vector3(t, wall_height, depth - t * 2.0),
		Vector3(half_w - t * 0.5, wall_height * 0.5, 0.0), wall_mat)

	# --- front gable end, with the doorway left out of it -------------------------
	var panel := maxf((width - door_width) * 0.5, 0.0)
	var front_z := half_d - t * 0.5
	if panel > 0.001:
		_slab("WallFrontL", Vector3(panel, wall_height, t),
			Vector3(-(width - panel) * 0.5, wall_height * 0.5, front_z), wall_mat)
		_slab("WallFrontR", Vector3(panel, wall_height, t),
			Vector3((width - panel) * 0.5, wall_height * 0.5, front_z), wall_mat)
	var lintel := wall_height - door_height
	if lintel > 0.001:
		_slab("Lintel", Vector3(door_width, lintel, t),
			Vector3(0.0, door_height + lintel * 0.5, front_z), trim_mat)

	# --- roof ---------------------------------------------------------------------
	# Two slabs leaning against each other. Built as rotated BoxMeshes rather than as
	# hand-wound triangles so Godot's own (clockwise-front-face) winding is used
	# instead of re-derived -- terrain.gd's class comment explains what getting that
	# wrong costs.
	var run := half_w + eave_overhang
	var rise := ridge_height - wall_height
	var slope := sqrt(run * run + rise * rise)
	var angle := atan2(rise, run)
	var slab := Vector3(slope, 0.22, depth + eave_overhang * 2.0)
	var mid_y := (wall_height + ridge_height) * 0.5
	_slab("RoofLeft", slab, Vector3(-run * 0.5, mid_y, 0.0), roof_mat, angle)
	_slab("RoofRight", slab, Vector3(run * 0.5, mid_y, 0.0), roof_mat, -angle)

	# --- gable infill --------------------------------------------------------------
	# The triangle of wall between the eaves and the ridge, at each end. Two
	# triangles, no collision (the roof slabs above already stop everything), and
	# CULL_DISABLED because a hand-wound triangle that comes out backwards would be an
	# invisible hole rather than a visible mistake -- and unlike the terrain, nothing
	# here depends on the facing.
	var gable := ArrayMesh.new()
	var verts := PackedVector3Array([
		Vector3(-half_w, wall_height, half_d), Vector3(half_w, wall_height, half_d),
		Vector3(0.0, ridge_height, half_d),
		Vector3(-half_w, wall_height, -half_d), Vector3(half_w, wall_height, -half_d),
		Vector3(0.0, ridge_height, -half_d),
	])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 3, 4, 5])
	gable.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var gable_mat := _material(wall_color)
	gable_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	gable.surface_set_material(0, gable_mat)
	var gable_node := MeshInstance3D.new()
	gable_node.name = "Gables"
	gable_node.mesh = gable
	add_child(gable_node)

	_add_interior_light()


## A warm fill light inside the shell.
##
## WHY A BUILDING NEEDS ITS OWN LIGHT. Phase 1A Task 9's integration pass walked the
## player in through the barn door and the render came back a black box: floor, walls
## and roof all at effectively zero luminance, with the pony a silhouette. The ranch is
## lit by one directional sun plus a low sky-ambient term (ranch.tscn's Environment:
## ambient_light_energy 0.32, 85% sky contribution), and there is no global illumination
## in a Forward+ scene without SDFGI -- so a closed box gets the ambient term and nothing
## else. That is physically reasonable and it is a bad room to walk into.
##
## FIXED HERE RATHER THAN BY RAISING THE ENVIRONMENT'S AMBIENT, deliberately: the
## exterior is already lit the way it should be (the establishing renders read well),
## and turning ambient up to rescue two interiors would flatten every outdoor shadow on
## the map to do it. A light that belongs to the building only affects the building.
##
## SHADOWS ARE ON, AND THAT IS NOT OPTIONAL. An OmniLight3D without shadows passes
## straight through geometry, so a shadowless fill inside the barn would light the
## OUTSIDE of its own walls and the grass around it -- a glowing barn in daylight. Two
## shadow-casting omnis on a low-poly map is a cost worth paying to avoid that.
func _add_interior_light() -> void:
	var light := OmniLight3D.new()
	light.name = "InteriorFill"
	# Just under the eaves and slightly back from the door, so the brightest part of the
	# room is the far end you are walking toward rather than the threshold.
	light.position = Vector3(0.0, wall_height * 0.78, -depth * 0.12)
	# Enough to reach every corner of the shell and no further -- the shadow map does the
	# real containment, but a range that stops near the walls also keeps the cost down.
	light.omni_range = maxf(width, depth) * 0.95
	light.light_color = Color(1.0, 0.92, 0.80)
	light.light_energy = 1.6
	# Straw and lamplight, not a spotlight: the falloff is deliberately soft so the room
	# reads as generally lit rather than as having a bulb hanging in it.
	light.omni_attenuation = 0.6
	light.shadow_enabled = true
	light.shadow_bias = 0.04
	add_child(light)


func _material(colour: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = 0.9
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return mat


## One box: a MeshInstance3D and a matching CollisionShape3D sharing a transform, so
## what you see and what you bump into cannot drift apart.
func _slab(slab_name: String, size: Vector3, at: Vector3, mat: StandardMaterial3D,
		roll := 0.0) -> void:
	var box := BoxMesh.new()
	box.size = size
	box.material = mat

	var mesh_node := MeshInstance3D.new()
	mesh_node.name = slab_name
	mesh_node.mesh = box
	mesh_node.position = at
	mesh_node.rotation.z = roll
	add_child(mesh_node)

	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.name = slab_name + "Col"
	col.shape = shape
	col.position = at
	col.rotation.z = roll
	add_child(col)
