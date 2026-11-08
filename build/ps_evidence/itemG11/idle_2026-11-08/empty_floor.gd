extends SceneTree
## The invisible display's presentation floor: one box, one light, one camera, vsync off,
## drawn the way scenes/test/perf.gd draws (same xvfb, same window), frame times measured
## for 15 s after a 3 s warm-up. Prints EMPTY avg_ms p99_ms worst_1s_fps.
var _t := 0.0
var _times: Array[float] = []

func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var root3 := Node3D.new()
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.5, 4)
	root3.add_child(cam)
	var box := MeshInstance3D.new()
	box.mesh = BoxMesh.new()
	root3.add_child(box)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	root3.add_child(sun)
	root.add_child(root3)
	cam.look_at(Vector3.ZERO)

func _process(delta: float) -> bool:
	_t += delta
	if _t > 3.0:
		_times.append(delta * 1000.0)
	if _t > 18.0:
		var s := _times.duplicate()
		s.sort()
		var sum := 0.0
		for x in s:
			sum += x
		var worst := INF
		var acc := 0.0
		var n := 0
		for x in _times:
			acc += x
			n += 1
			if acc >= 1000.0:
				worst = minf(worst, n * 1000.0 / acc)
				acc = 0.0
				n = 0
		print("EMPTY frames=%d avg_ms=%.2f p99_ms=%.2f max_ms=%.1f worst_1s_fps=%d" % [s.size(), sum / s.size(), s[int(s.size() * 0.99)], s[-1], int(worst)])
		return true
	return false
