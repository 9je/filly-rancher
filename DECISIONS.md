# Decisions

One line of reasoning per call. Newest at the bottom.

- 2026-10-22 -- Engine: installed Godot is 4.5.2 (pinned in tools/bin, matching 4.5.2 export templates installed incl. Windows/Linux); latest stable is 4.7.2. Upgrade is scheduled as the first build milestone (fetch 4.7.2 + templates, re-import, full suite green) rather than done during setup, because a two-minor jump under a 1647-test suite is a migration that needs its own gate and rollback point.
- 2026-10-22 -- .claude/worktrees/ gitignored instead of committed: it holds a stale agent git checkout, not project content.
- 2026-10-22 -- No references/ folder exists (owner confirmed). The visual target is the existing pony models plus the G4 show look as written in RESEARCH.md section 5; screenshots are compared against pony renders, not invented references.
- 2026-10-22 -- Blender MCP tools are not connected in this session. Meshes are modelled, UV'd, textured and exported to .glb by headless Blender Python scripts (tools/bin/blender, tools/*.py), which is the same pipeline with the advantage of being reproducible from the repo.
- 2026-10-22 -- An offscreen xvfb render of the ranch was declined by the owner mid-audit; the audit's visual verdict therefore rests on the owner's 2026-09-04 playtest and code reading, and renders resume at milestone reviews.
