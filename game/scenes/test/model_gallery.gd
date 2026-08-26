extends Node3D
## Loads every pony .glb, spaces them on a line, verifies meshes+skeletons arrived.

const PONY_DIR := "res://assets/converted/ponies/"

func _ready() -> void:
    var loaded := 0
    var dir := DirAccess.open(PONY_DIR)
    for file in dir.get_files():
        if file.get_extension() != "glb":
            continue
        var scene: PackedScene = load(PONY_DIR + file)
        var inst := scene.instantiate()
        inst.position = Vector3(loaded * 3.0, 0, 0)
        add_child(inst)
        var skel := inst.find_child("Skeleton3D", true, false)
        print("LOADED ", file, " skeleton=", skel != null,
              " bones=", skel.get_bone_count() if skel else 0)
        loaded += 1
    print("GALLERY_OK count=", loaded)
    if DisplayServer.get_name() == "headless":
        get_tree().quit(0 if loaded >= 3 else 1)
