extends Node
## Autoload (see game/project.godot's [autoload] block). Backstop, not the primary
## defence -- every known non-interactive invocation site (tools/run_tests.sh,
## tools/run_windows_build.sh, .github/workflows/smoke_run.sh, and the gate commands
## documented in docs/pipeline.md/docs/ci.md/docs/windows-testing.md) already passes
## `--audio-driver Dummy` itself. This exists for the case those scripts were built to
## guard against but cannot themselves prevent: a future ad-hoc invocation (someone
## hand-typing one of the `xvfb-run`/`proton run` recipes documented in this project's
## own scene-script headers -- see game/world/ranch.gd, game/scenes/test/capture_test.gd,
## wild_ponies.gd, camera_test.gd, terrain_probe.gd) that forgets the flag. Those
## recipes are windowed/offscreen runs (NOT --headless, which would render nothing), so
## Godot's own `--headless` -> dummy-audio-driver mapping does not apply to them, and
## without this they would open a real audio device by default.
##
## MUST run before anything else's _ready() can call AudioStreamPlayer.play() (the
## capture voice line, game/actors/player/magic_beam.gd, is the concrete incident this
## was written for) -- autoloads initialise before the main/current scene, so declaring
## this first in [autoload] is enough; no ordering trick beyond that is needed.
##
## Trigger condition mirrors this codebase's own existing "is this an automated run"
## test (see game/world/ranch.gd's DisplayServer.get_name() == "headless" /
## _screenshot_dir checks): headless already implies a Dummy audio driver by itself
## (redundant here, kept for defence in depth against that mapping ever changing), and
## every offscreen/windowed automated capture in this project is driven by a
## `--screenshot...` user arg (`--screenshot-dir=` in most scenes, `--screenshot=` in
## terrain_probe.gd) -- never present in genuine interactive play, so it is the one
## signal common to all of them and safe to key off.
func _ready() -> void:
	var automated := DisplayServer.get_name() == "headless"
	if not automated:
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--screenshot"):
				automated = true
				break
	if not automated:
		return
	var master := AudioServer.get_bus_index("Master")
	if master >= 0:
		AudioServer.set_bus_mute(master, true)
