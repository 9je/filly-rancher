extends GutTest
## The exit hang's fix (systems/babble.gd, "THE EXIT HANG"): a Babble's generator must
## outlive its node, because Godot's generator playback reads it through a raw pointer on the
## fade-out mix after the player stops.

const BabbleScript := preload("res://systems/babble.gd")


func test_a_freed_babble_leaves_its_generator_alive() -> void:
	var b: Node = BabbleScript.new()
	add_child(b)
	b.call("say", "Hello there!")
	await wait_frames(2)
	var player: AudioStreamPlayer = null
	for c in b.get_children():
		if c is AudioStreamPlayer:
			player = c
	assert_not_null(player, "the Babble plays through a child AudioStreamPlayer")
	var gen_id := player.stream.get_instance_id()
	b.free()
	assert_not_null(instance_from_id(gen_id),
		"its AudioStreamGenerator is buried, not freed, when the node goes")


func test_buried_generators_are_released_after_a_while() -> void:
	var first: Node = BabbleScript.new()
	add_child(first)
	await wait_frames(1)
	var first_id: int = (first.get_child(0) as AudioStreamPlayer).stream.get_instance_id()
	first.free()
	await wait_seconds(BabbleScript.BURY_SECONDS + 0.3)
	# The next burial sweeps anything older than BURY_SECONDS.
	var second: Node = BabbleScript.new()
	add_child(second)
	await wait_frames(1)
	second.free()
	assert_null(instance_from_id(first_id), "an old enough grave is let go")
