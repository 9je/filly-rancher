extends GutTest
## The Events bus (game/systems/events.gd): every signal it promises exists with the
## argument count its listeners rely on, and an emit reaches a connected listener. A fresh
## instance is used rather than the autoload, so a stray listener elsewhere cannot answer.

const EventsScript := preload("res://systems/events.gd")

const EXPECTED := {
	"delivered": 2, "bloomed": 2, "rescued": 1, "day_passed": 1, "flag_set": 2,
	"dread_changed": 1, "path_chosen": 1, "talk_started": 1, "talk_ended": 1,
	"area_entered": 1, "feel": 2, "heat_changed": 1, "ending_reached": 1,
}


func test_every_promised_signal_exists_with_its_arity() -> void:
	var bus: Node = autofree(EventsScript.new())
	var found := {}
	for sig: Dictionary in bus.get_signal_list():
		found[sig.name] = (sig.args as Array).size()
	for name: String in EXPECTED:
		assert_true(found.has(name), "Events lacks %s" % name)
		assert_eq(found.get(name, -1), EXPECTED[name], "%s arity" % name)


func test_an_emit_reaches_a_listener() -> void:
	var bus: Node = autofree(EventsScript.new())
	var got: Array = []
	bus.connect("delivered", func(uid: String, look: Dictionary) -> void: got.append([uid, look]))
	bus.emit_signal("delivered", "p1", {"coat": Color.RED})
	assert_eq(got.size(), 1)
	assert_eq(got[0][0], "p1")


func test_the_bus_is_registered_as_an_autoload() -> void:
	assert_not_null(get_tree().root.get_node_or_null("Events"),
		"Events must be an autoload so systems can reach it without wiring")
