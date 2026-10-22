extends GutTest
func test_probe_spawner_order() -> void:
	var data: PonyData = load("res://data/ponies/lyra.tres")
	var host := Node3D.new()
	add_child_autofree(host)
	for i in 3:
		var p: Node = (load("res://actors/pony/pony.tscn") as PackedScene).instantiate()
		host.add_child(p)
		p.set_stock(PonyGenerator.generate(100 + i).to_dict())
		p.setup(data)
	await wait_physics_frames(5)
	host.get_child(0).queue_free()
	await wait_physics_frames(3)
	assert_true(true)
