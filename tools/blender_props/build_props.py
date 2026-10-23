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
    "spike_purple": (0.36, 0.13, 0.58), "spike_belly": (0.5, 0.8, 0.28), "spike_green": (0.08, 0.6, 0.12),
    "eye_green": (0.04, 0.45, 0.1), "eye_white": (1.0, 1.0, 1.0), "pupil": (0.01, 0.02, 0.01),
    "cloud": (0.98, 0.98, 1.0), "cloud_shade": (0.86, 0.88, 0.96), "cream": (0.99, 0.95, 0.86),
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


def _tree(name, seed, height, canopy, color, extra_color, fruit=False):
    """The show's soft round tree: a chunky, slightly curved trunk under a cloud of lumpy
    leaf puffs, a darker puff tucked under for depth (the show paints its trees that way)."""
    import random
    rnd = random.Random(seed)
    trunk = cyl("trunk", 0.36, height, (0, 0, height / 2), "bark", r2=0.22, verts=12)
    for v in trunk.data.vertices:
        v.co.x += 0.12 * math.sin(v.co.z / height * math.pi)
    root = cyl("root", 0.55, 0.35, (0, 0, 0.17), "bark", r2=0.36, verts=12)
    puffs = [blob("c0", canopy, (0, 0, height + canopy * 0.55), color, seed=seed, lumps=0.32)]
    puffs.append(blob("under", canopy * 0.85, (0, 0, height + canopy * 0.15), "leaf_dark", seed=seed + 9, lumps=0.25,
                      scale=(1.1, 1.1, 0.6)))
    for k in range(4):
        a = k / 4 * math.tau + rnd.uniform(-0.3, 0.3)
        puffs.append(blob("c%d" % (k + 1), canopy * rnd.uniform(0.55, 0.72),
                          (math.cos(a) * canopy * 0.62, math.sin(a) * canopy * 0.62, height + canopy * rnd.uniform(0.25, 0.7)),
                          extra_color if k % 2 else color, seed=seed + k + 1, lumps=0.3))
    extras = []
    if fruit:
        for i in range(16):
            a = rnd.uniform(0, math.tau)
            el = rnd.uniform(-0.2, 0.9)
            r = canopy * 1.32
            p = Vector((math.cos(a) * math.cos(el), math.sin(a) * math.cos(el), math.sin(el))) * r
            extras.append(ball("apple%d" % i, 0.15, (p.x, p.y, height + canopy * 0.55 + p.z), "red", subdiv=1))
    join([trunk, root] + puffs + extras, name)
    export(name)


@prop("tree_round")
def tree_round():
    _tree("tree_round", 11, 1.8, 1.5, "leaf", "leaf_light")


@prop("tree_tall")
def tree_tall():
    _tree("tree_tall", 23, 2.6, 1.25, "leaf_dark", "leaf")


@prop("tree_apple")
def tree_apple():
    _tree("tree_apple", 31, 1.7, 1.45, "leaf", "leaf_light", fruit=True)


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


@prop("valley_rim")
def valley_rim():
    """The soft green hills that ring Haybrook Vale, outside the playable 220 m square: big
    rounded humps in two rows, the far row taller and bluer (aerial perspective is painted
    in, as the show's backgrounds do), with clumps of round trees on the near slopes."""
    import random
    rnd = random.Random(7)
    parts = []
    for row, (r_min, r_max, h_min, h_max, color) in enumerate(
            [(150, 175, 18, 34, "leaf"), (205, 240, 40, 72, "leaf_dark")]):
        count = 20 if row == 0 else 16
        for i in range(count):
            a = (i + rnd.uniform(-0.3, 0.3)) / count * math.tau
            r = rnd.uniform(r_min, r_max)
            h = rnd.uniform(h_min, h_max)
            w = rnd.uniform(45, 70) if row == 0 else rnd.uniform(70, 100)
            hump = blob("hill%d_%d" % (row, i), 1.0, (math.cos(a) * r, math.sin(a) * r, 0), color,
                        seed=100 + i + row * 50, lumps=0.12, scale=(w, w * 0.8, h))
            parts.append(hump)
    for i in range(26):
        a = rnd.uniform(0, math.tau)
        r = rnd.uniform(140, 162)
        x, y = math.cos(a) * r, math.sin(a) * r
        for k in range(3):
            ox, oy = rnd.uniform(-6, 6), rnd.uniform(-6, 6)
            s = rnd.uniform(4.5, 7.0)
            parts.append(cyl("trunk%d_%d" % (i, k), 0.5, s * 0.9, (x + ox, y + oy, 6 + s * 0.45), "bark", verts=8))
            parts.append(blob("crown%d_%d" % (i, k), s * 0.55, (x + ox, y + oy, 6 + s * 1.15),
                              "leaf_light" if k % 2 else "leaf", seed=300 + i * 3 + k, lumps=0.2))
    join(parts, "valley_rim")
    export("valley_rim")


