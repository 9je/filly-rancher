extends Node
## perf.gd exp=frametime: `first` (process_priority lowest) and `last` (highest) bracket the
## idle pass; from `last` to the next `first` is everything else the main thread does
## (physics ticks, the render sync, input, audio, deferred calls).
var role := 0
var other: Node = null
var stamp := 0
var proc_us := 0
var rest_us := 0
var frames := 0


func _process(_d: float) -> void:
	var now := Time.get_ticks_usec()
	if role == 0:
		if other != null and int(other.get("stamp")) > 0:
			rest_us += now - int(other.get("stamp"))
			frames += 1
		stamp = now
	else:
		if other != null:
			proc_us += now - int(other.get("stamp"))
		stamp = now
