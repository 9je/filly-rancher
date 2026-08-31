extends Node3D
## Loads every pony .glb, spaces them on a line, verifies meshes+skeletons arrived.

## This scene globs the directory rather than naming characters, so it loads the .glb
## itself instead of going through PonyRig.spawn(); it still attaches the hair
## simulation, which is what makes the gallery show what the ponies actually look like
## in game rather than with their manes welded to their skulls.
const PonyRigScript := preload("res://scripts/pony_rig.gd")
const GateWatchdogScript := preload("res://scripts/gate_watchdog.gd")
const StockPaletteScript := preload("res://systems/stock_palette.gd")
const StockTintScript := preload("res://systems/stock_tint.gd")
const PonyRegistryScript := preload("res://systems/pony_registry.gd")
const PonyVisualsScript := preload("res://actors/pony/pony_visuals.gd")
const CutieMarkScript := preload("res://systems/cutie_mark.gd")
const MarkStampsScript := preload("res://systems/mark_stamps.gd")
const MarkPaintScript := preload("res://systems/mark_paint.gd")

const PONY_DIR := "res://assets/converted/ponies/"

func _ready() -> void:
    if "--stock" in OS.get_cmdline_user_args():
        _build_stock_row()
        return
    if "--mark" in OS.get_cmdline_user_args():
        _build_mark_row()
        return
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


## Eight recoloured copies of the base model, for a person to look at. The one thing no
## assertion in this project can answer: whether the crowd looks like ponies or like
## paint chips.
func _build_stock_row() -> void:
    var palette: StockPalette = StockPaletteScript.load_stock()
    var registry := PonyRegistryScript.new()
    registry.load_all("res://data/ponies")
    var data: PonyData = registry.by_id(StockPaletteScript.IDS[0])
    var rng := RandomNumberGenerator.new()
    rng.seed = 20260830
    var built := 0
    for i in 8:
        var look: Dictionary = palette.draw_look(rng)
        var body: Node3D = PonyVisualsScript.build(data,
            StockPaletteScript.mane_style_path(int(look["mane_style"])))
        if body == null:
            continue
        StockTintScript.apply(body, palette, look)
        body.position = Vector3(built * 3.0, 0.0, 0.0)
        body.rotate_y(PI)
        add_child(body)
        if built == 0:
            # CutieMark.apply() reads the model's global_transform, so it has to run after
            # add_child(), not before: a node outside the tree has no global transform.
            CutieMarkScript.apply(body, MarkStampsScript.build(
                MarkStampsScript.Stamp.STAR, Color(0.95, 0.80, 0.25)))
        print("STOCK ", look)
        built += 1
    print("GALLERY_OK count=", built)
    if DisplayServer.get_name() == "headless":
        get_tree().quit(0 if built == 8 else 1)


## THREE COPIES OF THE BASE MODEL WEARING THE ORIENTATION PROBE, turned to show the left
## flank, the front and the right flank. The one question no assertion in this project can
## answer: whether the F on her side reads as an F to a person looking at her.
##
## WHAT TO LOOK FOR, and it is the whole point of this mode:
##   * the F is the right way up on BOTH flanks (its long arm at the TOP, not the bottom);
##   * the F is not back to front on either flank (its spine on the LEFT as you look at it);
##   * the two flanks read the SAME, because the right flank repeats the drawing rather
##     than mirroring it (see game/systems/cutie_mark.gd's own note on that decision).
## A half turned F, which is what a flip plus a mirror produces, is the 2026-08-31 bug.
func _build_mark_row() -> void:
    var registry := PonyRegistryScript.new()
    registry.load_all("res://data/ponies")
    var data: PonyData = registry.by_id(StockPaletteScript.IDS[0])
    var probe: Image = MarkPaintScript.orientation_probe()
    var built := 0
    for turn in [PI * 0.5, PI, PI * 1.5]:
        var body: Node3D = PonyVisualsScript.build(data)
        if body == null:
            continue
        body.position = Vector3(built * 3.0, 0.0, 0.0)
        body.rotate_y(turn)
        add_child(body)
        # apply() reads the model's global_transform, so it has to run after add_child().
        CutieMarkScript.apply(body, probe)
        built += 1
    print("GALLERY MARK: left flank, front, right flank. The F must read as an F on both flanks.")
    print("GALLERY_MARK_OK count=", built)
    if DisplayServer.get_name() == "headless":
        get_tree().quit(0 if built == 3 else 1)
