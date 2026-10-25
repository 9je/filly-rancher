# Playtest fixes (owner's real-hardware playtest, 2026-10-24)

Each note is mapped to its root cause, its fix, and the test that reproduces it.

Each test failed on the code before its fix, and that failing output is recorded. The tests are in `game/test_input/` and play the game through real input only:
- Every action is an `InputEvent` given to `Input.parse_input_event`, built from the project's own InputMap, or a mouse event at a screen position (`game/test_input/real_input.gd`).
- A test boots from the real title screen and clicks New game, just as the export does.
- A test may READ the game to decide what a person looking at the screen would do next. It never calls a game function to act.

Run them with `tools/run_input_tests.sh`. They play in an invisible display (xvfb) but render on the GPU, so nothing opens on the desktop and the mouse is never taken from whoever is at the machine.

Evidence (logs and screenshots) is in `build/playtest_evidence/`.

## Why the old suite missed the first-pony bug

The suite was green and the game was broken, for four reasons that compound.

1. **Every automated run was a run with "nobody at the keyboard".**
   - The GUT suite, the five playthroughs and the pacing bot all ran `--headless`.
   - The game reads a headless display as "no person here" (`TitleScreen.is_interactive()`, `ranch._interactive`).
   - On that answer it skips the title screen and the creator. It also skips the rule that the beam stays dead until Marigold hands over the Scoop (`ranch._apply_beam_recall`: `no_scoop = _interactive and not has_flag("has_scoop")`).
   - So in every test the beam worked from the first frame. None of them played the game the owner played.
2. **They acted through game functions, not input.**
   - The playthrough called `set_flag("has_scoop")` itself (`scenes/test/playthrough.gd:316`) and drove conversations, menus and catches by method.
   - The human-paced bot pressed actions with `Input.action_press` and turned the camera with `add_look_delta()`. Neither is a key or a mouse.
   - A test that grants the Scoop cannot find a Scoop the player never got. A test that presses the action cannot find a prompt that names no key.
3. **Nothing read the prompts.**
   - The onboarding tip a new player sees first read "Hold  on a pony to Scoop her up", with no button named.
   - No test looked at that text; they knew the button.
4. **`Input.is_action_just_pressed` is not the event.**
   - The bug that trapped a player in Tumble's chatter (below) only exists when the same E keypress reaches both the talk box (an input event) and the ranch's interact poll (`Input` state) in one frame.
   - Calling the talk box's `_accept()` directly, as the old bot did, never sends that second half.

## 1. "I could not collect the first pony."

**Test:** `game/test_input/test_first_pony.gd`. A fresh save, played from the title screen with keyboard and mouse, following only the onboarding prompts:
- The bot reads the tip to find out which button to hold, and fails if the tip names none.
- The first beam attempt on the first pony must put her in the bag.

**Root causes (three, all on the path a new player takes):**
1. **The first prompt named no button.**
   - `InputDevice.GLYPHS` had entries for only five actions.
   - `Onboarding.current()` filled `{beam}`, `{launch}` and `{sprint}` from it, and they printed as nothing.
   - "Hold  on a pony to Scoop her up" was the only instruction for the first catch.
   - Two tips also promised keys for things that do not exist: "fire a pony back out of the Scoop", and "Hold {sprint} to gallop" when running is already the default.
2. **The E that closed a conversation opened the next one.**
   - The talk box marks the key EVENT handled, but `ranch._update_interaction()` polls `Input.is_action_just_pressed("interact")` later in the same frame.
   - That poll still says yes, and with the talk box now closed it starts a new talk with whoever is in reach.
   - Tumble follows the player from her first meeting, so every E that ended one of her lines began another: an endless chatter loop on the very spot where the first catch happens.
3. **Before the Scoop, the beam failed silently** (fixed earlier the same day, 877d56d).
   - The horn is locked until Marigold's welcome.
   - A right-click did nothing and said nothing, and Marigold stayed wherever the player had left her.

**Fixes:**
- `InputDevice.hint()` names any action from its live InputMap binding ("Right Mouse", "E", "F", "Ctrl"), with gamepad names when a pad is in use. The dead `launch` and `sprint` tips are replaced or removed, and the feed tip names the treat key.
- `ranch._fresh_interact()`: the press that ended a conversation is spent until the key comes back up.
- A beam press before the Scoop shows a toast, and Marigold walks back over (877d56d).

**Failing before** (`build/playtest_evidence/`):
- With the GLYPHS change reverted: `INPUT_TEST_FAILED test_first_pony the Scoop prompt names no button: 'Hold  on a pony to Scoop her up'` (`fp_glyph.log`).
- With the talk latch removed: `INPUT_TEST_FAILED test_first_pony timed out after 300s`. The bot was stuck in Tumble's chatter (`fp_loop.log`; the first run, `first_pony_before.log`, shows the same).

**Passing after:** `INPUT_TEST_OK test_first_pony caught on the first try` (on the GPU in the invisible display; 1 attempt, at 5.7 m).

## 2 and 4. "Beam selection feels weird." Make targeting forgiving and readable.

**Test:** `game/test_input/test_beam_targeting.gd`. With the Scoop in hand, through real input:
- Aim at empty grass: nobody may be highlighted.
- Aim 0.9 m BESIDE a pony (not on her): she must be the highlighted one before the press.
- Press the right mouse button: the beam must take exactly her.

**Root cause:**
- The beam cast one thin ray from the screen centre. If that missed, it looked for a pony only within 0.5 m of where the RAY LANDED (`GRAB_ASSIST_RADIUS`).
- A crosshair a hair beside a pony 6 m away sends the ray on to the grass 8 m out, so being half a pony off took nothing, and the result depended on what lay behind her.
- Nothing showed what the beam would take: the reticle only changed colour.

**Fix** (`actors/player/magic_beam.gd`, `shaders/outline.gdshader`):
- **Aim assist:** every pony within reach, inside a 12 degree cone round the crosshair and within 1.6 m of its line, that the lens has a clear line to, is a candidate. The one nearest the crosshair wins, and ties go to the nearer pony.
- **Ray priority:** a pony the ray hits directly still wins outright. The old 0.5 m pass remains for loose props.
- **Highlight:** the target is lit before the press:
  - her outline turns gold and thick (a new `highlight` instance uniform on the outline shader, never distance-faded);
  - a pulsing ring sits at her hooves;
  - a gold chevron floats over her head and is drawn over everything, so the pick reads even with the player's own pony or a fence in the way.
- **Grab:** the press takes exactly the lit pony, and the highlight clears once she is held.

**Failing before:** `INPUT_TEST_FAILED test_beam_targeting aimed 0.9 m beside a pony 2.0 m away: she is not highlighted ([])` (`beam_targeting_before.log`).

**Passing after:** `INPUT_TEST_OK test_beam_targeting highlight before the press, aim assist 0.9 m, and the press took her`. Screenshot: `beam_highlight_after.png`.
