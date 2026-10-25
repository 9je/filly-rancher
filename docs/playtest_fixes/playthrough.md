# The playthrough driver, rewritten to play through real input

Owner's rule: tests drive the game through real player input (Input.parse_input_event with the
actual keybinds and mouse), never by calling game functions. Any test or playthrough that
bypasses input does not count.

## What counts now

| Tool | What it is |
|---|---|
| `tools/playthrough.sh` | runs `tools/playthrough_input.sh` (all five endings, or the ones named) |
| `tools/playthrough_input.sh` | one fresh game per ending, from the title screen, in the invisible GPU display, `--fixed-fps 60`, saves in a fresh `mktemp -d` each; prints `PLAYTHROUGH_OK <ending>` per ending and `PLAYTHROUGHS_OK 5`; logs `build/playthrough_<ending>.log` and a live, flushed `build/playthrough_<ending>.bot.log` |
| `game/test_input/playthrough_input.gd` | the driver (extends the InputTest base, acts only through RealInput) |
| `game/scenes/test/human_bot.gd` | now a 20 line wrapper: the same brain in its pacing mode (`--minutes=`), so `tools/pacing.sh` and the FIRST_10_MINUTES recording are real-input too |
| `tools/pacing.sh` | runs human_bot in the invisible display (it used to run headless) |
| `tools/smoke_endings.sh` + `game/scenes/test/smoke_endings.gd` | the OLD function-call driver, renamed. NON-COUNTING: kept only because it checks the ending table in seconds |

## What the old drivers bypassed

### `scenes/test/playthrough.gd` (now `smoke_endings.gd`, does not count)

