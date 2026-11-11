extends "res://test_input/test_first_pony.gd"
## ROUND 2 (owner playtest 2026-10-25), note 3: "i think the text and traits on catch can be
## better maybe icons and stuff instead of basic text on the top". Plays test_first_pony's
## whole first catch from the title screen, and then reads the screen: a card has slid in
## with her portrait, name, stars and trait icons, it covers neither the crosshair nor the
## saddlebag, and there is no "Caught ...!" line at the top. Screenshots go to
## build/playtest_evidence/round2/.

var _verdict := ""


## The first catch's own verdict is caught here rather than ending the run, so this test can
## go on to look at what the catch put on the screen.
func ok(msg: String = "") -> void:
	if _verdict == "":
		_verdict = msg if not msg.is_empty() else "caught"


func _play() -> void:
	await super._play()
	if _done:
		return
	if not check(_verdict != "", "the first catch never succeeded"):
		return
	var hud: Node = ranch.get_node_or_null(^"HUD")
	var card: Control = hud.call("catch_card")
	# The card waits for her flight into the Scoop (CatchCard.entrance_delay) before it comes.
	var tw := 0.0
	while card != null and not bool(card.call("is_showing")) and tw < 2.0:
		await wait(0.05)
		tw += 0.05
	var shots := ProjectSettings.globalize_path("res://").path_join("../build/playtest_evidence/round2")
	DirAccess.make_dir_recursive_absolute(shots)
	root.get_texture().get_image().save_png(shots.path_join("catch_card.png"))
	note("screenshot %s" % shots.path_join("catch_card.png"))
	if not check(card != null and bool(card.call("is_showing")), "no catch card on screen"):
		return
	# THE CENTRE MOMENT COMES FIRST (Fable AAA round 1): the card is meant to be over the
	# middle of the screen for its first second and a half. The checks below are about where
	# it settles, so they wait for it to fly to its corner.
	# A DRIFTER'S CARD IS LIGHT (P9 item 28): no centre moment, it slides straight into its
	# corner, holds CatchCard.LIGHT_HOLD seconds and goes. It is read once it has slid in.
	if bool(card.call("is_light")):
		await wait(CatchCard.SLIDE_IN + 0.1)
	else:
		while bool(card.call("in_moment")):
			await process_frame
		await wait(CatchCard.FLY + 0.1)
	if not check(bool(card.call("has_portrait")), "the card has no portrait of her"):
		return
	var traits: Array = card.call("shown_traits")
	note("card: '%s', rarity %d, traits %s" % [card.call("shown_name"),
		int(card.call("shown_rarity")), traits])
	if not check(traits.size() >= 3, "the card shows %d trait chips" % traits.size()):
		return
	var toast := str(hud.call("toast_text"))
	if not check(not toast.begins_with("Caught"), "the catch still raised a top line: '%s'" % toast):
		return
	var panel := card.get_node("Panel") as Control
	var r: Rect2 = panel.get_global_rect()
	var view: Vector2 = hud.get_viewport().get_visible_rect().size
	var centre := Rect2(view * 0.5 - Vector2(90, 90), Vector2(180, 180))
	var bag: Rect2 = (hud.get_node(^"Bag") as Control).get_global_rect()
	note("card rect %s, view %s, bag %s" % [r, view, bag])
	if not check(not r.intersects(centre), "the card covers the crosshair (%s)" % r):
		return
	if not check(not r.intersects(bag), "the card covers the saddlebag (%s)" % r):
		return
	await wait(0.3)
	root.get_texture().get_image().save_png(shots.path_join("catch_card_settled.png"))
	super.ok("%s; then a card with her portrait, %d trait chips, clear of the crosshair and bag"
		% [_verdict, traits.size()])
