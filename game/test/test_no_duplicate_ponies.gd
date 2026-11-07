extends GutTest
## PLAYTEST 2026-11-05 ITEMS 39 AND 70, in the owner's words:
##   39: "Two of the same named pony at once (two Sweetie Belles, two Scootaloos)."
##   70: "Ponies escaping fully upgraded pens." The owner had every pen at its highest tier
##       and still saw escapes, with repeats in the wild.
##
## WHAT HIS SAVE SAYS (slot_0.json of 2026-11-05): four Grand Pens, two Sweetie Belles caught
## 2.6 s apart, two Scootaloos, two Rarities, two Coco Pommels. Sweetie Belle and Scootaloo
## are the CMC Escape Artists: early on, in Paddocks, they hopped out at night, were dropped
## from the save, and the spawner (which then knew nothing of what she owned) drew them
## again, so he caught them twice; the same blind spot put a second Rarity in the wild. That
## build had no Spawner.owned_ids (PT3, de3f961, added it); no code path lets a Big or Grand
## Pen lose a pony at night. This file pins all of that, and the holes found past PT3:
##   - a guest (Tumble's sighting, a canon guest) was stood in the wild with no check that
##     the same character was already standing there;
##   - a pony walking off the map (her hours ended, or a runaway) was struck out of nothing,
##     so the next hour could draw her again while she was still there to be caught.

const RanchScene := preload("res://world/ranch.tscn")
const PonyInstanceScript := preload("res://systems/pony_instance.gd")
const GameStateScript := preload("res://systems/game_state.gd")
const StockPaletteScript := preload("res://systems/stock_palette.gd")
const SaveIOScript := preload("res://systems/save_io.gd")
const WorldStateScript := preload("res://systems/world_state.gd")

## Not 0 (the game's) and not 9 (ranch.gd's own probe); see test_pen.gd's SCRATCH_SLOT.
const SLOT := 33


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
	return ranch


## Every named character the player owns or that stands in the wild (walking off included,
## since she can still be caught), as {id: count}.
func _named_counts(ranch: Node) -> Dictionary:
	var counts := {}
	for id in ranch.call("_owned_named_ids"):
		counts[StringName(id)] = int(counts.get(StringName(id), 0)) + 1
	for p: Node3D in ranch.get("spawner").call("get_spawned"):
		if not is_instance_valid(p) or p.is_queued_for_deletion():
			continue
		var data: PonyData = p.call("get_data")
		if data == null or StockPaletteScript.is_stock_id(data.id):
			continue
		counts[data.id] = int(counts.get(data.id, 0)) + 1
	return counts


func _dupes(ranch: Node) -> Array:
	var out: Array = []
	var counts := _named_counts(ranch)
	for id in counts:
		if int(counts[id]) > 1:
			out.append("%s x%d" % [id, counts[id]])
	return out


func _named_wild(ranch: Node) -> Node3D:
	for p: Node3D in ranch.get("spawner").call("get_spawned"):
		var data: PonyData = p.call("get_data")
		if data != null and not StockPaletteScript.is_stock_id(data.id) and not p.call("is_leaving"):
			return p
	return null


