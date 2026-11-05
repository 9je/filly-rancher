class_name PonyVisuals
extends RefCounted
## The ONE canonical way any game code turns a PonyData record
## (game/systems/pony_data.gd) into a live, ready-to-use pony instance. A thin
## adapter over PonyRig (game/scripts/pony_rig.gd) -- it resolves `data.model_path`
## to a filename PonyRig can load, and delegates the actual instantiate-and-attach-
## hair work to PonyRig.spawn()/attach_hair_simulation() rather than reimplementing
## any part of it. See docs/notes-hair-sim.md for why the mane/tail spring
## simulation has to be built in code at spawn time (the .glb it would otherwise
## live inside is gitignored and regenerated per machine).
##
## Static-only helper, like PonyRig -- never instantiated. Preload by path, not by
## the global `class_name`: the global class cache lives in the gitignored
## game/.godot/ and a fresh clone hasn't built it yet (same convention documented
## at the top of pony_rig.gd and followed by test_pony_registry.gd).
##
## WHERE THIS SITS IN THE PIPELINE. PonyRegistry.load_all() deliberately keeps a
## malformed entry (bad/missing model_path) in its returned dictionary and only
## push_errors -- reviewed and endorsed in Task 3A so that one broken model_path
## can't take a pony's otherwise-good stats/zones/foods data down with it. That
## means the dictionary PonyRegistry hands back is NOT guaranteed spawnable.
## build() is the agreed choke point that actually enforces spawnability: it is the
## last place in the pipeline that still has both the PonyData and the freedom to
## refuse, so a bad model_path is caught here, loudly, before a half-built node
## could ever reach the scene tree.
##
## ANIMATIONPLAYER NODE PATH. build() returns the same root PonyRig.spawn() would
## return for that model, and on all three shipped characters the imported .glb's
## AnimationPlayer sits one level down as a DIRECT CHILD OF THE RETURNED ROOT,
## named exactly "AnimationPlayer":
##
##   twilight.glb    : Node3D "twilight"    -> TS_Rig, AnimationPlayer
##   rainbowdash.glb  : Node3D "rainbowdash" -> RD_Rig, AnimationPlayer
##   fluttershy.glb   : Node3D "fluttershy"  -> FS_Rig, AnimationPlayer
##
## (verified by dumping each imported scene's node tree; see
## game/scenes/test/registry_gallery.gd, the scene that asserts this holds).
## The character rig (TS_Rig/RD_Rig/FS_Rig) is a SIBLING of the AnimationPlayer,
## not an ancestor, and its own name differs per character -- so
## `build(data).get_node(ANIMATION_PLAYER_PATH)`, i.e. NodePath("AnimationPlayer"),
## is the stable, documented way to reach it. Later tasks that play idle/walk
## should use this path rather than a tree-wide find_child() scan.
##
## VOICE BANK. build() never touches `data.voice_bank` at all -- a character with
## no voice bank (every current pony but Twilight) spawns exactly the same way as
## one that has one; there is nothing here that could block on it.

const HoofPlanterScript := preload("res://actors/pony/hoof_planter.gd")
const RumpBounceScript := preload("res://actors/pony/rump_bounce.gd")
const PonyRigScript := preload("res://scripts/pony_rig.gd")

## Documented, stable path to the AnimationPlayer on any instance build() returns.
## See the class doc comment above for the per-character verification.
const ANIMATION_PLAYER_PATH := ^"AnimationPlayer"


## Build a ready-to-use instance of `data`: resolve and load its model, attach the
## mane/tail spring simulation via PonyRig, and hand back a Node3D whose AnimationPlayer is
## reachable at ANIMATION_PLAYER_PATH.
##
## `model_path_override` REPLACES data.model_path AND NOTHING ELSE. It exists because a
## stock pony's mane is a property of the INDIVIDUAL, not of the hidden record three
## thousand of them share (game/systems/stock_palette.gd MANE_STYLES); everything else about
## her, her personality, her stats, her name, still comes off the PonyData. Empty means "use
## the record's own model", which is what all 43 named characters pass and what every
## shipped call site did before this argument existed.
##
## Fails loudly via push_error and returns null -- never a half-built node -- for:
##   - a null `data`
##   - an empty resolved model path
##   - a model path that does not resolve to an existing resource
##   - a model path that resolves but does not load as a PackedScene
##   - a model that loads but has no AnimationPlayer at ANIMATION_PLAYER_PATH
##     (later tasks depend on that path to play idle/walk; a model without one
##     is not something anything downstream can use)
static func build(data: PonyData, model_path_override: String = "") -> Node3D:
	if data == null:
		push_error("PonyVisuals.build: data is null")
		return null

	var model_path: String = model_path_override if not model_path_override.is_empty() \
		else data.model_path
	if model_path.is_empty():
		push_error("PonyVisuals.build: pony '%s' has an empty model_path" % data.id)
		return null

	if not ResourceLoader.exists(model_path):
		push_error("PonyVisuals.build: pony '%s' model_path '%s' does not resolve to an existing resource" % [
			data.id, model_path
		])
		return null

	var scene: Resource = load(model_path)
	if scene == null or not (scene is PackedScene):
		push_error("PonyVisuals.build: pony '%s' model_path '%s' did not load as a PackedScene" % [
			data.id, model_path
		])
		return null

	var pony: Node3D = (scene as PackedScene).instantiate()
	if pony == null:
		push_error("PonyVisuals.build: pony '%s' model_path '%s' failed to instantiate" % [
			data.id, model_path
		])
		return null

	# Attach the mane/tail spring bones via PonyRig -- never duplicated here. This
	# must happen before the caller adds `pony` to the scene tree (PonyRig's own
	# contract; see attach_hair_simulation()'s doc comment), which build() already
	# satisfies since it never adds the instance anywhere itself.
	PonyRigScript.attach_hair_simulation(pony)
	# Hooves on the ground under them, not on the flat floor the clips were authored on.
	for sk: Skeleton3D in pony.find_children("*", "Skeleton3D", true, false):
		var planter := HoofPlanterScript.new()
		planter.name = "HoofPlanter"
		sk.add_child(planter)
		break
	_fold_wings(pony)
	# The owner's slapstick bounce (actors/pony/rump_bounce.gd).
	var bounce := RumpBounceScript.new()
	bounce.name = "RumpBounce"
	pony.add_child(bounce)
	bounce.bind(pony)

	var anim := pony.get_node_or_null(ANIMATION_PLAYER_PATH)
	if anim == null or not (anim is AnimationPlayer):
		push_error("PonyVisuals.build: pony '%s' (%s) has no AnimationPlayer at documented path %s" % [
			data.id, model_path, ANIMATION_PLAYER_PATH
		])
		pony.free()
		return null

	return pony


## THE MANE SIX'S FOLDED WINGS, AS THE SHOW FOLDS THEM. As exported they reached back over the
## whole flank, so Rainbow Dash, Fluttershy and Twilight wore their marks hidden but for
## slivers around the wing (owner 2026-11-05: "Make sure this cutie mark bug doesn't happen
## anywhere"). Each is drawn smaller about its root, the front top edge where it meets her
## shoulder, so it rests on her barrel and the mark shows whole behind it.
const FOLDED_WING_SCALE := 0.75


static func _fold_wings(pony: Node3D) -> void:
	for mi: MeshInstance3D in pony.find_children("Base_Wings_Folded*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		var box := mi.mesh.get_aabb()
		var root := Vector3(0.0, box.end.y, box.end.z)
		var k := FOLDED_WING_SCALE
		mi.transform = Transform3D(Basis().scaled(Vector3.ONE * k), root - root * k)
