class_name PonyGenParams
extends Resource
## The generator's palette and word lists (game/data/pony_gen.tres). Colors are curated
## swatches in the show's range: coats are mostly light pastels with a few darker naturals,
## manes are saturated and a step darker, eyes are vivid. The harmony rules that pair them
## live in game/systems/pony_generator.gd.

@export var coats: Array[Color] = []
@export var manes: Array[Color] = []
@export var eyes: Array[Color] = []
## Two-word names: one from each list ("Peach" + "Sunrise").
@export var name_first: PackedStringArray = []
@export var name_second: PackedStringArray = []
## Race weights for wild Drifters: earth, pegasus, unicorn.
@export var race_weights: PackedFloat32Array = PackedFloat32Array([0.5, 0.25, 0.25])