@prop("prism_works")
def prism_works():
    """The Prism Works: Brightsky's palace on a bank of cloud above the northern ridge.
    White towers with gold domes, a great round window, and the spout the Haybrook Rainbow
    pours from. Seen from the valley it is lovely; nothing about it is wrong at a distance."""
    import random
    rnd = random.Random(3)
    parts = []
    for i in range(14):
        a = i / 14 * math.tau
        r = rnd.uniform(18, 34)
        parts.append(blob("cloud%d" % i, rnd.uniform(9, 15), (math.cos(a) * r, math.sin(a) * r * 0.6, rnd.uniform(-3, 2)),
                          "cloud" if i % 3 else "cloud_shade", seed=500 + i, lumps=0.25, scale=(1.3, 1.0, 0.7)))
    parts.append(blob("cloud_core", 22, (0, 0, -2), "cloud", seed=499, lumps=0.2, scale=(1.4, 0.9, 0.6)))
    parts.append(cyl("keep", 11, 26, (0, 0, 16), "white", verts=32))
    parts.append(cyl("keep_dome", 11.5, 10, (0, 0, 34), "gold", r2=1.5, verts=32))
    parts.append(torus("keep_band", 11.2, 0.8, (0, 0, 27), "brightsky"))
    for i, (x, y, h) in enumerate([(-16, 4, 30), (16, 4, 30), (-9, -8, 22), (9, -8, 22), (0, 10, 38)]):
        parts.append(cyl("tower%d" % i, 3.2, h, (x, y, 4 + h / 2), "white", verts=20))
        parts.append(cyl("cap%d" % i, 3.8, 7, (x, y, 4 + h + 3.5), "gold", r2=0.2, verts=20))
        parts.append(torus("ring%d" % i, 3.3, 0.35, (x, y, 4 + h - 2), "brightsky"))
    parts.append(cyl("window", 6.5, 0.8, (0, -11.2, 20), "glass", verts=32, rot=(math.radians(90), 0, 0)))
    parts.append(torus("window_rim", 6.7, 0.7, (0, -11.4, 20), "gold", rot=(math.radians(90), 0, 0)))
    parts.append(cyl("spout", 4.5, 14, (12, -10, 30), "gold", r2=6.5, verts=24, rot=(math.radians(-55), 0, math.radians(20))))
    join(parts, "prism_works")
    export("prism_works")


@prop("cloud_lift")
def cloud_lift():
    """The lift up to the Rainbow Factory: a cart of crates on a fluffy cloud platform under
    a gold-ringed canopy. It rises from the Depot at night (clue 10)."""
    deck = blob("deck", 2.2, (0, 0, 0), "cloud", seed=600, lumps=0.25, scale=(1.4, 1.0, 0.35))
    rail = torus("rail", 1.9, 0.08, (0, 0, 0.75), "gold")
    posts = [cyl("post%d" % i, 0.07, 1.6, (math.cos(a) * 1.9, math.sin(a) * 1.9, 0.6), "gold", verts=10)
             for i, a in enumerate([k * math.tau / 6 for k in range(6)])]
    canopy = blob("canopy", 1.6, (0, 0, 2.1), "cloud_shade", seed=601, lumps=0.2, scale=(1.4, 1.4, 0.45))
    crates = [box("crate%d" % i, (0.7, 0.6, 0.6), (x, y, 0.55), "brightsky", bevel=0.04)
              for i, (x, y) in enumerate([(-0.5, -0.3), (0.45, -0.2), (0.0, 0.45)])]
    join([deck, rail, canopy] + posts + crates, "cloud_lift")
    export("cloud_lift")


@prop("weather_pylon")
def weather_pylon():
    """A weather pylon: a slim sky-blue mast with gold bands, a cloud-catcher dish and a
    glowing core the Rescue path holds the Scoop on to cut (STORY.md section 5)."""
    base = cyl("base", 0.9, 0.5, (0, 0, 0.25), "stone", verts=16, bevel=0.05)
    mast = cyl("mast", 0.28, 7.5, (0, 0, 4.0), "brightsky", r2=0.18, verts=16)
    bands = [torus("band%d" % i, 0.3 - i * 0.02, 0.06, (0, 0, 1.5 + i * 1.8), "gold") for i in range(4)]
    dish = cyl("dish", 1.4, 0.25, (0, 0, 7.8), "white", r2=0.5, verts=24)
    core = ball("core", 0.45, (0, 0, 8.4), "glass")
    vanes = [box("vane%d" % i, (0.06, 1.0, 0.25), (0, 0, 6.6), "gold", bevel=0.01, rot=(0, 0, i * math.pi / 3))
             for i in range(3)]
    join([base, mast, dish, core] + bands + vanes, "weather_pylon")
    export("weather_pylon")


