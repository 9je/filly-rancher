"""Author `idle` + `walk` Actions onto a CreatorOfPony-family pony rig, headlessly.

Imported by `tools/export_blend.py --anims`; also runnable standalone for debugging:

    tools/bin/blender/blender -b <file>.blend -P tools/author_anims.py -- --object TS_Rig

WHY THIS EXISTS (see task-7-report.md): none of the five CreatorOfPony packs ship a
single character Action (`bpy.data.actions` holds only `CameraAxisAction`, a camera
orbit helper), and no community Action library for this rig family survives on a
loginless, curl-reachable host. So the walk/idle clips are authored here, in script,
so they are reproducible and re-runnable against every pack rather than being a
hand-posed .blend nobody can regenerate.

WHY IK TARGETS AND NOT DEF_/FK_ BONES. On this rig every `DEF_*Leg*`/`DEF_*Hoof*`
bone carries two `COPY_TRANSFORMS` constraints -- from its `FK_` twin and then from
its `IK_` twin -- both at influence 1.0. Last constraint wins, so the rig is
permanently in IK mode and keyframing either the DEF_ bones or the FK_ chain is
silently discarded at evaluation time. The real handles are the four IK hoof targets
(`IK_FrontHoof.L/R`, `IK_RearHoof.L/R`), which are parented straight to `CON_Root`
rather than to their legs -- i.e. genuine world-space foot targets, which is exactly
what a quadruped gait wants. The glTF exporter's armature sampling then bakes the
resolved DEF_ bone transforms, so the IK solve is what ships.

BONE-LOCAL MATH. `pose_bone.location` is expressed along the bone's own rest axes,
not in armature space, and these hoof bones point straight down, so a naive
`location.z += lift` would shove the foot sideways. Every bone this script animates
is parented (directly or via `CON_Root`, which is left at rest) to an unanimated
parent, so a bone's armature-space offset is exactly `bone.matrix_local.to_3x3() @
location`; `_to_bone_space()` inverts that to turn an intended armature-space delta
into the pose value. Same trick for rotation axes.

ORIENTATION. The rig faces -Y in Blender (head at y=-1.05, rump at y=+0.97), which
`export_yup` turns into +Z in glTF. Godot's `look_at()` aims -Z at the target, so an
unrotated export moonwalks. `export_blend.py --rotate-z 180` is the fix; it lives
there rather than here because it is an export-orientation concern, not an animation
concern.
"""
import math

import bpy
from mathutils import Quaternion, Vector

# --- Canonical bone names. Verified (task-7 Step 1) to be present and identically
# named on all three tier-a rigs -- twilight/rainbowdash/fluttershy share a 93-bone
# core skeleton with a 100% intersection; only hair/mane/tail/wing chains diverge.
# So this same script authors the same clips on any pack in the family unchanged.
ROOT = "CON_Root"
BELLY = "CON_Belly"
HEAD = "DEF_Head"
# (bone name, gait phase offset). Diagonal pairs move together: front-left with
# rear-right, front-right with rear-left.
FEET = [
    ("IK_FrontHoof.L", 0.0),
    ("IK_RearHoof.R", 0.0),
    ("IK_FrontHoof.R", 0.5),
    ("IK_RearHoof.L", 0.5),
]
# Every clip keyframes every bone in this set, even the ones it holds still. A pose
# bone's basis is shared state: a clip that simply omits a channel does not reset it,
# it inherits whatever the previously-built clip left behind, both while authoring and
# in the exporter's per-Action bake. That is not hypothetical -- it is exactly how the
# idle first came out with the hooves frozen half a stride apart.
ANIMATED = [BELLY, HEAD] + [name for name, _ in FEET]

WALK_FRAMES = 20        # loop length; frame WALK_FRAMES+1 repeats frame 1
STRIDE = 0.30           # fore/aft hoof travel (front leg chain is ~1.066 long)
LIFT = 0.16             # swing-phase hoof clearance
BODY_BOB = 0.045        # vertical body oscillation, twice per gait cycle
BODY_PITCH = math.radians(2.5)

