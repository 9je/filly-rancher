"""Render a contact sheet of a pony .glb's animation clips, for judging poses by eye.

    tools/bin/blender/blender -b -P tools/anim_sheet.py -- --glb X.glb --out DIR \
        [--clips a,b,c] [--frames 5] [--size 240]

Each clip is sampled at --frames evenly spaced frames and rendered from the pony's left
side (Cycles on the CPU, so it runs headless with no GPU). Frames are written as
DIR/<clip>_<n>.png; tools/anim_sheet_tile.py tiles them. The camera frames the rest pose,
so a pose that leaves the frame (a rear, a jump) shows it.
"""
import argparse
import math
import os
import sys

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
p = argparse.ArgumentParser()
p.add_argument("--glb", required=True)
p.add_argument("--out", required=True)
p.add_argument("--clips", default="")
p.add_argument("--frames", type=int, default=5)
p.add_argument("--size", type=int, default=240)
p.add_argument("--view", default="side", choices=["side", "front", "three"])
args = p.parse_args(argv)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=args.glb)
arm = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")

scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = 12
scene.cycles.use_denoising = False
scene.render.resolution_x = args.size
scene.render.resolution_y = args.size
scene.render.film_transparent = False
world = bpy.data.worlds.new("w")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.75, 0.82, 0.9, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 0.9
scene.world = world

# Ground plane for contact reading.
bpy.ops.mesh.primitive_plane_add(size=6, location=(0, 0, 0))
ground = bpy.context.active_object
gm = bpy.data.materials.new("ground")
gm.diffuse_color = (0.45, 0.6, 0.35, 1)
ground.data.materials.append(gm)

sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
sun.data.energy = 3.5
sun.rotation_euler = (math.radians(50), 0, math.radians(30))
scene.collection.objects.link(sun)

# Frame the rest pose's bounding box.
mins = Vector((1e9, 1e9, 1e9))
maxs = Vector((-1e9, -1e9, -1e9))
for o in scene.objects:
    if o.type == "MESH" and o is not ground:
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            mins = Vector(map(min, mins, w))
            maxs = Vector(map(max, maxs, w))
center = (mins + maxs) / 2
size = max((maxs - mins).length, 0.5)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
cam.data.type = "ORTHO"
cam.data.ortho_scale = size * 0.75
scene.collection.objects.link(cam)
scene.camera = cam
# Godot's import faces the model +Z; Blender's glTF import maps that to -Y. Side view
# looks along X.
if args.view == "side":
    cam.location = center + Vector((size * 3, 0, size * 0.15))
elif args.view == "front":
    cam.location = center + Vector((0, -size * 3, size * 0.15))
else:
    cam.location = center + Vector((size * 2.2, -size * 2.2, size * 0.8))
direction = center + Vector((0, 0, size * 0.05)) - cam.location
cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()

os.makedirs(args.out, exist_ok=True)
wanted = [c for c in args.clips.split(",") if c]
actions = [a for a in bpy.data.actions if not wanted or any(a.name.startswith(w) for w in wanted)]
if arm.animation_data is None:
    arm.animation_data_create()
for action in sorted(actions, key=lambda a: a.name):
    arm.animation_data.action = action
    start, end = action.frame_range
    name = action.name.split("|")[-1] if "|" in action.name else action.name
    n = max(1, args.frames)
    for i in range(n):
        f = start + (end - start) * (i / max(1, n - 1))
        scene.frame_set(int(round(f)))
        scene.render.filepath = os.path.join(args.out, f"{name}_{i}.png")
        bpy.ops.render.render(write_still=True)
    print("SHEET_CLIP", name, start, end)
print("SHEET_OK")