@prop("intake_corral")
def intake_corral():
    """A Company intake corral: tidy white fence panels in a ring, a gate with a
    cloud-blue sign, and a lamp post at the gate (patrol light)."""
    parts = []
    n = 14
    for i in range(n):
        a = i / n * math.tau
        if i == 0:
            continue
        x, y = math.cos(a) * 5.0, math.sin(a) * 5.0
        parts.append(box("post%d" % i, (0.16, 0.16, 1.3), (x, y, 0.65), "white", bevel=0.03))
        a2 = (i + 0.5) / n * math.tau
        rx, ry = math.cos(a2) * 5.0, math.sin(a2) * 5.0
        for z in (0.5, 1.0):
            parts.append(box("rail%d_%.1f" % (i, z), (0.08, 2.3, 0.1), (rx, ry, z), "white", bevel=0.02,
                             rot=(0, 0, a2)))
    parts.append(box("sign", (1.4, 0.08, 0.6), (5.6, 0.0, 1.7), "brightsky", bevel=0.04, rot=(0, 0, math.pi / 2)))
    parts.append(cyl("signpost", 0.07, 1.6, (5.6, 0.0, 0.8), "white", verts=8))
    parts.append(cyl("lamppost", 0.09, 3.0, (5.8, 1.2, 1.5), "metal_dark", verts=10))
    parts.append(ball("lamp", 0.28, (5.8, 1.2, 3.1), "gold"))
    join(parts, "intake_corral")
    export("intake_corral")


@prop("lantern_gate")
def lantern_gate():
    """The Lantern Line's gate in the Everfree: two mossy stone pillars, a vine arch, and
    paper lanterns strung across it."""
    import random
    rnd = random.Random(9)
    parts = []
    for x in (-1.6, 1.6):
        parts.append(cyl("pillar", 0.45, 3.0, (x, 0, 1.5), "stone", verts=10, bevel=0.06))
        parts.append(blob("moss", 0.5, (x, 0, 3.0), "leaf_dark", seed=int(x * 10) + 700, lumps=0.3))
    # The vine arch: beads of leaf along a true semicircle from pillar top to pillar top.
    for k in range(19):
        a = math.pi * k / 18.0
        parts.append(blob("vine%d" % k, 0.24, (-math.cos(a) * 1.6, 0, 3.0 + math.sin(a) * 1.2),
                          "leaf" if k % 2 else "leaf_dark", seed=720 + k, lumps=0.3))
    for i in range(5):
        t = (i + 1) / 6.0
        x = -1.6 + 3.2 * t
        z = 2.9 - 0.35 * math.sin(t * math.pi)
        parts.append(ball("lantern%d" % i, 0.18, (x, 0, z), rnd.choice(["gold", "rose", "red"]), scale=(1, 1, 1.3), subdiv=1))
    join(parts, "lantern_gate")
    export("lantern_gate")


@prop("dye_vat")
def dye_vat():
    """Bramble's cellar dye vat: a round copper-banded wooden tub of swirling color with a
    paddle and a rack of little bottles. The customizer, used to hide a pony."""
    tub = cyl("tub", 0.8, 0.9, (0, 0, 0.45), "wood", verts=24, bevel=0.03)
    bands = [torus("hoop%d" % i, 0.81, 0.04, (0, 0, z), "gold") for i, z in enumerate((0.2, 0.7))]
    dye = cyl("dye", 0.72, 0.05, (0, 0, 0.93), "pink", verts=24)
    paddle = box("paddle", (0.08, 0.08, 1.3), (0.3, 0.1, 1.2), "wood_dark", bevel=0.02, rot=(0, math.radians(25), 0))
    rack = box("rack", (0.9, 0.3, 0.06), (0, 1.1, 0.9), "wood_dark", bevel=0.02)
    bottles = [cyl("bottle%d" % i, 0.07, 0.24, (-0.32 + i * 0.16, 1.1, 1.05), c, verts=10)
               for i, c in enumerate(["red", "gold", "leaf", "brightsky", "lilac"])]
    legs = [box("leg%d" % i, (0.06, 0.06, 0.9), (x, 1.1, 0.45), "wood_dark", bevel=0.01) for i, x in enumerate((-0.4, 0.4))]
    join([tub, dye, paddle, rack] + bands + bottles + legs, "dye_vat")
    export("dye_vat")


@prop("calm_lamp")
def calm_lamp():
    """The Calm Lamp, a Factory-path pen upgrade: an elegant gold post with a soft sky-blue
    bulb. Ponies under it never flee and never Bloom."""
    base = cyl("base", 0.3, 0.12, (0, 0, 0.06), "gold", verts=16)
    post = cyl("post", 0.06, 2.4, (0, 0, 1.3), "gold", verts=10)
    arm = box("arm", (0.5, 0.05, 0.05), (0.22, 0, 2.45), "gold", bevel=0.01)
    bulb = ball("bulb", 0.2, (0.45, 0, 2.3), "glass")
    shade = cyl("shade", 0.28, 0.16, (0.45, 0, 2.48), "brightsky", r2=0.08, verts=16)
    join([base, post, arm, bulb, shade], "calm_lamp")
    export("calm_lamp")


