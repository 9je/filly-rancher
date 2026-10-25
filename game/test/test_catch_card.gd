extends GutTest
## OWNER PLAYTEST 2026-10-25, note 3: "i think the text and traits on catch can be better
## maybe icons and stuff instead of basic text on the top". A catch slides in a card (name,
## portrait, rarity stars, trait icons) instead of raising a toast line.

const HudScene := preload("res://ui/hud.tscn")
const CardScript := preload("res://ui/catch_card.gd")
const IconScript := preload("res://ui/catch_icon.gd")
const PonyInstanceScript := preload("res://systems/pony_instance.gd")


func _card() -> Control:
	var host := Control.new()
	host.size = Vector2(1920, 1080)
	add_child_autofree(host)
	var card: Control = CardScript.new()
	host.add_child(card)
	return card


func test_a_catch_shows_her_name_stars_and_trait_chips() -> void:
	var card := _card()
	var twi = PonyInstanceScript.create(&"twilight")
	card.show_catch(twi, null)
	assert_true(card.is_showing())
	assert_eq(card.shown_name(), twi.display_name())
	var traits: Array[String] = card.shown_traits()
	assert_true(traits.has("Unicorn"), "her race: %s" % [traits])
	assert_true(traits.has("Night Owl"), "her quirk: %s" % [traits])
	assert_eq(traits.size(), 4, "race, quirk, food and hold: %s" % [traits])
	for t in traits:
		assert_false(t.contains(char(0x2014)), "no em dash on the card")
	var icons := 0
	for n in card.find_children("*", "Control", true, false):
		if n.get_script() == IconScript:
			icons += 1
	assert_eq(icons, 4, "each chip has a drawn icon")


func test_it_sits_top_right_clear_of_the_crosshair_and_the_bag() -> void:
	var card := _card()
	card.show_catch(PonyInstanceScript.create(&"fluttershy"), null)
	await wait_process_frames(2)
	var r: Rect2 = card.resting_rect()
	assert_gt(r.position.x, 1920 * 0.6, "on the right: %s" % r)
	assert_lt(r.end.y, 1080 * 0.45, "in the top half: %s" % r)
	var centre := Rect2(960 - 80, 540 - 80, 160, 160)
	assert_false(r.intersects(centre), "never over the crosshair")
	var bag := Rect2(44, 1080 - 216, 456, 172)
	assert_false(r.intersects(bag), "never over the saddlebag")


func test_the_hud_raises_a_card_not_a_toast_on_capture() -> void:
	var hud = HudScene.instantiate()
	add_child_autofree(hud)
	await wait_process_frames(1)
	hud.call("_on_captured", PonyInstanceScript.create(&"rainbowdash"))
	assert_true(hud.catch_card().is_showing(), "the card slid in")
	assert_false(hud.toast_text().begins_with("Caught"), "and no plain line at the top")


func test_every_icon_kind_draws() -> void:
	var kinds: Array[StringName] = [&"unicorn", &"pegasus", &"earth", &"hay", &"carrot",
		&"apple", &"daisy", &"daffodil", &"glutton", &"night_owl", &"social", &"loner",
		&"sparkler", &"skittish", &"escapee", &"sleepy", &"showoff", &"hold_0", &"hold_1",
		&"hold_2"]
	for k in kinds:
		var ic: Control = IconScript.new()
		ic.kind = k
		ic.size = Vector2(30, 30)
		add_child_autofree(ic)
	await wait_process_frames(2)
	assert_true(true, "no draw errors across %d kinds" % kinds.size())
