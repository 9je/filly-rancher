extends GutTest
## Project-wide import settings that a visual defect depends on.
##
## THE BUG THIS EXISTS FOR. The owner reported "still a weird pupil layering issue,
## sometimes it fixes itself when I get close". At 6 m both eyes were correct; from 10 m
## out one iris collapsed to a blank white disc. The cause was Godot's automatic mesh LOD:
## every pony's iris is a cap shrinkwrapped onto the eyeball with about 1.6 mm of
## clearance (tools/export_blend.py, and docs/pipeline.md section 5b), and the LOD
## generator decimates that cap by more than its own clearance, so the sclera wins the
## depth test and the pupil disappears. Walking closer loaded LOD 0 and it came back,
## which is exactly the symptom that was reported.
##
## WHY THIS IS ASSERTED HERE RATHER THAN ON THE ASSET. The per-file setting lives in
## game/assets/converted/**/*.glb.import, and that whole directory is gitignored, because
## it is pipeline output. A setting made there would be correct on this machine and absent
## on the next clone, and the bug would come back silently the first time somebody re-ran
## the pipeline. game/project.godot's [importer_defaults] is the only tracked place the
## project can say this, so that is where it is said, and this is the test that keeps it
## said.
##
## The cost is real and accepted: no mesh in the project gets automatic LODs. This is a
## small world (10 ponies and 33 props), correctness at 10 m matters more than the draw
## call saving, and the alternative (inflating the iris offset until it survives an
## unbounded decimation) trades a visible defect for an invisible one.


func test_scene_import_defaults_disable_mesh_lod_generation() -> void:
	var defaults = ProjectSettings.get_setting("importer_defaults/scene")
	assert_not_null(defaults,
		"project.godot must carry an [importer_defaults] scene block")
	assert_true(defaults is Dictionary,
		"importer_defaults/scene should be a Dictionary of importer options")
	assert_true(defaults.has("meshes/generate_lods"),
		"the scene importer defaults must state generate_lods explicitly -- leaving it "
		+ "unset means Godot's default (on) and the pupils break past 10 m again")
	assert_false(bool(defaults.get("meshes/generate_lods", true)),
		"mesh LOD generation must stay OFF: the LOD generator decimates each iris cap by "
		+ "more than its 1.6 mm clearance over the eyeball, so a pupil vanishes at "
		+ "distance and returns when the player walks closer")


func test_authored_clips_still_loop() -> void:
	# Guards the block this test's sibling assertion sits inside: adding a key to
	# [importer_defaults] by hand is easy to get wrong, and silently losing the loop flags
	# would leave every pony freezing at the end of her first idle cycle.
	var defaults = ProjectSettings.get_setting("importer_defaults/scene")
	var subs = defaults.get("_subresources", {}) if defaults is Dictionary else {}
	var anims = subs.get("animations", {})
	for clip in ["idle", "walk", "gallop"]:
		assert_true(anims.has(clip), "'%s' must still be configured in the import defaults" % clip)
		assert_eq(int(anims[clip].get("settings/loop_mode", -1)), 1,
			"'%s' must still import as a looping clip" % clip)
