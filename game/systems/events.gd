extends Node
## THE STORY AND TONE BUS. The systems built for v1 (story beats, the dread dial, NPC talk,
## the two paths, endings) talk to each other through these signals instead of through
## game/world/ranch.gd, which already glues everything older together and should not grow.
##
## Emitters call the signal directly (`Events.delivered.emit(...)`); listeners connect in
## their own _ready. Nothing here holds state: the state lives in GameState and the Story
## system, and this node only says that something happened.
##
## No class_name, matching the other autoloads (Godot refuses a class_name that hides an
## autoload singleton of the same name).

## A pony left the ranch through the Depot crate. `look` is her PonyLook dictionary, so a
## listener can name a dye shade or tint a sparkle without looking her up.
signal delivered(pony_uid: String, look: Dictionary)
## A pony earned her mark.
signal bloomed(pony_uid: String, look: Dictionary)
## A pony was freed: sent down the Lantern Line, or Bloomed while the Collectors wanted her.
signal rescued(pony_uid: String)
## The world clock rolled over into a new day.
signal day_passed(day: int)
## A story flag changed. `value` is the new value, usually true.
signal flag_set(flag: StringName, value: Variant)
## The dread dial moved. 0 is the cozy valley, 1 is the Works at its worst.
signal dread_changed(dread: float)
## The player chose a path at the reveal.
signal path_chosen(path: StringName)
## A conversation opened or closed. `speaker` is the character id.
signal talk_started(speaker: StringName)
signal talk_ended(speaker: StringName)
## The player walked into a named area (a region, a building, a Works room).
signal area_entered(area: StringName)
## Something the player did deserves a feedback burst (sound, particles, shake) at a place
## in the world. `kind` is a key in game/systems/feel.gd's table.
signal feel(kind: StringName, at: Vector3)
## Heat moved (Rescue path).
signal heat_changed(heat: int)
## An ending was reached.
signal ending_reached(ending: StringName)