# --- The front IK chain is 0.457 + 0.609 = 1.066 long but its rest shoulder-to-hoof
# distance is 1.054, i.e. the rig stands with only 0.012 of bend left in the front
# legs. Swinging a hoof half a stride fore or aft needs sqrt(1.054^2 + 0.15^2) =
# 1.065, so the solver reaches full extension right at the stance extremes and the
# knee pops -- visible in the baked curve as DEF_FrontUpperLeg snapping back toward
# zero for a single frame at t=0.5. Dropping the body a few centimetres restores the
# bend margin (sqrt(0.994^2 + 0.15^2) = 1.005) and the pop disappears. Rear legs have
# 0.069 of slack already (they carry a hock) and never needed this.
BODY_CROUCH = 0.06

IDLE_FRAMES = 48        # 2 s at 24 fps
IDLE_BOB = 0.018
IDLE_CROUCH = 0.03      # same reason: keeps the idle bob's high point off full extension
IDLE_HEAD_NOD = math.radians(1.8)

FORWARD = Vector((0.0, -1.0, 0.0))   # rig faces -Y in Blender
UP = Vector((0.0, 0.0, 1.0))
SIDE = Vector((1.0, 0.0, 0.0))


def _require(arm, names):
    missing = [n for n in names if n not in arm.pose.bones]
    if missing:
        raise SystemExit(
            f"rig {arm.name!r} is not a CreatorOfPony-family rig: missing bones {missing}"
        )


def _to_bone_space(pbone, delta):
    """Armature-space vector -> the bone's local (rest-axis) space."""
    return pbone.bone.matrix_local.to_3x3().inverted() @ delta


def _set_offset(pbone, delta):
    pbone.location = _to_bone_space(pbone, delta)


def _set_rotation(pbone, axis, angle):
    local_axis = _to_bone_space(pbone, axis)
    if local_axis.length == 0.0:
        return
    pbone.rotation_quaternion = Quaternion(local_axis.normalized(), angle)


def _new_action(arm, name):
    """Fresh Action bound to `arm`, replacing any same-named leftover."""
    old = bpy.data.actions.get(name)
    if old is not None:
        bpy.data.actions.remove(old)
    action = bpy.data.actions.new(name)
    action.use_fake_user = True   # survive the exporter's orphan purge
    if arm.animation_data is None:
        arm.animation_data_create()
    arm.animation_data.action = action
    return action


def _rest(arm, names):
    for name in names:
        pbone = arm.pose.bones[name]
        pbone.location = (0.0, 0.0, 0.0)
        pbone.rotation_mode = "QUATERNION"
        pbone.rotation_quaternion = (1.0, 0.0, 0.0, 0.0)


def _foot_offset(phase_t):
    """Hoof offset (armature space) at normalised gait time `phase_t` in [0,1).

    First half is stance: hoof planted, travelling backwards under the body.
    Second half is swing: hoof lifts and carries forward again.
    """
    if phase_t < 0.5:
        u = phase_t / 0.5
        ahead = STRIDE * (0.5 - u)          # +half-stride -> -half-stride
        lift = 0.0
    else:
        u = (phase_t - 0.5) / 0.5
        ahead = STRIDE * (u - 0.5)          # -half-stride -> +half-stride
        # Raised-cosine rather than sin(pi*u): it leaves and re-meets the ground with
        # zero vertical velocity, so lift-off and touchdown don't put a corner in the
        # knee-bend curve the way a half-sine's non-zero end slope does.
        lift = LIFT * 0.5 * (1.0 - math.cos(2.0 * math.pi * u))
    return FORWARD * ahead + UP * lift


