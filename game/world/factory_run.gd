class_name FactoryRun
extends Node3D
## THE RAINBOW FACTORY SCENE (game/world/factory.tscn). One interior (FactoryInterior), one
## player, and a script per visit: `mode` says which.
##   &"reveal"      Color Day, STORY.md R.1 to R.6: the tour, the walkway, the window, the
##                  choice, and either the contract (home with Tumble) or the escape.
##   &"jubilee"     the Factory path's climax (STORY.md section 4).
##   &"lights_out"  the Rescue path's climax (STORY.md section 5).
## It reads and writes GameState like the ranch does, saves before it leaves, and goes back
## down to world/ranch.tscn, which loads that save.
##
## Every beat is an awaitable step; `skip_waits` (the playthrough driver) makes the walks
## and the window instant so the whole route runs headless in seconds.

signal step_reached(step: StringName)
signal finished(outcome: StringName)

const PlayClockScript := preload("res://world/play_clock.gd")
const BootIntentScript := preload("res://world/boot_intent.gd")
const RANCH_SCENE := "res://world/ranch.tscn"
const LoadingScreenScript := preload("res://ui/loading_screen.gd")
const InteriorScript := preload("res://world/factory_interior.gd")
const WindowScript := preload("res://world/factory_window.gd")
const PatrolScript := preload("res://world/collector_patrol.gd")
const HappeningsScript := preload("res://world/happenings.gd")
const PeopleScript := preload("res://world/people.gd")
const NpcScript := preload("res://actors/npc/npc.gd")
const WorldToneScript := preload("res://world/world_tone.gd")
const StoryV1Script := preload("res://systems/story_v1.gd")
const PathRulesScript := preload("res://systems/path_rules.gd")
const PlayerScene := preload("res://actors/player/player.tscn")
const HudScene := preload("res://ui/hud.tscn")
const PauseMenuScene := preload("res://ui/pause_menu.tscn")
const PauseMenuScript := preload("res://ui/pause_menu.gd")
const PauseSettingsScript := preload("res://systems/settings.gd")
const InputDeviceScript := preload("res://systems/input_device.gd")

static var mode: StringName = &"reveal"

## True for the automated playthrough: walks and timed beats complete at once.
var skip_waits := false
## What the scene is waiting for the player to do right now ({kind: "area" | "hold", at}),
## or {}. Read by the human-paced bot (scenes/test/human_bot.gd); nothing in the game needs it.
var goal: Dictionary = {}
## The walkway's patrols, for the same reader.
func patrols() -> Array:
	return _patrols
## With skip_waits: false keeps the window at its real pace (the screenshot probe).
var fast_window := true
## Set by the choice (or by the driver).
var outcome: StringName = &""

var interior: FactoryInterior
var player: Node3D
var people: People
var tone: WorldTone
var window: FactoryWindow
var hud: CanvasLayer
var _env: WorldEnvironment
var _fade: ColorRect
var _patrols: Array[CollectorPatrol] = []
var _game_state: Node
var _last_area: StringName = &""
var _reset_point := Vector3.ZERO
var _cast := 0


func _ready() -> void:
	_game_state = get_node_or_null("/root/GameState")
	for arg in OS.get_cmdline_user_args():
		if arg == "--factory-fast":
			skip_waits = true
		elif arg.begins_with("--factory-mode="):
			mode = StringName(arg.substr(15))
		elif arg.begins_with("--factory-outcome="):
			outcome = StringName(arg.substr(18))
	# BEHIND THE LOADING SCREEN, WHEN THERE IS ONE (game/ui/loading_screen.gd): a frame
	# between building the rooms and casting the tour, and the screen lifts when the tour's
	# first step is reached. No screen (the driver, a gate) and nothing here changes.
	var paced: bool = LoadingScreenScript.claim()
	if paced:
		step_reached.connect(func(_s: StringName) -> void: LoadingScreenScript.release(),
			CONNECT_ONE_SHOT)
		LoadingScreenScript.report(0.1, "Opening the Factory doors")
		await get_tree().process_frame
	_build()
	if paced:
		LoadingScreenScript.report(0.6, "Meeting your guide")
		await get_tree().process_frame
	# Somebody playing (not a fast driver run): the play clock keeps running up here, and every
	# step of the tour is a story beat in the novelty log (MISSION.md fun rules).
	if not skip_waits and (DisplayServer.get_name() != "headless" or BootIntentScript.bot):
		add_child(PlayClockScript.new())
	step_reached.connect(func(step: StringName) -> void:
		if _game_state != null and _game_state.has_method("note_novelty"):
			_game_state.call("note_novelty", "clue" if step in [&"walkway", &"window", &"gallery"] else "story",
				"factory_%s_%s" % [String(mode), String(step)], "The Rainbow Factory: %s" % String(step).replace("_", " ")))
	var bus := get_node_or_null("/root/Events")
	if bus != null:
		bus.connect("area_entered", func(a: StringName) -> void: _last_area = a)
	await get_tree().process_frame
	match mode:
		&"jubilee", &"lights_out":
			await _climax(mode)
		_:
			await _reveal()


