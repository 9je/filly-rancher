extends GutTest
## Tests for PonyVisuals (game/actors/pony/pony_visuals.gd) -- the single choke
## point where a PonyData record turns into a live pony instance. Runs headlessly
## with no scene of its own: PonyRig.attach_hair_simulation() configures its
## simulator before the instance is ever added to a tree (see pony_rig.gd's
## spawn()/attach_hair_simulation() doc comments -- model_gallery.gd relies on the
## same thing), so build() is fully exercisable standalone. Preloads by path
## rather than the global class_name, matching the convention documented at the
## top of game/scripts/pony_rig.gd.

const PonyVisualsScript := preload("res://actors/pony/pony_visuals.gd")
const PonyDataScript := preload("res://systems/pony_data.gd")
const PonyRegistryScript := preload("res://systems/pony_registry.gd")
const PonyRigScript := preload("res://scripts/pony_rig.gd")

const PONY_DIR := "res://data/ponies/"


func _make_pony(id: StringName, model_path: String) -> PonyData:
	var data: PonyData = PonyDataScript.new()
	data.id = id
	data.model_path = model_path
	return data


func test_build_null_data_returns_null_and_reports() -> void:
	var result = PonyVisualsScript.build(null)
	assert_null(result)
	assert_push_error(1, "build(null) should push_error rather than crash")


func test_build_empty_model_path_returns_null_and_reports() -> void:
	var data := _make_pony(&"nomodel", "")
	var result = PonyVisualsScript.build(data)
	assert_null(result)
	assert_push_error(1, "an empty model_path should push_error, not silently return")


func test_build_missing_model_path_returns_null_and_reports() -> void:
	var data := _make_pony(&"ghost", "res://assets/converted/ponies/does_not_exist.glb")
	var result = PonyVisualsScript.build(data)
	assert_null(result)
	assert_push_error(1, "a model_path with no resource behind it should push_error, not return a half-built node")


func test_build_model_path_pointing_at_wrong_resource_type_returns_null_and_reports() -> void:
	# A path that resolves but isn't a PackedScene (e.g. a pony's own .tres data
	# file, mis-copy-pasted into model_path) must fail the same loud way.
	var data := _make_pony(&"wrongtype", "res://data/ponies/twilight.tres")
	var result = PonyVisualsScript.build(data)
	assert_null(result)
	assert_push_error(1, "a model_path resolving to a non-PackedScene resource should push_error")


func test_build_real_pony_has_animation_player_with_every_authored_clip() -> void:
	var registry := PonyRegistryScript.new()
	var ponies := registry.load_all(PONY_DIR)
	var data: PonyData = ponies[&"twilight"]

	var pony := PonyVisualsScript.build(data)
	autofree(pony)

	assert_not_null(pony, "build() should succeed for a real, valid pony")
	var anim: AnimationPlayer = pony.get_node_or_null(PonyVisualsScript.ANIMATION_PLAYER_PATH)
	assert_not_null(anim, "AnimationPlayer should be reachable at the documented ANIMATION_PLAYER_PATH")
	# Every Action tools/author_anims.py's author() builds. A clip added there and not
	# here is a clip nothing checks reached the .glb.
	for clip in ["idle", "walk", "gallop"]:
		assert_true(anim.has_animation(clip),
			"twilight's AnimationPlayer should have a '%s' clip" % clip)
		var animation: Animation = anim.get_animation(clip)
		assert_eq(animation.loop_mode, Animation.LOOP_LINEAR,
			("'%s' must import looping -- glTF carries no loop flag, so this comes from " +
			"the [importer_defaults] block in project.godot, which needs one entry per " +
			"clip NAME and silently leaves any clip it does not list playing once") % clip)


func test_build_real_pony_has_live_spring_bone_simulation() -> void:
	var registry := PonyRegistryScript.new()
	var ponies := registry.load_all(PONY_DIR)
	var data: PonyData = ponies[&"twilight"]

	var pony := PonyVisualsScript.build(data)
	autofree(pony)

	var skeleton: Skeleton3D = pony.find_child("Skeleton3D", true, false)
	assert_not_null(skeleton, "build() should produce a pony with a Skeleton3D")
	var sim := skeleton.get_node_or_null(NodePath(PonyRigScript.SIMULATOR_NAME))
	assert_true(sim is SpringBoneSimulator3D,
		"build() should attach a real SpringBoneSimulator3D via PonyRig, not just load the model")


func test_build_does_not_require_a_voice_bank() -> void:
	# Only Twilight has a voice bank on disk (game/assets/audio/voice/twilight/).
	# build() must never touch data.voice_bank, so a character without one --
	# Fluttershy here -- has to spawn exactly the same way.
	var registry := PonyRegistryScript.new()
	var ponies := registry.load_all(PONY_DIR)
	var data: PonyData = ponies[&"fluttershy"]
	assert_false(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(data.voice_bank)),
		"this test assumes fluttershy's voice bank does not exist on disk yet")

	var pony := PonyVisualsScript.build(data)
	autofree(pony)

	assert_not_null(pony, "a missing voice bank must not block a spawn")
