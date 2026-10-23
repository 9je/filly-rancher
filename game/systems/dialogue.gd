class_name Dialogue
extends Resource
## ONE CONVERSATION a character can have with the player (game/data/dialogue/*.tres).
##
## `nodes` is the script: an Array of Dictionaries, each
##   {"id": "start", "who": "fennel", "text": "...", "mood": "happy", "anim": "nod",
##    "next": "two", "choices": [{"text": "...", "next": "x", "flag": "f"}],
##    "flag": "on_reach", "event": "on_reach_event"}
## The first node is where it starts; a node with neither `next` nor `choices` ends it.
## `who` defaults to `speaker`. Text may use {name} (the player's) and {tumble}.
##
## `when` gates whether this conversation is offered (see DialogueRunner.matches):
##   {"chapters": [0, 1], "flags_all": [...], "flags_none": [...], "path": "factory",
##    "min": {"deliveries": 1, "blooms": 1}, "max": {...}}
## Among the matching ones a character offers the highest `priority`; `once` ones are
## offered until finished, then never again. Barks (`bark` true) are one-liners said when
## nothing else matches, picked at random.

@export var id: StringName = &""
@export var speaker: StringName = &""
@export var priority: int = 0
@export var once: bool = true
@export var bark: bool = false
@export var when: Dictionary = {}
@export var nodes: Array[Dictionary] = []


func start_node() -> Dictionary:
	return nodes[0] if not nodes.is_empty() else {}


func node(node_id: String) -> Dictionary:
	for n: Dictionary in nodes:
		if str(n.get("id", "")) == node_id:
			return n
	return {}
