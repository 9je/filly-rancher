# Sprint resume (re-read this after any compaction, not the big docs)

Sprint: P8, plan in docs/sprint-plan-2026-11-08.md. Branch v1-overhaul.
Status: owner said go 2026-11-08: ONE NON-STOP SWEEP S0 to S10, no owner gates; Fable stands in at each check.

Current state (2026-11-08 night): the P8 sweep is done pending the owner's playtest. Both
agent lanes are merged. The ledger (docs/playtest-2026-11-08-ledger.md) holds every item's
status and evidence. A final full suite run was started on 1832ce3.

2026-11-09, THE AAA GATE (owner: "ideally an unbiased fable 5 saying the game looks and feels
AAA should be the goal of this session along with the bug fixes"; asset hunting and Blender
allowed, Equestria throughout). Fable round 1 (docs/fable-aaa-round1-2026-11-09.md): NOT YET.
Fixes landed: the world pass (eb032bc, 26ffa41), the HUD and 2D screens from the UI agent
(442c99c..993581f), news markers (c3f8d96). A second agent is on blackjack court cards, slot
reel blur and the catch moment. Next: render, look, then re-render the full showcase
(scratchpad showcase.sh) and send it to a FRESH Fable with fable_brief.md only; loop until AAA.

If the owner reports back: start a NEW session, read this file and the ledger, and work from
their new list. Open items to carry: 26, 29, 37, 50, 65, 71, 77.

Rules that bite: no em dashes; tick only with a render of the owner's situation; suite in the
background on a snapshot, never blocking a commit; no bot playthroughs; at most 2 agents
(Opus 5.5, Fable for acceptance only); Godot test runs sandboxed under XDG_DATA_HOME; never
end a turn with open work and nothing running. Owner pronouns: they/them.

Owner's save to resume from: slot_0.json (2026-11-08 14:58), at Color Day; ./play.sh keep.
