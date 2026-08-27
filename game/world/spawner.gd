class_name Spawner
extends Node3D
## Fills the ranch's ZoneMarkers with wild ponies: for each marker, build a
## rarity-weighted SpawnTable from the registry entries zoned for that marker, draw
## `spawn_count` of them, and stand each one on the actual ground inside the
## marker's disc.
##
## THE GROUND IS FOUND BY RAYCAST, not assumed. game/world/terrain.gd is a rolling
## heightfield and the zone markers sit out past its flat apron on purpose, so
## `y = marker.y` would bury half a herd and float the other half. Each candidate
## point is probed with a downward ray and the pony is placed on what it hits. The
## ray also does a second job: a point that lands on a PROP is rejected and re-rolled,
## which is what stops a pony from spawning inside a tree trunk.
##
## RAYCASTS NEED A PHYSICS FRAME FIRST. The terrain's trimesh collider and the
## props' colliders are created in their own _ready(), and the physics server has
## not stepped since -- a space-state query made in the same frame sees an empty
## world and every ray misses. populate() must therefore be called AFTER at least
## one physics frame has elapsed; ranch.gd awaits two before calling it. Calling it
## too early does not fail silently: every ray misses, every placement falls back,
## and the fallback count is reported and asserted on.
##
## DETERMINISM. The draw is seeded, and the registry's entries are sorted BY THEIR
## id AS A STRING before the table is built. Both halves matter. PonyRegistry walks
## a directory, so its dictionary order is the filesystem's, not a guarantee; and
## StringName's `<` compares interned POINTERS rather than text, so sorting on the
## raw ids gives an order that is stable within one process and different between
## processes. That exact bug already shipped once in this project (game/scenes/test/
## wild_ponies.gd documents it) -- the String() casts below are the fix and must not
## be "simplified" away.
##
## COLLISION LAYERS ARE ASSIGNED HERE, per instance, rather than in pony.tscn. Not a
## style choice: the ranch is where the world's layer policy lives (see
## game/world/collision_layers.gd), and pony.tscn is shared with wild_ponies.tscn,
## which is a Phase 0-style test scene built entirely on the default layer 1. Setting
## the layers on the instance keeps that gate working untouched while the real world
## gets real layers.

const LayersScript := preload("res://world/collision_layers.gd")
const PonyScene := preload("res://actors/pony/pony.tscn")
const PonyRegistryScript := preload("res://systems/pony_registry.gd")
const SpawnTableScript := preload("res://systems/spawn_table.gd")
const ZoneMarkerScript := preload("res://world/zone_marker.gd")

## How far above and below a candidate point the ground ray is cast. Generous
## against terrain.gd's ~+/-2.4 m of relief, and cheap.
const RAY_UP := 40.0
const RAY_DOWN := 60.0

## Re-rolls allowed per pony before giving up on finding clear ground. Each reroll
## is rejected for one of two reasons: the ray hit a prop (she would be inside a
## tree) or she landed on top of a pony already placed.
const PLACEMENT_ATTEMPTS := 12

## Minimum ground distance between two freshly-spawned ponies, in metres. Two 0.42 m
## capsules need 0.84 m not to interpenetrate; 1.4 m leaves them visibly separate on
## frame one rather than shoving each other apart.
const MIN_SEPARATION := 1.4

@export_group("Spawning")
## Directory of PonyData .tres records.
@export_dir var pony_dir := "res://data/ponies"

## Fixed so the ranch is the same ranch every launch: same ponies, same spots, same
## wander targets. A collection game whose roster reshuffles every time you open it
## has no map to learn.
@export var spawn_seed := 20260827

## Node whose ZoneMarker children this spawner fills. Defaults to a sibling `Zones`.
@export var zones_path := NodePath("../Zones")

## Every PonyData the registry loaded, spawnable or not -- the roster as authored.
## Used to tell a mis-typed zone_id apart from an assetless checkout.
var _roster: Array = []

