class_name ShopRegistry
extends RefCounted
## Loads ShopItem resources (game/systems/shop_item.gd) out of a directory of .tres files
## and indexes them by id, mirroring PlotRegistry (game/systems/plot_registry.gd) exactly:
## same reasons apply: instance based, so load_all() populates this registry's own index
## rather than a shared global one; constructible and testable headlessly with a plain
## `.new()`; and the `.tres`/`.tres.remap` resolution in _resource_path() is copied
## verbatim from PlotRegistry because it is the same export-time fact. Godot's exporter
## converts text resources to binary by default, so an exported .pck carries
## `foo.tres.remap` stubs instead of bare `.tres` files, and the path to actually load is
## the original name with the `.remap` suffix stripped. See PonyRegistry's much longer
## comment on this exact bug, which shipped once already and emptied the whole pony roster
## in a build that still printed a green marker.
##
## THE ONE THING THIS ADDS OVER FoodRegistry: all() returns a SORTED list, cheapest first,
## and of_kind() filters that list by ShopItem.Kind for the Buy tab's tabs. The build menu
## and the Market both need a stable order for the same reason: a Dictionary's iteration
## order follows insertion, which follows a DirAccess listing, which is the filesystem's
## business and not ours.

const ShopItemScript := preload("res://systems/shop_item.gd")

## The directory the shipped catalogue lives in. Committed, unlike game/assets/converted/,
## so it is present on every machine and in every export (docs/ci.md section 4).
const SHOP_DIR := "res://data/shop"

var _by_id: Dictionary = {}  # StringName -> ShopItem
var _sorted: Array[ShopItem] = []


## Scans `dir` for `.tres`/`.tres.remap` files, loads each as a ShopItem resource, and
## indexes it by `id`. Returns the same {id: ShopItem} dictionary cached internally for
## by_id() to read.
##
## A resource that fails to load as ShopItem is REPORTED via push_error() rather than
## silently dropped, and a directory that cannot be opened at all is also reported and
## returns an empty dictionary rather than crashing: same contract as the other
## registries.
func load_all(dir: String = SHOP_DIR) -> Dictionary:
	_by_id.clear()
	_sorted.clear()
	var da := DirAccess.open(dir)
	if da == null:
		push_error("ShopRegistry.load_all: cannot open directory '%s' (%s)" % [
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
	if res == null or not (res is ShopItemScript):
		push_error("ShopRegistry.load_all: '%s' did not load as a ShopItem resource" % path)
		return

	var item: ShopItem = res
	if String(item.id).is_empty():
		push_error("ShopRegistry.load_all: '%s' has an empty id" % path)
		return
	if item.cost < 0:
		push_error("ShopRegistry.load_all: '%s' has a negative cost" % path)
		return
	if _by_id.has(item.id):
		push_error("ShopRegistry.load_all: duplicate id '%s' in '%s'" % [item.id, path])
		return

	_by_id[item.id] = item


## Cheapest first, then by id. The id is the tie-break rather than the display name so the
## order does not move if an item is renamed, and it makes the order total: two items at
## the same price would otherwise still be at the mercy of the directory listing.
func _rebuild_order() -> void:
	var list: Array[ShopItem] = []
	for key in _by_id:
		list.append(_by_id[key])
	list.sort_custom(func(a: ShopItem, b: ShopItem) -> bool:
		if a.cost != b.cost:
			return a.cost < b.cost
		return String(a.id) < String(b.id))
	_sorted = list


## Every loaded item, cheapest first. A COPY: the Market iterates this every time it opens,
## and handing out the live array would let a caller reorder the catalogue.
func all() -> Array[ShopItem]:
	return _sorted.duplicate()


## The ShopItem indexed under `id`, or NULL if this registry has never heard of it. NULL IS
## A SUPPORTED ANSWER: a save naming an item this build no longer carries must not take
## the load down. See PlotRegistry.by_id().
func by_id(id: StringName) -> ShopItem:
	return _by_id.get(id, null)


## Every loaded item of `kind`, cheapest first. Backs the Market's Buy tab, which shows
## CARE and GEAR rows in separate lists rather than one mixed one.
func of_kind(kind: int) -> Array[ShopItem]:
	var out: Array[ShopItem] = []
	for item in _sorted:
		if item.kind == kind:
			out.append(item)
	return out
