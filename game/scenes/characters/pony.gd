extends Node3D
## A spawnable pony: pick a character, get the model with working hair.
##
## The editor-friendly wrapper around `scripts/pony_rig.gd`. Instance
## `scenes/characters/pony.tscn`, set `character`, and this loads the matching
## converted .glb and attaches the mane/tail SpringBoneSimulator3D. Use this rather than
## `load("res://assets/converted/ponies/<name>.glb").instantiate()` directly: a bare
## .glb instance has no hair simulation, because the .glb is regenerated per machine and
## gitignored and so cannot carry one (see pony_rig.gd's header).
##
## From code, `PonyRig.spawn("twilight")` does the same thing without a scene file.

const PonyRigScript := preload("res://scripts/pony_rig.gd")

## Base name of a file in game/assets/converted/ponies/, e.g. "twilight".
@export var character: String = "twilight"
## Clip to start on spawn; "" leaves the AnimationPlayer stopped.
@export var autoplay: String = "idle"

var model: Node3D
var animation: AnimationPlayer
var hair: SpringBoneSimulator3D


func _ready() -> void:
	model = PonyRigScript.spawn(character)
	if model == null:
		return
	add_child(model)
	var skeleton: Skeleton3D = model.find_child("Skeleton3D", true, false)
	if skeleton != null:
		hair = skeleton.get_node_or_null(NodePath(PonyRigScript.SIMULATOR_NAME))
	animation = model.find_child("AnimationPlayer", true, false)
	if animation != null and autoplay != "" and animation.has_animation(autoplay):
		animation.play(autoplay)


## Play a clip by name, if the model has it. Returns false if it does not.
func play(clip: String) -> bool:
	if animation == null or not animation.has_animation(clip):
		return false
	animation.play(clip)
	return true
