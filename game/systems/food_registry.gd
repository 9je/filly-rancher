class_name FoodRegistry
extends RefCounted
## Loads FoodData resources (game/systems/food_data.gd) out of a directory of .tres files
## and indexes them by id, mirroring PonyRegistry (game/systems/pony_registry.gd) exactly --
## same reasons apply here: instance-based so load_all() populates this registry's own
## index rather than a shared global one, constructible and testable headlessly with a
## plain `.new()` (see game/test/test_food_registry.gd), and the `.tres`/`.tres.remap`
## resolution below is copied verbatim from PonyRegistry._resource_path() because it is the
## same export-time fact: Godot's exporter converts text resources to binary by default, so
## an exported .pck has `foo.tres.remap` stubs instead of bare `.tres` files, and the path
## to actually load is the original name with the `.remap` suffix stripped, which the
## engine's remap machinery then follows itself. See pony_registry.gd's much longer comment
## on this exact bug (it shipped once already and emptied the whole pony roster).

const FoodDataScript := preload("res://systems/food_data.gd")

var _by_id: Dictionary = {}  # StringName -> FoodData


## Scans `dir` for `.tres`/`.tres.remap` files, loads each as a FoodData resource, and
## indexes it by `id`. Returns the same {id: FoodData} dictionary cached internally for
## by_id() to read.
##
## A resource that fails to load as FoodData is REPORTED via push_error() rather than
## silently dropped, and a directory that cannot be opened at all is also reported via
## push_error and returns an empty dictionary rather than crashing -- same contract as
## PonyRegistry.load_all().
func load_all(dir: String) -> Dictionary:
	_by_id.clear()
	var da := DirAccess.open(dir)
	if da == null:
		push_error("FoodRegistry.load_all: cannot open directory '%s' (%s)" % [
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

	return _by_id


## The res:// path to load for a directory entry, or "" if it is not a resource this
## registry should read. See the class comment -- copied from PonyRegistry._resource_path().
func _resource_path(dir: String, file_name: String) -> String:
	var name := file_name
	if name.get_extension() == "remap":
		name = name.get_basename()
	var ext := name.get_extension()
	if ext == "tres" or ext == "res":
		return dir.path_join(name)
	return ""


func _load_one(path: String) -> void:
	var res: Resource = load(path)
	if res == null or not (res is FoodDataScript):
		push_error("FoodRegistry.load_all: '%s' did not load as a FoodData resource" % path)
		return

	var data: FoodData = res
	if String(data.id).is_empty():
		push_error("FoodRegistry.load_all: '%s' has an empty id" % path)

	_by_id[data.id] = data


## The FoodData indexed under `id`, or NULL if this registry has never heard of her. NULL
## IS A SUPPORTED ANSWER -- see PonyRegistry.by_id()'s comment; the same reasoning applies
## to a food_id that does not resolve, and Needs.feed() (game/systems/needs.gd) relies on
## this null to refuse feeding an unknown food rather than crash.
func by_id(id: StringName) -> FoodData:
	return _by_id.get(id, null)
