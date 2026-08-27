class_name GateWatchdog
extends RefCounted
## Shared "a gate must fail loudly, never hang silently" guard for the headless
## scene gates under game/scenes/test/ and game/world/ranch.gd.
##
## THE BUG THIS EXISTS FOR. Every gate in this project follows the same shape: every
## check runs inside one function (often `await`-chained across several physics
## frames), and the ONLY place that calls `get_tree().quit()` is the very end of that
## function. A reviewer proved that shape a class of bug, not a one-off: making
## `Player.get_magic_beam()` return null part-way through ranch.gd's `_report()` (at
## the `hud.get_capacity() == player.get_magic_beam().get_storage().capacity` line)
## raised an ordinary GDScript null-dereference error. GDScript aborts the coroutine
## that raised it -- everything after that line, including the `quit()` at the
## function's end, simply never runs -- but the engine itself keeps ticking:
## SceneTree, physics, `_process()` on every other node, all of it. Nothing about
## that failure looks like an infinite loop or a stuck `await`, so no amount of
## staring at the checks themselves would catch it. The process just sits there
## until something external kills it: the reviewer measured a full 240s external
## timeout, rc=124, with no marker printed at all -- worse than a failing check,
## because it reports nothing.
##
## THE FIX. Arm a `SceneTreeTimer` at the very top of `_ready()`, before any check
## that could raise mid-function has a chance to run. `SceneTree.create_timer()`
## fires on the tree's own timer processing -- independent of whatever coroutine is
## (or isn't) still alive -- so it fires even when the function that was supposed to
## reach `quit()` has silently aborted. If a gate reaches its own real `quit()`
## first, that ends the process outright and the timer never has anything left to
## time; this only fires on an actual hang, and when it does it prints one
## `<MARKER>_FAILED` line naming the timeout before quitting non-zero, so a stalled
## gate reports SOMETHING instead of nothing.
##
## Headless only, deliberately: a windowed run (someone playing the game, or driving
## a scene interactively to look at it) is meant to keep running with no quit() at
## all, and arming a kill timer against that would end a legitimate session instead
## of catching a bug.
static func arm(node: Node, marker: String, timeout_sec: float = 30.0) -> void:
	if DisplayServer.get_name() != "headless":
		return
	var timer: SceneTreeTimer = node.get_tree().create_timer(timeout_sec)
	timer.timeout.connect(func() -> void:
		push_error("%s: GATE WATCHDOG FIRED -- no quit() reached within %.0fs; treating this as a hang." % [marker, timeout_sec])
		print("%s_FAILED watchdog_timeout=%.0fs" % [marker, timeout_sec])
		node.get_tree().quit(1)
	)
