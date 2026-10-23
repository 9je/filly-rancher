"""Model the game's original props in Blender and export each as .glb.

    tools/bin/blender/blender -b -P tools/blender_props/build_props.py -- [--only a,b] [--out DIR]

Every prop is built from code, so it is reproducible and reviewable: chunky rounded forms
(bevels and a subdivision pass, the show's soft cartoon shapes), flat colors that the
game's toon shader bands (game/shaders/toon.gdshader), UVs unwrapped with smart project.
Default output: game/assets/models/<name>.glb (committed: these are original works).

Scale: 1 unit = 1 m. Ponies stand about 1.3 m at the withers in game.
"""
import argparse
import math
import os
import sys

import bpy
import bmesh
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ap = argparse.ArgumentParser()
ap.add_argument("--only", default="")
ap.add_argument("--out", default=os.path.join(ROOT, "game", "assets", "models"))
args = ap.parse_args(argv)

PALETTE = {
    "wood": (0.72, 0.47, 0.28), "wood_dark": (0.48, 0.3, 0.18), "straw": (0.96, 0.84, 0.46),
    "straw_dark": (0.82, 0.64, 0.3), "red": (0.86, 0.3, 0.32), "cream": (0.99, 0.95, 0.85),
    "brightsky": (0.36, 0.66, 0.98), "brightsky_dark": (0.2, 0.42, 0.78), "gold": (0.98, 0.78, 0.3),
    "white": (0.97, 0.97, 0.99), "leaf": (0.42, 0.76, 0.34), "leaf_light": (0.58, 0.86, 0.42),
    "leaf_dark": (0.3, 0.6, 0.3), "bark": (0.55, 0.38, 0.26), "metal": (0.62, 0.66, 0.72),
    "metal_dark": (0.36, 0.38, 0.44), "iron": (0.28, 0.29, 0.33), "glass": (0.75, 0.9, 0.98),
    "pink": (0.97, 0.62, 0.74), "teal": (0.2, 0.68, 0.66), "lilac": (0.74, 0.62, 0.94),
    "leather": (0.6, 0.38, 0.24), "black": (0.12, 0.11, 0.13), "grey": (0.56, 0.58, 0.62),
    "rose": (0.96, 0.42, 0.52), "stone": (0.74, 0.72, 0.68), "stone_dark": (0.56, 0.55, 0.52),
    "cloud": (0.98, 0.98, 1.0), "cloud_shade": (0.86, 0.88, 0.96),
}

BUILDERS = {}


def prop(name):
    def wrap(fn):
        BUILDERS[name] = fn
        return fn
    return wrap


# --- helpers -----------------------------------------------------------------------------

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def mat(key):
    name = "m_" + key
    m = bpy.data.materials.get(name)
    if m is None:
        m = bpy.data.materials.new(name)
        c = PALETTE[key]
        m.use_nodes = True
        bsdf = m.node_tree.nodes["Principled BSDF"]
        bsdf.inputs["Base Color"].default_value = (c[0], c[1], c[2], 1.0)
        bsdf.inputs["Roughness"].default_value = 1.0
        m.diffuse_color = (c[0], c[1], c[2], 1.0)
    return m


def finish(obj, color, bevel=0.0, subdiv=0, smooth=True):
    """Material, optional rounded edges (bevel) and softening (subsurf), applied."""
    obj.data.materials.clear()
    obj.data.materials.append(mat(color))
    bpy.context.view_layer.objects.active = obj
    if bevel > 0.0:
        m = obj.modifiers.new("bevel", "BEVEL")
        m.width = bevel
        m.segments = 3
        m.limit_method = "ANGLE"
    if subdiv > 0:
        m = obj.modifiers.new("sub", "SUBSURF")
        m.levels = subdiv
        m.render_levels = subdiv
    for mod in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=mod.name)
    if smooth:
        bpy.ops.object.shade_smooth()
    return obj


