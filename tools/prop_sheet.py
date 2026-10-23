"""Render a labelled contact sheet of static .glb props (three-quarter view, Cycles CPU).

    tools/bin/blender/blender -b -P tools/prop_sheet.py -- --out SHEET.png A.glb B.glb ...
"""
import math
import os
import sys

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
out = argv[argv.index("--out") + 1]
files = [a for a in argv if a.endswith(".glb")]
size = 300
tmp = os.path.join(os.path.dirname(out), "_prop_frames")
os.makedirs(tmp, exist_ok=True)
frames = []
for f in files:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=f)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 10
    sc.render.resolution_x = sc.render.resolution_y = size
    w = bpy.data.worlds.new("w")
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.8, 0.86, 0.92, 1)
    sc.world = w
    mins = Vector((1e9,) * 3)
    maxs = Vector((-1e9,) * 3)
    for o in sc.objects:
        if o.type == "MESH":
            for c in o.bound_box:
                p = o.matrix_world @ Vector(c)
                mins = Vector(map(min, mins, p))
                maxs = Vector(map(max, maxs, p))
    center = (mins + maxs) / 2
    ext = max((maxs - mins).length, 0.2)
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.0
    sun.rotation_euler = (math.radians(45), 0, math.radians(35))
    sc.collection.objects.link(sun)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = ext * 1.05
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.location = center + Vector((ext * 1.6, -ext * 1.6, ext * 1.1))
    cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()
    path = os.path.join(tmp, os.path.basename(f) + ".png")
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    frames.append((os.path.basename(f)[:-4], path))
print("PROP_FRAMES", len(frames))
with open(os.path.join(tmp, "list.txt"), "w") as fh:
    for name, p in frames:
        fh.write("%s\t%s\n" % (name, p))
