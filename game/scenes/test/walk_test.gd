extends Node3D
## Twilight walks a square path using her 'walk' animation.

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
        pony.position += to_target.normalized() * 2.0 * delta
        pony.look_at(target, Vector3.UP)
    frames += 1
    if frames == 300 and DisplayServer.get_name() == "headless":
        print("WALK_OK laps_progress=", target_idx)
        get_tree().quit(0 if target_idx >= 1 else 1)
