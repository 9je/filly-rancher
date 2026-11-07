extends GutTest
## PLAYTEST 2026-11-05 ITEM 53, in the owner's words: 'The trail keeps pointing to the
## paddock after you've upgraded it ("0/2") [45].'
##
## What [45] shows: the card reads "0/2 8 m" and the trail runs to the first pen, every pen
## a Grand Pen and full. The "0/2" is the Bloom step ("Help ponies Bloom 0/2"), whose goal
## is the pens, and Ranch._guide_pen_target() answers "a pen with room, else an empty plot,
## else Plots/Slot1": with every pen upgraded and full there is no room anywhere, so it fell
## through to Slot1, the old Paddock, forever. Upgrading did not move it because nothing about
## the Bloom step was ever about room. The Bloom step now leads to the pen holding a Drifter
## who can Bloom, and with no Drifter penned, to a wild Drifter.

const RanchScene := preload("res://world/ranch.tscn")
const PonyInstanceScript := preload("res://systems/pony_instance.gd")
const GeneratorScript := preload("res://systems/pony_generator.gd")
const StockPaletteScript := preload("res://systems/stock_palette.gd")

const NAMED: Array[StringName] = [&"twilight", &"rarity", &"fluttershy", &"octavia",
	&"bonbon", &"lotusblossom", &"soarin", &"milkyway", &"carrottop", &"berrypunch",
	&"vinylscratch", &"rainbowdash", &"cocopommel", &"scootaloo", &"sweetiebelle"]


func _ranch() -> Node:
	var ranch = RanchScene.instantiate()
	add_child_autofree(ranch)
	for i in 600:
		if bool(ranch.get("boot_done")):
			break
		await wait_physics_frames(1)
	var cs: Node = ranch.get("creation_screen")
	if cs != null and bool(cs.call("is_open")):
		cs.call("confirm")
	var lp: Node = ranch.get("letter_panel")
	if lp != null and bool(lp.call("is_open")):
		lp.call("close")
	get_tree().paused = false
	# Past the Depot lesson with six delivered: the next step is two Blooms (0/2).
	var story: Story = ranch.call("get_story")
	for f in ["has_scoop", "met_fennel", "depot_explained"]:
		story.set_flag(f)
	story.deliveries = 6
	return ranch


## Every plot a pen, Slot1's Paddock upgraded to a Grand Pen, every pen full. `drifter_in`
## is the slot index whose pen gets one Drifter among its named ponies, or -1 for none.
func _upgraded_full_pens(ranch: Node, drifter_in: int) -> Array[PlotSlot]:
	var catalogue: PlotRegistry = ranch.call("_plots_catalogue")
	var slots: Array[PlotSlot] = ranch.call("plot_slots")
	for i in slots.size():
		var slot := slots[i]
		if slot.is_overgrown():
			slot.set_overgrown(false)
		if i == 0:
			assert_true(slot.build(catalogue.by_id(&"pen_small")), "a Paddock on Slot1")
			assert_true(slot.upgrade(catalogue.by_id(&"pen_large")), "upgraded once")
			assert_true(slot.upgrade(catalogue.by_id(&"pen_grand")), "and fully")
		else:
			assert_true(slot.build(catalogue.by_id(&"pen_grand")))
		var pen := slot.get_built() as Pen
		if i == drifter_in:
			var d := PonyInstanceScript.create(&"stock_curious")
			d.stock = GeneratorScript.generate(4100 + i).to_dict()
			assert_true(pen.add_pony(d))
		var n := 0
		while not pen.is_full():
			pen.add_pony(PonyInstanceScript.create(NAMED[(i * 5 + n) % NAMED.size()]))
			n += 1
	await wait_physics_frames(2)
	return slots


func test_the_bloom_step_leads_to_the_drifter_not_the_old_paddock() -> void:
	var ranch = await _ranch()
	var slots := await _upgraded_full_pens(ranch, 2)
	var o: Dictionary = ranch.call("current_objective")
	assert_string_contains(String(o.get("words", "")), "0/2", "the card is the owner's '0/2'")
	var place: Array = ranch.call("_guide_place", StringName(o.get("goal", &"")))
	assert_ne(place[0], slots[0], "not the paddock she has upgraded and filled")
	assert_eq(place[0], slots[2], "the pen with the Drifter who can Bloom")


func test_with_no_drifter_penned_the_trail_finds_a_wild_drifter() -> void:
	var ranch = await _ranch()
	var slots := await _upgraded_full_pens(ranch, -1)
	var o: Dictionary = ranch.call("current_objective")
	assert_string_contains(String(o.get("words", "")), "0/2")
	var place: Array = ranch.call("_guide_place", StringName(o.get("goal", &"")))
	assert_ne(place[0], slots[0], "not the paddock")
	var wild_drifters := 0
	for p: Node3D in ranch.get("spawner").call("get_spawned"):
		var data: PonyData = p.call("get_data")
		if data != null and StockPaletteScript.is_stock_id(data.id):
			wild_drifters += 1
	assert_gt(wild_drifters, 0, "sanity: the wild has Drifters in it")
	var who: Node3D = place[0] as Node3D
	assert_not_null(who, "the trail points somewhere")
	if who != null and who.has_method("get_data"):
		var data: PonyData = who.call("get_data")
		assert_true(StockPaletteScript.is_stock_id(data.id),
			"a Drifter, who can Bloom, not %s" % data.id)
	else:
		fail_test("the trail points at %s, not a wild pony" % who)
