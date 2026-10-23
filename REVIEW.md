# Review

Two independent reviews of the v1 build (branch `v1-overhaul`), run at the end of M5: one on story and gameplay (the endings, Act Three's rules, the Factory scenes, the playthrough driver), one on UI and systems (settings, input, the epilogue, music). Each finding was checked against the code before it was accepted. Severity is the reviewers' own: **high** breaks an ending or a save, **medium** is a rule that can be exploited or a UI that misbehaves, **low** is polish.

Every high and medium finding is fixed, with a test that pins it (commit `cb234d6` and the commit after it). Two low findings were judged not to be defects and are explained below.

## Story and gameplay

| # | Severity | Finding | Status |
|---|---|---|---|
| 1 | high | **Placement was a softlock.** It overwrote the save with the ending set, never offered the morning before (STORY.md section 6 promises it), and re-ran on every later collection day; with `ending` set, no climax ending could ever play in that save. | **Fixed.** A Rescue path collection day keeps the morning before in its own slot (`GameState.BEFORE_COLLECTION_SLOT`). After Placement's epilogue, `placement_aftermath()` puts that morning back as the play save, merging in `endings_seen`, and reloads the ranch. With no morning kept, the ending is lifted and Heat drops below the take line instead. Act Three's collection-day rules no longer run once an ending is set. The Placement playthrough now proves the restore end to end: it reloads, then checks there is no ending, no `placed` flag, and that Placement is in `endings_seen`. |
| 2 | high | **Lights Out freed seven, not six.** The free-the-line count included the Tumble silhouette at the end of the line; Tumble is beside the player in this climax. | **Fixed.** Her place in the line is hidden and never counted. `test_factory_run` pins the rescue count at exactly 6. |
| 3 | high | **The Lights Out climax could be replayed.** `static_ready` had no `climax_done` guard, and `_climax_done` resets `ending`, so a second ride doubled the tallies and recomputed the ending. | **Fixed.** `static_ready` requires `flags_none: climax_done`, as `marigold_jubilee` already did, and `_ride_lift_to_factory` refuses a climax mode once the climax is done. |
| 4 | medium | **Corral guards added Heat by day.** Their patrol spots at any hour, and `_on_spotted` never asked whether it was night. | **Fixed.** A lantern counts only in the dark (`test_act3_world`). |
| 5 | medium | **The Dye Vat could be farmed.** The same pony could be dyed over and over for -6 Heat each time. | **Fixed.** The vat takes the first pony in the bag it has not had yet, and says so when there is none. |
| 6 | medium | **Dawn cooling ran before the collection-day check**, so Heat at 100 cooled to 97 before Placement was tested. | **Fixed.** The dawn's Act Three work runs after the phase's collection day. |
| 7 | medium | **Calm Lamps applied only at dawn**, so a lamp bought at noon did nothing until the next morning. | **Fixed.** On the Factory path the gear is applied on every Act Three tick. |
| 8 | medium | **Contracts stopped forever after the Jubilee.** STORY.md's post-game says "contracts keep coming". | **Fixed.** Once the climax is done, `post_contract` posts ordinary contracts again (`test_path_rules`). |
| 9 | medium | **The Express Chute promised a bonus and granted none.** | **Fixed.** It pays 25 bits per pony on top of the delivery, and the toast shows the amount. |
| 10 | medium | **A partial raid wasted ponies.** A bag too small for the whole corral marked it raided, and the ponies left inside could never be reached. | **Fixed.** The corral stays open until it is empty (`test_act3_world`). |
| 11 | low | The playthrough driver bypasses night, holds and spotting. | **Not a defect.** The driver proves every ending is reachable through the game's own verbs. Night, holds and lanterns are rules, pinned by unit tests (`test_path_rules`, `test_act3_world`, `test_factory_run`). The driver now raises Heat through `PathRules.add_heat` instead of the lantern callback. |
| 12 | low | Rank gating of the franchise and silent-Pip lines. | **Not a defect.** Both gate on `rank` through the dialogue's `min` conditions, which is the intended rank 2 and 3 progression. |

## UI and systems

| # | Severity | Finding | Status |
|---|---|---|---|
| 1 | high | **A stale key capture rebound the next key.** `_capturing` survived `close`, `open`, `back` and page changes. | **Fixed.** Every exit clears it (`test_pause_menu`). |
| 2 | high | **Clicks never advanced the epilogue**, because the veil ate them and input went through `_unhandled_input`; the cursor also stayed captured. | **Fixed.** The veil ignores the mouse, the epilogue takes input in `_input` ahead of the world, and it frees the cursor while it plays and restores it after (`test_epilogue`). |
| 3 | medium | **Music: a cut-short fade left a third track playing.** | **Fixed.** The reused player is stopped before every context change (`test_music`). |
| 4 | medium | **Bindings:** an action whose key was taken kept it in the InputMap; project defaults were never checked for conflicts; nothing put a default back. | **Fixed.** A taken key swaps the other action onto the thief's old key, defaults included. `apply_bindings` rebuilds every action from project.godot first. Backspace during a capture restores the default (`test_settings`, `test_pause_menu`). |
| 5 | medium | Epilogue tweens could fight when someone clicked quickly. | **Fixed.** One tween at a time; each stage kills the last. |
| 6 | medium | Epilogue `done` could fire twice (an `advance` after `_finish`). | **Fixed.** `advance` is a no-op once finished, and `done` fires exactly once (`test_epilogue`). |
| 7 | medium | The world stayed interactive behind the epilogue, so menus could open under it. | **Fixed.** The tree pauses under the epilogue, as under any menu (it runs `PROCESS_MODE_ALWAYS`), and `_no_menu_but` treats it as an open menu. |
| 8 | medium | `apply_graphics` overwrote the authored environment. HIGH switched SSAO and glow on even in scenes built without them, and it forced SDFGI off. | **Fixed.** The scene's own values are the ceiling: a preset can only turn an effect off. SDFGI is left alone. |
| 9 | low | Music's fade target went stale when dread moved during a fade. | **Fixed.** The fade ends by re-applying the current dread level. |
| 10 | low | `stop_all` and `set_dread` dereferenced `_drone` before `_ready`. | **Fixed.** Both are guarded, and `_ready` applies the dread level it was given (`test_music`). |
| 11 | low | A seed name could override a record name. | **Not a defect in practice.** Only stock Drifters carry a seed. A comment now says so. |
| 12 | low | Binding values from the settings file were not validated. | **Fixed.** Non-integer, non-positive, Escape and unknown-action entries are dropped on load (`test_settings`). |

## Also fixed in this pass

- A `test_sound` case that waits on the audio mix thread gave it only 500 ms of wall-clock time and failed once under full-suite load. It now allows three seconds.
