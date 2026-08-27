extends Node3D
## Task 3B verification scene: builds all three ponies through the canonical
## PonyRegistry -> PonyVisuals path -- id and model_path both come from the .tres
## data files under game/data/ponies/, never by globbing
## game/assets/converted/ponies/. That globbing pattern is what model_gallery.gd
## uses and is fine for "does every .glb in the directory still load", but it
## supersedes nothing here: this scene proves the actual spawn path any real game
## code will use, and a directory scan can't stand in for going through PonyData.
##
## Per instance this asserts more than "the node loaded": that the AnimationPlayer
## is reachable at PonyVisuals.ANIMATION_PLAYER_PATH and has both 'idle' and
## 'walk', and that a live SpringBoneSimulator3D actually sits under the
## Skeleton3D (not just that attach_hair_simulation() was called).
##
## Prints REGISTRY_OK count=3 and quits 0 under headless iff all three ponies
## built and passed both checks.

const PonyRegistryScript := preload("res://systems/pony_registry.gd")
const PonyVisualsScript := preload("res://actors/pony/pony_visuals.gd")
const PonyRigScript := preload("res://scripts/pony_rig.gd")

const PONY_DIR := "res://data/ponies/"


func _ready() -> void:
	var registry := PonyRegistryScript.new()
	var ponies := registry.load_all(PONY_DIR)

	var built := 0
	var all_ok := true
	var idx := 0
	for id in ponies.keys():
		var data: PonyData = ponies[id]
		var pony := PonyVisualsScript.build(data)
		if pony == null:
			push_error("registry_gallery: PonyVisuals.build failed for '%s'" % id)
			all_ok = false
			idx += 1
			continue

		# Display-only spacing/facing so a windowed run is legible; not part of
		# the verification. Assets face -Z (export_blend.py --rotate-z 180); the
		# camera sits at +Z, matching model_gallery.gd's convention.
		pony.position = Vector3(idx * 3.0, 0, 0)
		pony.rotate_y(PI)
		add_child(pony)

		var anim: AnimationPlayer = pony.get_node_or_null(PonyVisualsScript.ANIMATION_PLAYER_PATH)
		var has_idle_walk := anim != null and anim.has_animation("idle") and anim.has_animation("walk")
		if not has_idle_walk:
			push_error("registry_gallery: '%s' has no AnimationPlayer with idle+walk at %s" % [
				id, PonyVisualsScript.ANIMATION_PLAYER_PATH
			])

		var skeleton: Skeleton3D = pony.find_child("Skeleton3D", true, false)
		var sim: Node = skeleton.get_node_or_null(NodePath(PonyRigScript.SIMULATOR_NAME)) if skeleton else null
		var has_hair := sim is SpringBoneSimulator3D
		if not has_hair:
			push_error("registry_gallery: '%s' has no live SpringBoneSimulator3D under its Skeleton3D" % id)

		print("BUILT ", id, " anim_ok=", has_idle_walk, " hair_ok=", has_hair)

		if not (has_idle_walk and has_hair):
			all_ok = false
		else:
			built += 1
		idx += 1

	print("REGISTRY_OK count=", built)
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if (built == 3 and all_ok) else 1)
