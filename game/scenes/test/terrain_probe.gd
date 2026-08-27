extends Node3D
## Task 8 map-props probe: scatters every converted Kenney prop across a grass
## ground plane in a rough village layout, drops Twilight in at the center for a
## scale reference (res://assets/converted/ponies/twilight.glb), prints per-prop
## world-space heights plus PROBE_OK count=N, and quits under headless.
##
## Mirrors model_gallery.gd's directory-scan load pattern, but pairs each
## discovered file with a hardcoded position instead of a single line of ponies.

const PROP_DIR := "res://assets/converted/props/"
const PONY_PATH := "res://assets/converted/ponies/twilight.glb"

## Hardcoded scatter: buildings cluster near the center like a small plaza,
## trees ring the outside -- the brief's "does it read as a place in Ponyville"
## layout. Any .glb present in PROP_DIR but not listed here still loads (so the
## probe never silently drops a file) and falls back to a simple side row.
const LAYOUT := {
    "kenney_windmill.glb": Vector3(-7, 0, -3),
    "kenney_watermill.glb": Vector3(7, 0, -4),
    "kenney_market_stall.glb": Vector3(0, 0, -9),
    "kenney_survival_structure.glb": Vector3(-4, 0, 6),
    "kenney_tree_oak.glb": Vector3(-15, 0, -11),
    "kenney_tree_pine.glb": Vector3(15, 0, -13),
    "kenney_tree_default.glb": Vector3(-17, 0, 9),
    "kenney_tree_fat.glb": Vector3(17, 0, 10),
}

## Uniform scale applied to every prop instance (never the pony). Default 1.0
## renders props at native, as-authored scale -- deliberately NOT auto-corrected,
## so the probe honestly shows the Kenney-vs-pony scale mismatch documented in
## the Task 8 report. Override for a "what if" render: `-- --prop-scale=2.6`.
var prop_scale := 1.0

func _ready() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--prop-scale="):
            prop_scale = arg.split("=")[1].to_float()

    var loaded := 0
    var fallback_idx := 0
    var dir := DirAccess.open(PROP_DIR)
    for file in dir.get_files():
        if file.get_extension() != "glb":
            continue
        var scene: PackedScene = load(PROP_DIR + file)
        var inst := scene.instantiate()
        var pos: Vector3 = LAYOUT.get(file, Vector3())
        if not LAYOUT.has(file):
            pos = Vector3(fallback_idx * 4.0 - 20.0, 0, 16)
            fallback_idx += 1
        inst.position = pos
        inst.scale = Vector3.ONE * prop_scale
        add_child(inst)
        var height := _world_aabb(inst).size.y
        print("LOADED ", file, " pos=", pos, " native_height=", height)
        loaded += 1

    # Twilight, for scale reference (Phase-1 decision point: see task-8 report).
    # Loaded directly rather than through PonyRig.spawn(), which docs/pipeline.md section
    # 6 otherwise requires: this scene only measures a bounding box, and the mane/tail
    # spring simulation would make that box depend on which physics tick it is sampled
    # on. A deliberate exemption, not the pattern to copy -- anything that puts a pony on
    # screen must use PonyRig.spawn() or scenes/characters/pony.tscn, or it renders with
    # its hair welded to its skull.
    var pony_scene: PackedScene = load(PONY_PATH)
    var pony := pony_scene.instantiate()
    pony.position = Vector3(0, 0, 0)
    add_child(pony)
    print("PONY twilight height=", _world_aabb(pony).size.y)

    print("PROBE_OK count=", loaded)

    if DisplayServer.get_name() == "headless":
        get_tree().quit(0 if loaded >= 3 else 1)
        return

    # Windowed/offscreen (e.g. under xvfb-run): capture one frame for evidence,
    # then quit, when explicitly asked -- keeps this drivable non-interactively.
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--screenshot="):
            var out_path: String = arg.split("=")[1]
            await get_tree().process_frame
            await get_tree().process_frame
            var img := get_viewport().get_texture().get_image()
            img.save_png(out_path)
            print("SCREENSHOT_SAVED ", out_path)
            get_tree().quit(0)

## True world-space AABB of every MeshInstance3D under root (root included),
## computed from each mesh's local AABB corners transformed to global space.
## Handles both "GLB root is the MeshInstance3D" and "GLB root is a Node3D
## wrapping one" import shapes without assuming which one a given prop uses.
func _world_aabb(root: Node3D) -> AABB:
    var meshes: Array = root.find_children("*", "MeshInstance3D", true, false)
    if root is MeshInstance3D:
        meshes.append(root)
    var result := AABB()
    var first := true
    for m in meshes:
        var local_aabb: AABB = m.get_aabb()
        var xform: Transform3D = m.global_transform
        for i in range(8):
            var world_corner: Vector3 = xform * local_aabb.get_endpoint(i)
            if first:
                result = AABB(world_corner, Vector3.ZERO)
                first = false
            else:
                result = result.expand(world_corner)
    return result