var _spawned: Array[CharacterBody3D] = []
var _fallback_placements := 0
var _empty_zones: Array[StringName] = []
var _unspawnable: Array[StringName] = []


## Draw and place every zone's ponies. Returns how many actually reached the tree.
##
## Call after at least one physics frame -- see the class comment.
func populate() -> int:
	var markers := get_markers()
	if markers.is_empty():
		push_error("Spawner: no ZoneMarker found under '%s' -- nothing to populate" % zones_path)
		return 0

	var entries := _spawnable_entries()

	var rng := RandomNumberGenerator.new()
	rng.seed = spawn_seed

	var slot := 0
	for marker: ZoneMarker in markers:
		var pool: Array[PonyData] = []
		for data: PonyData in entries:
			if marker.zone_id in data.spawn_zones:
				pool.append(data)

		# TWO DIFFERENT FAILURES, KEPT APART ON PURPOSE. "This zone_id matches no
		# pony in the roster at all" is a content bug -- a typo'd zone name -- and
		# ranch.gd fails the gate on it. "The roster has ponies for this zone but
		# none of their models exist on this machine" is the ordinary assetless
		# checkout (CI, a fresh clone), and must NOT fail. Collapsing them made the
		# assetless run go red for the wrong reason.
		if _zoned_in_roster(marker.zone_id) == 0 and not marker.zone_id in _empty_zones:
			_empty_zones.append(marker.zone_id)

		if pool.is_empty():
			continue

		var table := SpawnTableScript.new(pool, rng)
		for i in range(marker.spawn_count):
			var data: PonyData = table.draw()
			if data == null:
				push_error("Spawner: SpawnTable.draw() returned null for zone '%s' slot %d"
					% [marker.zone_id, i])
				continue
			var pony := _spawn_one(data, marker, slot)
			if pony != null:
				_spawned.append(pony)
			slot += 1

	return _spawned.size()


func get_markers() -> Array[ZoneMarker]:
	var result: Array[ZoneMarker] = []
	var root := get_node_or_null(zones_path)
	if root == null:
		return result
	for child in root.get_children():
		if child is ZoneMarkerScript:
			result.append(child)
	return result


func get_spawned() -> Array[CharacterBody3D]:
	return _spawned


## How many ponies had to be placed WITHOUT a ground hit. Must be zero: a non-zero
## count means the raycast is not finding the terrain (physics not stepped yet, wrong
## mask, or no collider at all), and the herd is standing at the marker's own height
## instead of on the ground.
func get_fallback_placements() -> int:
	return _fallback_placements


## Zone ids whose registry query returned nothing.
func get_empty_zones() -> Array[StringName]:
	return _empty_zones


## Ponies in the registry whose model_path does not resolve on this machine.
func get_unspawnable() -> Array[StringName]:
	return _unspawnable


## How many PonyData records the registry loaded, spawnable or not. Zero here means
## the roster itself could not be read -- a different and much worse problem than a
## roster whose models are missing.
func get_roster_size() -> int:
	return _roster.size()


## How many ponies the AUTHORED roster places in `zone`, regardless of whether their
## models exist on this machine.
func _zoned_in_roster(zone: StringName) -> int:
	var n := 0
	for data: PonyData in _roster:
		if zone in data.spawn_zones:
			n += 1
	return n


## Registry entries that can actually be built right now, sorted by id text.
##
## PonyRegistry deliberately KEEPS an entry whose model_path is broken (its own doc
## comment explains why: one bad path must not take a pony's stats and zones down
## with it), and PonyVisuals.build() is the choke point that refuses it -- loudly.
## Filtering here instead means an assetless checkout produces one calm report line
## rather than a push_error per pony per zone, which is what keeps the ranch's
## degraded mode legible in a CI log.
func _spawnable_entries() -> Array[PonyData]:
	var registry := PonyRegistryScript.new()
	var by_id: Dictionary = registry.load_all(pony_dir)
	_roster = by_id.values()

	var result: Array[PonyData] = []
	for data: PonyData in by_id.values():
		if data.model_path.is_empty() or not ResourceLoader.exists(data.model_path):
			if not data.id in _unspawnable:
				_unspawnable.append(data.id)
			continue
		result.append(data)

	# See the class comment: String(), not the raw StringName. This is the fix for a
	# real nondeterminism bug, not a redundant cast.
	result.sort_custom(func(a: PonyData, b: PonyData) -> bool:
		return String(a.id) < String(b.id))
	return result


