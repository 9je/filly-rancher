# Sprint resume (re-read this after any compaction, not the big docs)

Sprint: P8, plan in docs/sprint-plan-2026-11-08.md. Branch v1-overhaul.
Status: owner said go 2026-11-08: ONE NON-STOP SWEEP S0 to S10, no owner gates; Fable stands in at each check.

Current batch (2026-11-08 evening): S0-S1 done; S4/S5/S8/S9/S10 code in, renders pending.
Agent lane (worktree, Opus): S2 core loop + S3 catching, not back yet.
Uncommitted on purpose until renders are looked at: project.godot shadow settings, toon.gdshader
(stepped shadow, dither include), outline/pony_eye shaders, dither.gdshaderinc, ranch.tscn
(env, sun, NightLights, SkyEvents nodes), sky_rig.gd (moon), night_lights.gd, sky_events.gd,
camera_rig.gd (dither), test_sky_rig.gd, look_world.gd, beam_low_shot.gd.

Next steps:
1. Look at $SCRATCH/look_after (day/night) and $SCRATCH/checks (creator, beam, toast, spike,
   flank, race, derpy, rainboom); fix, then commit the lighting batch.
2. Capture key art (key_art_shot.gd) into game/assets/ui/loading_ranch.png.
3. Merge the agent's S2/S3 branch (review diff, rerun its tests, parse sweep).
4. Then: Depot/Market on the kit with portraits (S5), town relayout (S7), hair shading (S6).
5. tools/parse_sweep.sh before each commit batch; commit only on green tests.

Rules that bite: no em dashes; tick only with a render of the owner's situation; suite in the
background on a snapshot, never blocking a commit; no bot playthroughs; at most 2 agents
(Opus 5.5, Fable for acceptance only); Godot test runs sandboxed under XDG_DATA_HOME; never
end a turn with open work and nothing running. Owner pronouns: they/them.

Owner's save to resume from: slot_0.json (2026-11-08 14:58), at Color Day; ./play.sh keep.
