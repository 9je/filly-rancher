# Decisions

One line of reasoning per call. Newest at the bottom.

- 2026-10-22 -- Engine: installed Godot is 4.5.2 (pinned in tools/bin, matching 4.5.2 export templates installed incl. Windows/Linux); latest stable is 4.7.2. Upgrade is scheduled as the first build milestone (fetch 4.7.2 + templates, re-import, full suite green) rather than done during setup, because a two-minor jump under a 1647-test suite is a migration that needs its own gate and rollback point.
- 2026-10-22 -- .claude/worktrees/ gitignored instead of committed: it holds a stale agent git checkout, not project content.
