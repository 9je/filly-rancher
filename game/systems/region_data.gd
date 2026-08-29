class_name RegionData
extends Resource
## ONE REGION OF THE MAP, as data. Where it is, how big, what its permit costs, what its
## grass looks like, and whether there is a lake in it. One .tres per region under
## game/data/regions/, so adding a region is authoring a data file: Terrain tints the
## ground from it, RegionFence rings it, the Market sells its permit, and the spawner's
## ZoneMarker for it carries the matching zone_id.
##
## `centre` is XZ in metres (Vector2.y is world Z), the same convention props.gd's LAYOUT
## uses. `gate_yaw_degrees` follows Pen.gate_yaw_degrees: 0 puts the gate on the +X side
## of the ring, positive turns counter-clockwise seen from above.

@export var id: StringName = &""
@export var display_name: String = ""
@export var centre := Vector2.ZERO
@export var radius := 20.0
@export var permit_cost := 0
@export var gate_yaw_degrees := 0.0
@export var grass_low := Color(0.239, 0.408, 0.196)
@export var grass_high := Color(0.443, 0.541, 0.271)
@export var has_lake := false
@export var lake_depth := 0.0


## The unlock string the Market writes and the fence reads.
func permit_id() -> StringName:
	return StringName("permit_" + String(id))


func contains(point: Vector2) -> bool:
	return point.distance_to(centre) <= radius


## 0 at the rim and beyond, 1 well inside. Terrain uses it to blend grass and, for the
## lake, to shape the basin. `feather` metres of smooth edge.
func weight_at(point: Vector2, feather: float = 8.0) -> float:
	var d := point.distance_to(centre)
	return 1.0 - smoothstep(radius - feather, radius, d)


func _to_string() -> String:
	return "RegionData(%s, r=%.0f, permit=%d)" % [String(id), radius, permit_cost]
