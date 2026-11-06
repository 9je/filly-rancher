extends GutTest
## A SAVE FROM BEFORE THE PLAYTEST SWEEP STILL LOADS (PLAN.md PS0, review focus 1): the
## fixture (test/fixtures/old_save_pre_ps, written by scenes/test/make_old_save.gd on the
## pre-sweep code) has a Paddock of two with its Escape Artist out for the night, a Grand Pen
## of two, a bought decoration and a full saddlebag. Loaded by the ranch, nothing is lost and
## nobody is doubled, at the load and after the next dawn.

const RanchScene := preload("res://world/ranch.tscn")
const BootIntentScript := preload("res://world/boot_intent.gd")
const FIXTURE := "res://test/fixtures/old_save_pre_ps/slot_0.json"


func before_each() -> void:
	var dst := ProjectSettings.globalize_path(SaveIO.slot_path(GameState.DEFAULT_SLOT))
	DirAccess.make_dir_recursive_absolute(dst.get_base_dir())
	var src := FileAccess.get_file_as_string(FIXTURE)
	assert_ne(src, "", "the fixture is readable")
	var f := FileAccess.open(dst, FileAccess.WRITE)
	f.store_string(src)
	f.close()


func after_each() -> void:
	BootIntentScript.driven = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveIO.slot_path(GameState.DEFAULT_SLOT)))


func _loaded_ranch() -> Node:
	BootIntentScript.driven = true
	var ranch = RanchScene.instantiate()
	add_child_autofree(ranch)
	# The save is restored late in the ranch's staged boot; boot_done is its last step.
	for i in 1200:
		if bool(ranch.get("boot_done")):
			break
		await wait_physics_frames(1)
	assert_true(bool(ranch.get("boot_done")), "the ranch finished booting")
	return ranch


func _pens(ranch: Node) -> Dictionary:
	var by_kind := {}
	for slot: PlotSlot in ranch.call("plot_slots"):
		var pen := slot.get_built() as Pen
		if pen != null:
			by_kind[slot.saved_plot_id()] = pen
	return by_kind


func _owned_ids(ranch: Node) -> Array:
	var ids: Array = []
	for pen: Pen in _pens(ranch).values():
		for p: PonyInstance in pen.ponies():
			ids.append(p.data_id)
	for p: PonyInstance in ranch.get("player").get_magic_beam().get_storage().contents():
		ids.append(p.data_id)
	for d: Dictionary in ranch.get("_game_state").story.get_var("escaped_tonight", []):
		ids.append(StringName(str(d.get("data_id", d.get("id", "")))))
	return ids


func test_the_pens_the_bag_the_decor_and_the_escapee_survive() -> void:
	var ranch = await _loaded_ranch()
	var gs: Node = ranch.get("_game_state")
	assert_eq(int(gs.bits), 1234, "the purse")
	var pens := _pens(ranch)
	assert_true(pens.has("pen_small"), "the Paddock is rebuilt")
	assert_true(pens.has("pen_grand"), "the Grand Pen is rebuilt, not reverted to a Paddock")
	# A save quit with an Escape Artist out loads with her home already (ranch.gd, after
	# restore_owned_ponies): her body did not survive the quit.
	if pens.has("pen_small"):
		assert_eq((pens["pen_small"] as Pen).ponies().size(), 3, "the Paddock's two, and Scootaloo home")
	if pens.has("pen_grand"):
		assert_eq((pens["pen_grand"] as Pen).ponies().size(), 2, "the Grand Pen's two")
	var bag: Storage = ranch.get("player").get_magic_beam().get_storage()
	assert_eq(bag.contents().size(), 12, "the full saddlebag")
	assert_eq((gs.story.get_var("escaped_tonight", []) as Array).size(), 0, "nobody is left out")
	assert_has(Decor.owned(gs.story), "hay_bales", "the bought decoration is still hers")
	# What the spawner reads to never make a second of a named pony she has (items 39, 63, 70).
	assert_has(ranch.call("_owned_named_ids"), &"scootaloo",
		"home from her night out, she still counts as hers: no wild Scootaloo")


func test_nobody_is_doubled_before_or_after_dawn() -> void:
	var ranch = await _loaded_ranch()
	var before := _owned_ids(ranch)
	assert_eq(before.size(), 17, "3 + 2 penned, 12 in the bag")
	_assert_unique(before, "after the load")
	ranch.call("_escapees_come_home")
	await wait_physics_frames(2)
	var after := _owned_ids(ranch)
	assert_eq(after.size(), 17, "a dawn adds nobody")
	_assert_unique(after, "after dawn")


func _assert_unique(ids: Array, when: String) -> void:
	var seen := {}
	for id in ids:
		assert_false(seen.has(id), "%s: %s appears twice" % [when, id])
		seen[id] = true
