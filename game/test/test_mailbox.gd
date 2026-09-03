extends GutTest
## The Company's mailbox: a post, a box and a flag that goes up when something is waiting.
## It is a child of $Buildings so it rides the same build-and-seat loop the six buildings
## do, but it is NOT a Building: game/world/building.gd would push_error on a doorway this
## small, and a mailbox has no doorway at all.

const MailboxScript := preload("res://world/mailbox.gd")
const LayersScript := preload("res://world/collision_layers.gd")


func _built() -> Mailbox:
	var box: Mailbox = MailboxScript.new()
	add_child_autofree(box)
	box.build()
	return box


func test_it_builds_a_post_a_box_and_a_flag() -> void:
	var box: Mailbox = _built()
	assert_not_null(box.get_node_or_null("Post"))
	assert_not_null(box.get_node_or_null("Box"))
	assert_not_null(box.get_node_or_null("Flag"))


func test_building_twice_does_not_build_it_twice() -> void:
	var box: Mailbox = _built()
	var before: int = box.get_child_count()
	box.build()
	assert_eq(box.get_child_count(), before, "build() is idempotent, like Building.build()")


func test_it_is_solid_and_on_the_props_layer_like_every_other_prop() -> void:
	var box: Mailbox = _built()
	assert_gt(box.find_children("*", "CollisionShape3D", true, false).size(), 0,
		"the gate fails a prop with no collision shape")
	assert_eq(box.collision_layer, LayersScript.PROPS)
	assert_eq(box.collision_mask, 0)


func test_it_stands_high_enough_to_see_and_low_enough_to_be_a_mailbox() -> void:
	var box: Mailbox = _built()
	assert_gt(MailboxScript.POST_HEIGHT, 0.8, "a mailbox on the floor is not readable")
	assert_lt(MailboxScript.POST_HEIGHT, 1.6, "a mailbox is not a signpost")


func test_the_flag_starts_down_and_goes_up_when_something_is_waiting() -> void:
	var box: Mailbox = _built()
	assert_false(box.is_flag_up())
	box.set_flag_up(true)
	assert_true(box.is_flag_up())
	var flag := box.get_node("Flag") as Node3D
	assert_almost_eq(flag.rotation_degrees.z, MailboxScript.FLAG_UP_DEGREES, 0.01)
	box.set_flag_up(false)
	assert_false(box.is_flag_up())
	assert_almost_eq(flag.rotation_degrees.z, 0.0, 0.01)


func test_the_flag_is_a_mesh_and_never_a_label() -> void:
	var source: String = FileAccess.get_file_as_string("res://world/mailbox.gd")
	assert_false(source.contains("Label3D"), "no floating text anywhere in the world")


func test_no_line_of_it_carries_a_dash() -> void:
	var source: String = FileAccess.get_file_as_string("res://world/mailbox.gd")
	for line in source.split("\n"):
		var text: String = String(line)
		if text.begins_with("# ---") or text.begins_with("## ---"):
			continue
		assert_false(text.contains("--"), "double hyphen: %s" % text)
		assert_false(text.contains(char(0x2014)), "em dash: %s" % text)
