class_name TalkLibrary
extends RefCounted
## EVERY CONVERSATION IN THE GAME, and the rule for which one a character offers next.
## Loads game/data/dialogue/*.tres (export-safe: .remap names are resolved, as the other
## registries do). `seen` is the set of finished `once` conversations, saved with the story.

const DIR := "res://data/dialogue"

var all: Array[Dialogue] = []
var seen: Dictionary = {}


func load_all(dir: String = DIR) -> int:
	all.clear()
	var d := DirAccess.open(dir)
	if d == null:
		return 0
	for f in d.get_files():
		var name := f.trim_suffix(".remap")
		if not name.ends_with(".tres"):
			continue
		var res: Resource = load(dir.path_join(name))
		if res is Dialogue:
			all.append(res)
	all.sort_custom(func(a: Dialogue, b: Dialogue) -> bool: return String(a.id) < String(b.id))
	return all.size()


func by_id(id: StringName) -> Dialogue:
	for d in all:
		if d.id == id:
			return d
	return null


## What `speaker` says now: the highest-priority matching unseen conversation, else a
## matching bark (picked with `rng`), else null.
func pick(speaker: StringName, ctx: Dictionary, rng: RandomNumberGenerator = null) -> Dialogue:
	var best: Dialogue = null
	var barks: Array[Dialogue] = []
	for d in all:
		if d.speaker != speaker or not DialogueRunner.matches(d, ctx):
			continue
		if d.bark:
			barks.append(d)
			continue
		if d.once and seen.has(String(d.id)):
			continue
		if best == null or d.priority > best.priority:
			best = d
	if best != null:
		return best
	if barks.is_empty():
		return null
	var i := rng.randi_range(0, barks.size() - 1) if rng != null else 0
	return barks[i]


## True when `speaker` has something new (not a bark) to say: the "!" over her head.
func has_news(speaker: StringName, ctx: Dictionary) -> bool:
	var d := pick(speaker, ctx)
	return d != null and not d.bark


func mark_seen(id: StringName) -> void:
	seen[String(id)] = true


func to_dict() -> Dictionary:
	return {"seen": seen.keys()}


func from_dict(d: Dictionary) -> void:
	seen.clear()
	for k in d.get("seen", []):
		seen[str(k)] = true
