# Playtest fix: the loading screen

## The note

> "No loading screen after New Game. I thought it froze."

The order: a loading screen with visible progress for New Game, Load and area transitions,
using threaded loading. Nothing may freeze the screen for more than half a second without
feedback.

## Root cause, measured

`TitleScreen._enter_world()` called `change_scene_to_file("res://world/ranch.tscn")`. That
loads the scene file on the main thread, then the ranch's `_ready()` builds the whole valley
before the next frame can be drawn. Measured by the test below on the owner's machine (RX 9070
XT, quiet machine, real time):

| transition | time to playable | longest single frozen frame | loading screen |
|---|---|---|---|
| New game (title to creator) | 17.2 s | **11.84 s** (plus 1.24 s, 1.13 s, 0.58 s) | none |
| Load game (pause menu) | 12.7 s | **9.46 s** | none |
| Continue (title) | 12.5 s | **9.28 s** | none |
| The lift (Depot to the Rainbow Factory) | 1.1 s | 0.68 s | none |

Where the time went, step by step through `Ranch._ready()` (timestamps printed between its
statements, windowed, first boot; this run was on a busy machine, so the absolute numbers are
about 1.5x the quiet ones, the shares are what matter):

| step | time |
|---|---|
| `ranch.tscn` loaded on the main thread (inside `change_scene_to_file`) | 2.0 s |
| terrain heightfield and collider | 0.4 s |
| region dressing (Everfree, meadow, lake, orchard) | 2.0 s |
| region fences | 1.0 s |
| buildings (barn, farmhouse, Depot, Palace...) | 1.1 s |
| props (115 Kenney / Sweet Apple Acres props) | 3.1 s |
| **the herd, `spawner.populate()`, 49 ponies** | **16.0 s** |
| settle frames and the pen containment probe | 3.2 s |
| menus, the cast (Marigold, Tumble...), self-checks | 2.3 s |

The herd was the big one, and inside it one call: `PonyLod.apply()`, the runtime LOD chain
for every pony mesh. `ImporterMesh.generate_lods()` measured **0.4 to 1.2 s per pony**, on the
main thread, inside every spawn. It is skipped under `--headless` (which is why every headless
gate boots in a few seconds and nobody saw it). Its cache never hit: it was keyed by the
mesh's instance id, and a donor scene is reloaded once the last pony holding its original
meshes has swapped them for LOD'd copies, so every pony got fresh ids and rebuilt her chain
from scratch.

## The fix

1. **`game/ui/loading_screen.gd`, new.** `LoadingScreen.change_scene(tree, path, look)` puts a
   full-screen layer over everything (layer 120, survives the scene change because it lives
   under the root), loads the next scene with `ResourceLoader.load_threaded_request`, instances
   it on a `WorkerThreadPool` task, and swaps with `change_scene_to_node`. The arriving scene
   may `claim()` the screen, `report(fraction, caption)` its own boot steps, and `release()` it
   when the player can play; one that does not claim it is shown as soon as it is in. While it
   is up the screen swallows input and turns off 3D drawing of the root viewport (the world
   behind an opaque screen is never seen, and drawing it made every mesh read in the boot wait
   on the render thread). The look: the creation screen's show-style sky with drifting clouds
   and rolling hills, the Fredoka title, a wooden pill bar filling with a rainbow and a star
   riding its front edge, a caption for the step and the percentage. Going up to the Factory
   the same screen is dusk purple, and the bar is still a rainbow.
2. **Every transition uses it:** New game and Continue (`title_screen.gd`, interactive only;
   an automated boot changes scene exactly as before), the pause menu's Load game and the
   placement ending's reload (`ranch.gd`, was `reload_current_scene()`), the lift up
   (`ranch.gd`) and the ride back down (`factory_run.gd`).
3. **The ranch boot is paced (`ranch.gd`).** `_boot_beat(fraction, caption)` reports the step
   and, if the boot has held the main thread for 100 ms, pauses the tree for one frame so only
   the loading screen moves. The long loops in other files got paced twins with the same body
   (`Spawner.populate_paced`, `Props.build_paced`, `RegionDressing.dress_paced`,
   `People.populate_paced`); the plain versions call the same body with no pace, so every gate
   and test runs the exact code it did. The dressing's paced run first does a dry pass to list
   the models and warms them one per step (a region's first use of a model was the second-long
   part); a GUT test checks it builds the identical valley. No screen up (every gate, every
   headless run): no beat ever yields.
4. **`PonyLod` off the main thread (`pony_lod.gd`).** The cache is keyed by the mesh's resource
   path, and a mesh not yet in it is decimated on a `WorkerThreadPool` task; the pony is drawn
   at full detail for the frame or two until her chain is ready and is then moved onto it.
5. **The Factory (`factory_run.gd`)** claims the screen, takes a frame before and after
   building its rooms, steps the bar for each pony it casts, and lifts the screen on the tour's
   first step.

## The test

`game/test_input/test_loading.gd`, run with `tools/run_input_tests.sh loading` (marked
`## INPUT_TEST_REALTIME`, so the runner leaves out `--fixed-fps`: it measures wall-clock time).
It plays from the real title screen with RealInput only:

