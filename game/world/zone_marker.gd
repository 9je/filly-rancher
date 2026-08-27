class_name ZoneMarker
extends Area3D
## A place on the map where wild ponies live. Declares WHICH ponies (`zone_id`,
## matched against PonyData.spawn_zones), HOW MANY (`spawn_count`), and OVER WHAT
## GROUND (`spawn_radius`). game/world/spawner.gd reads these and does the work;
## this node holds no logic of its own beyond sizing its own shape.
##
## WHY AN Area3D and not a plain Marker3D. Two reasons, one now and one soon. Now:
## an Area3D draws its shape in the editor, so the spawn footprint is something you
## can see and drag rather than a number you have to imagine -- which matters when
## the whole job is judging whether a zone sits clear of the buildings. Soon: "the
## player has entered the north meadow" is the natural trigger for zone music, a
## location banner, or a re-spawn tick, and that needs a real overlap volume. The
## shape is built and layered for that; `monitoring` stays OFF until something
## actually consumes the signal, because an area that reports overlaps nobody reads
## is pure broadphase cost.
##
## ROAM RADIUS IS NOT SPAWN RADIUS, and the gap between them is load-bearing.
## Pony.roam_radius is a SOFT boundary: _leash() bends a fleeing pony's heading back
## along the circle rather than stopping her dead, so her momentum carries her about
## 1.15 m past it at full gallop. Anything sized to "where a pony can be" therefore
## has to be roam_radius PLUS that overshoot -- a fence built exactly on the roam
## radius is a fence ponies clip through. `roam_radius` below defaults to
## comfortably inside `spawn_radius` for the same reason: a pony spawned on the rim
## of the zone should still be wandering inside the zone, not straddling its edge.

const LayersScript := preload("res://world/collision_layers.gd")

## Metres a fleeing pony overruns her roam circle by, at top speed. Measured, not
## guessed -- see the class comment. Anything deriving a hard boundary from a roam
## radius must add this.
const ROAM_OVERSHOOT := 1.15

@export_group("Zone")
## Matched against PonyData.spawn_zones. The whole current roster is zoned `ranch`
## (game/data/ponies/*.tres), so every marker on this map uses it; the field exists
## so Phase 2 can add a `forest`/`mountain` roster without touching this code, and
## the spawner already reports a zone whose pool comes back empty rather than
## quietly spawning nothing.
@export var zone_id: StringName = &"ranch"

## Radius, in metres, of the disc that ponies are scattered over.
@export var spawn_radius := 10.0

## How many ponies the spawner draws for this zone.
@export var spawn_count := 3

## roam_radius handed to each pony spawned here. Kept below spawn_radius so a pony
## who spawns on the rim still roams within the zone rather than out of it.
@export var roam_radius := 6.0


func _ready() -> void:
	collision_layer = LayersScript.INTERACTION
	collision_mask = LayersScript.PLAYER
	# See the class comment: declared and shaped, not yet listened to.
	monitoring = false
	monitorable = false
	_ensure_shape()


## Furthest a pony spawned in this zone can legitimately get from the marker: the
## rim of the spawn disc, plus her whole roam circle, plus the flee overshoot. The
## bound ranch.gd checks each pony against -- and the bound any future fence or
## boundary prop for this zone must clear.
func outer_bound() -> float:
	return spawn_radius + roam_radius + ROAM_OVERSHOOT


## A CylinderShape3D matching spawn_radius. Built in code so the shape cannot drift
## from the exported number the spawner actually uses -- the same "one source of
## truth, pushed into the shape" treatment pony.gd gives its DetectionArea.
func _ensure_shape() -> void:
	var node := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if node == null:
		node = CollisionShape3D.new()
		node.name = "CollisionShape3D"
		add_child(node)
	var shape := CylinderShape3D.new()
	shape.radius = spawn_radius
	# Tall enough to contain the relief the zone sits on plus a pony's full 2.14 m.
	shape.height = 12.0
	node.shape = shape
	node.position = Vector3(0.0, 4.0, 0.0)
