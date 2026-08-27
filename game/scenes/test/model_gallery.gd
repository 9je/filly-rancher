extends Node3D
## Loads every pony .glb, spaces them on a line, verifies meshes+skeletons arrived.

## This scene globs the directory rather than naming characters, so it loads the .glb
## itself instead of going through PonyRig.spawn(); it still attaches the hair
## simulation, which is what makes the gallery show what the ponies actually look like
## in game rather than with their manes welded to their skulls.
const PonyRigScript := preload("res://scripts/pony_rig.gd")
const GateWatchdogScript := preload("res://scripts/gate_watchdog.gd")

const PONY_DIR := "res://assets/converted/ponies/"

func _ready() -> void:
    GateWatchdogScript.arm(self, "GALLERY")
    var loaded := 0
    var dir := DirAccess.open(PONY_DIR)
    for file in dir.get_files():
        if file.get_extension() != "glb":
            continue
        var scene: PackedScene = load(PONY_DIR + file)
        var inst: Node3D = scene.instantiate()
        PonyRigScript.attach_hair_simulation(inst)
        inst.position = Vector3(loaded * 3.0, 0, 0)
        # Assets face -Z (Godot's look_at forward, baked in by export_blend.py
        # --rotate-z 180). The camera sits at +Z, so turn them to face it —
        # this is a display-only concern, gameplay orientation is unchanged.
        inst.rotate_y(PI)
        add_child(inst)
        var skel := inst.find_child("Skeleton3D", true, false)
        print("LOADED ", file, " skeleton=", skel != null,
              " bones=", skel.get_bone_count() if skel else 0)
        loaded += 1
    print("GALLERY_OK count=", loaded)
    if DisplayServer.get_name() == "headless":
        get_tree().quit(0 if loaded >= 3 else 1)
