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
const PropsScript := preload("res://world/props.gd")

const PONY_DIR := "res://assets/converted/ponies/"

const PROP_DIR := "res://assets/converted/props/"

## Metres of clear grass between one prop and the next in the row.
const PROP_GAP := 1.5

## The floor on how many props must load before this gate calls itself a pass. Below the
## manifest's 45 on purpose: a machine mid conversion should not report green, and a
## machine with no packs at all should not be told it is broken in a way it can fix.
const PROP_FLOOR := 30

## The model MLP_SCALE is derived from. See Props.MLP_TARGET_BARN_RIDGE.
const SCALE_REFERENCE := "saa_barn.glb"

## The five id prefixes tools/prop_manifest.txt actually names. See _build_props_row()'s
## doc comment for why kenney_ files (present in the same directory) are not scanned.
## "neon_" is not among them: the Neon Lights Pack converted no usable mesh (see
## tools/prop_manifest.txt's own note), so nothing was ever going to begin with it.
const PROP_PREFIXES := ["saa_", "pv_", "mlp_", "school_", "lp_"]

func _ready() -> void:
    if "--stock" in OS.get_cmdline_user_args():
        _build_stock_row()
        return
    if "--mark" in OS.get_cmdline_user_args():
        _build_mark_row()
        return
    if "--props" in OS.get_cmdline_user_args():
        _build_props_row()
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


## THE PROPS ROW, and the one measurement the whole dressing slice hangs off.
##
## Every converted prop is loaded, stood in a line spaced by its own measured width, and
## reported with the size of its world AABB. Two things are proved here that no unit test
## can prove. First, that a .glb whose textures came out of a VTF tree still HAS its
## materials after tools/convert_props.sh downscaled them: a texture cap that silently
## dropped the image would leave a fully structured model that renders flat white, and
## validate_gltf.py --props only asks whether meshes exist. Second, how big these models
## actually are, which is where Props.MLP_SCALE comes from. Show scale is not Kenney
## scale, and guessing at it is how a barn ends up the size of a hay bale.
##
## SCOPED TO PROP_PREFIXES, NOT EVERY .glb IN THE DIRECTORY. kenney_*.glb files live in the
## same PROP_DIR but never went through tools/convert_props.sh; they use flat material
## colors instead of albedo textures by design (Kenney's Nature Kit, docs/pipeline.md
## section 4 quirk 6), and their placement/seating/collision is already proven by
## game/world/ranch.gd's own gate. Counting them here would fail this gate on a texture
## convention this pipeline never touched.
func _build_props_row() -> void:
    GateWatchdogScript.arm(self, "GALLERY")
    var camera := $PropCamera as Camera3D
    var loaded := 0
    var untextured: Array[String] = []
    var empty: Array[String] = []
    var cursor := 0.0
    var dir := DirAccess.open(PROP_DIR)
    if dir == null:
        print("GALLERY props: no ", PROP_DIR, " on this machine; run tools/convert_props.sh")
        print("GALLERY_OK count=0")
        if DisplayServer.get_name() == "headless":
            get_tree().quit(1)
        return
    # PackedStringArray, not Array: DirAccess.get_files() returns the packed kind, and
    # assigning it to a `var x: Array` is a hard type error rather than a conversion.
    # Sorted so the row, and therefore the printed report, is the same on every machine.
    var files := dir.get_files()
    files.sort()
    for file: String in files:
        if file.get_extension() != "glb":
            continue
        var known := false
        for prefix: String in PROP_PREFIXES:
            if file.begins_with(prefix):
                known = true
                break
        if not known:
            continue
        var scene: PackedScene = load(PROP_DIR + file)
        var inst: Node3D = scene.instantiate()
        add_child(inst)
        # Measured before it is moved: a translation cannot change a size, and the row
        # wants each model's own width to space it by.
        var box: AABB = PropsScript.world_aabb(inst)
        inst.position = Vector3(cursor + box.size.x * 0.5, 0.0, 0.0)
        cursor += box.size.x + PROP_GAP
        var meshes := 0
        var materials := 0
        var textured := 0
        for mesh: MeshInstance3D in _mesh_instances(inst):
            meshes += 1
            for i in range(mesh.get_surface_override_material_count()):
                var material: Material = mesh.get_active_material(i)
                if material == null:
                    continue
                materials += 1
                var pbr: BaseMaterial3D = material as BaseMaterial3D
                if pbr != null and pbr.albedo_texture != null:
                    textured += 1
        if box.size == Vector3.ZERO:
            empty.append(file)
        if textured == 0:
            untextured.append(file)
        print("PROP %-26s size=(%.3f, %.3f, %.3f) meshes=%d materials=%d textured=%d"
              % [file, box.size.x, box.size.y, box.size.z, meshes, materials, textured])
        if file == SCALE_REFERENCE and box.size.y > 0.001:
            print("PROP_SCALE model=%s native_height=%.3f target=%.2f mlp_scale=%.4f"
                  % [file, box.size.y, PropsScript.MLP_TARGET_BARN_RIDGE,
                     PropsScript.MLP_TARGET_BARN_RIDGE / box.size.y])
        loaded += 1
    camera.position = Vector3(cursor * 0.5, 9.0, 34.0)
    camera.look_at(Vector3(cursor * 0.5, 2.0, 0.0), Vector3.UP)
    camera.make_current()
    print("GALLERY props untextured=", untextured, " empty=", empty)
    print("GALLERY_OK count=", loaded)
    if DisplayServer.get_name() == "headless":
        get_tree().quit(0 if loaded >= PROP_FLOOR and untextured.is_empty() \
            and empty.is_empty() else 1)


## Every MeshInstance3D under `root`, root itself included when it is one. The same walk
## Props.world_aabb() does, kept local for the same reason props.gd keeps its own copy:
## this is a test scene and that is shipping world code.
func _mesh_instances(root: Node3D) -> Array[MeshInstance3D]:
    var result: Array[MeshInstance3D] = []
    if root is MeshInstance3D:
        result.append(root as MeshInstance3D)
    for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
        result.append(mesh)
    return result
