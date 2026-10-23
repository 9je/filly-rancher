#!/usr/bin/env python3
"""Compile game/data/dialogue_src/*.txt into game/data/dialogue/<id>.tres (Dialogue resources).

    python3 -I tools/make_dialogue.py

The source format keeps the writing readable:

    === fennel_intro
    speaker: fennel
    priority: 10
    once: true
    bark: false
    when: {"chapters": [0], "flags_none": ["met_fennel"]}

    start [fennel happy nod] Well now. You'd be the new steward.
      -> two
    two [fennel] I'm Fennel.
      flag: met_fennel
      event: open_board
      * Nice to meet you! -> warm
      * Is it always this sunny? -> sunny !asked_sun
    warm [fennel happy] Likewise.

A node line is `<id> [<who> <mood> <anim>] <text>`: mood and anim optional, `-` skips one.
Indented `-> next`, `flag: f`, `event: e`, and `* text -> next !flag` choices follow it. A
node with no `->` and no choices ends the conversation. `when` is JSON. Lines starting
with `#` are comments. Every generated file is rewritten; stale ones are removed.
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "game", "data", "dialogue_src")
OUT = os.path.join(ROOT, "game", "data", "dialogue")
MOODS = {"neutral", "happy", "sad", "scared", "angry", "blank"}

NODE = re.compile(r"^(\w+)\s+\[([^\]]*)\]\s*(.*)$")
CHOICE = re.compile(r"^\*\s*(.+?)\s*->\s*(\w*)\s*(?:!(\w+))?\s*(?:@(\w+))?\s*$")


def gd(v):
    """A Python value as Godot .tres text."""
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return json.dumps(v)
    if isinstance(v, str):
        return json.dumps(v, ensure_ascii=False)
    if isinstance(v, list):
        return "[" + ", ".join(gd(x) for x in v) + "]"
    if isinstance(v, dict):
        return "{\n" + ",\n".join("%s: %s" % (json.dumps(k), gd(x)) for k, x in v.items()) + "\n}"
    raise TypeError(v)


def parse(path):
    convs, cur, node = [], None, None
    for lineno, raw in enumerate(open(path, encoding="utf-8"), 1):
        line = raw.rstrip("\n")
        s = line.strip()
        if not s or s.startswith("#"):
            continue
        if s.startswith("=== "):
            cur = {"id": s[4:].strip(), "speaker": "", "priority": 0, "once": True,
                   "bark": False, "when": {}, "nodes": []}
            convs.append(cur)
            node = None
            continue
        if cur is None:
            sys.exit("%s:%d: text before the first === block" % (path, lineno))
        indented = line[:1] in (" ", "\t")
        if not indented:
            m = NODE.match(s)
            if m:
                tags = m.group(2).split()
                node = {"id": m.group(1), "text": m.group(3)}
                if tags and tags[0] != "-":
                    node["who"] = tags[0]
                if len(tags) > 1 and tags[1] != "-":
                    if tags[1] not in MOODS:
                        sys.exit("%s:%d: unknown mood %r" % (path, lineno, tags[1]))
                    node["mood"] = tags[1]
                if len(tags) > 2 and tags[2] != "-":
                    node["anim"] = tags[2]
                cur["nodes"].append(node)
                continue
            key, _, val = s.partition(":")
            val = val.strip()
            if key == "when":
                cur["when"] = json.loads(val)
            elif key == "priority":
                cur["priority"] = int(val)
            elif key in ("once", "bark"):
                cur[key] = val.lower() == "true"
            elif key == "speaker":
                cur["speaker"] = val
            else:
                sys.exit("%s:%d: cannot read %r" % (path, lineno, s))
            continue
        if node is None:
            sys.exit("%s:%d: indented line outside a node" % (path, lineno))
        if s.startswith("->"):
            node["next"] = s[2:].strip()
        elif s.startswith("flag:"):
            node["flag"] = s[5:].strip()
        elif s.startswith("event:"):
            node["event"] = s[6:].strip()
        elif s.startswith("*"):
            m = CHOICE.match(s)
            if not m:
                sys.exit("%s:%d: bad choice %r" % (path, lineno, s))
            c = {"text": m.group(1), "next": m.group(2)}
            if m.group(3):
                c["flag"] = m.group(3)
            if m.group(4):
                c["event"] = m.group(4)
            node.setdefault("choices", []).append(c)
        else:
            node["text"] += " " + s
    return convs


def check(conv, path):
    ids = {n["id"] for n in conv["nodes"]}
    for n in conv["nodes"]:
        for target in [n.get("next")] + [c["next"] for c in n.get("choices", [])]:
            if target and target not in ids:
                sys.exit("%s: %s node %s points at missing %r" % (path, conv["id"], n["id"], target))
        for bad in ("—", "--"):
            if bad in n["text"]:
                sys.exit("%s: %s node %s uses a dash the house style bans" % (path, conv["id"], n["id"]))
    if not conv["speaker"]:
        sys.exit("%s: %s has no speaker" % (path, conv["id"]))


def main():
    os.makedirs(OUT, exist_ok=True)
    written = set()
    for fn in sorted(os.listdir(SRC)):
        if not fn.endswith(".txt"):
            continue
        path = os.path.join(SRC, fn)
        for conv in parse(path):
            check(conv, path)
            name = conv["id"] + ".tres"
            if name in written:
                sys.exit("duplicate dialogue id %s" % conv["id"])
            written.add(name)
            text = (
                '[gd_resource type="Resource" script_class="Dialogue" load_steps=2 format=3]\n\n'
                '[ext_resource type="Script" path="res://systems/dialogue.gd" id="1_dlg"]\n\n'
                '[resource]\nscript = ExtResource("1_dlg")\n'
                'id = &"%s"\nspeaker = &"%s"\npriority = %d\nonce = %s\nbark = %s\n'
                "when = %s\nnodes = Array[Dictionary](%s)\n" % (
                    conv["id"], conv["speaker"], conv["priority"], gd(conv["once"]),
                    gd(conv["bark"]), gd(conv["when"]), gd(conv["nodes"])))
            with open(os.path.join(OUT, name), "w", encoding="utf-8") as f:
                f.write(text)
    for fn in os.listdir(OUT):
        if fn.endswith(".tres") and fn not in written:
            os.remove(os.path.join(OUT, fn))
    print("DIALOGUE_OK", len(written))


if __name__ == "__main__":
    main()
