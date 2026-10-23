class_name PlayClock
extends Node
## THE PLAY CLOCK (GameState.play_seconds, the clock MISSION.md's pacing rules are written in).
## Runs through menus, talk and pauses, because those are play time too; added by whichever
## scene somebody is playing (the ranch, the Rainbow Factory) when it is interactive.

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	var gs := get_node_or_null("/root/GameState")
	if gs != null:
		gs.set("play_seconds", float(gs.get("play_seconds")) + delta)
