class_name CollectorPatrol
extends Node3D
## A COLLECTOR ON PATROL (STORY.md R.3; reused by the Rescue path's corral raids): walks a
## loop of points carrying a lantern, and SEES what stands inside the lantern's cone, in
## range, with nothing in the way. Spotting is the whole verdict; what it costs (a buzzer
## and a reset, more Heat) is the caller's business.
##
## Add as a child of an Npc. The cone is drawn as a soft translucent volume so the player
## can read where it looks, the way the stealth in a cartoon is always readable.

signal spotted(target: Node3D)

const LayersScript := preload("res://world/collision_layers.gd")
## Walking into her is being caught (playtest 2026-11-10 item 11: "i can push and spin them").
const BUMP_RADIUS := 1.4
## Her lantern hangs at her head, ahead of her body's centre (item 12: the cone came out
## behind her head).
const LANTERN_AHEAD := 0.75
const LANTERN_HEIGHT := 1.45

@export var range := 8.5
@export var half_angle_deg := 24.0
@export var pause_seconds := 1.6
@export var walk_speed := 1.25

var points: Array[Vector3] = []
var target: Node3D
var enabled := true

var _npc: Npc
var _i := 0
var _wait := 0.0
var _light: SpotLight3D
var _cone: MeshInstance3D
var _cooldown := 0.0


func _ready() -> void:
	_npc = get_parent() as Npc
	_light = SpotLight3D.new()
	_light.light_color = Color(1.0, 0.92, 0.66)
	_light.light_energy = 3.0
	_light.spot_range = range
	_light.spot_angle = half_angle_deg
	_light.shadow_enabled = false
	_light.position = Vector3(0, 1.4, 0)
	add_child(_light)
	_cone = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	var r := tan(deg_to_rad(half_angle_deg)) * range
	cyl.top_radius = 0.05
	cyl.bottom_radius = r
	cyl.height = range
	cyl.radial_segments = 24
	_cone.mesh = cyl
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(1.0, 0.9, 0.55, 0.08)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	_cone.material_override = m
	_cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_cone)
	if _npc != null:
		_npc.walk_speed = walk_speed


func _physics_process(delta: float) -> void:
	if _npc == null:
		return
	_aim()
	_cooldown = maxf(0.0, _cooldown - delta)
	if not enabled:
		return
	_walk(delta)
	if target != null and _cooldown <= 0.0 and (bumped(target.global_position)
			or sees(target.global_position + Vector3(0, 0.8, 0))):
		_cooldown = 2.0
		spotted.emit(target)


## True when `point` is close enough that she has walked into her.
func bumped(point: Vector3) -> bool:
	var d := Vector2(point.x - global_position.x, point.z - global_position.z).length()
	return d < BUMP_RADIUS


func _lantern() -> Vector3:
	return global_position + forward() * LANTERN_AHEAD + Vector3(0, LANTERN_HEIGHT, 0)


func _walk(delta: float) -> void:
	if points.is_empty():
		return
	if _npc.mode == Npc.Mode.STAND:
		_wait -= delta
		if _wait <= 0.0:
			_i = (_i + 1) % points.size()
			_npc.set_mode_walk_to(points[_i])
			_wait = pause_seconds


## Point the lantern the way she is facing.
func _aim() -> void:
	var fwd := forward()
	var origin := _lantern()
	_light.global_transform = Transform3D(Basis.looking_at(fwd + Vector3(0, -0.25, 0), Vector3.UP), origin)
	var centre := origin + fwd * range * 0.5 + Vector3(0, -0.6, 0)
	var dir := (centre - origin).normalized()
	# CylinderMesh's axis is +Y with its wide end down: aim -Y along the look.
	_cone.global_transform = Transform3D(Basis(Quaternion(Vector3.DOWN, dir)), centre)


func forward() -> Vector3:
	var visuals := _npc.get_node_or_null("Visuals") as Node3D
	var yaw := visuals.global_rotation.y if visuals != null else _npc.global_rotation.y
	# Donor bodies face -Z.
	return Vector3(-sin(yaw), 0, -cos(yaw)).normalized()


## True when `point` is in the cone, in range, and in the clear.
func sees(point: Vector3) -> bool:
	var origin := _lantern()
	var to := point - origin
	if to.length() > range:
		return false
	var flat := Vector3(to.x, 0, to.z)
	if flat.length() < 0.01:
		return true
	if rad_to_deg(forward().angle_to(flat.normalized())) > half_angle_deg:
		return false
	var space := get_world_3d().direct_space_state
	# WALLS AND PROPS HIDE HER, PONIES DO NOT (item 11: the companion at her heels stood in
	# every line of sight, so no Collector ever saw her).
	var q := PhysicsRayQueryParameters3D.create(origin, point, LayersScript.WORLD)
	# BUILT, THEN ASSIGNED: `exclude` hands back a copy, so appending to it after the fact
	# dropped the target and the ray stopped on her own body. That is why no Collector ever
	# saw anyone (item 11).
	var skip: Array[RID] = [_npc.get_rid()]
	if target is CollisionObject3D:
		skip.append((target as CollisionObject3D).get_rid())
	q.exclude = skip
	var hit := space.intersect_ray(q)
	return hit.is_empty()
