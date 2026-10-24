#!/usr/bin/env python3
"""Drop Godot import caches older than their source asset, so the next import rebuilds them.

WHY (2026-10-23): Fluttershy, Twilight and Rainbow Dash were re-exported after their first
import, and Godot kept serving the old cached scene, which had the eyeballs hanging off the
back of the head. Every fresh checkout imported correctly, so the bug lived only in the
working copy the owner plays from. Run before launching or exporting (play.sh does).
Prints how many cache files it removed.
"""
import glob, os, re, sys

game = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "game")
os.chdir(game)
removed = 0
for imp in glob.glob("assets/**/*.import", recursive=True):
    src = imp[: -len(".import")]
    if not os.path.exists(src):
        continue
    text = open(imp, errors="ignore").read()
    for m in re.finditer(r'"(res://\.godot/imported/[^"]+)"', text):
        cached = m.group(1).replace("res://", "")
        if os.path.exists(cached) and os.path.getmtime(src) > os.path.getmtime(cached) + 1:
            base = re.sub(r"\.(scn|ctex|res)$", "", cached)
            for f in glob.glob(base + "*"):
                os.remove(f)
                removed += 1
print("STALE_IMPORTS_REMOVED %d" % removed)
sys.exit(0)
