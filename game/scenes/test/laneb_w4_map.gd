extends SceneTree
## P9 W4: print a map of the ranch (top-level nodes, buildings, signs, trees by family) so the
## view probes can stand at the places the owner photographed.
##   -s res://scenes/test/laneb_w4_map.gd
const Boot := preload("res://scenes/test/laneb_boot.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var ranch: Node = await Boot.boot(self)
	var player: Node3D = ranch.get("player")
	print("PLAYER ", player.global_position)
	for c in ranch.get_children():
		if c is Node3D:
			print("TOP ", c.name, " ", (c as Node3D).global_position, " kids=", c.get_child_count())
			if c.get_child_count() < 60:
				for k in c.get_children():
					if k is Node3D:
						print("   ", k.name, " ", (k as Node3D).global_position, " ", k.scene_file_path)
	print("MAP_OK")
	quit()