## One pony: drawn record, ground-found position, seeded RNG, layered collision.
func _spawn_one(data: PonyData, marker: ZoneMarker, slot: int) -> CharacterBody3D:
	var pony: CharacterBody3D = PonyScene.instantiate()
	pony.name = "Pony%02d_%s" % [slot, data.id]
	pony.roam_radius = marker.roam_radius

	# Each pony gets her own generator, seeded from the world seed plus her slot, so
	# the map is reproducible AND no two ponies pick their wander targets in lockstep.
	var pony_rng := RandomNumberGenerator.new()
	pony_rng.seed = spawn_seed + slot * 7919
	pony.set_rng(pony_rng)

	pony.collision_layer = LayersScript.PONY
	pony.collision_mask = LayersScript.WALKABLE
	var detection := pony.get_node_or_null("DetectionArea") as Area3D
	if detection != null:
		detection.collision_layer = LayersScript.INTERACTION
		# She notices the player. Nothing else. Masking for PROPS here would make
		# every tree she walks past read as "the player is here".
		detection.collision_mask = LayersScript.PLAYER

	# Position BEFORE add_child: Pony._ready() records wherever she is standing at
	# that moment as her roaming anchor, and a pony added at the origin and moved
	# afterwards spends the rest of her life being leashed back to the origin
	# (pony.gd's setup() doc says so explicitly).
	pony.position = to_local(_ground_point(marker, slot))
	add_child(pony)
	pony.setup(data)
	return pony


## A random point inside `marker`'s disc, on the ground, clear of props and of the
## ponies already placed. Uniform over the disc's AREA -- sqrt() on the radius --
## because without it every draw crowds the centre and the herd spawns in a knot.
func _ground_point(marker: ZoneMarker, slot: int) -> Vector3:
	var rng := RandomNumberGenerator.new()
	# Derived from the world seed and the slot rather than shared with the draw RNG,
	# so a re-roll here cannot shift which pony the NEXT slot draws.
	rng.seed = spawn_seed * 31 + slot

	var space := get_world_3d().direct_space_state
	var centre := marker.global_position
	var last := centre

	for attempt in range(PLACEMENT_ATTEMPTS):
		var angle := rng.randf() * TAU
		var radius := sqrt(rng.randf()) * marker.spawn_radius
		var candidate := centre + Vector3(cos(angle), 0.0, sin(angle)) * radius
		last = candidate

		var query := PhysicsRayQueryParameters3D.create(
			candidate + Vector3.UP * RAY_UP,
			candidate + Vector3.DOWN * RAY_DOWN,
			LayersScript.WORLD)
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			continue

		var collider: Object = hit.get("collider")
		if collider is CollisionObject3D \
				and (collider as CollisionObject3D).collision_layer & LayersScript.PROPS != 0:
			# Inside a building or a tree canopy. Try somewhere else.
			continue

		var point: Vector3 = hit["position"]
		if _too_close(point):
			continue
		return point

	# Every attempt was rejected or missed. Fall back to the last candidate at the
	# marker's own height and COUNT IT -- ranch.gd fails the gate on a non-zero
	# count, so this can never quietly become the normal path.
	_fallback_placements += 1
	return Vector3(last.x, centre.y, last.z)


func _too_close(point: Vector3) -> bool:
	for other in _spawned:
		var d := Vector2(other.global_position.x - point.x, other.global_position.z - point.z)
		if d.length() < MIN_SEPARATION:
			return true
	return false
