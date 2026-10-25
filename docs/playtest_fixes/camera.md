# Playtest fix: the camera under the terrain

**The note** (owner, real-hardware playtest): "The camera showed under the terrain in places."

**The order:** camera collision so it never clips into terrain or buildings, and a test that
sweeps the camera around the map checking it never goes below the terrain surface.

## Root cause

Two faults, both measured by the new test before anything was changed. The first is the one
the owner saw.

1. **The arm was a physics tick late.** `SpringArm3D` works out how long the camera arm can be
   only in the physics step, 60 times a second. The mouse turns the arm in `_unhandled_input`
   on every rendered frame. On a monitor faster than 60 Hz, the frames between two ticks are
   drawn with this frame's pitch and the last tick's length. Look up quickly (which swings the
   lens down behind her) and the lens goes through the ground on its old, long arm for a frame
   or two before the arm catches up. A typical case: pitch 30, zoom 6.5, the ground is 2.90 m
   along the arm, but the arm is still 5.33 m from the last tick. The lens ends up **1.02 m
   under flat grass**, and the frame shows the underside of the world (`shots/hill_top_before.png`).
   It happened at every stop on the map and in the Factory too (`shots/factory_landing_before.png`:
   the underside of the floor). Every earlier camera gate ran one rendered frame per physics
   tick, which hides this completely. That is why the new test runs at 144 fps.
2. **A ray has no size.** The arm probed with a ray and backed off 0.2 m along that ray, and
   the shoulder offset had its own ray with 0.1 m of skin. When the arm meets the ground at a
   grazing angle, 0.2 m back along it is only centimetres off the surface. A lens next to a wall
   running parallel to the ray had no clearance at all. The near plane cut into the grass
   (`too_close_to_ground`) and into walls (`near_plane_in_*`, about 9,000 frames).

There was also a third, smaller fault: **the map's boundary walls stopped at y = 3 m.** On the
east edge's high ground her head is already above that, so the arm swung over the wall and the
lens hung outside the map with no ground under it (339 frames `outside_map`).

Jolt was checked as a suspect, and it is not the cause: its ray and shape casts against the
terrain trimesh are correct. It does have one quirk that matters to the fix. A Jolt
`cast_motion()` that starts already touching something ignores that thing and passes
straight through it (measured: a wall 0.05 m from the pivot left the mount 3.5 m out on the
far side).

## The fix

`game/actors/player/camera_rig.gd` (see `LENS_RADIUS` and the functions it points to):

- **The lens is a ball of 0.25 m and it is placed on every rendered frame.** `_process()`,
  after this frame's look input and before the draw, sweeps the ball from the pivot out along
  the arm (`_resolve_arm()`). It then sweeps from the mount out along the shoulder offset
  (`_room_for()`). The lens stops where the ball first touches anything. `SpringArm3D` carries
  the same ball, so its own per-tick answer (`get_hit_length()`, which ranch.gd's camera probe
  reads) agrees with what is drawn.
- **Jolt's start-inside quirk is handled** (`_sweep_fraction()`). The start point is checked
  first. If the full ball already touches something there, the sweep falls back to smaller
  balls, and if none fits it answers 0.
- **When her head is inside something** (the pivot is at 1.45 m and her capsule stops at
  1.3 m, so she can walk under an eave or a low bough that the pivot is then inside), the ball
  is first swept up from the middle of her capsule. The arm is then swept from wherever that
  stopped. The lens is always somewhere a ball can reach from her body without passing
  through anything.
- **A last floor:** the lens is never left less than 0.25 m above the triangle the terrain
  actually draws under it. This uses the new `Terrain.surface_height_at()`, which is the
  mesh's own triangle and not the smooth `height_at()`. The Terrain joins group `terrain` so
  the rig can find it. A scene with no terrain, such as the Factory, relies on the sweeps.
- `game/world/terrain.gd`: the boundary walls are now 16 m tall (top at y = 13), above the
  highest point the lens can reach (about 9.5 m).
- The `ShoulderProbe` RayCast3D node is gone from `camera_rig.tscn`. The ball sweep replaces it.

## The test

