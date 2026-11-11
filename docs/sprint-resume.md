# Sprint resume (re-read this after any compaction, not the big docs)

Sprint: P9, plan in docs/sprint-plan-2026-11-10.md. Branch v1-overhaul, local commits only.
Owner playtested 2026-11-10 (docs/playtest-2026-11-10.md, 76 items) and said go on overnight
work. Status of every item: docs/playtest-2026-11-10-ledger.md.

THE RULE: FIXED needs a looked-at frame from the real scene reached the owner's way. Tests
alone never tick an item. Three items came back after tests ticked them (74, 75, 26).

Lanes: me on W1 then W2 in the main checkout; ONE Opus 5.5 worktree agent on W3 then W4.
Renders on the GPU via headless weston (memory gpu-headless-renders). Parse sweep per batch.

Previous sprint (P8, AAA gate rounds 1-8) notes: docs/fable-aaa-round*-2026-11-09.md and
docs/playtest-2026-11-08-ledger.md.

## Status 2026-11-11 00:20 (Lane A)
- W1 (mine) done to PARTIAL/FIXED: 1 play with Drifters, 2 objective, 3/5/6 event pacing, 4 rest till
  nightfall, 26 Tumble lines, 27 beam scenery, 29 pen bystanders, 37 talk prompt, 38 sell tip,
  74 factory pause, 75 run toggle.
- W2 (mine): 7 opening shot, 8 posters, 9 NPC routes, 10 staff door, 11/12/83 Collectors can see
  (exclude-copy bug), 13 factory collision, 14/17/85 objective card + beacon in the Factory,
  15 choice text, 16 Tumble via hatch, 18 lever, 19 colour, 21/22 Heat gauge, 23 corral,
  24 ending results card, 25 Static's talk. Evidence in build/p9_evidence/.
- Lane B round 1 (W3) cherry-picked (0da0eb6..82e481e as dd484a0 range); my review notes in the
  ledger (49 Scootaloo portrait still wrong, 41 cost pop overlaps title, 48 pace pill reworked).
- Lane B round 2 (W4 art/rendering) running in a worktree; it uses weston socket filly-wl-b,
  mine is filly-wl-a (scratchpad scripts). Review its frames before cherry-picking.
- A full suite on the merged snapshot was started ~23:43 (task bthj71yjj).
- Probes: scenes/test/factory_guide_shot.gd (modes reveal, lights_out), play_pen_shot.gd,
  heat_shot.gd, ending_shot.gd, laneb_*.gd.

## Status 2026-11-11 02:20 (Lane A)
- Lane B round 2 (W4) cherry-picked (474ad02..90545f3); review fixes a68b606 (Kerfuffle index
  stability, Marigold's line moved into its source).
- Suite on 3a6dc53: 2296/2296. Input tests: camera_terrain, pen_upgrade, loading, factory_solid
  pass; first_pony, catch_card, find_market, scale fail and failed before this sprint.
- Lane B round 3 (76 tail, 39 talk box, 71 prompt over faces, 30 pile-up, 53 marks, 31, 61, 57)
  running in a worktree; review its frames before cherry-picking.
