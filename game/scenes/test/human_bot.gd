extends "res://test_input/playthrough_input.gd"
## THE HUMAN-PACED BOT (tools/pacing.sh, and the FIRST_10_MINUTES recording): a fresh save,
## from the title screen, played the way a person plays it for `--minutes` of game time.
##
## IT IS THE REAL-INPUT PLAYTHROUGH'S BRAIN (game/test_input/playthrough_input.gd) with no
## ending to reach: every action is an InputEvent (keys from the InputMap, mouse motion for the
## camera, the right button for the Scoop, E and the arrow keys for prompts and menus). It used
## to act through Input.action_press(), the camera rig's add_look_delta() and the menus' own
## confirm()/close()/move_selection() calls; that version no longer counted (owner's rule,
## docs/playtest_fixes/playthrough.md) and was replaced, not kept beside this.
##
## It must run in a real window (tools/pacing.sh gives it an invisible one): a headless ranch
## treats the run as "nobody at the keyboard" and skips the title and the creator.
##
##   ... -s res://scenes/test/human_bot.gd -- [--minutes=75] [--pacing=/abs/PACING.md] [--seed=7]
##
## Prints BOT_OK (and PACING_OK / PACING_FAILED with --pacing) when the time is up.


func _play() -> void:
	minutes = 75.0
	await super()