`game/test_input/test_camera_terrain.gd`, run with `tools/run_input_tests.sh camera_terrain`.
It drives the real game through `RealInput` only. It starts a fresh game from the title screen,
then walks with W held and steers with the mouse, backing off and sidestepping when blocked.
The route covers 27 stops: the yard, ramp, interior, back wall and side wall of the Barn,
Farmhouse, Market and Depot, under a tree, the town road, a town house wall, the Palace front,
the highest hill top, the steepest slope and the deepest valley (found from the terrain's own
height function), the map edge on its highest ground, and under a far tree. At every stop the
mouse sweeps 12 yaw steps through the full pitch range both ways, at the widest, default and
tightest zoom (zoom actions). Mouse motion goes out on every rendered frame, at 144 fps (the
`## fixed-fps: 144` header, which the runner now reads).

A watcher node runs after every other `_process` and checks every frame. The lens must be
at least 0.2 m above the terrain's drawn triangle, with all four near-plane corners above it,
inside the map, not inside a solid prop or building collider, with no collider cutting its
near plane, and not through anything on the rig's own legs. Point "inside" queries are skipped
for trimesh colliders: those are open shells, and Jolt's guess at their inside was wrong next
to a trunk the picture shows from outside. The test saves the frame where the lens was lowest
at each stop, plus the first wall fault.

`game/test_input/test_camera_factory.gd` does the same inside the Rainbow Factory's landing.
It loads the scene the way the cloud lift does and then plays it with real input.

### Before (the code as it was, v1-overhaul 848f48c, 144 fps)

```
INPUT_TEST_FAILED test_camera_terrain 11343 of 198395 frames had the camera under or inside the world
  kind too_close_to_ground: 749 frames   kind under_terrain: 371 frames   kind outside_map: 339 frames
  (plus about 9,900 frames of the near plane in or through walls and props)
BAD [yard] under_terrain cam (2.08, -1.02, 11.96) ground 0.000 clearance -1.025 yaw 19 pitch 30.0 zoom 6.5 arm 5.33 arm_leg_hits:Terrain@2.90
BAD [hill_top] under_terrain cam (-31.14, 1.32, 61.55) ground 2.300 clearance -0.982 pitch 30.0 zoom 6.5 arm 5.11 arm_leg_hits:Terrain@2.82
BAD [steepest_slope] under_terrain cam (28.09, -0.33, 7.95) ground 0.014 clearance -0.342 pitch 30.0 zoom 6.5 arm 5.47
worst per stop: steepest_slope -1.333 m, under_tree_far -1.402, hill_top -1.241, Depot_ramp -1.125, map_edge -0.444
INPUT_TEST_FAILED test_camera_factory 1801 of 6056 frames had the camera under or inside the Factory
BAD [factory_landing] under_terrain cam (0.64, -1.02, 0.45) ground 0.000 clearance -1.025 pitch 30.0 zoom 6.5 arm 5.33
```

Full logs: `build/playtest_evidence/camera/before_144fps.log`, `before_factory_144fps.log`.

### After

```
INPUT_TEST_NOTE checked 180297 frames, 0 bad
INPUT_TEST_NOTE   lowest lens over the ground: 0.250 m (Farmhouse_out, Market_out) ... 0.915 m; every stop >= 0.25
INPUT_TEST_OK test_camera_terrain 180297 frames at 27 stops, the camera never went under the terrain or into a building
INPUT_TEST_OK test_camera_factory 5838 frames, the camera never went through the Factory's floor or walls
```

Full logs: `build/playtest_evidence/camera/after_144fps.log`, `after_factory_144fps.log`.
Pictures, before and after at the same stops (the lowest frame at each):
`build/playtest_evidence/camera/shots/{yard,hill_top,steepest_slope,map_edge,factory_landing}_{before,after}.png`.

The GUT suites still pass: `test_camera_rig`, `test_ranch_world`, `test_player_look`,
`test_terrain` (74 of 74). `test_first_pony` still passes. The ranch's own camera probe now
reads `hit=0.50` against the Palace, where it read 0.55: the 0.25 m ball replaces the 0.2 m margin.

## Found along the way, not fixed here

- **The Factory landing's +Z edge is open.** Walking off it drops her into the void (the test
  saw y -245). An earlier run that walked from the landing toward the welcome room also fell
  (y -63). The Factory test stays on the landing for that reason.
- One launch of the camera test crashed at boot (signal 11 right after "The caller thread can't
  call propagate_notification() on /root"), before the test did anything. The next launch was
  clean. This looks like the threaded renderer or the new loading screen, and it is worth
  watching.
