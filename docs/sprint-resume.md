# Sprint resume (re-read this after any compaction, not the big docs)

Sprint: P8, plan in docs/sprint-plan-2026-11-08.md. Branch v1-overhaul.
Status: owner said go 2026-11-08: ONE NON-STOP SWEEP S0 to S10, no owner gates; Fable stands in at each check.

Current batch (2026-11-08, ~20:15): most of S1-S10 in; ledger docs/playtest-2026-11-08-ledger.md
has the statuses. S2/S3 (agent) merged at ca3b40c. S7 town agent running in a worktree.
Uncommitted: game/systems/cutie_mark.gd (mark on the upper haunch) waiting on the flank render.

Running in the background: stress_pen (then checks3: flank, hall, derpy), a flank/market/depot
check, the mane card re-bake (game/assets/ui/style_icons/mane_*.png, commit them after a look).

Next steps:
1. Look at $SCRATCH/stress/sheet.png and the STRESS line (items 28, 29, 30, 32); fix what shows.
2. Look at the flank render (item 40 mark; item 34 hair; item 33 dither) and commit cutie_mark.gd.
3. Look at the hall (item 56 crowd), Market and Depot renders.
4. When the S7 agent reports: review, merge, parse sweep, focused tests; then recapture the key
   art (key_art_shot.gd -> game/assets/ui/loading_ranch.png) on the new town.
5. Full suite on a snapshot after the S7 merge; fix failures; final ledger pass; report.

Rules that bite: no em dashes; tick only with a render of the owner's situation; suite in the
background on a snapshot, never blocking a commit; no bot playthroughs; at most 2 agents
(Opus 5.5, Fable for acceptance only); Godot test runs sandboxed under XDG_DATA_HOME; never
end a turn with open work and nothing running. Owner pronouns: they/them.

Owner's save to resume from: slot_0.json (2026-11-08 14:58), at Color Day; ./play.sh keep.
