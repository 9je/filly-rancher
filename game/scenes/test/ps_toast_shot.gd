extends SceneTree
## PS EVIDENCE, item 59 (playtest 2026-11-05: "Toasts and companion lines vanish too fast, and
## pausing clears them"). A new game, the welcome talked through, the toast queue left to
## empty; then a long line (the Palace flyer's own words, world/happenings.gd) is raised and
## photographed as it ages; then a second long line, the pause menu opened over it with the
## pause key for five seconds and closed again, and the line photographed after.
##   xvfb-run ... godot --display-driver x11 --path game -s res://scenes/test/ps_toast_shot.gd -- --out=/abs/dir
const Boot := preload("res://scenes/test/ps_boot.gd")
const HudScript := preload("res://ui/hud.gd")
const FLYER := "A flyer on the board: the Palace on the Strip has its GRAND OPENING tonight! Slots, the wheel, cards, and racing."
const SPIKE := "Spike: \"Your ponies are getting hungry! Grab some hay at the Market. Once it's in the pantry they eat on their own.\""
var out := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _quiet(hud: Node) -> void:
	for i in 1800:
		if float(hud.call("toast_seconds_left")) <= 0.0 and (hud.call("pending_toasts") as Array).is_empty():
			break
		await process_frame
	await Boot.frames(self, 60)


func _press(action: StringName) -> void:
	Input.action_press(action)
	await Boot.frames(self, 2)
	Input.action_release(action)
	await Boot.frames(self, 10)


func _run() -> void:
	var ranch: Node = await Boot.boot(self)
	await Boot.talk_through(self, ranch)
	var hud: Node = ranch.get_node("HUD")
	await _quiet(hud)
	print("ITEM59 hold for the flyer line: %.2f s (%d words); short line: %.2f s" % [
		HudScript.toast_hold_for(FLYER), FLYER.split(" ", false).size(), HudScript.toast_hold_for("Short line.")])
	hud.call("toast", FLYER)
	var t0 := Time.get_ticks_msec()
	for at: float in [0.5, 3.0, 5.0, 6.5]:
		while float(Time.get_ticks_msec() - t0) / 1000.0 < at:
			await process_frame
		var toast := hud.get_node("Toast") as CanvasItem
		print("ITEM59 aging t=%.1f s: left %.2f s, shown %s, alpha %.2f, text '%s'" % [at,
			hud.call("toast_seconds_left"), toast.visible, toast.modulate.a, String(hud.call("toast_text")).left(40)])
		await Boot.shot(self, out, "item59_long_toast_%.1fs" % at)
	await _quiet(hud)

	# The pause menu over a long line.
	hud.call("toast", SPIKE)
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 1500:
		await process_frame
	var left_before := float(hud.call("toast_seconds_left"))
	print("ITEM59 before the pause: left %.2f s" % left_before)
	await Boot.shot(self, out, "item59_before_pause")
	var pm: Node = ranch.get("pause_menu")
	await _press(&"pause")
	if not bool(pm.call("is_open")):
		print("ITEM59 the pause key did not open the menu; opened by its open()")
		pm.call("open")
	print("ITEM59 pause menu open: ", pm.call("is_open"))
	var tp := Time.get_ticks_msec()
	while Time.get_ticks_msec() - tp < 5000:
		await process_frame
	print("ITEM59 after 5 s paused: left %.2f s" % float(hud.call("toast_seconds_left")))
	await Boot.shot(self, out, "item59_paused_5s")
	await _press(&"pause")
	if bool(pm.call("is_open")):
		print("ITEM59 the pause key did not close the menu; closed by its close()")
		pm.call("close")
	await Boot.frames(self, 10)
	var toast2 := hud.get_node("Toast") as CanvasItem
	print("ITEM59 after closing the pause: left %.2f s, shown %s, alpha %.2f, text '%s'" % [
		float(hud.call("toast_seconds_left")), toast2.visible, toast2.modulate.a, String(hud.call("toast_text")).left(40)])
	await Boot.shot(self, out, "item59_after_unpause")
	print("PS_TOAST_SHOT_OK")
	quit(0)
