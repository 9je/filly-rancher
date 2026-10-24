extends Node
## perf.gd exp=steptime: stamps the end of the scripts' physics tick (process_physics_priority
## last) and the start of the next idle frame (process_priority first). Between them runs the
## physics server's own step; the scripts run between physics_frame and `last_phys`.
var phase := 0
var t_start := 0
var t_last := 0
var scripts_us := 0
var step_us := 0
var ticks := 0
var frames_with_tick := 0
var _ticked := false


func _physics_process(_d: float) -> void:
	if phase >= 1:
		t_last = Time.get_ticks_usec()
		scripts_us += t_last - t_start
		ticks += 1
		_ticked = true


func _process(_d: float) -> void:
	if phase == 2 and _ticked:
		step_us += Time.get_ticks_usec() - t_last
		frames_with_tick += 1
	_ticked = false