1. Ran headless, so the ranch treated the run as nobody at the keyboard: no title screen, no creator, no Scoop gate, no play clock.
2. `BootIntent.request_new_game()` + `change_scene_to_file(ranch.tscn)`: skipped the title screen and the creator.
3. `BootIntent.driven = true`: the ranch did not change scene for the lift; the driver did.
4. `ranch._v1_tick(0.5)` called every waited frame (the story tick).
5. `People.talk(id)` to start conversations: no walking up, no E.
6. `talk_box.chose.emit(i)` / `talk_box.advanced.emit()`: choices and lines by signal, not keys.
7. `story.set_flag("has_scoop")` when it was missing.
8. Catches: `PonyInstance.create` + `PonyGenerator.generate` + `Storage.store` straight into the bag, no beam; coats FORCED vivid (`from_hsv(h, 0.85, 0.9)`) or pastel; `story.add_var("catches")`.
9. Pens: `PlotSlot.build(pen_grand)` on every slot, free.
10. Penning: `ranch._move_pony_into_pen(slot)`.
11. Blooms: `Pen.bloom_now(inst)` forced.
12. Deliveries: `ranch.deliver_pony(uid)`.
13. Time: `ranch._on_world_phase_changed(DAWN)` to make Color Day come.
14. The lift: `GameState.save_to_slot()`, `FactoryRun.mode = ...`, `change_scene_to_file(factory.tscn)` by the driver.
15. The Factory: `skip_waits = true` / `--factory-fast` (walks teleported the player in `_until_area`, holds skipped, the window instant) and `outcome` set directly (the reveal's choice).
16. Act Three: `act3.act("corral_*")`, `act("dye_vat")`, `act("pylon_*")`, `act("lantern_gate")`: no walking, no night, no hold.
17. Placement: `PathRules.add_heat(story, "spotted")` in a loop to 100, `ranch.run_collection_day()` and `ranch.placement_aftermath()` called directly.

### `scenes/test/human_bot.gd` (old version, replaced)

1. `BootIntent.bot/driven = true` + `change_scene_to_file(ranch.tscn)`: no title screen; ran headless.
2. Movement and buttons by `Input.action_press/action_release` (no InputEvent, so `_input`/`_unhandled_input` never saw them; analog strength on keys).
3. Camera by `rig.add_look_delta()`.
4. A `NavigationRegion3D` added as a child of the ranch (wrote to the game's scene tree).
5. Creator: `cycle_coat/cycle_mane/cycle_mane_style/cycle_eyes/confirm()`.
6. Letters: `letter_panel.close()`; stray menus: `menu.close()`.
7. Talk: `talk_box.emit_signal("chose", 0)`, `talk_box._accept()`.
8. Mailbox: `pause_menu.confirm()/close_letter()/close()`.
9. Build menu: `move_selection()/confirm()/close()`.
10. Depot: `move_selection()/confirm()/close()`.
11. Market: `sell_everything()/set_tab()/move_selection()/confirm()/close()`.
12. Casino and slots: `set_tab()/move_selection()/confirm()/close()`.
13. The lift: `FactoryRun.mode = ...` and `change_scene_to_file(factory.tscn)` itself.

## How the new driver works

Every ACTION is an InputEvent through `RealInput` (`Input.parse_input_event`):

- movement: the InputMap's own keys for `move_forward/left/right`, `sneak`, `gallop`, `jump`, held and released as key events (a key is all or nothing, so she turns first, then walks);
- the camera: `InputEventMouseMotion` while the cursor is captured. Capture DOES work in the invisible display (`Input.mouse_mode` reads CAPTURED once the ranch is up), so the look keys are only a fallback, and a cursor left uncaptured for 3 s with no menu open is logged as a bug;
- the Scoop: the right mouse button held while the crosshair is on the pony;
- E (`interact`) for every prompt, held for the holds (pylons, corral gates, the Factory's hatch, Clover's stall, the lever, Tumble at the window);
- talk: E per line (the first E finishes the reveal), the number key of the choice;
- menus by keyboard: arrow keys until the menu's selected row is the wanted one, Enter, Escape. Build menu, Market (Sell everything, Buy tab), Depot (Deliver, and Up to Yes on a named pony), letters, the epilogue;
- the creator: arrows and Enter on a swatch, then a mouse click on "This is me"; the title screen's "New game" by mouse click.

It READS the game the way a person reads the screen: positions, the HUD prompt, `current_interaction()`, menu rows and the selected index, story flags and vars (to know which branch it is on, what a contract wants, whether a Collector's lantern sees the next step), coat colours. It never WRITES: no `set_flag`, no state-changing method, no `--factory-fast`, no teleport, no scene change of its own (the ranch takes the lift itself, the Factory brings her down itself). The navmesh it walks by is baked into its own NavigationServer map, so nothing is added to the game's scene tree.

Time passes only by playing: there is no bed, so a night (pylons, raids) or a collection day (Placement) is waited for by working the ranch.

The brain, per ending: Acts One and Two are the same for all five (talk to whoever has news, build the two free Paddocks, catch, pen, keep the first pen for the two Blooms and ship from the second, Market for food and gear, six deliveries, the invitation, wait for Color Day, the lift). At the window it picks "Sign the contract" (Brightest Rainbow, Gray Gold) or "Get Tumble out" (the other three), read off the button text.

- Brightest Rainbow: contracts by coat (pastel, vivid, any), Calm Lamp, nopony Blooms after the reveal; the Jubilee; the lever.
- Gray Gold: the same, but the six ponies furthest along are kept in the pens until five have Bloomed after the reveal.
- Half Light: permits, the four pylons at night, Static, the lift; she never asks Pip, Bramble or Fennel to join.
- Lights Out: one raid (Pip, Fennel), the Dye Vat (Bramble), Blooms, the Lantern Line, the pylons, then Static; in the Works, the hatch, Clover, the lever.
- Placement: raids on the night before a collection day (Heat cools three a dawn), no deliveries, the Collector at dawn; then checks the morning before comes back.

Dev aids, never counted: `--continue` (Continue on the title screen instead of New game; prints `PLAYTHROUGH_DEV_OK`, never `PLAYTHROUGH_OK`) and `--stop-at=<milestone>` to cut a checkpoint.

## Game bugs the real-input bot found

1. **FIXED: no everyday Drifter could ever be "vivid".** `PathRules.VIVID` was 0.55, but every one of the 24 coat swatches in `data/pony_gen.tres` is at saturation 0.45 or below (22 of them under 0.4). The Factory path's third contract (3 vivid) and the Jubilee order (2 vivid) could only be filled by the rare starry Nightmeadow variant (6% of that region's Drifters); the bot roamed the Nightmeadow for 18 game minutes, day and night, and found none. The old driver hid it by forcing every caught coat to saturation 0.85. Fix: `VIVID := 0.37` (the brightest five swatches, about one Drifter in five), commented in `game/systems/path_rules.gd`. `test_path_rules.gd` uses explicit colours (0.9 and 0.1 saturation) and is unaffected.
2. **NOT FIXED (layout): the Dye Vat hides behind the Market's prompt.** The vat (`Act3World.VAT_AT`, -6, -1.6) stands 4 m from the Market, inside the Market's 6 m E radius, and an Act Three site only speaks when the ranch offers nothing. Over most of the vat's 3.6 m reach the prompt reads "E: Market, sell gems"; the vat answers only from a narrow strip on its far (west) side. A player told "repaint a pony at the Dye Vat" stands at it and gets the Market. Suggested fix: move the vat a few metres west, or let an Act Three site in reach outrank a building's radius.
3. **NOT FIXED (minor): a named pony is judged by the wrong coat on the Factory path.** A delivery's contract check reads `PonyLook.from_stock(inst.stock)`; a named (canon) pony has an empty stock, so she is judged by stock palette swatch 0, not her own coat.
4. **NOT FIXED (design, reported): a Bloomed pony can never leave a pen on the Factory path.** The Depot refuses marked ponies and there is no release verb, so every pre-reveal Bloom (and every Gray Gold Bloom) takes a stall for good. Two free Paddocks full of marked ponies is a real squeeze for a player who Bloomed a lot before the reveal.
5. **NOT FIXED (design, reported): Placement depends on which night you raid.** Heat cools 3 a dawn and a collection day comes every third dawn; three corrals raided two nights early leave Heat at 94 to 97 on the day, which costs a fine and a pony instead of the ending. The bot has to raid on the night before a collection dawn (it reads the ledger's cycle, as a player reads the collection notice).
6. **REPORTED, flaky: `tools/run_input_tests.sh first_pony` on the merged v1-overhaul tip (b9f25c7) passed 1 run in 4** ("attempt 1 failed: she got out of the beam after 0.8s" the other three). Nothing from this branch touches the beam; the playthrough's own catches work on the same build (dozens a run, a few "she got away").
7. **Seen once, cause not pinned: Marigold out of reach at the Depot.** In one Gray Gold run the bot could not get within talk range of Marigold for about three minutes (walks blocked at (6.4, 4.6) and (8.0, 6.7), the Depot's prompt winning at 3.3 to 3.6 m), and before the fix it kept trying and never shipped again. The driver now gives up on somebody it cannot reach and comes back three minutes later (logged as a bug if it happens three times); the next run did not hit it.
8. **Checked, NOT a bug:** Tumble follows at 2.6 m, inside the 2.8 m talk radius, and a companion with nothing to say still wins E when nothing else is offered. It looked as though she would mask the pylons and corrals; she does not (all pylons cut, all corrals slipped by holding E).
9. **Driver lessons, not game bugs:** the build band beside a plot is a hand's width (outside the stakes at 4.32 m, inside the trigger at 4.77 m), and the +z side of Slot1 is Slot2's footprint, so the bot builds from the open side of the column and steps in or out reading the prompt. The old human bot's controller stopped 1.4 m short of every target whatever the walk asked, which is why it "gave up on blocked walks" near the Market.

## Results

Every run: a new game from the title screen (fresh `mktemp -d` save dir), invisible GPU display, `--fixed-fps 60`, `tools/playthrough_input.sh`. Game time is the bot's own clock from boot; wall time is the shell's.

| Ending | Result | Game time | Wall time | Reveal (up the lift) | Climax / ending | Driver revision |
|---|---|---|---|---|---|---|
| brightest_rainbow | PLAYTHROUGH_OK | 0:56:23 | 32:11 | 0:23 | Jubilee at 0:55 | 140ae82 |
| gray_gold | PLAYTHROUGH_OK | 0:40:46 | 23:57 | 0:23 | Jubilee at 0:40, 6 rescued | final |
| lights_out | PLAYTHROUGH_OK | 0:49:37 | 31:19 | 0:22 | lever at 0:49, 3 allies, Clover, 22 rescued | 140ae82 |
| half_light | PLAYTHROUGH_OK | 0:41:30 | 25:07 | 0:23 | lever at 0:41, no allies | 140ae82 |
| placement | PLAYTHROUGH_OK | 1:07:34 | 43:21 | 0:23 | Collector at the 1:07 dawn, then the morning before came back | 140ae82 |

Five of five. The runs went one at a time; the game ran about 1.5 to 1.8 times real time when the machine was quiet and about 0.4 times when other agents were rendering at the same time (the first attempts). The final commit only adds the give-up-and-return rule for an unreachable person, which none of the 140ae82 runs needed.

Timing per ending, roughly: Acts One and Two take 22 to 24 game minutes for every ending (two Blooms and six deliveries by about 0:13, then waiting for Color Day's dawn at 0:20 and walking to Marigold). After the reveal: Half Light about 15 minutes (the first night's four pylons), Lights Out about 25 (one raid, the vat, sixteen Blooms, the Line), Gray Gold about 16, Brightest Rainbow about 31 (the vivid contract is the slow one even at the new threshold), Placement about 44 (the raids wait for the night before the first collection day at 1:00).

Not run to completion: the pacing mode (`tools/pacing.sh`, 70 minutes) and the FIRST_10_MINUTES recording (`tools/record_first10.sh`, which opens a visible window and was not run on the owner's machine). Both now drive this same brain. The pacing mode does not visit the Palace (the old bot played the slots for its novelty log); the casino menus are reachable by keyboard and can be added.