# --- building ------------------------------------------------------------------------

## DIRECTION AT EVERY STEP (playtest 2026-11-10 items 14 and 85: "i had no clear direction at
## any point", "im up here again idk what to do"). Every wait in this file already says where
## it waits (`goal`: an area to walk into, or a spot to hold E at). The card under the compass
## says it in words, the compass lights it, and a ring of light stands on the floor there.
const AREA_WORDS := {
	&"factory_welcome": "Follow Marigold into the Welcome Hall",
	&"factory_classroom": "Follow Marigold to the classroom",
	&"factory_giftshop": "Follow Marigold to the gift shop",
	&"factory_gallery": "Sneak past the Collectors to the gallery",
	&"factory_landing": "Run for the lift",
	&"factory_holding": "Find the holding pens",
	&"factory_control": "Get to the control room",
}
var _card: Control
var _compass: Control
var _beacon: Node3D
var _goal_node: Node3D


func _build_guidance() -> void:
	_compass = (load("res://ui/compass.gd") as GDScript).new()
	_compass.name = "Compass"
	hud.add_child(_compass)
	_compass.set("player", player)
	_compass.call("set_places", [] as Array[Dictionary])
	_card = (load("res://ui/objective_card.gd") as GDScript).new()
	_card.name = "ObjectiveCard"
	hud.add_child(_card)
	_goal_node = Node3D.new()
	_goal_node.name = "GoalPoint"
	add_child(_goal_node)
	_beacon = _make_beacon()
	add_child(_beacon)
	_beacon.visible = false


## A ring of light on the floor with a soft column over it: where to go, without words in
## the world (house rule: no floating text).
func _make_beacon() -> Node3D:
	var root := Node3D.new()
	root.name = "GoalBeacon"
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.86, 0.42, 0.85)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.75
	torus.outer_radius = 0.95
	torus.rings = 40
	torus.ring_segments = 8
	ring.mesh = torus
	ring.material_override = mat
	ring.position.y = 0.06
	ring.scale = Vector3(1, 0.25, 1)
	root.add_child(ring)
	var col_mat := mat.duplicate() as StandardMaterial3D
	col_mat.albedo_color = Color(1.0, 0.9, 0.55, 0.16)
	var col := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.55
	cyl.bottom_radius = 0.85
	cyl.height = 3.2
	col.mesh = cyl
	col.material_override = col_mat
	col.position.y = 1.6
	col.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(col)
	var tw := root.create_tween().set_loops()
	tw.tween_property(ring, "scale", Vector3(1.15, 0.25, 1.15), 0.7).set_trans(Tween.TRANS_SINE)
	tw.tween_property(ring, "scale", Vector3(1.0, 0.25, 1.0), 0.7).set_trans(Tween.TRANS_SINE)
	return root


func _process(_delta: float) -> void:
	if _card == null:
		return
	if goal.is_empty() or people.is_talking():
		_card.call("show_objective", {}, -1.0)
		_compass.call("set_goal", null, 0)
		_beacon.visible = false
		return
	var at: Vector3 = goal.get("at", Vector3.ZERO)
	var words := ""
	if String(goal.get("kind", "")) == "hold":
		var verb := String(goal.get("verb", ""))
		words = "Hold %s: %s" % [InputDeviceScript.hint(&"interact"), verb]
	else:
		words = String(AREA_WORDS.get(StringName(goal.get("area", &"")), "Go on"))
	_goal_node.global_position = at
	_compass.call("set_goal", _goal_node, PlaceSign.Icon.STAR)
	_beacon.global_position = Vector3(at.x, player.global_position.y if absf(player.global_position.y - at.y) < 1.5 else at.y, at.z)
	_beacon.visible = true
	var d := Vector2(at.x - player.global_position.x, at.z - player.global_position.z).length()
	_card.call("show_objective", {"id": StringName(words), "goal": &"", "icon": PlaceSign.Icon.STAR,
		"words": words}, d)