@prop("lure_post")
def lure_post():
    """A Factory-path Lure Post: a candy-striped pole with a sugar-cube feeder and a little
    music box on top. Drifters gather round it at night."""
    pole = cyl("pole", 0.08, 1.6, (0, 0, 0.8), "white", verts=12)
    stripes = [torus("stripe%d" % i, 0.085, 0.03, (0, 0, 0.2 + i * 0.25), "rose") for i in range(6)]
    tray = cyl("tray", 0.35, 0.06, (0, 0, 1.62), "brightsky", verts=20)
    cubes = [box("cube%d" % i, (0.1, 0.1, 0.1), (math.cos(i) * 0.15, math.sin(i) * 0.15, 1.7), "white", bevel=0.01)
             for i in range(5)]
    musicbox = box("musicbox", (0.22, 0.16, 0.14), (0, 0, 1.82), "gold", bevel=0.03)
    join([pole, tray, musicbox] + stripes + cubes, "lure_post")
    export("lure_post")


# --- the Rainbow Factory interior kit (assembled in game/world/factory_interior.gd) ------
# Every wall piece is 4 m wide, 6 m tall and 0.4 m thick, standing on the origin and facing
# -Y; floors are 4 x 4 m tiles at z = 0. Cloud-white and gold for the public rooms, grey
# metal for the parts nopony is shown.

def _wall(name, color, trim):
    w = box("panel", (4.0, 0.4, 6.0), (0, 0, 3.0), color, bevel=0.03)
    base = box("base", (4.02, 0.5, 0.35), (0, -0.02, 0.18), trim, bevel=0.03)
    crown = box("crown", (4.02, 0.5, 0.3), (0, -0.02, 5.85), trim, bevel=0.03)
    return [w, base, crown]


@prop("fx_wall")
def fx_wall():
    join(_wall("fx_wall", "white", "gold") + [box("pilaster", (0.35, 0.55, 5.4), (-1.83, -0.05, 3.0), "cloud_shade", bevel=0.05)], "fx_wall")
    export("fx_wall")


@prop("fx_wall_metal")
def fx_wall_metal():
    parts = _wall("fx_wall_metal", "metal", "metal_dark")
    for x in (-1.5, -0.5, 0.5, 1.5):
        for z in (0.8, 3.0, 5.2):
            parts.append(ball("rivet", 0.06, (x, -0.21, z), "metal_dark", subdiv=1))
    parts.append(box("seam", (4.0, 0.42, 0.05), (0, 0, 2.0), "metal_dark", bevel=0.0))
    parts.append(box("seam2", (4.0, 0.42, 0.05), (0, 0, 4.0), "metal_dark", bevel=0.0))
    join(parts, "fx_wall_metal")
    export("fx_wall_metal")


@prop("fx_arch")
def fx_arch():
    """A wall with a round-topped doorway 2.2 m wide, 3.6 m tall."""
    parts = [box("left", (0.9, 0.4, 6.0), (-1.55, 0, 3.0), "white", bevel=0.03),
             box("right", (0.9, 0.4, 6.0), (1.55, 0, 3.0), "white", bevel=0.03),
             box("lintel", (4.0, 0.4, 1.8), (0, 0, 5.1), "white", bevel=0.03)]
    for k in range(9):
        a = math.pi * k / 8
        parts.append(box("arc%d" % k, (0.42, 0.42, 0.25), (-math.cos(a) * 1.1, 0, 3.6 + math.sin(a) * 0.6 - 0.1), "gold",
                         bevel=0.02, rot=(0, -a + math.pi / 2, 0)))
    parts.append(box("base", (4.02, 0.5, 0.35), (0, -0.02, 0.18), "gold", bevel=0.03))
    join(parts, "fx_arch")
    export("fx_arch")


@prop("fx_window_wall")
def fx_window_wall():
    """The long gallery window over the processing floor: a metal wall with a wide frosted
    pane (the frosting is a material in game; this is the frame and the glass slab)."""
    parts = [box("low", (4.0, 0.4, 1.4), (0, 0, 0.7), "metal", bevel=0.03),
             box("high", (4.0, 0.4, 1.2), (0, 0, 5.4), "metal", bevel=0.03),
             box("sill", (4.1, 0.7, 0.15), (0, -0.15, 1.45), "metal_dark", bevel=0.02),
             box("mullion", (0.18, 0.45, 3.4), (-1.95, 0, 3.1), "metal_dark", bevel=0.02),
             box("mullion2", (0.18, 0.45, 3.4), (1.95, 0, 3.1), "metal_dark", bevel=0.02)]
    join(parts, "fx_window_wall")
    export("fx_window_wall")


@prop("fx_floor")
def fx_floor():
    t = box("tile", (4.0, 4.0, 0.2), (0, 0, -0.1), "cream", bevel=0.02)
    inlay = box("inlay", (3.6, 3.6, 0.02), (0, 0, 0.005), "cloud_shade", bevel=0.0)
    join([t, inlay], "fx_floor")
    export("fx_floor")


@prop("fx_floor_grate")
def fx_floor_grate():
    parts = [box("frame", (4.0, 4.0, 0.15), (0, 0, -0.08), "metal_dark", bevel=0.01)]
    for i in range(9):
        parts.append(box("bar%d" % i, (0.08, 3.8, 0.05), (-1.8 + i * 0.45, 0, 0.0), "metal", bevel=0.0))
    join(parts, "fx_floor_grate")
    export("fx_floor_grate")


