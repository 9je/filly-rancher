# Filly Rancher

A cozy pony-ranching game with a secret. Catch Drifters across a valley outside Ponyville, pen them, feed them, race them, help them find their cutie marks, and deliver them to the Cloudsdale Weather Corporation's Depot for the rainbow. Then go up to the Rainbow Factory on Color Day and see where the colour comes from.

Built in Godot 4.7.2 (Forward+), in typed GDScript. A fan game: *My Little Pony: Friendship is Magic* belongs to Hasbro, and the Factory's premise is from the fan story *Rainbow Factory*. Not for redistribution. See [CREDITS.md](CREDITS.md).

## Playing

| | |
|---|---|
| Move | WASD (or the left stick) |
| Look | mouse (or the right stick) |
| Beam, catch | hold the right mouse button (right trigger) |
| Interact, talk | E (west face button) |
| Jump / sneak | Space / Shift (south face button / left bumper) |
| Pause, settings, save | Esc (Start) |
| Controls card | H |

Every key can be rebound in **Pause > Settings**, alongside a volume per bus (master, music, ambience, effects, menus, voices), a picture-quality preset, fullscreen and vsync.

### The shape of the game

- **Act One, the ranch.** Marigold gives you the Scoop. Catch, pen, care, Bloom, deliver, pay the ledger.
- **Act Two, the clues.** Postcards in the same hoofwriting. Rainbow Dye named after ponies you delivered. The invitation to Color Day.
- **The reveal.** A tour of the Rainbow Factory, a walkway past Collector lanterns, and a window. Then a choice.
- **Act Three.** Sign on as Senior Steward (contracts, ranks, the Supply Desk, a valley going grey), or run with Tumble and take up the Lantern Line (Heat, raids on Intake Corrals, four weather pylons, the Dye Vat, allies).
- **Five endings:** The Brightest Rainbow, Gray Gold, Lights Out, Half Light, and Placement. Each plays an epilogue over the valley, a closing letter, and credits, then the save continues in that world.

## Running from source

```sh
./play.sh          # fresh start (the current save is stashed, never deleted)
./play.sh keep     # continue the existing save
```

or open `game/project.godot` in Godot 4.7.2. The engine binary used for everything here is `tools/bin/godot`.

## Tests and checks

```sh
tools/run_tests.sh                 # the full GUT suite (headless, saves isolated)
tools/gut_one.sh test_endings ...  # one or more test files
tools/playthrough.sh               # headless playthroughs to all five endings
tools/playthrough.sh lights_out    # just one
tools/capture_shots.sh DIR --set=lineup,factory   # offscreen screenshots (xvfb)
```

`tools/playthrough.sh` plays a new save to an ending through the game's own verbs: conversations, catches into the Scoop's bag, pens, Blooms, deliveries, dawns and collection days, the Rescue path's pylons, raids, Dye Vat and Lantern Line, and both trips up the lift to the Factory. It prints `ENDING_REACHED <id>` and `PLAYTHROUGH_OK <id>` for each.

## Building

```sh
tools/bin/godot --headless --path game --export-release "Linux"   ../build/filly-rancher-linux.x86_64
tools/bin/godot --headless --path game --export-release "Windows" ../build/filly-rancher-windows.exe
build/filly-rancher-linux.x86_64 --headless --quit-after 300       # smoke-launch the export
```

Export templates for 4.7.2 must be installed (`~/.local/share/godot/export_templates/4.7.2.stable`). Both presets embed the pack in the binary.

## Layout

| Path | What |
|---|---|
| `game/world/` | the ranch (`ranch.tscn`), the Rainbow Factory (`factory.tscn`, `factory_run.gd`, `factory_interior.gd`), the Rescue path's places (`act3_world.gd`) |
| `game/systems/` | rules with no scene: story (`story.gd`, `story_v1.gd`), Act Three (`path_rules.gd`), endings (`endings.gd`), economy, ledger, generator, settings |
| `game/actors/` | ponies, the player, NPCs |
| `game/ui/` | HUD, menus, the creator, the epilogue |
| `game/data/dialogue_src/` | conversations as text; `python3 -I tools/make_dialogue.py` compiles them |
| `game/test/` | GUT tests |
| `tools/` | test, playthrough, screenshot, Blender prop and model pipelines |

Design documents: [GDD.md](GDD.md), [STORY.md](STORY.md), [PLAN.md](PLAN.md); decisions in [DECISIONS.md](DECISIONS.md); progress in [PROGRESS.md](PROGRESS.md); the review in [REVIEW.md](REVIEW.md).
