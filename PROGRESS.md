# Progress

## Done
- Setup: branch `v1-overhaul`, MISSION.md, CLAUDE.md, DECISIONS.md.
- Phase 1: AUDIT.md. Baseline suite on 4.5.2: 1647/1647.
- Phase 2: RESEARCH.md.
- Phase 3: GDD.md, STORY.md.
- Phase 4: PLAN.md.
- M0.1: Godot 4.7.2 (templates installed, pins updated in setup_env.sh, CI and pipeline.md). Suite 1650/1650 on 4.7.2. GUT stays 9.5.0 (see DECISIONS.md).
- M0.2: Events autoload.
- M0.3: toon, outline, eye, hidden and vignette shaders; ToonStyler; the `dread` shader global. WorldTone is drafted but not yet in a scene.
- M0.4: generator v2 (PonyLook, DonorTable from tools/make_donors.py, PonyGenerator, MarkComposer, PonyPaint); the spawner, Pony and PonyInstance run on it. 14 tests.
- M1.1 in progress: 17 new clips authored in tools/author_anims.py and verified by eye on bonbon's contact sheets (tools/anim_sheet.py + anim_sheet_tile.py, Cycles CPU, headless). PonyFace (runtime blink, ears, brows, jaw, look) is drafted.

## Next
- Re-export all 38 donors with the new clips (tools/convert_roster.sh --only <donors> --force).
- Add the trot band to gait.gd; build an AnimationTree, or a clip router in pony.gd, for the new states.
- M0.5 (remaining): global renames (Company, regions, player default name), drop the Twilight voice clip, stock-only spawning. Pony Book, the board and letters close the de-canon in M1.
- M0.6: shot capture tool.

## Known issues
- The owner declined an offscreen render during the audit; renders resume at milestone reviews.
- Blender MCP is not connected; the headless Blender scripting pipeline is used instead.
- The player still uses the legacy StockTint path until the customizer rebuild (M1.6).
- Headless runs skip the toon shader swap (a dummy-renderer limitation, see DECISIONS.md).
- The rear clip's top frame is clipped in the sheet camera; check the pose in-engine.