def build_walk(arm):
    """20-frame diagonal-pair walk loop driven through the IK hoof targets."""
    _require(arm, ANIMATED)
    _rest(arm, ANIMATED)
    action = _new_action(arm, "walk")

    for i in range(WALK_FRAMES + 1):        # inclusive: last frame repeats the first
        frame = i                           # start at 0: a clip starting at frame 1
                                            # exports a leading 1/fps hold that shows
                                            # up as a stutter once Godot loops it
        t = (i % WALK_FRAMES) / WALK_FRAMES

        for name, phase in FEET:
            pbone = arm.pose.bones[name]
            _set_offset(pbone, _foot_offset((t + phase) % 1.0))
            pbone.keyframe_insert("location", frame=frame, group=name)

        # Hold the head at rest explicitly -- see ANIMATED's note on why every clip
        # keys every bone any sibling clip touches.
        head = arm.pose.bones[HEAD]
        head.rotation_quaternion = (1.0, 0.0, 0.0, 0.0)
        head.keyframe_insert("rotation_quaternion", frame=frame, group=HEAD)

        # Two body bobs per gait cycle -- one per diagonal-pair footfall -- plus a
        # small pitch so she nods into the stride instead of gliding flat. The bob is
        # -cos so the body rides highest at mid-stance (hoof directly underneath) and
        # lowest at the stance/swing changeover, which is both what a real quadruped
        # does and what keeps the front chain furthest from full extension exactly
        # when the hoof is at its most fore/aft.
        belly = arm.pose.bones[BELLY]
        _set_offset(belly, UP * (-BODY_BOB * math.cos(4.0 * math.pi * t) - BODY_CROUCH))
        _set_rotation(belly, SIDE, BODY_PITCH * math.sin(2.0 * math.pi * t))
        belly.keyframe_insert("location", frame=frame, group=BELLY)
        belly.keyframe_insert("rotation_quaternion", frame=frame, group=BELLY)

    _rest(arm, ANIMATED)
    return action


def build_idle(arm):
    """Slow breathing sway: body rise/fall plus a barely-there head nod."""
    _require(arm, ANIMATED)
    _rest(arm, ANIMATED)
    action = _new_action(arm, "idle")

    # Six keys around the loop is enough for a sine this slow; Bezier interpolation
    # fills in the rest, and key 0 == key IDLE_FRAMES keeps the loop seamless.
    steps = 6
    for i in range(steps + 1):
        frame = round(i * IDLE_FRAMES / steps)
        t = (i % steps) / steps

        belly = arm.pose.bones[BELLY]
        _set_offset(belly, UP * (IDLE_BOB * math.sin(2.0 * math.pi * t) - IDLE_CROUCH))
        belly.keyframe_insert("location", frame=frame, group=BELLY)

        # DEF_Head is CHILD_OF CON_Root at influence 1.0 (the rig stabilises the head
        # against body motion), so it needs its own key to move at all.
        head = arm.pose.bones[HEAD]
        _set_rotation(head, SIDE, IDLE_HEAD_NOD * math.sin(2.0 * math.pi * t + math.pi / 3))
        head.keyframe_insert("rotation_quaternion", frame=frame, group=HEAD)

        # Plant all four hooves at their rest position for the whole clip. Without
        # these keys the idle inherits whatever the walk left in the IK targets and
        # Twilight "stands" frozen mid-stride, hooves splayed half a stride apart.
        for name, _phase in FEET:
            pbone = arm.pose.bones[name]
            pbone.location = (0.0, 0.0, 0.0)
            pbone.keyframe_insert("location", frame=frame, group=name)

    _rest(arm, ANIMATED)
    return action


def author(arm):
    """Create both clips. Returns them in export order."""
    if arm is None or arm.type != "ARMATURE":
        raise SystemExit(f"--anims needs an armature object, got {arm!r}")
    actions = [build_idle(arm), build_walk(arm)]
    # Leaving `walk` as the active action is deliberate: Blender's glTF exporter in
    # its default ACTIONS mode still needs a bound animation_data block on the object
    # to consider it animatable at all.
    print("ANIMS_AUTHORED", [a.name for a in actions])
    return actions


if __name__ == "__main__":
    import argparse
    import sys

    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--object", required=True, help="armature object to animate")
    args = p.parse_args(argv)
    author(bpy.data.objects.get(args.object))
