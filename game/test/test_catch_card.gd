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


## Fable AAA round 1: "keep the data; make it a full-screen moment rather than a toast". The
## card opens big over the middle of the screen, then settles into its corner.
func test_a_catch_is_a_centre_moment_that_settles_into_the_corner() -> void:
	var card := _card()
	card.show_catch(PonyInstanceScript.create(&"fluttershy"), null)
	await wait_process_frames(2)
	assert_true(card.in_moment(), "it opens as the moment")
	var panel: Control = card.get_node("Panel")
	var tw: Tween = card.get("_tween")
	tw.custom_step(CardScript.POP_IN + 0.05)
	assert_gt(panel.scale.x, 1.3, "big while it is the moment")
	var mid: Vector2 = panel.get_global_rect().get_center()
	assert_almost_eq(mid.x, 960.0, 60.0, "near the middle of the screen: %s" % mid)
	tw.custom_step(CardScript.MOMENT)
	assert_false(card.in_moment(), "the moment lasts about a second and a half")
	card.get("_tween").custom_step(CardScript.FLY + 0.05)
	assert_almost_eq(panel.scale.x, 1.0, 0.001)
	assert_eq(panel.position, Vector2.ZERO, "settled where the corner card always sat")
	assert_true(card.is_showing())


func test_any_click_skips_the_moment_to_the_corner() -> void:
	var card := _card()
	card.show_catch(PonyInstanceScript.create(&"twilight"), null)
	await wait_process_frames(1)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	card._input(click)
	assert_false(card.in_moment(), "the click skipped it")
	assert_eq(card.star_pop(3), 1.0, "every star is in place at once")
	card.get("_tween").custom_step(CardScript.FLY)
	assert_eq(card.get_node("Panel").position, Vector2.ZERO)
	assert_true(card.is_showing(), "the card itself stays up in its corner")