@prop("fx_column")
def fx_column():
    join([cyl("shaft", 0.35, 5.4, (0, 0, 3.0), "white", verts=16),
          cyl("foot", 0.55, 0.3, (0, 0, 0.15), "gold", verts=16, bevel=0.03),
          cyl("cap", 0.55, 0.3, (0, 0, 5.85), "gold", verts=16, bevel=0.03)], "fx_column")
    export("fx_column")


@prop("fx_pipe")
def fx_pipe():
    """A 4 m glass spectrum pipe on gold collars, lying along X at 4 m up. Its colour is a
    spectral material in game (the only saturated thing left in the dread grade)."""
    join([cyl("glass", 0.35, 4.0, (0, 0, 0), "glass", verts=16, rot=(0, math.radians(90), 0)),
          cyl("collarA", 0.45, 0.25, (-1.9, 0, 0), "gold", verts=16, rot=(0, math.radians(90), 0)),
          cyl("collarB", 0.45, 0.25, (1.9, 0, 0), "gold", verts=16, rot=(0, math.radians(90), 0))], "fx_pipe")
    export("fx_pipe")


@prop("fx_catwalk")
def fx_catwalk():
    """A 4 m walkway, 1.6 m wide, with railings both sides (the reveal's stealth route)."""
    parts = [box("deck", (4.0, 1.6, 0.12), (0, 0, 0), "metal_dark", bevel=0.01)]
    for y in (-0.78, 0.78):
        parts.append(box("rail", (4.0, 0.06, 0.06), (0, y, 1.0), "metal", bevel=0.0))
        parts.append(box("rail2", (4.0, 0.05, 0.05), (0, y, 0.5), "metal", bevel=0.0))
        for x in (-1.9, 0.0, 1.9):
            parts.append(box("post", (0.06, 0.06, 1.0), (x, y, 0.5), "metal", bevel=0.0))
    join(parts, "fx_catwalk")
    export("fx_catwalk")


@prop("fx_ring")
def fx_ring():
    """The processing ring: a broad glowing hoop on a pedestal with a glass column rising
    from it into the pipes. A pony steps into the light; nothing more is ever shown."""
    join([cyl("plinth", 1.8, 0.4, (0, 0, 0.2), "metal_dark", verts=32, bevel=0.03),
          torus("ring", 1.6, 0.22, (0, 0, 1.9), "gold", rot=(math.radians(90), 0, 0)),
          torus("halo", 1.6, 0.08, (0, 0, 1.9), "glass", rot=(math.radians(90), 0, 0)),
          cyl("column", 0.4, 6.0, (0, 0, 6.5), "glass", verts=16),
          cyl("cap", 0.7, 0.5, (0, 0, 9.6), "gold", verts=16)], "fx_ring")
    export("fx_ring")


@prop("fx_stall")
def fx_stall():
    """A holding stall: a low pen of bars with a tag board (long-term holding)."""
    parts = [box("floor", (2.0, 2.0, 0.1), (0, 0, 0.05), "metal_dark", bevel=0.01)]
    for i in range(7):
        parts.append(cyl("bar%d" % i, 0.04, 1.8, (-0.9 + i * 0.3, -1.0, 0.9), "metal", verts=8))
    parts.append(box("top", (2.0, 0.08, 0.1), (0, -1.0, 1.8), "metal", bevel=0.0))
    parts.append(box("tag", (0.5, 0.04, 0.3), (0.6, -1.05, 1.5), "white", bevel=0.01))
    join(parts, "fx_stall")
    export("fx_stall")


@prop("fx_lever")
def fx_lever():
    """The control console. The lever itself is fx_lever_handle, so it can be pulled."""
    join([box("desk", (2.4, 1.0, 1.0), (0, 0, 0.5), "metal_dark", bevel=0.05),
          box("panel", (2.2, 0.1, 0.8), (0, -0.25, 1.3), "metal", bevel=0.03, rot=(math.radians(-25), 0, 0)),
          ball("lampR", 0.08, (-0.7, -0.35, 1.4), "red", subdiv=1),
          ball("lampG", 0.08, (-0.45, -0.35, 1.4), "leaf", subdiv=1),
          ball("lampB", 0.08, (-0.2, -0.35, 1.4), "brightsky", subdiv=1),
          cyl("socket", 0.15, 0.2, (0.6, 0, 1.05), "gold", verts=12)], "fx_lever")
    export("fx_lever")


@prop("fx_lever_handle")
def fx_lever_handle():
    join([cyl("stick", 0.05, 0.9, (0, 0, 0.45), "metal", verts=10), ball("knob", 0.13, (0, 0, 0.95), "red")], "fx_lever_handle")
    export("fx_lever_handle")


