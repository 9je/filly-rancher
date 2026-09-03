class_name Mailbox
extends StaticBody3D
## THE COMPANY'S MAILBOX, BY THE RANCH DOOR. A post, a box on top of it, and a flag that
## goes up when there is something in it. Assembled from primitives at load time, like
## game/world/building.gd, for the two reasons that file gives: it is IN GIT, so it exists
## on a CI checkout and in a fresh clone where game/assets/converted/ does not, and it is
## sized from a measurement rather than from whatever a converted mesh happened to be.
##
## NOT A Building, DELIBERATELY. Building.build() push_errors when door_height is under
## MIN_DOOR_CLEARANCE (2.25 m, a pony's horn tip), which is the right rule for a thing with
## a doorway and a silly one for a thing 1.15 m tall with no door at all. So this is its own
## small node, a child of $Buildings so it rides the same build-and-seat loop and is counted
## by the same census, and ranch.gd's gate measures it by the rule it measures every non
## Building prop by: seated against terrain.height_at() under its own origin.
##
## THE FLAG IS THE UNREAD SIGNAL, AND IT IS A MESH. The owner's standing note on the look:
## no floating text in the world. So "you have post" is a red flag standing up off the side
## of the box, readable across the yard, and one HUD toast when it lands; there is no
## floating world label here and there never will be.

const LayersScript := preload("res://world/collision_layers.gd")

## How high the post stands, in metres. Measured against the pony: 1.163 m at the withers
## (docs/pipeline.md section 3), so a box whose lid is a little under that is a box a pony
## can reach into, and a post any taller reads as a signpost.
const POST_HEIGHT := 1.05
const POST_THICKNESS := 0.10

## The box on top: wider than it is tall, deeper than it is wide, like every mailbox.
const BOX_SIZE := Vector3(0.34, 0.26, 0.52)

## The flag on its side.
const FLAG_SIZE := Vector3(0.04, 0.24, 0.03)

## How far the flag turns when it goes up. Ninety degrees about Z takes it from lying flat
## along the box to standing off its side, which is the shape everybody reads instantly.
const FLAG_UP_DEGREES := 90.0

## The Company's own colours, the Depot's walls and roof from game/world/ranch.tscn, so the
## box at the door and the building across the yard are the same company.
const BOX_COLOR := Color(0.62, 0.64, 0.68)
const POST_COLOR := Color(0.36, 0.30, 0.24)
const FLAG_COLOR := Color(0.78, 0.20, 0.22)

var _built := false
var _flag_up := false
var _flag: Node3D = null


func _ready() -> void:
	collision_layer = LayersScript.PROPS
	collision_mask = 0


## Assemble it. Idempotent, and called by ranch.gd's build-and-seat loop over $Buildings'
## children, which is why this is a method rather than work done in _ready().
func build() -> void:
	if _built:
		return
	_built = true
	_slab("Post", Vector3(POST_THICKNESS, POST_HEIGHT, POST_THICKNESS),
		Vector3(0.0, POST_HEIGHT * 0.5, 0.0), POST_COLOR)
	_slab("Box", BOX_SIZE, Vector3(0.0, POST_HEIGHT + BOX_SIZE.y * 0.5, 0.0), BOX_COLOR)
	_flag = _slab("Flag", FLAG_SIZE,
		Vector3(BOX_SIZE.x * 0.5 + FLAG_SIZE.x, POST_HEIGHT + BOX_SIZE.y * 0.5
			+ FLAG_SIZE.y * 0.5, 0.0), FLAG_COLOR)
	_apply_flag()


## Something is waiting, or is not. A no op when the flag is already where it should be, so
## a caller may push this every frame without churning a transform.
func set_flag_up(up: bool) -> void:
	if _flag_up == up:
		return
	_flag_up = up
	_apply_flag()


func is_flag_up() -> bool:
	return _flag_up


func _apply_flag() -> void:
	if _flag == null:
		return
	_flag.rotation_degrees.z = FLAG_UP_DEGREES if _flag_up else 0.0


## One box: a mesh, a matching collision shape, and a material. Returns the node so the flag
## can be kept and turned. The collision is on THIS body, which is what makes the whole
## assembly one solid thing on the PROPS layer, the way a Building is.
func _slab(part_name: String, size: Vector3, at: Vector3, colour: Color) -> Node3D:
	var holder := Node3D.new()
	holder.name = part_name
	holder.position = at
	add_child(holder)

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.85
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mesh.material_override = material
	holder.add_child(mesh)

	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	shape.position = at
	add_child(shape)
	return holder