func test_ten_nights_upgraded_pens_a_recatch_and_a_save_make_no_second_of_anyone() -> void:
	var ranch = await _ranch()
	# She caught them: whoever of the four stands in the wild right now is taken off it, as
	# a catch would (the pens below are filled by hand, not by the Scoop).
	for p: Node3D in ranch.get("spawner").call("get_spawned"):
		var pd: PonyData = p.call("get_data")
		if pd != null and pd.id in [&"scootaloo", &"sweetiebelle", &"rarity", &"applebloom"]:
			p.queue_free()
	await wait_physics_frames(2)
	var catalogue: PlotRegistry = ranch.call("_plots_catalogue")
	var slots: Array[PlotSlot] = ranch.call("plot_slots")
	# The owner's case: a Paddock upgraded all the way, the two CMC Escape Artists in it.
	assert_true(slots[0].build(catalogue.by_id(&"pen_small")))
	assert_true(slots[0].upgrade(catalogue.by_id(&"pen_large")))
	assert_true(slots[0].upgrade(catalogue.by_id(&"pen_grand")))
	var grand := slots[0].get_built() as Pen
	for id in [&"scootaloo", &"sweetiebelle", &"rarity"]:
		assert_true(grand.add_pony(PonyInstanceScript.create(id)))
	# And one Paddock with the third, who does hop out (her trait) and must come home.
	if slots[1].is_overgrown():
		slots[1].set_overgrown(false)
	assert_true(slots[1].build(catalogue.by_id(&"pen_small")))
	var paddock := slots[1].get_built() as Pen
	var apple := PonyInstanceScript.create(&"applebloom")
	assert_true(paddock.add_pony(apple))
	await wait_physics_frames(2)

	var gs: Node = ranch.get("_game_state")
	var beam = ranch.get("player").get_magic_beam()
	var escapes_seen := 0
	var recaught := false
	for night in 10:
		for step in int(WorldStateScript.CYCLE_SECONDS / 60.0):
			ranch.call("advance_world", 60.0)
			assert_eq(grand.ponies().size(), 3,
				"night %d: nobody leaves a fully upgraded pen" % (night + 1))
			var out: Array = gs.story.get_var("escaped_tonight", [])
			if not out.is_empty():
				escapes_seen = maxi(escapes_seen, 1)
				# On the third night she is caught again while she is out (the recatch).
				if night == 2 and not recaught:
					var body: Node3D = ranch.call("_escaped_body", apple.uid)
					if body != null:
						assert_true(beam.get_storage().store(apple))
						body.queue_free()
						beam.emit_signal("captured", apple)
						recaught = true
			var d := _dupes(ranch)
			assert_eq(d, [], "night %d: no second of anyone (%s)" % [night + 1, ", ".join(d)])
			if not d.is_empty():
				return
		await wait_physics_frames(1)
	assert_gt(escapes_seen, 0, "sanity: the Paddock's Escape Artist did hop out")
	assert_true(recaught, "sanity: she was caught again while out")
	assert_eq(_dupes(ranch), [], "after ten nights")

	# Save and load: the tier survives (70a) and nobody is doubled in the file.
	assert_true(gs.save_to_slot(SLOT), "the save lands")
	var back: Node = autofree(GameStateScript.new())
	assert_true(back.load_from_slot(SLOT), "and loads")
	assert_eq(String(back.plots.get(String(slots[0].slot_id), "")), "pen_grand",
		"the upgraded tier is what the save holds")
	var seen := {}
	for inst: PonyInstance in back.get_ponies():
		if inst.is_stock():
			continue
		assert_false(seen.has(inst.data_id), "one %s in the save" % inst.data_id)
		seen[inst.data_id] = true
	SaveIOScript.delete_slot(SLOT)


func test_a_guest_is_never_a_second_of_a_pony_already_in_the_wild() -> void:
	# Tumble's sighting and the canon guests stood a named pony in the wild without asking
	# whether she was already standing there.
	var ranch = await _ranch()
	var spawner: Node = ranch.get("spawner")
	var wild := _named_wild(ranch)
	assert_not_null(wild, "sanity: a named pony is in the wild")
	var data: PonyData = wild.call("get_data")
	var guest: Node3D = spawner.call("spawn_guest", data, {}, wild.global_position + Vector3(3, 0, 0))
	assert_null(guest, "no second %s next to the first" % data.id)
	assert_eq(_dupes(ranch), [])


func test_a_guest_is_never_a_pony_she_owns() -> void:
	var ranch = await _ranch()
	var spawner: Node = ranch.get("spawner")
	var beam = ranch.get("player").get_magic_beam()
	var reg: PonyRegistry = ranch.get("_game_state").get_registry()
	var sweetie := PonyInstanceScript.create(&"sweetiebelle")
	assert_true(beam.get_storage().store(sweetie), "Sweetie Belle in the saddlebag")
	var guest: Node3D = spawner.call("spawn_guest", reg.by_id(&"sweetiebelle"), {},
		ranch.get("player").global_position + Vector3(6, 0, 0))
	assert_null(guest, "no wild Sweetie Belle while hers is in the bag")


func test_a_pony_walking_off_is_still_on_the_map_for_the_draw() -> void:
	# She can still be caught while she walks off, so the next hour must not draw her again.
	var ranch = await _ranch()
	var spawner: Node = ranch.get("spawner")
	var wild := _named_wild(ranch)
	assert_not_null(wild)
	var id: StringName = (wild.call("get_data") as PonyData).id
	assert_true(wild.call("leave"), "she sets off")
	assert_true(spawner.call("_standing_ids").has(id),
		"%s, walking off and still catchable, is not drawn a second time" % id)
	# And through a day of hours, while she is still out there, nobody draws her again.
	for phase in 4:
		for weather in 4:
			spawner.call("refresh", phase, weather, 1, ranch.get("player").global_position)
			assert_eq(_dupes(ranch), [], "phase %d weather %d" % [phase, weather])
