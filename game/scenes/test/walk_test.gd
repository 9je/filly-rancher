extends Node3D
## Twilight walks a square path using her 'walk' animation.

## Ground speed matched to the 'walk' clip so her hooves stay planted instead of
## skating. A hoof is planted for half of the 20-frame @ 24 fps cycle and travels
## STRIDE backwards relative to the body during that stance, so the body has to
## cover STRIDE in half a cycle. Note the divisor is the stance half, not the whole
## cycle -- dividing by the full cycle understates the clip's speed by 2x.
## These constants must track tools/author_anims.py, which prints the same number as
## WALK_IMPLIED_SPEED on every export; compare them if you retune the clip.
## FOUR values are duplicated here with no automatic sync: STRIDE (0.55), WALK_FRAMES
## (20), STANCE_FRACTION (the 0.5 divisor) and -- the easiest one to miss -- the frame
## rate. 24 is hardcoded below, whereas author_anims.py reads it from
## bpy.context.scene.render.fps, i.e. from whatever the source .blend happens to be
## set to. A pack authored at any other fps silently desyncs this scene's WALK_SPEED
## while every structural gate still passes; the only symptom is foot skate. Compare
## against the WALK_IMPLIED_SPEED line the export prints before trusting this number.
const WALK_STRIDE := 0.55
const WALK_FRAMES := 20.0
const WALK_FPS := 24.0            # must match the source .blend's scene.render.fps
const WALK_CYCLE_SECONDS := WALK_FRAMES / WALK_FPS
const WALK_SPEED := WALK_STRIDE / (WALK_CYCLE_SECONDS * 0.5)  # 1.32 units/s

var pony: Node3D
var waypoints := [Vector3(4,0,4), Vector3(4,0,-4), Vector3(-4,0,-4), Vector3(-4,0,4)]
var target_idx := 0
var frames := 0

func _ready() -> void:
    pony = load("res://assets/converted/ponies/twilight.glb").instantiate()
    add_child(pony)
    var anim: AnimationPlayer = pony.find_child("AnimationPlayer", true, false)
    assert(anim != null, "no AnimationPlayer in glb")
    print("ANIMS ", anim.get_animation_list())
    anim.play("walk")

func _physics_process(delta: float) -> void:
    var target: Vector3 = waypoints[target_idx]
    var to_target := target - pony.position
    if to_target.length() < 0.2:
        target_idx = (target_idx + 1) % waypoints.size()
    else:
        pony.position += to_target.normalized() * WALK_SPEED * delta
        pony.look_at(target, Vector3.UP)
    frames += 1
    if frames == 300 and DisplayServer.get_name() == "headless":
        print("WALK_OK laps_progress=", target_idx)
        get_tree().quit(0 if target_idx >= 1 else 1)
