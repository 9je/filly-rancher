#!/usr/bin/env python3
"""Write game/data/donors.tres: every SFM pony model the generator may build a pony from.

Read straight out of the converted .glb files (their glTF JSON chunk), so the table cannot
drift from the models: a donor's race comes from whether it has horn or wing meshes, and
its mane/tail surfaces from its material names. Run after tools/convert_roster.sh:

    python3 -I tools/make_donors.py

The five tier-a Blender-pack models are never donors (distinct rig, untintable flat
materials, and the most recognisable canon meshes); see DECISIONS.md.
"""
import json
import os
import struct
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PONIES = os.path.join(ROOT, "game", "assets", "converted", "ponies")
OUT = os.path.join(ROOT, "game", "data", "donors.tres")

TIER_A = {"twilight", "rainbowdash", "fluttershy", "applejack", "rarity"}
# Surfaces that are a canon character's signature accessory: hidden on every generated pony.
ACCESSORIES = {"hair_clip", "clothes"}
# Second-tone mane surfaces: back layers and streaks.
MANE2 = {"hairback", "hairbacklower", "maneside", "ss_hairy"}
# Donors whose own eye texture is a signature (wall-eyed): borrow a neutral pair instead.
EYE_FROM = {"derpyhooves": "pokeypierce"}
# Foal-proportioned donors (the Crusaders and friends): read as fillies even at full scale.
FOALS = {"applebloom", "scootaloo", "sweetiebelle"}


def gltf(path):
    with open(path, "rb") as f:
        f.read(12)
        length, _ = struct.unpack("<II", f.read(8))
        return json.loads(f.read(length))


def role(name):
    n = name.lower()
    if n in ACCESSORIES:
        return "hide"
    if "tail" in n:
        return "tail"
    if "hair" in n or "mane" in n:
        return "mane2" if n in MANE2 else "mane"
    return None


def main():
    rows = []
    for fn in sorted(os.listdir(PONIES)):
        if not fn.endswith(".glb"):
            continue
        pid = fn[:-4]
        if pid in TIER_A:
            continue
        j = gltf(os.path.join(PONIES, fn))
        mats = [m.get("name", "") for m in j.get("materials", [])]
        has_horn = "horn" in mats
        has_wings = "wings" in mats
        race = "unicorn" if has_horn else ("pegasus" if has_wings else "earth")
        mane, mane2, tail, hide = [], [], [], []
        for m in mats:
            r = role(m)
            if r == "mane":
                mane.append(m)
            elif r == "mane2":
                mane2.append(m)
            elif r == "tail":
                tail.append(m)
            elif r == "hide":
                hide.append(m)
        if not mane or not tail:
            print("skip %s: mane=%s tail=%s" % (pid, mane, tail), file=sys.stderr)
            continue
        rows.append({
            "id": pid, "race": race, "mane": mane, "mane2": mane2, "tail": tail,
            "hide": hide, "eye_from": EYE_FROM.get(pid, ""), "foal": pid in FOALS,
        })

    def arr(xs):
        return "PackedStringArray(%s)" % ", ".join('"%s"' % x for x in xs)

    entries = []
    for r in rows:
        entries.append(
            '{\n"eye_from": "%s",\n"foal": %s,\n"hide": %s,\n"id": &"%s",\n"mane": %s,\n'
            '"mane2": %s,\n"race": &"%s",\n"tail": %s\n}' % (
                r["eye_from"], "true" if r["foal"] else "false", arr(r["hide"]), r["id"],
                arr(r["mane"]), arr(r["mane2"]), r["race"], arr(r["tail"])))
    text = (
        '[gd_resource type="Resource" script_class="DonorTable" load_steps=2 format=3]\n\n'
        '[ext_resource type="Script" path="res://systems/donor_table.gd" id="1_donors"]\n\n'
        '[resource]\nscript = ExtResource("1_donors")\n'
        "donors = Array[Dictionary]([%s])\n" % ", ".join(entries))
    with open(OUT, "w") as f:
        f.write(text)
    races = {}
    for r in rows:
        races[r["race"]] = races.get(r["race"], 0) + 1
    print("donors=%d %s" % (len(rows), races))


if __name__ == "__main__":
    main()
