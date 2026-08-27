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
