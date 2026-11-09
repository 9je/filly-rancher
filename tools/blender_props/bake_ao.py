"""BAKED AMBIENT OCCLUSION FOR THE PROPS AND BUILDINGS (P8; docs/aaa-review-2026-11-08.md 2.1:
"bake AO into vertex colour in Blender for the buildings and props (one Cycles bake per glb,
multiply in the shader)"). SSAO is off since the lighting reset, so creases, eaves and the
foot of every wall lost their contact shade; this puts it back as data, stable and free at run
time, the way Slime Rancher and Animal Crossing carry it.

A TEXTURE, NOT VERTEX COLOUR. The first cut baked into COLOR_0 and changed nothing on screen:
these models are low-poly, a wall is four corners, and the shade under an eave has no vertex
to land on. So every mesh gets a second UV map (smart-projected, packed together, exported as
TEXCOORD_1 = Godot's UV2), Cycles bakes AO into one image per model, and the image is saved
beside the .glb as <name>_ao.png. ToonStyler finds it by name and the toon shader multiplies
it in (ao_texture, ao_strength).

A GROUND PLANE OCCLUDES. A temporary plane under the model, in the scene but not baked, gives
the foot of every wall and post its contact shade on the grass, the one thing SSAO did best.

  blender -b -P tools/blender_props/bake_ao.py -- in.glb out.glb [samples] [size]
"""
import os
import sys

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
src, dst = argv[0], argv[1]
samples = int(argv[2]) if len(argv) > 2 else 48
size = int(argv[3]) if len(argv) > 3 else 0
png = os.path.splitext(dst)[0] + "_ao.png"

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
scene = bpy.context.scene
meshes = [o for o in scene.objects if o.type == "MESH" and len(o.data.polygons) > 0]

# The model's extent sets the AO reach: an eave on a house, a slat on a crate.
lo = Vector((1e9, 1e9, 1e9))
hi = Vector((-1e9, -1e9, -1e9))
for ob in meshes:
    for c in ob.bound_box:
        w = ob.matrix_world @ Vector(c)
        lo = Vector((min(lo.x, w.x), min(lo.y, w.y), min(lo.z, w.z)))
        hi = Vector((max(hi.x, w.x), max(hi.y, w.y), max(hi.z, w.z)))
extent = max(hi.x - lo.x, hi.y - lo.y, hi.z - lo.z, 0.1)
# A house earns 1024 texels a side, a crate 256 (0 = choose).
if size <= 0:
    size = 1024 if extent > 6.0 else 512 if extent > 2.0 else 256

scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = samples
# Ubuntu's Blender is built without OpenImageDenoiser, and Cycles asks for it by default: every
# bake then fails silently and leaves the image black.
scene.cycles.use_denoising = False
scene.render.bake.margin = 6
if scene.world is None:
    scene.world = bpy.data.worlds.new("bake")
scene.world.light_settings.distance = max(0.3, extent * 0.09)

# The ground: twice the footprint, a hair under the lowest point.
bpy.ops.mesh.primitive_plane_add(size=1.0, location=((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z - 0.005))
ground = bpy.context.active_object
ground.scale = ((hi.x - lo.x) * 2.0 + 1.0, (hi.y - lo.y) * 2.0 + 1.0, 1.0)

# One UV map named AO on every mesh, laid out together so they share one image.
for ob in meshes:
    me = ob.data
    for name in list(me.color_attributes.keys()):
        me.color_attributes.remove(me.color_attributes[name])
    while len(me.uv_layers) > 1:
        me.uv_layers.remove(me.uv_layers[-1])
    me.uv_layers.new(name="AO")
    me.uv_layers.active = me.uv_layers["AO"]
bpy.ops.object.select_all(action="DESELECT")
for ob in meshes:
    ob.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.004, area_weight=0.0, scale_to_bounds=False)
bpy.ops.uv.pack_islands(margin=0.004)
bpy.ops.object.mode_set(mode="OBJECT")

image = bpy.data.images.new("AO", size, size, alpha=False)
image.generated_color = (1, 1, 1, 1)
added = []
for ob in meshes:
    if len(ob.material_slots) == 0:
        mat = bpy.data.materials.new("ao_bake")
        mat.use_nodes = True
        ob.data.materials.append(mat)
    for slot in ob.material_slots:
        mat = slot.material
        if mat is None:
            continue
        mat.use_nodes = True
        nodes = mat.node_tree.nodes
        if any(n.get("ao_bake") for n in nodes):
            continue
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = image
        tex["ao_bake"] = True
        nodes.active = tex
        added.append((mat, tex))

scene.render.bake.use_selected_to_active = False
bpy.ops.object.select_all(action="DESELECT")
for ob in meshes:
    ob.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
bpy.ops.object.bake(type="AO", target="IMAGE_TEXTURES", uv_layer="AO", margin=6)

image.filepath_raw = png
image.file_format = "PNG"
image.save()

# Leave the model as it came, plus its AO map: the bake nodes and the ground go.
for mat, tex in added:
    mat.node_tree.nodes.remove(tex)
bpy.data.objects.remove(ground, do_unlink=True)
for ob in meshes:
    ob.data.uv_layers.active = ob.data.uv_layers[0]
    ob.data.uv_layers[0].active_render = True

bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", export_colors=False,
                          export_image_format="AUTO")
print("BAKE_AO_OK %s meshes=%d extent=%.2f size=%d png=%s" % (dst, len(meshes), extent, size, png))
