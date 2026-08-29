class_name RegionRegistry
extends RefCounted
## Loads RegionData resources (game/systems/region_data.gd) out of a directory of .tres
## files and indexes them by id, mirroring ShopRegistry (game/systems/shop_registry.gd)
## exactly: same reasons apply: instance based, so load_all() populates this registry's
## own index rather than a shared global one; constructible and testable headlessly with a
## plain `.new()`; and the `.tres`/`.tres.remap` resolution in _resource_path() is copied
## verbatim from ShopRegistry/PlotRegistry because it is the same export-time fact. Godot's
## exporter converts text resources to binary by default, so an exported .pck carries
## `foo.tres.remap` stubs instead of bare `.tres` files, and the path to actually load is
## the original name with the `.remap` suffix stripped. See PonyRegistry's much longer
## comment on this exact bug, which shipped once already and emptied the whole pony roster
## in a build that still printed a green marker.
##
## THE ONE THING THIS ADDS OVER ShopRegistry: region_at() answers "which region's disc, if
## any, contains this XZ point", which Terrain and the fences need every frame they care.

const RegionDataScript := preload("res://systems/region_data.gd")

## The directory the shipped regions live in. Committed, unlike game/assets/converted/,
## so it is present on every machine and in every export (docs/ci.md section 4).
const REGION_DIR := "res://data/regions"

var _by_id: Dictionary = {}  # StringName -> RegionData
var _ordered: Array[RegionData] = []


## Scans `dir` for `.tres`/`.tres.remap` files, loads each as a RegionData resource, and
## indexes it by `id`. Returns the same {id: RegionData} dictionary cached internally for
## by_id() to read.
##
## A resource that fails to load as RegionData is REPORTED via push_error() rather than
## silently dropped, and a directory that cannot be opened at all is also reported and
## returns an empty dictionary rather than crashing: same contract as the other
## registries.
func load_all(dir: String = REGION_DIR) -> Dictionary:
	_by_id.clear()
	_ordered.clear()
	var da := DirAccess.open(dir)
	if da == null:
		push_error("RegionRegistry.load_all: cannot open directory '%s' (%s)" % [
			dir, error_string(DirAccess.get_open_error())
		])
		return _by_id

	da.list_dir_begin()
	var seen := {}
	var file_name := da.get_next()
	while file_name != "":
		if not da.current_is_dir():
			var path := _resource_path(dir, file_name)
			if path != "" and not seen.has(path):
				seen[path] = true
				_load_one(path)
		file_name = da.get_next()
	da.list_dir_end()

	_rebuild_order()
	return _by_id


## The res:// path to load for a directory entry, or "" if it is not a resource this
## registry should read. See the class comment; copied verbatim from
## PlotRegistry._resource_path().
func _resource_path(dir: String, file_name: String) -> String:
	var entry := file_name
	if entry.get_extension() == "remap":
		entry = entry.get_basename()
	var ext := entry.get_extension()
	if ext == "tres" or ext == "res":
		return dir.path_join(entry)
	return ""


func _load_one(path: String) -> void:
	var res: Resource = load(path)
	if res == null or not (res is RegionDataScript):
		push_error("RegionRegistry.load_all: '%s' did not load as a RegionData resource" % path)
		return

	var region: RegionData = res
	if String(region.id).is_empty():
		push_error("RegionRegistry.load_all: '%s' has an empty id" % path)
		return
	if region.permit_cost < 0:
		push_error("RegionRegistry.load_all: '%s' has a negative permit_cost" % path)
		return
	if _by_id.has(region.id):
		push_error("RegionRegistry.load_all: duplicate id '%s' in '%s'" % [region.id, path])
		return

	_by_id[region.id] = region


## Cheapest permit first, then by id. The id is the tie-break rather than the display name
## so the order does not move if a region is renamed, and it makes the order total: two
## regions at the same price would otherwise still be at the mercy of the directory listing.
func _rebuild_order() -> void:
	var list: Array[RegionData] = []
	for key in _by_id:
		list.append(_by_id[key])
	list.sort_custom(func(a: RegionData, b: RegionData) -> bool:
		if a.permit_cost != b.permit_cost:
			return a.permit_cost < b.permit_cost
		return String(a.id) < String(b.id))
	_ordered = list


## Every loaded region, cheapest permit first. A COPY: callers iterate this repeatedly, and
## handing out the live array would let a caller reorder the catalogue.
func all() -> Array[RegionData]:
	return _ordered.duplicate()


## The RegionData indexed under `id`, or NULL if this registry has never heard of it. NULL
## IS A SUPPORTED ANSWER: a save naming a region this build no longer carries must not take
## the load down. See ShopRegistry.by_id().
func by_id(id: StringName) -> RegionData:
	return _by_id.get(id, null)


## The region whose disc contains `point`, or null if the point is open ranch (the
## homestead, or anywhere outside every region).
func region_at(point: Vector2) -> RegionData:
	for region in _ordered:
		if region.contains(point):
			return region
	return null
