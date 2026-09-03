class_name StoryLibrary
extends RefCounted
## EVERY AUTHORED LETTER, LOADED OFF DISK AND INDEXED BY ID. Mirrors
## game/systems/region_registry.gd exactly, including the .tres/.tres.remap resolution in
## _resource_path(): Godot's exporter converts text resources to binary by default, so an
## exported .pck carries `foo.tres.remap` stubs rather than bare `.tres` files, and the path
## to actually load is the original name with the `.remap` suffix stripped. PonyRegistry's
## much longer comment on that bug is worth reading; it shipped once and emptied the whole
## roster in a build that still printed a green marker.
##
## WHAT IS OWED, AND NOTHING ELSE. due() is the whole of "which letters should be in her
## mailbox now": a beat whose chapter the story has reached, whose counter has met its
## threshold, and which has not already been posted. Ordering is the ladder's, so a session
## that crosses two thresholds at once posts them in the order they were written rather than
## in whatever order the directory listing produced.
##
## Instance based and constructible with a plain .new(), so a test and a gate each get their
## own; nothing here is a singleton and nothing here caches across processes.

const StoryBeatScript := preload("res://systems/story_beat.gd")
const StoryScript := preload("res://systems/story.gd")

## The directory the shipped letters live in. Committed, unlike game/assets/converted/, so
## it is present on every machine and in every export (docs/ci.md section 4).
const STORY_DIR := "res://data/story"

var _by_id: Dictionary = {}
var _ordered: Array[StoryBeat] = []


func load_all(dir: String = STORY_DIR) -> Dictionary:
	_by_id.clear()
	_ordered.clear()
	var da := DirAccess.open(dir)
	if da == null:
		push_error("StoryLibrary.load_all: cannot open directory '%s' (%s)" % [
			dir, error_string(DirAccess.get_open_error())])
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
	if res == null or not (res is StoryBeatScript):
		push_error("StoryLibrary.load_all: '%s' did not load as a StoryBeat resource" % path)
		return
	var beat: StoryBeat = res
	if String(beat.id).is_empty():
		push_error("StoryLibrary.load_all: '%s' has an empty id" % path)
		return
	if _by_id.has(beat.id):
		push_error("StoryLibrary.load_all: duplicate id '%s' in '%s'" % [beat.id, path])
		return
	_by_id[beat.id] = beat


## Chapter first, then threshold, then id. The id is the tie break so the order is TOTAL:
## two letters at the same threshold would otherwise be at the mercy of the directory
## listing, and "which arrived first" is a thing the player reads.
func _rebuild_order() -> void:
	var list: Array[StoryBeat] = []
	for key in _by_id:
		list.append(_by_id[key])
	list.sort_custom(func(a: StoryBeat, b: StoryBeat) -> bool:
		if a.chapter_index() != b.chapter_index():
			return a.chapter_index() < b.chapter_index()
		if a.threshold != b.threshold:
			return a.threshold < b.threshold
		return String(a.id) < String(b.id))
	_ordered = list


func all() -> Array[StoryBeat]:
	return _ordered.duplicate()


## The beat under `id`, or NULL. Null is a supported answer: a save naming a letter this
## build no longer carries must not take the load down. See ShopRegistry.by_id().
func by_id(id: StringName) -> StoryBeat:
	return _by_id.get(id, null)


## Every letter `story` is owed right now, in ladder order. A beat whose chapter or trigger
## this build does not have is skipped here and failed loudly by the story gate, rather than
## being posted as a letter nobody can read.
func due(story: Story) -> Array[StoryBeat]:
	var out: Array[StoryBeat] = []
	if story == null:
		return out
	for beat: StoryBeat in _ordered:
		var chapter: int = beat.chapter_index()
		var kind: int = beat.trigger_index()
		if chapter < 0 or kind < 0:
			continue
		if chapter > story.chapter:
			continue
		if story.has_mail(beat.id):
			continue
		if story.counter(kind) < beat.threshold:
			continue
		out.append(beat)
	return out
