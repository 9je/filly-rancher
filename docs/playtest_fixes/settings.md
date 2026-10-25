# Playtest fix: Settings

## The note

> "Settings UI is awful and hard to navigate."

The order: a clear tabbed menu (Graphics, Audio, Controls, Gameplay), readable text, full
keyboard and controller navigation with a visible focus, Apply and Revert, and a confirmation
timeout for display changes.

## Root cause: what made the old one awful, concretely

There was no settings menu. There were two hand-drawn row lists that happened to edit the
same `Settings` object, and they disagreed about almost everything.

1. **Two different menus behind one word.** The title screen's Settings page had five rows
   (`TitleScreen.SETTING_ROWS`: master, ambience, effects, mouse sensitivity, invert). The
   pause menu's had twenty three (`PauseMenu.SettingRow` plus one row per rebindable key).
   The title screen could not reach graphics, music, voices or keys at all.
2. **One flat list, no grouping.** The pause page put volumes, look, picture quality,
   fullscreen, vsync and twelve key bindings in a single column, scrolled through a
   twelve-row window (`SETTINGS_WINDOW`). Finding "Vsync" meant walking past six volume rows;
   the key rows were off the bottom of the panel.
3. **No real focus.** The rows were Labels inside PanelContainers with a `"> "` caret and a
   tint (`MouseRows.row`). Nothing in them was a focusable Control, so Godot's own keyboard
   and controller focus never landed anywhere; Tab did nothing; the only "highlight" was a
   faint 16 per cent background and a two-character caret.
4. **Invisible affordances for the mouse.** A click on a settings row adjusted it by which
   HALF of the row the pointer was in (`_click_adjust_row`: left half down, right half up).
   No arrow, slider or switch was drawn; a player had to guess.
5. **Every nudge was final.** Each left/right wrote `settings.cfg` immediately (ranch.gd's
   `_on_settings_changed` saves on every emit). There was no Apply, no Revert, no way to try
   something and back out.
6. **Fullscreen with no safety net.** The Fullscreen row toggled the window mode the instant
   it was pressed and saved it. A mode the monitor could not show stayed applied and stayed
   on disk.
7. **Small, low-contrast values.** The title page drew its values at 18 px
   (`SUBTITLE_SIZE`) in 58 per cent white; the footer was text naming keys.
8. **Options missing.** No window mode beyond a fullscreen bool, no resolution, no FOV, no
   frame cap, no controller look speed, nothing on gameplay.

## The fix

One reusable scene, `game/ui/settings_menu.tscn` (`game/ui/settings_menu.gd`,
`class_name SettingsMenu`), opened by both doors: the title screen's Settings row and the
pause menu's Settings row each instance it over themselves and call `open(settings)`. The old
row pages are gone from both (`title_screen.gd` keeps only the swap; `pause_menu.gd` keeps
`Page.SETTINGS` as a door into the new menu so every other page keeps its number).

* **Four tabs**, drawn as gold pills with drawn icons (monitor, speaker, controller, star):
  * Graphics: window mode (windowed / fullscreen / exclusive), resolution, VSync, quality
    preset, field of view, frame rate cap.
  * Audio: master, music, ambience, effects, menus, voices (heard live while adjusted).
  * Controls: mouse sensitivity, controller look speed, invert look, then every key with its
    keyboard key and controller button as keycaps. Keys are rebindable (Enter, press the new
    key; Backspace restores the default; Esc cancels). Beam, look and zoom are shown as fixed.
  * Gameplay: the corner controls reminder chip, the Getting started list, and pausing when
    the window loses focus. Each is wired to something real (`hud.gd`
    `set_controls_chip_enabled` / `set_checklist_enabled`; `ranch.gd` opens the pause menu on
    `NOTIFICATION_APPLICATION_FOCUS_OUT`). FOV and controller look speed reach the camera
    rig in `ranch.gd`'s `_apply_settings`.
