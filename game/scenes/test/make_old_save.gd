extends SceneTree
## Writes the pre-sweep save fixture for test_old_save_loads.gd (PLAN.md PS0, review focus 1):
## a ranch with a Paddock of three, a Grand Pen of two, a bought decoration, an Escape
## Artist out for the night and a full saddlebag, saved by the code as it stood before
## section PS (b9cbc4b, the save format of 13d0c11 plus 72e9736's fixes). Run once, headless:
##
##   FILLY_TEST_SAVE_DIR=/tmp/x tools/bin/godot --headless --path game \
##     -s res://scenes/test/make_old_save.gd
##
## then copy the slot file it names into game/test/fixtures/old_save_pre_ps/.

const BootIntentScript := preload("res://world/boot_intent.gd")
const PonyInstanceScript := preload("res://systems/pony_instance.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	BootIntentScript.driven = true
	BootIntentScript.request_new_game()
	change_scene_to_file("res://world/ranch.tscn")
	var ranch: Node = null
	for i in 600:
		await process_frame
		ranch = current_scene
		if ranch != null and ranch.get("people") != null and i > 30:
			break
	for i in 30:
		await physics_frame
	var slots: Array = ranch.call("plot_slots")
	var cat: PlotRegistry = ranch.call("_plots_catalogue")
	var small: PlotSlot = slots[0]
	var grand: PlotSlot = null
	for s: PlotSlot in slots.slice(1):
		if not s.is_overgrown():
			grand = s
			break
	assert(small.build(cat.by_id(&"pen_small")))
	assert(grand != null and grand.build(cat.by_id(&"pen_grand")))
	for i in 10:
		await physics_frame
	var paddock := small.get_built() as Pen
	var big := grand.get_built() as Pen
	var scoot := PonyInstanceScript.create(&"scootaloo")
	for id: StringName in [&"scootaloo", &"twilight", &"derpyhooves"]:
		paddock.add_pony(scoot if id == &"scootaloo" else PonyInstanceScript.create(id))
	for id: StringName in [&"fluttershy", &"octavia"]:
		big.add_pony(PonyInstanceScript.create(id))
	# Scootaloo hops the Paddock fence: out for the night when the save is taken.
	ranch.call("_escape_artists")
	var gs: Node = ranch.get("_game_state")
	Decor.add(gs.story, &"hay_bales")
	var storage: Storage = ranch.get("player").get_magic_beam().get_storage()
	var fill := [&"applejack", &"rarity", &"pinkiepie", &"rainbowdash", &"trixie", &"lyra",
		&"bonbon", &"vinylscratch", &"carrottop", &"berrypunch", &"minuette", &"sweetiebelle",
		&"applebloom", &"cheerilee"]
	var k := 0
	while not storage.is_full():
		storage.store(PonyInstanceScript.create(fill[k % fill.size()]))
		k += 1
	gs.bits = 1234
	assert(gs.save_to_slot())
	print("OLD_SAVE_WRITTEN %s paddock=%d grand=%d bag=%d escaped=%d" % [
		ProjectSettings.globalize_path(SaveIO.slot_path(gs.DEFAULT_SLOT)),
		paddock.ponies().size(), big.ponies().size(), storage.contents().size(),
		(gs.story.get_var("escaped_tonight", []) as Array).size()])
	quit(0)
