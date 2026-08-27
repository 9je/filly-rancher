extends Node

const GateWatchdogScript := preload("res://scripts/gate_watchdog.gd")

func _ready() -> void:
    GateWatchdogScript.arm(self, "SMOKE")
    print("SMOKE_OK renderer=", RenderingServer.get_current_rendering_method())
    get_tree().quit(0)
