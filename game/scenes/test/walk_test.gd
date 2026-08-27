extends Node3D
## Twilight walks a square path using her 'walk' animation.

## Ground speed matched to the 'walk' clip so her hooves stay planted instead of
## skating. The derivation (stride / stance-duration, where the divisor is the stance
## HALF of the cycle and not the whole cycle) used to be copy-pasted here from
## tools/author_anims.py, four separate constants deep; it now lives once in
## game/systems/gait.gd, which is also where the same numbers for the `gallop` clip and
## the playback-scaling rules live. Compare Gait.WALK_CLIP_SPEED against the
## WALK_IMPLIED_SPEED line every export prints before trusting either.
##
## This scene deliberately still plays `walk` at 1.0x and travels at exactly the clip's
## own speed: it is the reference for what zero foot skate looks like, so it must not
## go through Gait.clip_for_speed() (which would pick a clip) or the playback scaler.
##
## Spawn through PonyRig, not `load(...).instantiate()`: that is what attaches the
## mane/tail SpringBoneSimulator3D, and this scene is where the missing follow-through
## was first noticed ("hair bobbing out of sync with the pony"). See
## scripts/pony_rig.gd and docs/notes-hair-sim.md.
const PonyRigScript := preload("res://scripts/pony_rig.gd")
const GaitScript := preload("res://systems/gait.gd")
const GateWatchdogScript := preload("res://scripts/gate_watchdog.gd")

const WALK_SPEED := GaitScript.WALK_CLIP_SPEED  # 0.66 m/s

## Everything below is metres, like everything else in the project (1 unit = 1 metre,
## docs/pipeline.md section 3). The square path and the arrival radius are half what
## they were before the ponies were normalised to metric scale, for the same reason
## the clip's stride is: the pony now covers half the ground per second, and this scene's
## gate (WALK_OK at frame 300, i.e. 5 s) budgets no extra time. At 0.66 m/s she needs
## ~4.1 s to reach the first waypoint, which leaves a ~0.9 s margin; a full-size path
## would leave her still walking toward waypoint 1 when the gate fires.
const ARRIVAL_RADIUS := 0.1

var pony: Node3D
var waypoints := [Vector3(2,0,2), Vector3(2,0,-2), Vector3(-2,0,-2), Vector3(-2,0,2)]
var target_idx := 0
var frames := 0

func _ready() -> void:
    GateWatchdogScript.arm(self, "WALK", 60.0)
    pony = PonyRigScript.spawn("twilight")
    add_child(pony)
    var anim: AnimationPlayer = pony.find_child("AnimationPlayer", true, false)
    assert(anim != null, "no AnimationPlayer in glb")
    print("ANIMS ", anim.get_animation_list())
    anim.play("walk")

func _physics_process(delta: float) -> void:
    var target: Vector3 = waypoints[target_idx]
    var to_target := target - pony.position
    if to_target.length() < ARRIVAL_RADIUS:
        target_idx = (target_idx + 1) % waypoints.size()
    else:
        pony.position += to_target.normalized() * WALK_SPEED * delta
        pony.look_at(target, Vector3.UP)
    frames += 1
    if frames == 300 and DisplayServer.get_name() == "headless":
        print("WALK_OK laps_progress=", target_idx)
        get_tree().quit(0 if target_idx >= 1 else 1)
