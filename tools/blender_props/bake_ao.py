"""BAKED AMBIENT OCCLUSION FOR THE PROPS AND BUILDINGS (P8; docs/aaa-review-2026-11-08.md 2.1:
"bake AO into vertex colour in Blender for the buildings and props (one Cycles bake per glb,
multiply in the shader)"). SSAO is off since the lighting reset, so creases, eaves and the
foot of every wall lost their contact shade; this puts it back as data, stable and free at run
time, the way Slime Rancher and Animal Crossing carry it.

For one converted .glb: import, give every mesh a byte colour attribute, bake Cycles AO into it
(occluders: the whole model, so a porch shades the wall under it), and export the .glb again
with COLOR_0. game/shaders/toon.gdshader multiplies by it (ao_strength); a mesh with no
COLOR_0 reads white there, so nothing else changes.

  blender -b -P tools/blender_props/bake_ao.py -- in.glb out.glb [samples]
"""
import sys

import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
src, dst = argv[0], argv[1]
samples = int(argv[2]) if len(argv) > 2 else 24

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)

scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = samples
scene.render.bake.target = "VERTEX_COLORS"
# The AO distance in metres: eaves and fence rails, not the whole valley.
bpy.context.scene.world = bpy.data.worlds.new("bake") if scene.world is None else scene.world
scene.world.light_settings.distance = 1.2

meshes = [o for o in scene.objects if o.type == "MESH"]
for ob in meshes:
    me = ob.data
    for name in list(me.color_attributes.keys()):
        me.color_attributes.remove(me.color_attributes[name])
    attr = me.color_attributes.new(name="AO", type="BYTE_COLOR", domain="CORNER")
    me.color_attributes.active_color = attr
    me.color_attributes.render_color_index = me.color_attributes.active_color_index

baked = 0
for ob in meshes:
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    try:
        bpy.ops.object.bake(type="AO")
        baked += 1
    except RuntimeError as e:
        print("BAKE_AO skip %s: %s" % (ob.name, e))

bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", export_colors=True,
                          export_image_format="AUTO")
print("BAKE_AO_OK %s meshes=%d baked=%d" % (dst, len(meshes), baked))