## PAUSE UP HERE TOO (playtest 2026-11-10 item 74: "you cant pause when youre in dialogue and
## this whole time im up here"). The Factory had no pause menu at all. Same menu as the
## ranch, minus the rows that only mean something down there; a conversation waits under it.
var pause_menu: CanvasLayer
var _talk_hidden := false


func _build_pause() -> void:
	pause_menu = PauseMenuScene.instantiate()
	add_child(pause_menu)
	var st = PauseSettingsScript.new()
	st.load_from()
	pause_menu.set("settings", st)
	var R := PauseMenuScript.Row
	pause_menu.set("hidden_rows", [R.COMPENDIUM, R.REQUESTS, R.MAIL, R.LEDGER, R.SAVE, R.LOAD,
		R.UNSTUCK] as Array[int])
	pause_menu.connect("opened", func() -> void:
		var talk: CanvasLayer = people.get("talk_box") if people != null else null
		if talk != null and people.is_talking():
			talk.visible = false
			_talk_hidden = true
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE)
	pause_menu.connect("closed", func() -> void:
		if _talk_hidden:
			_talk_hidden = false
			var talk: CanvasLayer = people.get("talk_box") if people != null else null
			if talk != null and people.is_talking():
				talk.visible = true
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
	pause_menu.connect("quit_requested", func() -> void:
		get_tree().paused = false
		get_tree().quit())


func _build() -> void:
	_env = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.82, 0.86, 0.95)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.92, 0.9, 0.96)
	env.ambient_light_energy = 0.28
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	# Less milk (item 19): a lower white point for contrast, and a thinner, warmer haze.
	env.tonemap_white = 3.2
	env.tonemap_exposure = 0.82
	env.ssao_enabled = true
	env.ssao_intensity = 1.2
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_hdr_threshold = 1.6
	env.fog_enabled = true
	env.fog_density = 0.0025
	env.fog_light_color = Color(0.95, 0.88, 0.9)
	_env.environment = env
	_env.name = "WorldEnvironment"
	add_child(_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60, 30, 0)
	sun.light_energy = 0.15
	add_child(sun)
	interior = InteriorScript.new()
	interior.name = "Interior"
	add_child(interior)
	player = PlayerScene.instantiate()
	player.name = "Player"
	player.add_to_group(&"player")
	add_child(player)
	# OFF THE LIFT, NOT UNDER IT (playtest 2026-11-10 item 7: the first look at the Factory
	# was from floor level under the cloud-lift's canopy, a grey slab over half the screen).
	# She stands far enough down the landing that the camera behind her is clear of the lift.
	# room_origin() is the landing's far (+Z) edge; the lift stands 2.5 m in from its centre and
	# its base reaches 0.4 m past the centre, 1.1 m tall. Off it, toward the Welcome Hall.
	player.global_position = interior.room_origin(&"landing") + Vector3(0, 0.3, -8.0)
	hud = HudScene.instantiate()
	add_child(hud)
	tone = WorldToneScript.new()
	tone.environment_path = ^"../WorldEnvironment"
	add_child(tone)
	people = PeopleScript.new()
	people.player = player
	people.presence = func(_id: StringName) -> bool: return false
	people.context_provider = _talk_context
	add_child(people)
	people.camera = player.get_camera_pivot().get_node_or_null("CameraRig/SpringArm3D/CameraMount/Camera3D") \
		if player.has_method("get_camera_pivot") else null
	people.effect.connect(_on_effect)
	_build_pause()
	_build_guidance()
	_fade = ColorRect.new()
	_fade.color = Color(1, 1, 1, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var layer := CanvasLayer.new()
	layer.layer = 60
	layer.add_child(_fade)
	add_child(layer)
	if _game_state != null and _game_state.player != null and player.has_method("apply_look"):
		player.call("apply_look", _game_state.player)
	var music := get_node_or_null("/root/Music")
	if music != null:
		music.call("play_context", &"works")


func _talk_context() -> Dictionary:
	var name := "friend"
	if _game_state != null and _game_state.player != null:
		name = _game_state.player.player_name
	return {"chapter": 2, "path": "", "flags": {"in_factory": true}, "counts": {},
		"name": name, "tumble": "Tumble"}


func _npc(id: StringName, def: CharacterDef, at: Vector3) -> Npc:
	# Each one cast while the loading screen is still up moves its bar a step.
	_cast += 1
	LoadingScreenScript.report(minf(0.95, 0.6 + 0.07 * _cast), "Meeting your guide")
	var n: Npc = NpcScript.new()
	n.name = "Npc_%s" % id
	n.position = at
	add_child(n)
	n.setup(def)
	people.add_npc(id, n)
	return n


func _cast_npc(id: StringName, at: Vector3) -> Npc:
	return _npc(id, load("res://data/characters/%s.tres" % id), at)


## A Collector: a generated pony in grey with goggles, who never speaks.
func _collector(index: int, at: Vector3) -> Npc:
	var def := CharacterDef.new()
	def.id = StringName("collector_%d" % index)
	def.display_name = "Collector"
	def.char_seed = 4400 + index
	def.gen = {"race": &"earth"}
	def.look = {"coat": "8a8f99", "mane": "4d525c", "mane2": "5f6470", "tail": "4d525c"}
	var n := _npc(def.id, def, at)
	# The Collector's uniform (coat, clipboard, fitted goggles; owner 2026-11-11), the same
	# as the one who walks past the ranch. The old goggles prop sat as a ring over the crown.
	HappeningsScript._dress_collector(n)
	return n


# --- the reveal ------------------------------------------------------------------------

func _reveal() -> void:
	tone.snap(0.0)
	var landing := interior.room_origin(&"landing")
	# Marigold in front of her, Tumble at her side, the other stewards along the right wall:
	# everyone the welcome is about is in the frame (item 7).
	var marigold := _cast_npc(&"marigold", landing + Vector3(0.9, 0, -10.4))
	var tumble := _cast_npc(&"tumble", landing + Vector3(-1.3, 0, -8.2))
	tumble.set_mode_follow(player)
	for i in range(3):
		var s := CharacterDef.new()
		s.id = StringName("steward_%d" % i)
		s.char_seed = 5100 + i
		_npc(s.id, s, landing + Vector3(3.6, 0, -7.6 - i * 1.4)).set_mode_stand()
	step_reached.emit(&"landing")
	await _establish(landing)
	await _say(&"marigold", &"factory_welcome")
	var from_room := &"landing"
	for room in [&"welcome", &"classroom", &"giftshop"]:
		var guide := interior.marker(room, "guide")
		# Through the doorway, not at the wall beside it (item 9).
		var route: Array[Vector3] = []
		for mk in [interior.marker(from_room, "exit"), interior.marker(room, "entry")]:
			if mk != null:
				route.append(mk.global_position)
		route.append(guide.global_position if guide != null else interior.room_origin(room))
		marigold.set_mode_walk_route(route)
		from_room = room
		await _until_area(StringName("factory_" + String(room)), interior.room_origin(room) + Vector3(0, 0, -2))
		tone.set_target(InteriorScript.dread_of(room))
		step_reached.emit(room)
		await _say(&"marigold", StringName("factory_room_" + String(room)))
	# Alone by the staff door (STORY.md R.3).
	step_reached.emit(&"alone")
	var music := get_node_or_null("/root/Music")
	if music != null:
		music.call("play_context", &"stealth")
	await _walkway()
	await _until_area(&"factory_gallery", interior.room_origin(&"gallery") + Vector3(0, 0, -3))
	step_reached.emit(&"gallery")
	tone.set_target(0.8)
	await _window_scene()
	# IN FRONT OF HER, FACING HER (playtest 2026-11-10 item 39: the speaker stood at the lens,
	# a dithered ghost over the most important offer in the game).
	var cam := get_viewport().get_camera_3d()
	var ahead := -cam.global_basis.z if cam != null else -player.global_basis.z
	ahead.y = 0.0
	ahead = ahead.normalized() if ahead.length() > 0.01 else Vector3(0, 0, -1)
	var spot := player.global_position + ahead * 2.6 + ahead.cross(Vector3.UP) * 0.7
	spot.y = player.global_position.y
	marigold.global_position = spot
	marigold.set_mode_stand(spot)
	step_reached.emit(&"choice")
	await _say(&"marigold", &"factory_window")
	if outcome == &"":
		outcome = &"rescue"
	if outcome == &"factory":
		await _contract_ending()
	else:
		await _escape()


## THE FIRST LOOK (item 7): a short, skippable establishing move down the landing from the
## lift to the doors of the Welcome Hall, the party colours and the cast in frame, before the
## camera settles behind her.
func _establish(landing: Vector3) -> void:
	if skip_waits:
		return
	var c := Cinematic.shared(get_tree())
	await c.play([
		{"from": landing + Vector3(-4.4, 3.4, -4.6), "to": landing + Vector3(-3.4, 2.5, -6.6),
			"look": landing + Vector3(0.6, 1.0, -9.8), "time": 3.2, "fov": 55.0,
			"caption": "The Rainbow Factory"},
	], {"freeze": [player]})


func _walkway() -> void:
	var room := interior.rooms.get(&"walkway") as Node3D
	var origin := interior.room_origin(&"walkway")
	_reset_point = origin + Vector3(0, 0.3, -0.5)
	for i in range(2):
		var a := interior.marker(&"walkway", "patrol_a").global_position
		var b := interior.marker(&"walkway", "patrol_b").global_position
		var c := interior.marker(&"walkway", "patrol_c").global_position
		var n := _collector(i, a if i == 0 else c)
		var patrol: CollectorPatrol = PatrolScript.new()
		patrol.points.assign([a, b, c] if i == 0 else [c, a, b])
		patrol.target = player
		n.add_child(patrol)
		patrol.spotted.connect(_on_spotted)
		_patrols.append(patrol)
	# Crates to hide behind.
	for z in [-3.0, 1.0]:
		var crate: Node3D = (load("res://assets/models/depot_crate.glb") as PackedScene).instantiate()
		room.add_child(crate)
		crate.position = Vector3(-1.5, 0, z)
		ToonStyler.style(crate, &"prop", {})
		InteriorScript.make_solid(crate)
	step_reached.emit(&"walkway")


func _on_spotted(_t: Node3D) -> void:
	# A buzzer and a reset to the walkway's entry, never a fail state (STORY.md R.3).
	var sound := get_node_or_null("/root/Sound")
	if sound != null:
		sound.call("play", &"ui_denied")
	await _fade_to(Color(1, 0.3, 0.3, 0.55), 0.15)
	player.global_position = _reset_point
	await _fade_to(Color(1, 0.3, 0.3, 0.0), 0.35)


func _window_scene() -> void:
	var floor := interior.get_node_or_null("Rooms/gallery/ProcessingFloor") as Node3D
	if floor == null:
		return
	window = WindowScript.new()
	floor.add_child(window)
	_frost_the_glass()
	for p in _patrols:
		p.enabled = false
	if skip_waits and fast_window:
		window.step_seconds = 0.01
		window.hold_seconds = 0.01
	# The Scoop's gauge shows what it always measured (clue 9).
	if hud != null and hud.has_method("toast"):
		hud.call("toast", "Sparkle... Spectral yield")
	var music := get_node_or_null("/root/Music")
	if music != null:
		music.call("play_context", &"works")
	await window.play()
	step_reached.emit(&"window_done")


func _frost_the_glass() -> void:
	var gallery := interior.rooms.get(&"gallery") as Node3D
	var pane := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(11.6, 3.4)
	pane.mesh = quad
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/frosted_glass.gdshader")
	pane.material_override = m
	gallery.add_child(pane)
	pane.position = Vector3(InteriorScript.ROOM_SIZE * 0.5 + 0.05, 3.1, 0)
	pane.rotation_degrees = Vector3(0, -90, 0)


func _contract_ending() -> void:
	step_reached.emit(&"contract")
	_choose(StoryV1Script.PATH_FACTORY)
	await _fade_to(Color(1, 1, 1, 1), 1.2 if not skip_waits else 0.01)
	_leave(&"factory")


## THE ESCAPE (STORY.md R.6, second choice): Scoop Tumble out of the line, then run for the
## lift with the alarm up and Collectors on the way.
func _escape() -> void:
	step_reached.emit(&"escape_grab")
	var tb := window.tumble_body() if window != null else null
	var gallery := interior.room_origin(&"gallery")
	var tumble := people.npc(&"tumble")
	# SCOOPED OUT OF THE LINE, THROUGH THE HATCH (playtest 2026-11-10 item 16: she was
	# teleported to the gallery floor to be scooped). She is in the line below; the hold is at
	# the hatch, and the beam brings her up through it.
	var hatch := gallery + Vector3(InteriorScript.ROOM_SIZE * 0.5 - 1.2, 0, -6.0)
	await _hold_at(hatch, 3.0, "scoop Tumble out of the line")
	if tb != null:
		tb.visible = false
	if tumble != null:
		tumble.visible = true
		tumble.process_mode = Node.PROCESS_MODE_INHERIT
		tumble.global_position = hatch + Vector3(0, -1.8, 0)
		var up := create_tween()
		up.tween_property(tumble, "global_position", hatch + Vector3(-0.8, 0.3, 0.8), 0.0 if skip_waits else 0.9) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await up.finished
		tumble.act(&"happy", &"hop")
		tumble.set_mode_follow(player)
	_alarm()
	step_reached.emit(&"escape_run")
	_reset_point = gallery + Vector3(0, 0.3, 1.0)
	var welcome := interior.room_origin(&"welcome")
	var g := _collector(9, welcome + Vector3(3.0, 0, -4.0))
	var patrol: CollectorPatrol = PatrolScript.new()
	patrol.points.assign([welcome + Vector3(3.0, 0, -4.0), welcome + Vector3(-3.0, 0, -4.0)])
	patrol.target = player
	g.add_child(patrol)
	patrol.spotted.connect(_on_spotted)
	for p in _patrols:
		p.enabled = true
	await _until_area(&"factory_landing", interior.room_origin(&"landing") + Vector3(0, 0, -2))
	step_reached.emit(&"lift")
	_choose(StoryV1Script.PATH_RESCUE)
	await _fade_to(Color(0, 0, 0, 1), 1.0 if not skip_waits else 0.01)
	_leave(&"rescue")


## TAKEN (item 51: she walked a straight line at the gift shop and wedged in a corner). She
## goes out through the nearest door, and once out of the room she is gone: her place is in
## the line now, until the escape brings her back up through the hatch.
func _take_tumble(tumble: Npc) -> void:
	tumble.act(&"scared")
	var room := String(_last_area).trim_prefix("factory_")
	var door := interior.marker(StringName(room), "exit") if not room.is_empty() else null
	if door != null:
		tumble.set_mode_walk_route([door.global_position] as Array[Vector3])
		var t := 0.0
		while tumble.is_walking_to() and t < 6.0 and not skip_waits:
			await get_tree().process_frame
			t += get_process_delta_time()
	tumble.visible = false
	tumble.process_mode = Node.PROCESS_MODE_DISABLED


func _alarm() -> void:
	tone.set_target(0.9)
	for room in interior.rooms.values():
		for l in (room as Node3D).find_children("*", "OmniLight3D", true, false):
			(l as OmniLight3D).light_color = Color(1.0, 0.35, 0.3)
	var music := get_node_or_null("/root/Music")
	if music != null:
		music.call("play_context", &"stealth")


# --- the climaxes ----------------------------------------------------------------------

func _climax(m: StringName) -> void:
	step_reached.emit(m)
	if m == &"jubilee":
		await _jubilee()
	else:
		await _lights_out()


## THE JUBILEE (STORY.md section 4): a party all the way in, a stage in the control room,
## the lever, the Grand Spectrum. The most beautiful thing in the game, and the worst.
func _jubilee() -> void:
	tone.snap(0.15)
	var landing := interior.room_origin(&"landing")
	var marigold := _cast_npc(&"marigold", landing + Vector3(0.9, 0, -10.4))
	for i in range(8):
		var s := CharacterDef.new()
		s.id = StringName("guest_%d" % i)
		s.char_seed = 6100 + i
		var room: StringName = [&"welcome", &"classroom", &"giftshop", &"control"][i % 4]
		var at := interior.room_origin(room) + Vector3(-3.5 + (i % 3) * 3.5, 0, -4.0 - (i % 2) * 2.0)
		var n := _npc(s.id, s, at)
		n.set_mode_stand(at)
		n.act(&"happy", &"hop")
	await _say(&"marigold", &"jubilee_welcome")
	var control := interior.room_origin(&"control")
	marigold.set_mode_walk_to(control + Vector3(1.5, 0, -6.0))
	await _until_area(&"factory_control", control + Vector3(0, 0, -2))
	step_reached.emit(&"stage")
	tone.set_target(0.3)
	await _say(&"marigold", &"jubilee_stage")
	await _hold_at(_lever_point(), 2.0, "pull the lever")
	step_reached.emit(&"lever")
	await _grand_spectrum(true)
	_climax_done()
	await _fade_to(Color(1, 1, 1, 1), 2.0 if not skip_waits else 0.01)
	_leave(&"jubilee")


## LIGHTS OUT (STORY.md section 5): up with the town behind you, free the line, find
## holding and Clover, and pull the same lever the other way.
func _lights_out() -> void:
	tone.snap(0.5)
	var landing := interior.room_origin(&"landing")
	var allies: Array[StringName] = [&"static"]
	var story: Story = _game_state.story if _game_state != null else null
	if story != null:
		for a in [&"pip", &"bramble", &"fennel"]:
			if story.has_flag("ally_" + String(a)):
				allies.append(a)
	var k := 0
	for a in allies:
		var n := _cast_npc(a, landing + Vector3(-2.0 + k * 1.4, 0, -9.6))
		n.set_mode_follow(player)
		k += 1
	await _say(&"static", &"lights_out_landing")
	var music := get_node_or_null("/root/Music")
	if music != null:
		music.call("play_context", &"stealth")
	await _walkway()
	await _until_area(&"factory_gallery", interior.room_origin(&"gallery") + Vector3(0, 0, -3))
	step_reached.emit(&"gallery")
	# Free the line: the queue on the processing floor, beamed out through the hatch.
	var floor := interior.get_node_or_null("Rooms/gallery/ProcessingFloor") as Node3D
	if floor != null:
		window = WindowScript.new()
		window.line_length = 6
		floor.add_child(window)
	# Tumble is beside you this time, not at the end of the line: her place in it stays empty.
	var tumble_shape: Node3D = window.tumble_body() if window != null else null
	if tumble_shape != null:
		tumble_shape.visible = false
	var hatch := interior.room_origin(&"gallery") + Vector3(InteriorScript.ROOM_SIZE * 0.5 - 1.2, 0, -6.0)
	await _hold_at(hatch, 3.0, "beam the line out through the hatch")
	var freed := 0
	if window != null:
		for p in floor.get_children():
			if p is CharacterBody3D and p.visible and p != tumble_shape:
				p.visible = false
				freed += 1
	if story != null and freed > 0:
		PathRulesScript.count_rescue(story, "", freed)
	step_reached.emit(&"line_freed")
	if hud != null and hud.has_method("toast"):
		hud.call("toast", "%d ponies out of the line." % freed)
	# Holding, and Clover (only Fennel's page tells you where she is).
	var holding := interior.room_origin(&"holding")
	await _until_area(&"factory_holding", holding + Vector3(0, 0, -2))
	step_reached.emit(&"holding")
	if story != null and story.has_flag("ally_fennel"):
		var mark := interior.marker(&"holding", "clover")
		var clover := _cast_npc(&"clover", mark.global_position if mark != null else holding)
		clover.act(&"scared", &"cower")
		await _hold_at(clover.global_position, 2.0, "open Clover's stall")
		clover.act(&"happy", &"hop")
		clover.set_mode_follow(player)
		story.set_flag("clover_rescued")
		step_reached.emit(&"clover")
		await _say(&"clover", &"clover_found")
	var control := interior.room_origin(&"control")
	await _until_area(&"factory_control", control + Vector3(0, 0, -2))
	step_reached.emit(&"control")
	await _hold_at(_lever_point(), 3.0, "pull the lever the other way")
	step_reached.emit(&"lever")
	await _grand_spectrum(false)
	_climax_done()
	await _fade_to(Color(0, 0, 0, 1), 2.0 if not skip_waits else 0.01)
	_leave(&"lights_out")


func _lever_point() -> Vector3:
	var m := interior.marker(&"control", "lever")
	return m.global_position if m != null else interior.room_origin(&"control") + Vector3(0, 0, -8)


## The lever's work. Up: every light in the Works goes to rainbow, sparkles pour up.
## Down: the lights fail room by room, from the far end back to the lift.
func _grand_spectrum(up: bool) -> void:
	var handle := interior.find_child("LeverHandle", true, false) as Node3D
	if handle != null:
		var t := create_tween()
		t.tween_property(handle, "rotation_degrees:x", -70.0 if up else 70.0, 0.4)
	var names: Array = interior.rooms.keys()
	if not up:
		names.reverse()
	var colors: Array[Color] = [Color(1, 0.3, 0.3), Color(1, 0.6, 0.2), Color(1, 0.95, 0.3), Color(0.3, 0.9, 0.4),
		Color(0.3, 0.6, 1), Color(0.6, 0.35, 0.95)]
	var i := 0
	for room_name in names:
		var room := interior.rooms[room_name] as Node3D
		for l in room.find_children("*", "OmniLight3D", true, false):
			var light := l as OmniLight3D
			var lt := create_tween()
			if up:
				lt.tween_property(light, "light_color", colors[i % colors.size()], 0.5)
				lt.parallel().tween_property(light, "light_energy", light.light_energy * 2.5, 0.5)
			else:
				lt.tween_property(light, "light_energy", 0.0, 0.25)
		if up:
			var p := BloomCeremony.sparkles(colors)
			p.amount = 120
			room.add_child(p)
			p.position = Vector3(0, 1.0, 0)
			p.emitting = true
		var sound := get_node_or_null("/root/Sound")
		if sound != null and sound.call("has_sound", &"sparkle" if up else &"ui_denied"):
			sound.call("play", &"sparkle" if up else &"ui_denied")
		i += 1
		if not skip_waits:
			await get_tree().create_timer(0.45).timeout
	tone.set_target(0.85 if up else 0.0)
	if not skip_waits:
		await get_tree().create_timer(2.5).timeout


func _climax_done() -> void:
	if _game_state == null:
		return
	var story: Story = _game_state.story
	story.set_flag("climax_done")
	story.set_var("ending", "")


## Hold interact within reach of `at` for `seconds`. The scene waits on it.
func _hold_at(at: Vector3, seconds: float, verb: String) -> void:
	if skip_waits:
		return
	goal = {"kind": "hold", "at": at, "verb": verb}
	var held := 0.0
	while held < seconds:
		await get_tree().process_frame
		var near := player.global_position.distance_to(at) < 3.2
		var dt := get_process_delta_time()
		if near and Input.is_action_pressed(&"interact"):
			held += dt
		else:
			held = maxf(0.0, held - dt * 0.5)
		if hud != null and hud.has_method("set_prompt"):
			hud.call("set_prompt", "%s: hold to %s  %d%%" % [InputDeviceScript.hint(&"interact"),
				verb, int(held / seconds * 100.0)] if near else "")
	if hud != null and hud.has_method("set_prompt"):
		hud.call("set_prompt", "")
	goal = {}


# --- helpers -----------------------------------------------------------------------

func _choose(p: String) -> void:
	if _game_state == null:
		return
	var story: Story = _game_state.story
	StoryV1Script.choose_path(story, p)
	story.set_flag("color_day_done")
	if p == StoryV1Script.PATH_FACTORY:
		story.set_var("stipend_mult", 2)
		story.set_var("rank", 1)


func _leave(o: StringName) -> void:
	outcome = o
	finished.emit(o)
	if _game_state != null and _game_state.has_method("save_to_slot") and not skip_waits:
		_game_state.save_to_slot()
	if not skip_waits:
		# Down behind the loading screen (game/ui/loading_screen.gd); the ranch reports its
		# own boot on the bar and lifts the screen when she can play.
		LoadingScreenScript.change_scene(get_tree(), RANCH_SCENE, LoadingScreenScript.Look.RANCH,
			"Back down to the ranch")


func _say(speaker: StringName, id: StringName) -> void:
	if not people.talk_id(speaker, id):
		return
	if skip_waits:
		# Drive it to the end, taking the first choice unless outcome is pinned.
		var guard := 0
		while people.is_talking() and guard < 64:
			if people.runner.has_choices():
				var pick := 0
				if id == &"factory_window" and outcome == &"rescue":
					pick = 1
				people.talk_box.chose.emit(pick)
			else:
				people.talk_box.advanced.emit()
			guard += 1
		return
	while people.is_talking():
		await get_tree().process_frame


## Wait for the player to walk into `area` (or, in a fast run, put her there).
func _until_area(area: StringName, fallback: Vector3) -> void:
	if skip_waits:
		player.global_position = fallback + Vector3(0, 0.3, 0)
		_last_area = area
		return
	goal = {"kind": "area", "at": fallback, "area": area}
	while _last_area != area:
		await get_tree().process_frame
	goal = {}


func _fade_to(c: Color, seconds: float) -> void:
	var t := create_tween()
	t.tween_property(_fade, "color", c, maxf(seconds, 0.01))
	await t.finished


func _on_effect(kind: StringName, value: String) -> void:
	if kind != &"event":
		return
	match value:
		"tumble_taken":
			var tumble := people.npc(&"tumble")
			if tumble != null:
				_take_tumble(tumble)
		"marigold_leaves":
			var m := people.npc(&"marigold")
			if m != null:
				m.set_mode_walk_to(interior.room_origin(&"landing"))
		"path_factory":
			outcome = &"factory"
		"path_rescue":
			outcome = &"rescue"