* **Every row is a focusable Button** with a gold three-pixel focus ring and glow; tabs and
  the Back / Revert / Apply buttons carry the same ring. The focus map is explicit (tab strip
  to first row, rows in a column, last row to Apply), so keyboard (arrows, Tab, Enter, Esc),
  controller (d-pad or left stick, A, B, LB/RB) and mouse (hover moves focus, click, drag)
  all drive one highlight. Q/E or LB/RB switch tabs from anywhere.
* **Drawn controls**: sliders with a gold fill and knob (click or drag), on/off pills, list
  values with chevrons and position pips, keycaps for keys. A gold dot marks a changed,
  unapplied row; a "Changes not applied" pill sits in the header.
* **A side card** explains the focused row, shows its default, and shows the keys that change
  it for the device in hand.
* **Draft, Apply, Revert.** Edits go to a copy (`Settings.duplicate_settings()`); Apply
  copies it back, applies audio, graphics and bindings, and writes `settings.cfg`; Revert
  throws the copy away. Leaving with unapplied changes asks: Apply, Discard or Keep editing.
* **Display confirmation.** A change to window mode or resolution is applied, then a modal
  asks "Keep these display settings?" with a draining bar and "Changing back in N". After
  `DISPLAY_CONFIRM_SECONDS` (10) with no answer it changes back. Until kept, the file still
  holds the old display values, so a crash on a black screen cannot boot into it again.
* **Readable**: every label on the menu is at least 22 px at 1080p (rows 27, values 26,
  tabs 28, title 46); the test asserts the floor.
* The Settings model (`game/systems/settings.gd`) gains `window_mode`, `resolution` (zero
  means "the size the window opened at", so nothing resizes until somebody picks a size),
  `fov`, `max_fps`, `stick_sensitivity` and the three gameplay switches, plus `copy_from`,
  `duplicate_settings` and `differences`. `fullscreen` stays as a view of `window_mode`, so
  old settings files load.

Screenshots (1920x1080, GPU, invisible display): `build/playtest_evidence/settings/`
(`tab_graphics.png`, `tab_audio.png`, `tab_controls.png`, `tab_gameplay.png` with a row
focused, `title_open.png`, `pause_open.png`, `display_confirm.png`).

## The test

`game/test_input/test_settings.gd`, run with `tools/run_input_tests.sh settings`. It acts only
through `RealInput` (keys, joypad buttons and stick motion, mouse moves and clicks, all through
`Input.parse_input_event`; `real_input.gd` gained `joy_button`, `joy_axis` and `key_mod`) and
reads the UI to decide what a person would press next.

1. **Keyboard only, from the title screen.** Down to Settings, Enter. On every tab: Up to the
   tab strip, Left/Right to the tab, Down to a row, change it (FOV Right, Master Left, Invert
   Enter, Controls reminder Enter), Tab and Shift+Tab. Down to the button bar, Right to Apply,
   Enter: the file holds all four. Change music, Revert: draft back, file untouched. Esc leaves
   with the title cursor where it was.
2. **Controller only, from the pause menu** (Start opens it, d-pad to Settings, A). LB/RB to
   each tab, left stick or d-pad down to a row, change it (quality, effects, controller look
   speed, Getting started list); Apply with A persists. Window mode Right, Apply: the modal
   asks, the window really changes; the pad is left alone for the timeout: the modal closes,
   the window is back in its old mode at its old size, and the draft and file say windowed.
   B returns to the pause menu's Settings row; B again resumes.
3. **Mouse only, from the pause menu** (Esc). Click each tab and change a value on it (VSync
   and the focus switch by clicking the row, ambience by clicking a quarter along the slider,
   invert by clicking the row); click Resolution's arrow, Apply, "Keep it": the file holds the
   resolution and the clicked changes and the window is that size. Back returns to the pause
   menu.

