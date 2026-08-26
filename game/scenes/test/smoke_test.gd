extends Node

func _ready() -> void:
    print("SMOKE_OK renderer=", RenderingServer.get_current_rendering_method())
    get_tree().quit(0)
