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


def main():
    wanted = [n for n in args.only.split(",") if n] or list(BUILDERS)
    for name in wanted:
        reset()
        BUILDERS[name]()
    print("PROPS_DONE", len(wanted))


main()