@prop("fx_counter")
def fx_counter():
    """The gift shop counter with a shelf of Rainbow Dye bottles."""
    parts = [box("counter", (3.0, 0.8, 1.0), (0, 0, 0.5), "white", bevel=0.05),
             box("top", (3.1, 0.9, 0.08), (0, 0, 1.02), "gold", bevel=0.02),
             box("shelf", (3.0, 0.4, 0.06), (0, 0.9, 1.6), "wood", bevel=0.01),
             box("shelf2", (3.0, 0.4, 0.06), (0, 0.9, 2.2), "wood", bevel=0.01)]
    cols = ["red", "gold", "straw", "leaf", "brightsky", "lilac", "pink"]
    for row, z in enumerate((1.75, 2.35)):
        for i in range(9):
            parts.append(cyl("b%d_%d" % (row, i), 0.08, 0.26, (-1.3 + i * 0.32, 0.9, z), cols[(i + row) % 7], verts=10))
    join(parts, "fx_counter")
    export("fx_counter")


@prop("fx_poster")
def fx_poster():
    """A framed poster board (the image is a texture made in game)."""
    join([box("frame", (1.6, 0.08, 2.2), (0, 0, 0), "gold", bevel=0.03),
          box("board", (1.4, 0.1, 2.0), (0, -0.02, 0), "cream", bevel=0.0)], "fx_poster")
    export("fx_poster")


@prop("creator_stage")
def creator_stage():
    """The character creator's stage: a round grassy hillock with daisies and a scrap of
    fence, the pony standing on its crown. Wide enough that the turntable's edge never shows."""
    import random
    rnd = random.Random(12)
    mound = blob("mound", 1.0, (0, 0, -0.55), "leaf", seed=900, lumps=0.05, scale=(3.4, 3.4, 0.6))
    rim = blob("rim", 1.0, (0, 0, -0.75), "leaf_dark", seed=901, lumps=0.06, scale=(3.7, 3.7, 0.55))
    parts = [mound, rim]
    for i in range(22):
        a = rnd.uniform(0, math.tau)
        r = rnd.uniform(1.2, 3.0)
        x, y = math.cos(a) * r, math.sin(a) * r
        z = 0.02 - (r / 3.4) ** 2 * 0.5
        parts.append(cyl("stem%d" % i, 0.015, 0.12, (x, y, z + 0.06), "leaf_dark", verts=6))
        parts.append(ball("petal%d" % i, 0.06, (x, y, z + 0.14), rnd.choice(["white", "pink", "gold"]),
                          scale=(1, 1, 0.5), subdiv=1))
    for k in range(3):
        x = -2.4 + k * 0.7
        parts.append(box("fpost%d" % k, (0.08, 0.08, 0.6), (x, 2.1, -0.15), "wood", bevel=0.01))
    parts.append(box("frail", (1.6, 0.05, 0.07), (-1.7, 2.1, 0.05), "wood", bevel=0.01))
    join(parts, "creator_stage")
    export("creator_stage")


@prop("fx_ceiling")
def fx_ceiling():
    """A 4 x 4 m ceiling tile, cloud-soft underneath, at z 6 (the wall height)."""
    join([box("slab", (4.0, 4.0, 0.3), (0, 0, 6.15), "cloud_shade", bevel=0.02),
          blob("puff", 1.0, (0, 0, 5.95), "cloud", seed=950, lumps=0.2, scale=(1.7, 1.7, 0.3))], "fx_ceiling")
    export("fx_ceiling")


@prop("fx_ceiling_metal")
def fx_ceiling_metal():
    parts = [box("slab", (4.0, 4.0, 0.3), (0, 0, 6.15), "metal_dark", bevel=0.01)]
    for y in (-1.2, 1.2):
        parts.append(cyl("duct%d" % int(y), 0.25, 4.0, (0, y, 5.7), "metal", verts=12, rot=(0, math.radians(90), 0)))
    join(parts, "fx_ceiling_metal")
    export("fx_ceiling_metal")


@prop("fx_skylight")
def fx_skylight():
    join([box("frame", (4.0, 4.0, 0.3), (0, 0, 6.15), "gold", bevel=0.02),
          box("pane", (3.2, 3.2, 0.06), (0, 0, 6.0), "glass", bevel=0.0)], "fx_skylight")
    export("fx_skylight")


@prop("fx_banner")
def fx_banner():
    """A tall hanging banner in rainbow stripes with a gold rod and a swallowtail hem."""
    cols = ["red", "gold", "straw", "leaf", "brightsky", "lilac"]
    parts = [cyl("rod", 0.05, 1.5, (0, 0, 0), "gold", verts=10, rot=(0, math.radians(90), 0))]
    for i, c in enumerate(cols):
        parts.append(box("stripe%d" % i, (1.3, 0.04, 0.42), (0, 0, -0.25 - i * 0.42), c, bevel=0.0))
    for x in (-0.33, 0.33):
        parts.append(box("tail", (0.64, 0.04, 0.5), (x, 0, -2.75), "lilac", bevel=0.0, rot=(0, math.radians(18 if x < 0 else -18), 0)))
    join(parts, "fx_banner")
    export("fx_banner")


@prop("fx_runner")
def fx_runner():
    """A 4 m carpet runner in rainbow stripes down the middle of a public room."""
    cols = ["red", "gold", "leaf", "brightsky", "lilac"]
    parts = [box("edge", (1.8, 4.0, 0.03), (0, 0, 0.015), "gold", bevel=0.0)]
    for i, c in enumerate(cols):
        parts.append(box("band%d" % i, (0.3, 4.0, 0.04), (-0.6 + i * 0.3, 0, 0.02), c, bevel=0.0))
    join(parts, "fx_runner")
    export("fx_runner")