def box(name, size, loc, color, bevel=0.02, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.name = name
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    return finish(o, color, bevel=bevel, smooth=False)


def cyl(name, r, h, loc, color, verts=24, bevel=0.0, rot=(0, 0, 0), r2=None):
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=h, location=loc, rotation=rot)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r2, depth=h, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.name = name
    return finish(o, color, bevel=bevel)


def ball(name, r, loc, color, scale=(1, 1, 1), subdiv=2):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdiv, radius=r, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    return finish(o, color)


def torus(name, R, r, loc, color, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, location=loc, rotation=rot,
                                     major_segments=32, minor_segments=12)
    o = bpy.context.active_object
    o.name = name
    return finish(o, color)


def blob(name, r, loc, color, seed=1, lumps=0.18, scale=(1, 1, 1)):
    """A soft, lumpy cartoon mass (tree canopies, clouds, bushes)."""
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=r, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    import random
    rnd = random.Random(seed)
    centers = [Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-0.3, 1))).normalized() for _ in range(7)]
    for v in o.data.vertices:
        d = v.co.normalized()
        bump = sum(max(0.0, d.dot(c)) ** 6 for c in centers)
        v.co *= 1.0 + lumps * bump
    return finish(o, color, subdiv=1)


def join(objs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    o = bpy.context.active_object
    o.name = name
    return o


def unwrap_all():
    for o in bpy.context.scene.objects:
        if o.type != "MESH":
            continue
        bpy.ops.object.select_all(action="DESELECT")
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.02)
        bpy.ops.object.mode_set(mode="OBJECT")


def export(name):
    unwrap_all()
    os.makedirs(args.out, exist_ok=True)
    path = os.path.join(args.out, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_apply=True,
                              export_yup=True, export_materials="EXPORT")
    tris = sum(len(o.data.polygons) for o in bpy.context.scene.objects if o.type == "MESH")
    print("PROP_OK %s faces=%d -> %s" % (name, tris, path))


# --- props -------------------------------------------------------------------------------

@prop("depot_crate")
def depot_crate():
    """The Brightsky Depot crate: a big friendly slatted box on a pallet, the company's sky
    blue with gold trim, its lid hinged open a crack. Scratches inside the lid (clue 16)."""
    parts = [box("pallet", (1.9, 1.5, 0.16), (0, 0, 0.08), "wood_dark", bevel=0.02)]
    for i, x in enumerate((-0.7, 0.0, 0.7)):
        parts.append(box("skid%d" % i, (0.18, 1.5, 0.12), (x, 0, 0.02), "wood_dark", bevel=0.015))
    parts.append(box("body", (1.7, 1.3, 1.2), (0, 0, 0.78), "brightsky", bevel=0.06))
    for z in (0.42, 0.78, 1.14):
        parts.append(box("slat%.2f" % z, (1.74, 1.34, 0.08), (0, 0, z), "brightsky_dark", bevel=0.02))
    for x in (-0.85, 0.85):
        for y in (-0.65, 0.65):
            parts.append(box("post", (0.12, 0.12, 1.24), (x, y, 0.8), "gold", bevel=0.03))
    lid = box("lid", (1.78, 1.38, 0.12), (0, 0, 0), "brightsky", bevel=0.04)
    for k in range(5):
        s = box("scratch%d" % k, (0.5, 0.02, 0.01), (-0.3 + 0.12 * k, 0.2 - 0.07 * k, -0.065), "wood_dark", bevel=0.0,
                rot=(0, 0, math.radians(30 + 8 * k)))
        parts.append(s)
    lid_all = join([lid] + parts[-5:], "lid")
    parts = parts[:-5]
    lid_all.location = (0, -0.69, 1.42)
    lid_all.rotation_euler = (math.radians(-14), 0, 0)
    sun = cyl("emblem", 0.28, 0.04, (0, -0.66, 0.8), "gold", rot=(math.radians(90), 0, 0))
    ring = torus("emblem_ring", 0.34, 0.035, (0, -0.665, 0.8), "white", rot=(math.radians(90), 0, 0))
    join(parts + [sun, ring], "crate")
    export("depot_crate")


