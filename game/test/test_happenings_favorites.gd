extends GutTest
## The second half of the first hour (world/happenings.gd): Rainbow Dash's Sonic Rainboom,
## Derpy's mail mix-up and Trixie's show each play, are stamped as novelty for PACING.md,
## and bring their canon pony along only while she is still uncaught.

const RanchScene := preload("res://world/ranch.tscn")


func _ranch() -> Node:
	var ranch = RanchScene.instantiate()
	add_child_autofree(ranch)
	await wait_frames(3)
	return ranch


func _noted(ranch: Node) -> Array:
	var ids: Array = []
	for e in (ranch.get("_game_state").get("novelty").get("entries") as Array):
		ids.append(String((e as Dictionary).get("id", "")))
	return ids


func test_the_rainboom_lands_rainbow_dash_and_is_noted() -> void:
	var ranch = await _ranch()
	var h: Node = ranch.get("happenings")
	assert_not_null(h, "the ranch stands its happenings")
	h.call("_rainboom")
	await wait_frames(2)
	assert_has(_noted(ranch), "rainboom")
	var dash := false
	for p in ranch.get("spawner").call("get_spawned"):
		if is_instance_valid(p) and String(p.name).ends_with("_rainbowdash"):
			dash = true
	assert_true(dash, "Rainbow Dash lands after her Rainboom")


func test_derpys_mix_up_leaves_apples() -> void:
	var ranch = await _ranch()
	var inv: Inventory = ranch.get("_game_state").get("inventory")
	var before := inv.count(&"apple")
	ranch.get("happenings").call("_derpy_mail")
	await wait_frames(2)
	assert_eq(inv.count(&"apple"), before + 3, "three apples to say sorry")
	assert_has(_noted(ranch), "derpy_mail")


func test_trixie_plays_the_strip() -> void:
	var ranch = await _ranch()
	ranch.get("happenings").call("_trixie_show")
	await wait_frames(2)
	assert_has(_noted(ranch), "trixie_show")
