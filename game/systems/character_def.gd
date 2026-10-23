class_name CharacterDef
extends Resource
## A STORY CHARACTER (game/data/characters/*.tres): an original pony built by the same
## generator as every Drifter, from a fixed seed, with hand-set overrides where the story
## needs her to look a particular way (STORY.md section 2). Never a canon character.

@export var id: StringName = &""
@export var display_name: String = ""
@export var char_seed: int = 1
## PonyGenerator.generate opts: race, foal, talent, marked.
@export var gen: Dictionary = {}
## PonyLook fields to force after generation: donor, coat, mane, mane2, tail, eyes (Colors
## as HTML strings), foal.
@export var look: Dictionary = {}
## Voice: babble pitch multiplier (1.0 is an adult mare's) and a timbre index.
@export var voice_pitch: float = 1.0
@export var voice_timbre: int = 0
## A face that never blinks while it smiles (Marigold's tell, STORY.md clue 14).
@export var never_blinks: bool = false
## One line describing her, for the Pony Book.
@export var blurb: String = ""


func build_look() -> PonyLook:
	var l := PonyGenerator.generate(char_seed, gen)
	for k: String in look:
		var v: Variant = look[k]
		match k:
			"donor":
				l.donor = StringName(str(v))
			"race":
				l.race = StringName(str(v))
			"foal":
				l.foal = bool(v)
			"coat", "mane", "mane2", "tail", "eyes":
				l.set(k, Color.html(str(v)))
	return l
