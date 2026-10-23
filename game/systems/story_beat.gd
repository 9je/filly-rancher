class_name StoryBeat
extends Resource
## ONE LETTER, AS DATA. Everything the player reads from the Company is one of these: an id,
## the chapter it belongs to, the trigger that brings it, who signed it, a title, a body, an
## optional list of Compendium ids it relabels, whether it is evidence, and whether it
## carries a reply control. One .tres per letter under game/data/story/, so writing more
## story is adding files (the spec's approach: spine first, content as data).
##
## THE CHAPTER, THE TRIGGER AND THE REPLY ARE NAMES, NOT NUMBERS. A .tres carrying
## `chapter = 1` is unreadable and unreviewable, and a typo in it is a silent zero. A .tres
## carrying `chapter = &"WEATHER"` says what it means, and a chapter this build does not
## have resolves to -1, which game/scenes/test/story_test.gd fails the gate on. The spec
## asks for exactly that check: "every StoryBeat has a chapter that exists, a trigger the
## game can emit".
##
## RENDERING ANSWERS THE SHAPE game/ui/letter_panel.gd ALREADY TAKES: {"sender", "title",
## "body": Array[String]}, identical to game/systems/letters.gd's render(). One reader, two
## senders; the stub sender keeps the six letters slice 1 needs and this is the data driven
## one beside it.
##
## PLACEHOLDERS ARE {name} STYLE and filled by String.format, because "%s" positional
## formatting in authored data is how a letter comes to say the wrong number when somebody
## reorders a line. A parameter the caller did not supply falls back to DEFAULTS rather than
## rendering a brace, for game/systems/letters.gd's reason: a letter that fails to render is
## a letter the player never sees and never knows she missed.

const StoryScript := preload("res://systems/story.gd")

## The reply control a letter may carry. PICK_PONY is the Survey's picker over the ponies
## she owns; YES_NO is the two row question a later slice's letters use.
enum Reply { NONE, PICK_PONY, YES_NO }

const REPLY_NAMES: Array[String] = ["NONE", "PICK_PONY", "YES_NO"]

## What every placeholder renders as when the caller supplied nothing. Never a brace, never
## an empty string: a letter reads as a letter even in a test that handed it no world.
const DEFAULTS := {
	"name": "Valued Partner",
	"pony": "your pony",
	# THE SURVEY'S PONY, KEPT SEPARATE FROM THE DELIVERED ONE. {pony} always names whoever
	# a receipt is actually about (Story.last_named); {chosen} names whoever she named on
	# the Survey (Story.survey_choice). The two can diverge the moment she answers the
	# Survey and then delivers somebody else, and a Requisition letter that used {pony} for
	# this would silently start naming the wrong pony the instant they did.
	"chosen": "your pony",
	"colour": "a colour",
	"count": 1,
	"quota": 2,
	"balance": 0,
}

@export var id: StringName = &""

## A name from Story.CHAPTER_NAMES.
@export var chapter: StringName = &"SUNNY"

## A name from Story.TRIGGER_NAMES, and the value that counter must reach.
@export var trigger: StringName = &"CHAPTER"
@export var threshold: int = 0

@export var sender: String = "Cloudsdale Weather Corporation"
@export var title: String = ""
@export var body: PackedStringArray = PackedStringArray()

## Compendium ids this letter relabels when it lands. Empty for every letter in this slice;
## the field exists because the spec's data model names it and because story_test checks
## that every id in it is a character this build actually carries.
@export var reveals: PackedStringArray = PackedStringArray()

## Whether this is one of the letters the Resistance route can carry to a town NPC. Authored
## now, read in slice 5.
@export var evidence: bool = false

## A name from REPLY_NAMES.
@export var reply: StringName = &"NONE"
## A template is never posted by the ladder; it is posted by the game under ids of the form
## "<template id>#<n>" (the postcards: one beat, many cards).
@export var template: bool = false


func chapter_index() -> int:
	return StoryScript.chapter_index(chapter)


func trigger_index() -> int:
	return StoryScript.trigger_index(trigger)


func reply_index() -> int:
	return REPLY_NAMES.find(String(reply))


func body_lines() -> Array[String]:
	var out: Array[String] = []
	for line in body:
		out.append(String(line))
	return out


## The letter, in game/ui/letter_panel.gd's shape. `params` may carry any of DEFAULTS' keys;
## anything missing falls back to its default.
func render(params: Dictionary) -> Dictionary:
	var filled: Dictionary = DEFAULTS.duplicate()
	for key in params:
		filled[String(key)] = params[key]
	var lines: Array[String] = []
	for line: String in body_lines():
		lines.append(line.format(filled))
	return {"sender": sender, "title": title.format(filled), "body": lines}