@prop("fx_planter")
def fx_planter():
    """A gold pot with a cloud-shaped topiary: the public rooms' cheer."""
    join([cyl("pot", 0.45, 0.6, (0, 0, 0.3), "gold", r2=0.35, verts=16, bevel=0.03),
          blob("cloud", 0.55, (0, 0, 1.15), "cloud", seed=960, lumps=0.3, scale=(1.2, 1.2, 0.9)),
          blob("cloud2", 0.35, (0.3, 0.1, 1.55), "cloud_shade", seed=961, lumps=0.3)], "fx_planter")
    export("fx_planter")


@prop("fx_lamp_hanging")
def fx_lamp_hanging():
    join([cyl("cord", 0.02, 1.4, (0, 0, 5.3), "metal_dark", verts=6),
          cyl("shade", 0.5, 0.35, (0, 0, 4.5), "metal", r2=0.15, verts=16),
          ball("bulb", 0.14, (0, 0, 4.3), "glass", subdiv=1)], "fx_lamp_hanging")
    export("fx_lamp_hanging")


@prop("fx_tank")
def fx_tank():
    """A tall glass tank of distilled spectrum: rainbow bands of colour inside, gold collars,
    pipes off the top. The thing the Works makes, standing in rows where you can see it."""
    cols = ["red", "gold", "leaf", "brightsky", "lilac"]
    parts = [cyl("base", 0.95, 0.4, (0, 0, 0.2), "metal_dark", verts=24, bevel=0.04),
             cyl("cap", 0.95, 0.35, (0, 0, 3.45), "metal_dark", verts=24, bevel=0.04),
             cyl("collarA", 1.0, 0.12, (0, 0, 0.45), "gold", verts=24),
             cyl("collarB", 1.0, 0.12, (0, 0, 3.22), "gold", verts=24)]
    for i, c in enumerate(cols):
        parts.append(cyl("band%d" % i, 0.78, 0.5, (0, 0, 0.75 + i * 0.5), c, verts=24))
    # The glass is open struts, not a solid pane: the toon shader draws opaque, and the
    # colour inside is the point.
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4
        parts.append(cyl("strut%d" % k, 0.06, 2.8, (math.cos(a) * 0.86, math.sin(a) * 0.86, 1.85), "metal", verts=8))
    parts.append(cyl("pipe", 0.16, 1.6, (0, 0, 4.3), "metal", verts=12))
    parts.append(cyl("valve", 0.32, 0.14, (0, 0, 3.9), "gold", verts=16))
    join(parts, "fx_tank")
    export("fx_tank")


@prop("fx_console")
def fx_console():
    """A control desk: a sloped panel of dials and coloured buttons, a little gauge screen."""
    parts = [box("desk", (2.2, 0.9, 1.0), (0, 0, 0.5), "metal_dark", bevel=0.04),
             box("panel", (2.2, 0.75, 0.12), (0, -0.1, 1.08), "metal", bevel=0.02, rot=(math.radians(-28), 0, 0)),
             box("screen", (0.8, 0.08, 0.55), (0, 0.32, 1.45), "iron", bevel=0.02),
             box("glow", (0.66, 0.02, 0.4), (0, 0.27, 1.45), "teal", bevel=0.0)]
    cols = ["red", "gold", "leaf", "brightsky", "lilac", "pink"]
    for i, c in enumerate(cols):
        parts.append(cyl("btn%d" % i, 0.07, 0.06, (-0.75 + i * 0.3, -0.18, 1.12), c, verts=12,
                         rot=(math.radians(-28), 0, 0)))
    for k in range(2):
        parts.append(cyl("dial%d" % k, 0.13, 0.05, (-0.75 + k * 1.5, 0.05, 1.22), "cream", verts=16,
                         rot=(math.radians(-28), 0, 0)))
    join(parts, "fx_console")
    export("fx_console")


@prop("fx_canisters")
def fx_canisters():
    """A metal rack of small spectrum canisters, one colour to a shelf: the Works' output,
    crated for Cloudsdale."""
    cols = ["red", "gold", "leaf", "brightsky"]
    parts = [box("post%d" % i, (0.08, 0.08, 2.2), (x, y, 1.1), "metal_dark", bevel=0.0)
             for i, (x, y) in enumerate([(-1.0, -0.3), (1.0, -0.3), (-1.0, 0.3), (1.0, 0.3)])]
    for k, c in enumerate(cols):
        z = 0.25 + k * 0.55
        parts.append(box("shelf%d" % k, (2.1, 0.7, 0.05), (0, 0, z), "metal", bevel=0.0))
        for j in range(5):
            parts.append(cyl("can%d_%d" % (k, j), 0.13, 0.36, (-0.8 + j * 0.4, 0, z + 0.21), c, verts=12, bevel=0.01))
    join(parts, "fx_canisters")
    export("fx_canisters")