@prop("postbox")
def postbox():
    """The ranch mailbox: a rounded red box on a wooden post with a flag."""
    post = box("post", (0.14, 0.14, 1.1), (0, 0, 0.55), "wood", bevel=0.02)
    body = box("body", (0.38, 0.62, 0.34), (0, 0, 1.23), "red", bevel=0.05)
    top = cyl("top", 0.19, 0.62, (0, 0, 1.4), "red", rot=(math.radians(90), 0, 0))
    door = box("door", (0.36, 0.02, 0.44), (0, -0.32, 1.28), "rose", bevel=0.01)
    flag_post = box("flagpole", (0.03, 0.03, 0.34), (0.22, 0.1, 1.45), "metal", bevel=0.0)
    flag = box("flag", (0.02, 0.16, 0.1), (0.22, 0.18, 1.58), "gold", bevel=0.005)
    join([post, body, top, door, flag_post, flag], "postbox")
    export("postbox")


def _tree(name, seed, height, canopy, color, extra_color):
    trunk = cyl("trunk", 0.22, height, (0, 0, height / 2), "bark", r2=0.14, verts=12)
    puffs = [blob("c0", canopy, (0, 0, height + canopy * 0.55), color, seed=seed)]
    puffs.append(blob("c1", canopy * 0.72, (canopy * 0.6, 0.1, height + canopy * 0.2), extra_color, seed=seed + 1))
    puffs.append(blob("c2", canopy * 0.68, (-canopy * 0.55, -0.15, height + canopy * 0.25), color, seed=seed + 2))
    puffs.append(blob("c3", canopy * 0.6, (0.05, canopy * 0.55, height + canopy * 0.35), extra_color, seed=seed + 3))
    join([trunk] + puffs, name)
    export(name)


@prop("tree_round")
def tree_round():
    """The show's soft round tree: a short trunk under a cloud of leaf puffs."""
    _tree("tree_round", 11, 1.8, 1.5, "leaf", "leaf_light")


@prop("tree_tall")
def tree_tall():
    _tree("tree_tall", 23, 2.6, 1.25, "leaf_dark", "leaf")


@prop("tree_apple")
def tree_apple():
    trunk = cyl("trunk", 0.24, 1.7, (0, 0, 0.85), "bark", r2=0.15, verts=12)
    puffs = [blob("c0", 1.45, (0, 0, 2.5), "leaf", seed=31), blob("c1", 1.0, (0.9, 0.2, 2.2), "leaf_light", seed=32),
             blob("c2", 1.0, (-0.85, -0.2, 2.25), "leaf", seed=33)]
    import random
    rnd = random.Random(5)
    apples = []
    for i in range(14):
        a = rnd.uniform(0, math.tau)
        z = rnd.uniform(1.8, 3.2)
        r = 1.35 if z < 2.8 else 1.0
        apples.append(ball("apple%d" % i, 0.13, (math.cos(a) * r, math.sin(a) * r, z), "red", subdiv=1))
    join([trunk] + puffs + apples, "tree_apple")
    export("tree_apple")


@prop("bush")
def bush():
    join([blob("b0", 0.7, (0, 0, 0.45), "leaf", seed=41, scale=(1.3, 1.0, 0.8)),
          blob("b1", 0.5, (0.6, 0.2, 0.35), "leaf_light", seed=42)], "bush")
    export("bush")


@prop("straw_hat")
def straw_hat():
    """Old Fennel's straw hat: wide floppy brim, a red band. Sized for a pony's head."""
    brim = cyl("brim", 0.42, 0.03, (0, 0, 0), "straw", verts=32)
    for v in brim.data.vertices:
        r = math.hypot(v.co.x, v.co.y)
        v.co.z -= 0.08 * max(0.0, r - 0.2) ** 1.5 * 3.0
    crown = cyl("crown", 0.2, 0.2, (0, 0, 0.1), "straw", r2=0.16, verts=24, bevel=0.03)
    band = cyl("band", 0.205, 0.05, (0, 0, 0.04), "red", verts=24)
    join([brim, crown, band], "straw_hat")
    export("straw_hat")


