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
	env.tonemap_white = 6.0
	env.tonemap_exposure = 0.78
	env.ssao_enabled = true
	env.ssao_intensity = 1.2
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_hdr_threshold = 1.6
	env.fog_enabled = true
	env.fog_density = 0.006
	env.fog_light_color = Color(0.85, 0.87, 0.95)
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
	player.global_position = interior.room_origin(&"landing") + Vector3(0, 0.3, -2.0)
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
	n.attach_prop("res://assets/models/goggles.glb", "Head", Vector3(0, 1.95, -0.62), Vector3(0, 0, 0), 1.6)
	return n


# --- the reveal ------------------------------------------------------------------------

func _reveal() -> void:
	tone.snap(0.0)
	var landing := interior.room_origin(&"landing")
	var marigold := _cast_npc(&"marigold", landing + Vector3(1.5, 0, -3.5))
	var tumble := _cast_npc(&"tumble", landing + Vector3(-1.5, 0, -2.5))
	tumble.set_mode_follow(player)
	for i in range(3):
		var s := CharacterDef.new()
		s.id = StringName("steward_%d" % i)
		s.char_seed = 5100 + i
		_npc(s.id, s, landing + Vector3(-3.0 + i * 1.6, 0, -5.0)).set_mode_stand()
	step_reached.emit(&"landing")
	await _say(&"marigold", &"factory_welcome")
	for room in [&"welcome", &"classroom", &"giftshop"]:
		var guide := interior.marker(room, "guide")
		marigold.set_mode_walk_to(guide.global_position if guide != null else interior.room_origin(room))
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
	marigold.global_position = interior.room_origin(&"gallery") + Vector3(1.0, 0, -1.0)
	marigold.set_mode_stand(marigold.global_position)
	step_reached.emit(&"choice")
	await _say(&"marigold", &"factory_window")
	if outcome == &"":
		outcome = &"rescue"
	if outcome == &"factory":
		await _contract_ending()
	else:
		await _escape()


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
	if tumble != null:
		tumble.global_position = gallery + Vector3(-2.0, 0, -3.0)
		tumble.set_mode_stand(tumble.global_position)
		tumble.act(&"scared", &"cower")
	if tb != null:
		tb.visible = false
	await _hold_to_scoop(tumble)
	if tumble != null:
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


## Hold interact beside her: the hardest catch in the game so far (she is too wiggly).
func _hold_to_scoop(tumble: Npc) -> void:
	if tumble != null:
		await _hold_at(tumble.global_position, 3.0, "scoop Tumble out")


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
	var marigold := _cast_npc(&"marigold", landing + Vector3(1.5, 0, -3.5))
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
		var n := _cast_npc(a, landing + Vector3(-2.0 + k * 1.4, 0, -1.0))
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
				tumble.set_mode_walk_to(interior.room_origin(&"giftshop") + Vector3(4.5, 0, -4.0))
				tumble.act(&"scared")
		"marigold_leaves":
			var m := people.npc(&"marigold")
			if m != null:
				m.set_mode_walk_to(interior.room_origin(&"landing"))
		"path_factory":
			outcome = &"factory"
		"path_rescue":
			outcome = &"rescue"
