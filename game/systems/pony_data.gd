class_name PonyData
extends Resource
## Static description of one collectible pony: identity, stats, and where her
## assets live. One .tres per pony under game/data/ponies/ -- adding a pony is
## authoring a new data file, never writing new code. Loaded and indexed by
## PonyRegistry (game/systems/pony_registry.gd).

enum Rarity { COMMON, UNCOMMON, RARE, LEGENDARY }
enum Personality { SHY, BOLD, CURIOUS }

## Unique lookup key, e.g. &"twilight". Matches the PonyRegistry dictionary key.
@export var id: StringName = &""
@export var display_name: String = ""
## res:// path to the pony's converted .glb, e.g.
## "res://assets/converted/ponies/twilight.glb". Not loaded by this resource --
## PonyRegistry only validates it resolves; the actual load happens in the
## visuals layer (a later task).
@export var model_path: String = ""
@export var rarity: Rarity = Rarity.COMMON
@export var spawn_zones: Array[StringName] = []
@export var favorite_foods: Array[StringName] = []
@export var personality: Personality = Personality.SHY
## res:// directory of this pony's voice lines, e.g.
## "res://assets/audio/voice/twilight/". Not every pony has one yet -- a
## missing voice bank is expected and must not be treated as an error
## anywhere in the loading path.
@export var voice_bank: String = ""
@export var base_speed: float = 0.0
@export var base_stamina: float = 0.0
@export var base_spirit: float = 0.0

## WHEN she appears, as the companion of `spawn_zones`, which says where.
##
## Both are WorldState enum ints (game/systems/world_state.gd): `phases` holds
## Phase values (DAWN 0, DAY 1, DUSK 2, NIGHT 3) and `weathers` holds Weather
## values (CLEAR 0, RAIN 1, FOG 2, STORM 3). AN EMPTY ARRAY MEANS ANY, which is
## what every unconditional character carries and what an older .tres that
## predates these fields loads as, so adding them broke no roster file.
##
## Typed Array[int] rather than the enums themselves because Godot exports an
## enum-typed array as a plain int array anyway; the enum lives in WorldState and
## PonyData deliberately does not import it, so a data record stays readable
## without dragging the world clock in behind it. available() below is the only
## place the two arrays are ever interpreted.
@export var phases: Array[int] = []
@export var weathers: Array[int] = []

## WHAT THE RANCH MUST HAVE BUILT before she comes by: a decoration id (systems/decor.gd),
## or &"" for nothing. Read by RareGate (game/systems/rare_gate.gd), idea C1.
@export var needs_decor: StringName = &""

## WHICH WORD THE GAME USES FOR THEM: &"she" (the default, and every Drifter) or &"he"
## (playtest 2026-11-08 item 70: the Depot called Braeburn and Doctor Whooves "she").
@export var pronoun: StringName = &"she"

## The word forms, by pronoun: subject, object, possessive, reflexive.
const PRONOUNS := {
	&"she": {"she": "she", "her": "her", "hers": "her", "herself": "herself"},
	&"he": {"she": "he", "her": "him", "hers": "his", "herself": "himself"},
}


## "she" or "he" for `data` (null, a Drifter's hidden record, is "she").
static func pronoun_of(data: PonyData) -> StringName:
	return data.pronoun if data != null and PRONOUNS.has(data.pronoun) else &"she"


## The `form` of `data`'s pronoun: form is one of "she", "her" (object), "hers"
## (possessive), "herself".
static func word(data: PonyData, form: String) -> String:
	return str((PRONOUNS[pronoun_of(data)] as Dictionary).get(form, form))


## Whether this character can be drawn right now. Empty means any, in each list
## independently, so "[NIGHT], []" is a pony who keeps night hours in any weather
## and "[], [FOG]" is a pony who wants fog at any hour. Both non empty is an AND:
## a listed phase with an unlisted weather is false.
func available(phase: int, weather: int) -> bool:
	if not phases.is_empty() and not phase in phases:
		return false
	if not weathers.is_empty() and not weather in weathers:
		return false
	return true
