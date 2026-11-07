#!/usr/bin/env python3
"""PS13 acceptance packet: for each ledger row, the owner's words, the screenshot tags, and
ONLY the evidence a reviewer may see -- render/file paths and test names pulled out of the
ledger's evidence cell. My explanations, commit messages and notes are left out (PLAN.md PS13).

    tools/ps13_packet.py [--rows 6,18,M] > docs/ps13/packet.md
"""
import os
import re
import sys

LEDGER = "docs/playtest-2026-11-05-ledger.md"

rows_wanted = None
if "--rows" in sys.argv:
    rows_wanted = set(sys.argv[sys.argv.index("--rows") + 1].split(","))

path_re = re.compile(r"build/ps_evidence/[\w./-]+|game/scenes/test/[\w./-]+\.gd|tools/[\w./-]+\.(?:py|sh)")
test_re = re.compile(r"\btest_[a-z0-9_]+\b")

out = ["# PS13 acceptance packet", "",
       "For each item: the owner's words (docs/playtest-2026-11-05.md), the owner's screenshot tags, "
       "and the evidence to judge it by. Judge each MET or NOT-MET from the evidence and the code "
       "alone. A missing render, or a test that does not assert what the owner asked for, is NOT-MET.", ""]
for line in open(LEDGER, encoding="utf-8"):
    if not line.startswith("| ") or line.startswith("| Item") or line.startswith("|---"):
        continue
    cells = [c.strip() for c in line.strip().strip("|").split("|")]
    if len(cells) < 6:
        continue
    item, words, shots, task, state, evidence = cells[:6]
    if rows_wanted and item not in rows_wanted:
        continue
    paths = []
    for p in path_re.findall(evidence):
        p = p.rstrip(".,;)")
        if p not in paths:
            paths.append(p)
    tests = []
    for t in test_re.findall(evidence):
        if t not in tests:
            tests.append(t)
    out.append("## %s" % item)
    out.append("")
    out.append("**Owner:** %s" % words)
    if shots and shots != "--":
        out.append("")
        out.append("**Owner's screenshots:** %s" % shots)
    out.append("")
    out.append("**State claimed:** %s" % state)
    out.append("")
    # Every file in each evidence folder named, so nothing named only by its file name is lost.
    folders = []
    for p in paths:
        d = p if os.path.isdir(p) else os.path.dirname(p)
        if d.startswith("build/ps_evidence/") and d not in folders and os.path.isdir(d):
            folders.append(d)
    for d in folders:
        for root, _dirs, files in os.walk(d):
            for f in sorted(files):
                fp = os.path.join(root, f)
                if fp not in paths:
                    paths.append(fp)
    out.append("**Renders and files:** " + (", ".join(paths) if paths else "none"))
    quotes = [q for q in re.findall(r'"([^"]{12,})"', evidence)]
    if quotes:
        out.append("")
        out.append("**Text quoted in the evidence (the shipped words, or the owner's):** " +
                   " / ".join('"%s"' % q for q in quotes))
    out.append("")
    out.append("**Tests:** " + (", ".join(tests) if tests else "none"))
    out.append("")
print("\n".join(out))
