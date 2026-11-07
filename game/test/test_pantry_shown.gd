extends GutTest
## FEEDING IS SHOWN (PS9, playtest 2026-11-05 item 64: "Feeding is automatic from the pantry,
## and nothing says so; show the pantry stock and the hungry state"). The HUD carries a
## Pantry chip under the saddlebag: the food in stock and how many residents are hungry,
## warning when hungry ponies meet an empty pantry; and a hungry resident looks sad.

const HudScene := preload("res://ui/hud.tscn")
const PenScript := preload("res://world/pen.gd")
const PonyInstanceScript := preload("res://systems/pony_instance.gd")
const NeedsScript := preload("res://systems/needs.gd")


func _hud() -> Node:
	var hud: Node = HudScene.instantiate()
	add_child_autofree(hud)
	return hud


func test_the_chip_shows_the_food_in_stock_and_the_hungry() -> void:
	var hud := _hud()
	hud.set_pantry(12, 0)
	var s: Dictionary = hud.pantry_state()
	assert_true(s.visible, "the chip is up")
	assert_eq(s.food, "12")
	assert_eq(s.hungry, "", "nobody hungry: no hungry count")
	assert_false(s.warn)
	hud.set_pantry(3, 2)
	s = hud.pantry_state()
	assert_eq(s.hungry, "2")
	assert_false(s.warn, "hungry, but there is food: they are eating")


func test_hungry_ponies_and_an_empty_pantry_warn() -> void:
	var hud := _hud()
	hud.set_pantry(0, 2)
	assert_true(hud.pantry_state().warn)


func test_no_pens_no_chip() -> void:
	var hud := _hud()
	hud.set_pantry(-1, 0)
	assert_false(hud.pantry_state().visible, "before the first pen there is nothing to feed")


func test_a_hungry_resident_looks_sad_and_a_fed_one_happy() -> void:
	var pen: Pen = PenScript.new()
	pen.capacity = 2
	pen.slot_id = &"slot_hungry"
	add_child_autofree(pen)
	var her: PonyInstance = PonyInstanceScript.create(&"twilight")
	assert_true(pen.add_pony(her))
	var body: Node3D = pen.body_for(her.uid)
	var face: Node = body.call("_face_ref")
	assert_not_null(face, "precondition: she has a face")
	her.hunger = NeedsScript.HUNGRY_THRESHOLD + 0.2
	await wait_seconds(1.0)
	assert_true(body.call("looks_hungry"))
	assert_eq(int(face.mood), PonyFace.Mood.SAD, "hungry in her pen, she looks sad")
	assert_true(body.call("hunger_bubble_shown"), "and wears a bubble with a bale in it")
	her.hunger = 0.0
	await wait_seconds(1.0)
	assert_false(body.call("looks_hungry"))
	assert_ne(int(face.mood), PonyFace.Mood.SAD, "fed, she cheers up")
	assert_false(body.call("hunger_bubble_shown"), "and the bubble goes")