At **every** step: something has focus, it is inside the settings menu and inside the visible
viewport, and its `focus` stylebox is a real outline (StyleBoxFlat, border alpha > 0.5, width
>= 2). On open, on every tab and on the display modal, every visible Label and Button with
text has a font size of at least 22.

### Before (commit 512241a, the old rows)

```
Vulkan 1.4.354 - Forward+ - Using Device #0: AMD - AMD Radeon RX 9070 XT (RADV GFX1201)
INPUT_TEST_FAILED test_settings the title screen's Settings opened no tabbed Settings menu (Graphics, Audio, Controls, Gameplay)
INPUT_TESTS passed=0 failed=1
```

### After

`tools/run_input_tests.sh settings first_pony` (first_pony re-run because ranch.gd and hud.gd
changed):

```
[settings] INPUT_TEST_OK test_settings keyboard, controller and mouse all drove every tab; apply, revert and the display timeout hold
[first_pony] INPUT_TEST_OK test_first_pony caught on the first try
INPUT_TESTS passed=2 failed=0
```

The full log of one run (1280x720):

```
Vulkan 1.4.354 - Forward+ - Using Device #0: AMD - AMD Radeon RX 9070 XT (RADV GFX1201)
INPUT_TEST_NOTE 1.0s title -> settings by keyboard
INPUT_TEST_NOTE 1.3s Graphics: fov 75.0 -> 80.0
INPUT_TEST_NOTE 1.8s Audio: master_volume 1.0 -> 0.9
INPUT_TEST_NOTE 2.2s Controls: invert_look false -> true
INPUT_TEST_NOTE 2.6s Gameplay: show_controls_chip true -> false
INPUT_TEST_NOTE 2.8s apply persisted
INPUT_TEST_NOTE 3.8s revert restored
INPUT_TEST_NOTE 42.1s pause -> settings by controller
INPUT_TEST_NOTE 42.6s pad Graphics: quality 2 -> 1
INPUT_TEST_NOTE 43.3s pad Audio: effects_volume 1.0 -> 0.9
INPUT_TEST_NOTE 43.8s pad Controls: stick_sensitivity 2.2 -> 2.4
INPUT_TEST_NOTE 44.2s pad Gameplay: show_checklist true -> false
INPUT_TEST_NOTE 46.0s confirmation up; waiting out 10s without answering
INPUT_TEST_NOTE 59.4s display timeout reverted
INPUT_TEST_NOTE 60.1s mouse Graphics: vsync true -> false
INPUT_TEST_NOTE 60.4s mouse Audio: ambient_volume 0.5 -> 0.2
INPUT_TEST_NOTE 60.6s mouse Controls: invert_look true -> false
INPUT_TEST_NOTE 60.9s mouse Gameplay: pause_on_focus_loss true -> false
INPUT_TEST_NOTE 62.0s mouse resolution kept
INPUT_TEST_OK test_settings keyboard, controller and mouse all drove every tab; apply, revert and the display timeout hold
INPUT_TESTS passed=1 failed=0
```

The full GUT suite (`tools/run_tests.sh`, parse sweep included): 1754 tests, 1754 passing.

Underneath it, headless GUT: `game/test/test_settings_menu.gd` (draft, Apply, Revert, the
display confirmation kept and timed out, the unapplied-changes ask, key capture, the new
fields round-tripping). The old pause and title settings-page tests that drove the removed
rows were replaced by tests that the Settings row opens the shared menu, that Apply reaches
`settings_changed`, and that leaving returns the cursor to the Settings row.

## Decisions made without asking

* Gameplay holds only switches the game actually honours (reminder chip, checklist, pause
  on focus loss); no camera shake option because the game has no camera shake.
* Rebinding stays keyboard only, as before; controller buttons are shown, not rebound.
* Closing the pause menu while Settings is open discards unapplied changes without asking;
  the host is going away and a dialog there would trap the player.
* Resolution defaults to "as the game opened" (zero) so test runs at `--resolution` and the
  1600x900 window override are never resized until a player picks a size.