@prop("fx_crates")
def fx_crates():
    """Three stacked shipping crates stencilled with the Corporation's cloud mark."""
    parts = []
    for i, (x, y, z, w) in enumerate([(0, 0, 0.45, 0.9), (1.0, 0.1, 0.45, 0.9), (0.5, 0.05, 1.35, 0.9)]):
        parts.append(box("crate%d" % i, (w, w, w), (x, y, z), "metal", bevel=0.03))
        parts.append(box("band%d" % i, (w + 0.02, w + 0.02, 0.1), (x, y, z), "metal_dark", bevel=0.0))
        parts.append(box("mark%d" % i, (0.35, 0.02, 0.22), (x, y - w / 2 - 0.01, z + 0.2), "gold", bevel=0.0))
    join(parts, "fx_crates")
    export("fx_crates")


@prop("spike")
def spike():
    """Spike the baby dragon (for Damon): a big round head and snout, a pear of a body with a
    pale green belly, stubby arms and legs, a long curling tail with a spade tip, green spines
    down his head and back, green ear frills, big green eyes. Faces -Y (the front view)."""
    P, B, G = "spike_purple", "spike_belly", "spike_green"
    parts = [
        ball("head", 0.27, (0, 0, 0.8), P, scale=(1.0, 1.0, 0.95), subdiv=3),
        ball("snout", 0.17, (0, -0.21, 0.73), P, scale=(1.05, 1.0, 0.78), subdiv=3),
        ball("jaw", 0.13, (0, -0.17, 0.64), B, scale=(1.1, 0.9, 0.55), subdiv=2),
        ball("body", 0.22, (0, 0.02, 0.42), P, scale=(1.0, 0.9, 1.25), subdiv=3),
        ball("belly", 0.18, (0, -0.08, 0.4), B, scale=(0.9, 0.62, 1.15), subdiv=3),
    ]
    for sx in (-1, 1):
        parts += [
            ball("thigh%d" % sx, 0.11, (0.12 * sx, 0.0, 0.2), P, subdiv=2),
            ball("foot%d" % sx, 0.09, (0.14 * sx, -0.07, 0.05), P, scale=(1.0, 1.55, 0.6), subdiv=2),
            ball("arm%d" % sx, 0.06, (0.2 * sx, -0.05, 0.47), P, scale=(1.0, 1.0, 1.8), subdiv=2),
            ball("hand%d" % sx, 0.055, (0.22 * sx, -0.1, 0.36), P, subdiv=2),
            # Ear frills: green fins swept back from the sides of the head.
            cyl("frill%d" % sx, 0.09, 0.22, (0.27 * sx, 0.06, 0.88), G, verts=10, r2=0.0,
                rot=(math.radians(-20), math.radians(70 * sx), 0)),
            # Eyes: a tall white, a green iris, a black pupil, a highlight.
            ball("eye%d" % sx, 0.1, (0.11 * sx, -0.215, 0.85), "eye_white", scale=(0.85, 0.45, 1.2), subdiv=2),
            ball("iris%d" % sx, 0.068, (0.115 * sx, -0.262, 0.84), "eye_green", scale=(0.9, 0.35, 1.15), subdiv=2),
            ball("pupil%d" % sx, 0.04, (0.118 * sx, -0.286, 0.835), "pupil", scale=(0.9, 0.3, 1.2), subdiv=1),
            ball("glint%d" % sx, 0.017, (0.138 * sx, -0.3, 0.87), "eye_white", subdiv=1),
        ]
    # Spines: down the head and the back, biggest at the crown.
    for k, (y, z, r, tilt) in enumerate([(0.05, 1.06, 0.07, -10), (0.18, 1.0, 0.065, 20), (0.26, 0.88, 0.055, 45),
                                         (0.24, 0.62, 0.05, 70), (0.24, 0.47, 0.045, 80), (0.22, 0.33, 0.04, 85)]):
        parts.append(cyl("spine%d" % k, r, r * 2.6, (0, y, z), G, verts=8, r2=0.0, rot=(math.radians(tilt), 0, 0)))
    # The tail: a curl of shrinking beads out behind him, a spade at the tip.
    pts = [(0.0, 0.2, 0.24, 0.085), (0.04, 0.32, 0.17, 0.07), (0.1, 0.43, 0.13, 0.06), (0.17, 0.52, 0.13, 0.05),
           (0.23, 0.58, 0.17, 0.042), (0.27, 0.6, 0.23, 0.035)]
    for k, (x, y, z, r) in enumerate(pts):
        parts.append(ball("tail%d" % k, r, (x, y, z), P, subdiv=2))
    parts.append(cyl("spade", 0.07, 0.12, (0.29, 0.6, 0.31), G, verts=4, r2=0.0, rot=(0, 0, math.radians(45))))
    join(parts, "spike")
    export("spike")


def main():
    wanted = [n for n in args.only.split(",") if n] or list(BUILDERS)
    for name in wanted:
        reset()
        BUILDERS[name]()
    print("PROPS_DONE", len(wanted))


main()
