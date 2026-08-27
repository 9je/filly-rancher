class_name PlotRegistry
extends RefCounted
## Loads PlotData resources (game/systems/plot_data.gd) out of a directory of .tres files
## and indexes them by id, mirroring FoodRegistry (game/systems/food_registry.gd) and
## PonyRegistry (game/systems/pony_registry.gd) exactly -- same reasons apply: instance
## based, so load_all() populates this registry's own index rather than a shared global
## one; constructible and testable headlessly with a plain `.new()`; and the
## `.tres`/`.tres.remap` resolution in _resource_path() is copied verbatim from
## PonyRegistry because it is the same export-time fact. Godot's exporter converts text
## resources to binary by default, so an exported .pck carries `foo.tres.remap` stubs
## instead of bare `.tres` files, and the path to actually load is the original name with
## the `.remap` suffix stripped. See pony_registry.gd's much longer comment on this bug --
## it shipped once already and emptied the whole pony roster in a build that still printed
## a green marker.
##
## THE ONE THING THIS ADDS OVER FoodRegistry: all() returns a SORTED list. The build menu
## (game/ui/build_menu.gd) draws it in that order, and a Dictionary's iteration order
## follows insertion, which follows a DirAccess listing, which is the filesystem's business
## and not ours. Without the sort the menu would silently come out in a different order on
## a different machine and a gamepad player's muscle memory ("down, down, accept") would
## break between the two.

const PlotDataScript := preload("res://systems/plot_data.gd")

## The directory the shipped catalogue lives in. Committed, unlike game/assets/converted/,
## so it is present on every machine and in every export (docs/ci.md section 4).
const PLOT_DIR := "res://data/plots"

var _by_id: Dictionary = {}  # StringName -> PlotData
var _sorted: Array[PlotData] = []


## Scans `dir` for `.tres`/`.tres.remap` files, loads each as a PlotData resource, and
## indexes it by `id`. Returns the same {id: PlotData} dictionary cached internally for
## by_id() to read.
##
## A resource that fails to load as PlotData is REPORTED via push_error() rather than
## silently dropped, and a directory that cannot be opened at all is also reported and
## returns an empty dictionary rather than crashing -- same contract as the other two
## registries.
func load_all(dir: String = PLOT_DIR) -> Dictionary:
	_by_id.clear()
	_sorted.clear()
	var da := DirAccess.open(dir)
	if da == null:
		push_error("PlotRegistry.load_all: cannot open directory '%s' (%s)" % [
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
## registry should read. See the class comment.
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
	if res == null or not (res is PlotDataScript):
		push_error("PlotRegistry.load_all: '%s' did not load as a PlotData resource" % path)
		return

	var data: PlotData = res
	if String(data.id).is_empty():
		push_error("PlotRegistry.load_all: '%s' has an empty id" % path)

	_by_id[data.id] = data


## Cheapest first, then by id. The id is the tie-break rather than the display name so the
## order does not move if a plot is renamed, and it makes the order total -- two plots at
## the same price would otherwise still be at the mercy of the directory listing.
func _rebuild_order() -> void:
	var list: Array[PlotData] = []
	for key in _by_id:
		list.append(_by_id[key])
	list.sort_custom(func(a: PlotData, b: PlotData) -> bool:
		if a.cost != b.cost:
			return a.cost < b.cost
		return String(a.id) < String(b.id))
	_sorted = list


## Every loaded plot, cheapest first. A COPY: the build menu iterates this every time it
## opens, and handing out the live array would let a caller reorder the catalogue.
func all() -> Array[PlotData]:
	return _sorted.duplicate()


## The PlotData indexed under `id`, or NULL if this registry has never heard of it. NULL IS
## A SUPPORTED ANSWER -- a save naming a plot type this build no longer carries must leave
## the slot empty and buildable rather than take the load down. See PonyRegistry.by_id().
func by_id(id: StringName) -> PlotData:
	return _by_id.get(id, null)
