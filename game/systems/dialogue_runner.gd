class_name DialogueRunner
extends RefCounted
## STEPS THROUGH A Dialogue. Pure logic, no nodes: the talk box (game/ui/talk_box.gd)
## shows `current()` and calls `advance()` / `choose()`; everything a conversation does to
## the world (flags, events) comes back as `effects` for the caller to apply, so a test can
## run any conversation end to end with a plain Dictionary as the world.
##
## The context a conversation reads is a Dictionary:
##   {"chapter": int, "path": String, "flags": Dictionary, "counts": Dictionary,
##    "name": String, "tumble": String}

signal finished(dialogue_id: StringName)

var dialogue: Dialogue
var context: Dictionary = {}
var effects: Array[Dictionary] = []
var _node: Dictionary = {}


static func matches(d: Dialogue, ctx: Dictionary) -> bool:
	var w: Dictionary = d.when
	if w.has("chapters") and not (int(ctx.get("chapter", 0)) in (w["chapters"] as Array)):
		return false
	if w.has("path") and str(w["path"]) != str(ctx.get("path", "")):
		return false
	var flags: Dictionary = ctx.get("flags", {})
	for f in w.get("flags_all", []):
		if not bool(flags.get(str(f), false)):
			return false
	for f in w.get("flags_none", []):
		if bool(flags.get(str(f), false)):
			return false
	var counts: Dictionary = ctx.get("counts", {})
	var lo: Dictionary = w.get("min", {})
	for k in lo:
		if int(counts.get(k, 0)) < int(lo[k]):
			return false
	var hi: Dictionary = w.get("max", {})
	for k in hi:
		if int(counts.get(k, 0)) > int(hi[k]):
			return false
	return true


func start(d: Dialogue, ctx: Dictionary) -> Dictionary:
	dialogue = d
	context = ctx
	effects.clear()
	_enter(d.start_node())
	return current()


## The line on screen: {who, text, mood, anim, choices: [String]} or {} once finished.
func current() -> Dictionary:
	if _node.is_empty():
		return {}
	var choices: Array[String] = []
	for c: Dictionary in _node.get("choices", []):
		choices.append(fill(str(c.get("text", ""))))
	return {
		"who": StringName(str(_node.get("who", dialogue.speaker))),
		"text": fill(str(_node.get("text", ""))),
		"mood": StringName(str(_node.get("mood", "neutral"))),
		"anim": StringName(str(_node.get("anim", ""))),
		"choices": choices,
	}


func is_running() -> bool:
	return not _node.is_empty()


func has_choices() -> bool:
	return not (_node.get("choices", []) as Array).is_empty()


## Move past a line with no choices.
func advance() -> Dictionary:
	if _node.is_empty() or has_choices():
		return current()
	_goto(str(_node.get("next", "")))
	return current()


func choose(index: int) -> Dictionary:
	var choices: Array = _node.get("choices", [])
	if index < 0 or index >= choices.size():
		return current()
	var c: Dictionary = choices[index]
	if c.has("flag"):
		effects.append({"flag": str(c["flag"])})
	if c.has("event"):
		effects.append({"event": str(c["event"])})
	_goto(str(c.get("next", "")))
	return current()


func fill(text: String) -> String:
	return text.replace("{name}", str(context.get("name", "friend"))) \
		.replace("{tumble}", str(context.get("tumble", "Tumble")))


func _goto(next_id: String) -> void:
	if next_id.is_empty():
		_node = {}
		finished.emit(dialogue.id)
		return
	_enter(dialogue.node(next_id))
	if _node.is_empty():
		finished.emit(dialogue.id)


func _enter(n: Dictionary) -> void:
	_node = n
	if n.is_empty():
		return
	if n.has("flag"):
		effects.append({"flag": str(n["flag"])})
	if n.has("event"):
		effects.append({"event": str(n["event"])})
