extends GutTest
## AN ESCAPE ARTIST IS NEVER LOST (PT3; playtest 2026-11-05 items 39, 63, 70). She hops a
## Paddock fence at night, as her trait says, but comes home at dawn, and while she is out
## the spawner counts her as the player's, so no second of her ever turns up in the wild.

const RanchScene := preload("res://world/ranch.tscn")
const PonyInstanceScript := preload("res://systems/pony_instance.gd")


func _ranch_with_paddock() -> Array:
	var ranch = RanchScene.instantiate()
	add_child_autofree(ranch)
	await wait_physics_frames(4)
	var slot: PlotSlot = ranch.plot_slots()[0]
	var paddock: PlotData = ranch.call("_plots_catalogue").by_id(&"pen_small")
	assert_true(slot.build(paddock))
	await wait_physics_frames(2)
	return [ranch, slot.get_built()]


func test_she_hops_out_at_night_and_is_home_at_dawn() -> void:
	var got := await _ranch_with_paddock()
	var ranch = got[0]
	var pen: Pen = got[1]
	var scoot := PonyInstanceScript.create(&"scootaloo")
	assert_true(pen.add_pony(scoot))
	ranch.call("_escape_artists")
	assert_eq(pen.ponies().size(), 0, "the Escape Artist hopped the Paddock fence")
	assert_has(ranch.call("_owned_named_ids"), &"scootaloo", "she is still the player's while she is out")
	ranch.call("_escapees_come_home")
	await wait_physics_frames(2)
	assert_eq(pen.ponies().size(), 1, "she walked back in at dawn")
	assert_eq(pen.ponies()[0].uid, scoot.uid, "the same pony, not a new one")
	assert_eq((ranch.get("_game_state").story.get_var("escaped_tonight", []) as Array).size(), 0,
		"nobody is left out")


func test_she_waits_outside_when_every_pen_is_full() -> void:
	var got := await _ranch_with_paddock()
	var ranch = got[0]
	var pen: Pen = got[1]
	assert_true(pen.add_pony(PonyInstanceScript.create(&"scootaloo")))
	ranch.call("_escape_artists")
	while not pen.is_full():
		pen.add_pony(PonyInstanceScript.create(&"twilight"))
	ranch.call("_escapees_come_home")
	assert_eq((ranch.get("_game_state").story.get_var("escaped_tonight", []) as Array).size(), 1,
		"she is still remembered, to come home when there is room")
	assert_has(ranch.call("_owned_named_ids"), &"scootaloo")