1. **New game**: clicks New game; then This is me; then the letter's Close.
2. **Load game**: Escape, Save game, Load game.
3. **Continue**: launches the title again, clicks Continue.
4. **The lift**: writes the save a player has on Color Day morning (the ranch from steps 1 to
   3 plus the `invited` and `color_day` flags; playing to the invitation by hand is hours),
   launches the title, Continue, walks to Marigold, presses E, reads to the choice and clicks
   "Let's go.".

**The method.** Every `SceneTree.process_frame` the test takes the wall clock and what the
screen shows (is the loading screen up, its bar's value, its caption). A frame's stall is its
gap minus the run's median gap (on the GPU about 4 to 16 ms; the median absorbs a slow renderer
or a busy machine). A stall over 0.5 s fails unless the loading screen was on the frozen picture
and its bar had moved by the next frame (or the screen had finished). Each transition must also
show the screen at all, with at least three bar values. Picking the pony is a menu button, so
it only has to have no freeze. The test captures one frame of each look into
`build/playtest_evidence/loading/`.

### Before (v1-overhaul 26ce63f, the test and harness only)

```
INPUT_TEST_LOADING new game: title -> creator: 17.2 s, 273 frames, median frame 8 ms, worst stall 11.84 s, 4 stalls over 0.5 s (4 with no moving loading screen, worst 11.84 s), loading screen seen=false with 0 bar values
INPUT_TEST_LOADING load game: pause menu -> the ranch: 12.7 s, 255 frames, median frame 9 ms, worst stall 9.46 s, 2 stalls over 0.5 s (2 with no moving loading screen, worst 9.46 s), loading screen seen=false with 0 bar values
INPUT_TEST_LOADING continue: title -> the ranch: 12.5 s, 276 frames, median frame 8 ms, worst stall 9.28 s, 2 stalls over 0.5 s (2 with no moving loading screen, worst 9.28 s), loading screen seen=false with 0 bar values
INPUT_TEST_LOADING the lift: Depot -> the Rainbow Factory: 1.1 s, 36 frames, median frame 6 ms, worst stall 0.68 s, 1 stalls over 0.5 s (1 with no moving loading screen, worst 0.68 s), loading screen seen=false with 0 bar values
INPUT_TEST_FAILED test_loading new game: title -> creator: 4 freeze(s) over 0.5 s with no moving loading screen (worst 11.84 s) | load game: pause menu -> the ranch: 2 freeze(s) over 0.5 s with no moving loading screen (worst 9.46 s) | continue: title -> the ranch: 2 freeze(s) over 0.5 s with no moving loading screen (worst 9.28 s) | the lift: Depot -> the Rainbow Factory: 1 freeze(s) over 0.5 s with no moving loading screen (worst 0.68 s)
```

### After

```
[loading] INPUT_TEST_LOADING new game: title -> creator: 12.2 s, 1049 frames, median frame 4 ms, worst stall 0.35 s, 0 stalls over 0.5 s (0 with no moving loading screen, worst 0.00 s), loading screen seen=true with 65 bar values
[loading] INPUT_TEST_LOADING new game: This is me -> the ranch: 0.3 s, 36 frames, median frame 8 ms, worst stall 0.01 s, 0 stalls over 0.5 s (0 with no moving loading screen, worst 0.00 s), loading screen seen=false with 0 bar values
[loading] INPUT_TEST_LOADING load game: pause menu -> the ranch: 7.5 s, 684 frames, median frame 4 ms, worst stall 0.21 s, 0 stalls over 0.5 s (0 with no moving loading screen, worst 0.00 s), loading screen seen=true with 44 bar values
[loading] INPUT_TEST_LOADING continue: title -> the ranch: 7.0 s, 687 frames, median frame 4 ms, worst stall 0.18 s, 0 stalls over 0.5 s (0 with no moving loading screen, worst 0.00 s), loading screen seen=true with 43 bar values
[loading] INPUT_TEST_LOADING the lift: Depot -> the Rainbow Factory: 1.2 s, 140 frames, median frame 6 ms, worst stall 0.17 s, 0 stalls over 0.5 s (0 with no moving loading screen, worst 0.00 s), loading screen seen=true with 5 bar values
[loading] INPUT_TEST_OK test_loading every transition showed a moving loading screen over every stall
```

No frame anywhere is frozen for more than 0.35 s, loading screen or not, and every way into the
ranch is 30 to 40 per cent quicker. On a heavily loaded machine (load average 20, other Godot
runs alongside) single steps still reach 0.6 to 0.9 s, always under a loading screen whose bar
moves across them, which the test allows.

Also run: `tools/run_input_tests.sh first_pony` passes; `tools/playthrough.sh` PLAYTHROUGHS_OK 5;
GUT test_region_dressing (with the new paced-equals-plain test), test_title_screen,
test_spawner, test_spawner_seed, test_props, test_people, test_factory_run, test_ranch_creation,
test_ranch_load: 92 of 92 pass; the headless ranch gate prints RANCH_OK.

## Notes

- `tools/run_input_tests.sh`: a test file with a `## INPUT_TEST_REALTIME` line runs without
  `--fixed-fps 60`; `FILLY_INPUT_VERBOSE=1` prints every `INPUT_TEST_*` line.
- `FILLY_LOADING_TRACE=1` makes the loading screen print each step with its time.
- The fading screen lets clicks through, so a click on the creator that lands during the fade
  is not eaten (test_first_pony found that one).
- The test reads `Ranch.boot_done` (set when the boot is finished and the screen released).
