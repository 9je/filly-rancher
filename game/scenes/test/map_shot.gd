extends SceneTree
## A TOP-DOWN MAP OF THE VALLEY (playtest 2026-10-25 layout work): an orthographic camera
## over the ranch at noon, every labelled place listed with its position. Invisible display:
##   xvfb-run ... godot --display-driver x11 --path game -s res://scenes/test/map_shot.gd -- --out=/abs/file.png [--size=180] [--centre=x,z]
const BootIntentScript := preload("res://world/boot_intent.gd")
const WorldStateScript := preload("res://systems/world_state.gd")

var out := ""
var span := 180.0
var centre := Vector2.ZERO


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--size="):
			span = float(a.substr(7))
		elif a.begins_with("--centre="):
			var p := a.substr(9).split(",")
			centre = Vector2(float(p[0]), float(p[1]))
	_run.call_deferred()


func _run() -> void:
	root.get_window().size = Vector2i(1400, 1400)
	BootIntentScript.driven = true
	BootIntentScript.request_new_game()
	change_scene_to_file("res://world/ranch.tscn")
	var ranch: Node = null
	for i in 900:
		await process_frame
		ranch = current_scene
		if ranch != null and ranch.get("people") != null and i > 30:
			break
	for i in 60:
		await process_frame
	var cs: Node = ranch.get("creation_screen")
	if cs != null and bool(cs.call("is_open")):
		cs.call("confirm")
	var lp: Node = ranch.get("letter_panel")
	if lp != null and bool(lp.call("is_open")):
		lp.call("close")
	paused = false
	var w: Object = ranch.get("_world")
	if w != null:
		w.call("pin", WorldStateScript.Phase.DAY, WorldStateScript.Weather.CLEAR)
		var sky: Node = ranch.get("sky_rig")
		if sky != null and sky.has_method("apply_immediately"):
			sky.call("apply_immediately", w)
	var hud := ranch.get_node_or_null(^"HUD") as CanvasLayer
	if hud != null:
		hud.visible = false
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = span
	cam.far = 600.0
	ranch.add_child(cam)
	cam.global_position = Vector3(centre.x, 250.0, centre.y)
	cam.rotation_degrees = Vector3(-90, 0, 0)
	cam.make_current()
	for i in 30:
		await process_frame
	root.get_texture().get_image().save_png(out)
	# Everything with a name worth knowing.
	for n in ranch.find_children("*", "Node3D", true, false):
		var nd := n as Node3D
		var cls := String(nd.get_script().get_global_name()) if nd.get_script() != null else ""
		if cls in ["Building", "PlotSlot", "Mailbox", "Npc", "ZoneMarker", "LobbySign", "PalaceFacade", "Pen", "RaceTrack", "SpikeActor"] \
				or nd.name.contains("Market") or nd.name.contains("Depot") or nd.name.contains("Palace") \
				or nd.name.contains("Build") or nd.name.contains("Vat") or nd.name.contains("Spawn"):
			print("PLACE %s [%s] %.1f %.1f %.1f" % [nd.name, cls, nd.global_position.x, nd.global_position.y, nd.global_position.z])
	print("MAP_OK ", out)
	quit()
