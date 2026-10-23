class_name BootIntent
extends RefCounted
## WHAT THE TITLE SCREEN TOLD THE RANCH, AND NOTHING ELSE. A change_scene_to_file() hands the
## next scene nothing, and the obvious place for "she picked New game" is a field on the
## GameState autoload, which this phase may not touch: game/systems/ is read only for the
## whole presentation redesign except the two exemptions the spec names. A static var on a
## script under game/world/ lives exactly as long as the process, which is exactly as long as
## the handoff needs, and it is not in the save file, which is correct: an intent is about
## this launch, not about this ranch.
##
## FALSE IS THE DEFAULT AND THAT IS THE WHOLE SAFETY PROPERTY. Every gate, every screenshot
## run and every export smoke boots world/ranch.tscn directly and never touches this file, so
## they consume `false` and load the save exactly as they always have.
##
## CONSUMED ONCE. ranch.gd's _bind_game_state() takes it, and a reload_current_scene() (the
## pause menu's Load game row) must not then start a second new game on top of the load.
##
## Static only, no state beyond the latch, no scene. Preload by path.

static var _new_game := false
## A driver owns this process (scenes/test/playthrough.gd): the ranch reports but never
## quits, and still loads the save like a launched game does.
static var driven := false


static func request_new_game() -> void:
	_new_game = true


## Is a new game intended, without taking the intent? For the boot veil, which has to know
## before _bind_game_state() has run.
static func peek_new_game() -> bool:
	return _new_game


static func consume_new_game() -> bool:
	var was: bool = _new_game
	_new_game = false
	return was


static func clear() -> void:
	_new_game = false
