class_name PonyRegistry
extends RefCounted
## Loads PonyData resources (game/systems/pony_data.gd) out of a directory of
## .tres files and indexes them for lookup by zone or rarity. No scene-tree
## dependency -- constructible and testable headlessly with plain `.new()`
## (see game/test/test_pony_registry.gd).
##
## Instance-based rather than static: load_all() populates the registry's own
## index, and by_zone()/by_rarity() read that cached index, so callers do a
## single load_all() and then query freely without re-scanning disk.

const PonyDataScript := preload("res://systems/pony_data.gd")

var _by_id: Dictionary = {}  # StringName -> PonyData


## Scans `dir` for `.tres` files, loads each as a PonyData resource, and
## indexes it by `id`. Returns the same {id: PonyData} dictionary cached
## internally for by_zone()/by_rarity() to read.
##
## A resource that fails to load as PonyData, or whose model_path is empty
## or does not resolve to an existing resource, is REPORTED via push_error()
## (visible to any caller through Godot's error output, and assertable in
## GUT tests via assert_push_error) rather than silently dropped. A bad
## model_path does not remove the entry from the result -- the pony's other
## data (stats, zones, etc.) is still usable; only the model reference is
## broken, so failing the whole load would throw away good data over one
## bad field. A directory that can't be opened at all is also reported via
## push_error, and load_all returns an empty dictionary rather than crashing.
func load_all(dir: String) -> Dictionary:
	_by_id.clear()
	var da := DirAccess.open(dir)
	if da == null:
		push_error("PonyRegistry.load_all: cannot open directory '%s' (%s)" % [
			dir, error_string(DirAccess.get_open_error())
		])
		return _by_id

	da.list_dir_begin()
	var file_name := da.get_next()
	while file_name != "":
		if not da.current_is_dir() and file_name.get_extension() == "tres":
			_load_one(dir.path_join(file_name))
		file_name = da.get_next()
	da.list_dir_end()

	return _by_id


func _load_one(path: String) -> void:
	var res: Resource = load(path)
	if res == null or not (res is PonyDataScript):
		push_error("PonyRegistry.load_all: '%s' did not load as a PonyData resource" % path)
		return

	var data: PonyData = res
	if String(data.id).is_empty():
		push_error("PonyRegistry.load_all: '%s' has an empty id" % path)

	if data.model_path.is_empty() or not ResourceLoader.exists(data.model_path):
		push_error("PonyRegistry.load_all: pony '%s' (%s) has a missing or malformed model_path '%s'" % [
			data.id, path, data.model_path
		])

	_by_id[data.id] = data


## Ponies whose spawn_zones includes `zone`. Empty array if none match --
## never null, so callers can iterate the result unconditionally.
func by_zone(zone: StringName) -> Array[PonyData]:
	var result: Array[PonyData] = []
	for data: PonyData in _by_id.values():
		if zone in data.spawn_zones:
			result.append(data)
	return result


## Ponies whose rarity equals `r` (compare against PonyData.Rarity constants).
func by_rarity(r: int) -> Array[PonyData]:
	var result: Array[PonyData] = []
	for data: PonyData in _by_id.values():
		if data.rarity == r:
			result.append(data)
	return result