@prop("satchel")
def satchel():
    """Pip's mail satchel: a rounded leather bag on a strap, with a gold envelope badge."""
    bag = box("bag", (0.36, 0.14, 0.28), (0, 0, 0), "leather", bevel=0.05)
    flap = box("flap", (0.37, 0.15, 0.12), (0, -0.005, 0.1), "wood_dark", bevel=0.04)
    badge = box("badge", (0.1, 0.01, 0.07), (0, -0.08, 0.08), "gold", bevel=0.01)
    strap = torus("strap", 0.36, 0.02, (0, 0.02, 0.34), "leather", rot=(math.radians(90), 0, 0))
    join([bag, flap, badge, strap], "satchel")
    export("satchel")


@prop("sash")
def sash():
    """Marigold's Brightsky sash: a sky blue band with a gold sun badge."""
    band = torus("band", 0.42, 0.045, (0, 0, 0), "brightsky", rot=(0, math.radians(35), 0))
    band.scale = (1.0, 0.75, 1.0)
    bpy.ops.object.transform_apply(scale=True)
    badge = cyl("badge", 0.07, 0.02, (0.33, -0.3, 0.2), "gold", rot=(math.radians(90), 0, 0))
    join([band, badge], "sash")
    export("sash")


@prop("goggles")
def goggles():
    """A Collector's goggles: two round brass-rimmed dark lenses on a strap."""
    lens = [torus("rimL", 0.075, 0.02, (-0.085, 0, 0), "metal_dark", rot=(math.radians(90), 0, 0)),
            torus("rimR", 0.075, 0.02, (0.085, 0, 0), "metal_dark", rot=(math.radians(90), 0, 0)),
            cyl("glassL", 0.07, 0.015, (-0.085, 0, 0), "iron", rot=(math.radians(90), 0, 0)),
            cyl("glassR", 0.07, 0.015, (0.085, 0, 0), "iron", rot=(math.radians(90), 0, 0)),
            torus("strap", 0.2, 0.015, (0, 0.18, 0), "black")]
    join(lens, "goggles")
    export("goggles")


@prop("patch")
def patch():
    """Static's Brightsky flank patch: a rounded badge that hides her mark."""
    p = cyl("patch", 0.16, 0.012, (0, 0, 0), "brightsky", verts=32, bevel=0.004)
    s = cyl("sun", 0.08, 0.016, (0, 0, 0.002), "gold", verts=24)
    join([p, s], "patch")
    export("patch")


@prop("scoop")
def scoop():
    """The Brightsky Scoop: a friendly lantern-like device worn at the side. A brass body,
    a glass bulb that glows when it works, a gauge, the company's blue."""
    body = cyl("body", 0.1, 0.32, (0, 0, 0), "brightsky", rot=(0, math.radians(90), 0), bevel=0.02)
    nozzle = cyl("nozzle", 0.11, 0.12, (0.21, 0, 0), "gold", r2=0.15, rot=(0, math.radians(90), 0))
    bulb = ball("bulb", 0.085, (0.3, 0, 0), "glass")
    cap = cyl("cap", 0.1, 0.06, (-0.18, 0, 0), "gold", rot=(0, math.radians(90), 0), bevel=0.01)
    gauge = cyl("gauge", 0.05, 0.02, (-0.02, -0.105, 0.03), "white", rot=(math.radians(90), 0, 0))
    strap = torus("strap", 0.13, 0.018, (-0.05, 0, 0), "leather", rot=(0, math.radians(90), 0))
    join([body, nozzle, bulb, cap, gauge, strap], "scoop")
    export("scoop")


def main():
    wanted = [n for n in args.only.split(",") if n] or list(BUILDERS)
    for name in wanted:
        reset()
        BUILDERS[name]()
    print("PROPS_DONE", len(wanted))


main()
