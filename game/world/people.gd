class_name People
extends Node3D
## THE VALLEY'S PEOPLE: the story cast standing in the world, and every conversation with
## them. Owns the NPC nodes, the TalkLibrary, one DialogueRunner, the TalkBox and a Babble
## voice. The ranch asks it for interaction candidates and hands TALK actions back; the
## story context comes from `context_provider` (a Callable returning the Dictionary that
## DialogueRunner documents), and everything a conversation does comes out as `effect`.
##
## Who stands where, and when, is `SPOTS` plus `presence`: a Callable(id) -> bool the ranch
## supplies from story state (Clover is nowhere until she is rescued, Static only at night
## on the Rescue path, and so on).

signal effect(kind: StringName, value: String)
signal talk_finished(speaker: StringName, dialogue_id: StringName)

const BodySpaceScript := preload("res://systems/body_space.gd")
const NpcScript := preload("res://actors/npc/npc.gd")
const LibraryScript := preload("res://systems/talk_library.gd")
const RunnerScript := preload("res://systems/dialogue_runner.gd")
const TalkBoxScript := preload("res://ui/talk_box.gd")
const BabbleScript := preload("res://systems/babble.gd")
const InteractionScript := preload("res://world/interaction.gd")

## Where each character stands by default (ranch space), and the way she faces (degrees).
const SPOTS := {
	# Re-laid round the plaza 2026-10-25 (see ranch.tscn's Buildings): each by her place.
	# Marigold at the Depot door, Bramble at the Market door, Pip by the mailbox, the two
	# pen hands at the yard's corner, Static on the road out.
	&"marigold": [Vector3(-9.0, 0.0, 0.5), 250.0],
	# Beside the plots, never on one: a spot inside a slot's footprint was fenced in by the
	# first pen built there (and the Market's own footprint lifted Bramble onto its plinth).
	&"fennel": [Vector3(-3.6, 0.0, 7.6), 110.0],
	&"bramble": [Vector3(12.0, 0.0, 0.8), 270.0],
	# Clear of the mailbox (8, 7) by more than TALK_RADIUS plus the mailbox's own 2.6 m: a
	# postmare standing at the box answered every E meant for it.
	&"pip": [Vector3(13.0, 0.0, 10.5), 240.0],
	&"static": [Vector3(16.0, 0.0, 14.0), 230.0],
	&"clover": [Vector3(-6.4, 0.0, 8.2), 120.0],
}
const TALK_RADIUS := 2.8
const CAST: Array[StringName] = [&"tumble", &"marigold", &"fennel", &"pip", &"bramble", &"static", &"clover"]

var library: TalkLibrary
var runner: DialogueRunner
var talk_box: TalkBox
var babble: Babble
var context_provider: Callable = func() -> Dictionary: return {}
var presence: Callable = func(_id: StringName) -> bool: return true
var player: Node3D
var camera: Camera3D
var npcs: Dictionary = {}
## The wild herd Tumble points at: a Callable returning the standing wild ponies (the
## ranch hands over spawner.get_spawned()).
var wild_provider: Callable = func() -> Array: return []
## Emitted when Tumble points at a Drifter (for the onboarding tip and the HUD ping).
signal tumble_pointed(pony: Node3D)

const POINT_RADIUS := 25.0
const POINT_EVERY := 2.5
const POINT_HOLD := 4.0
var _point_t := 0.0
var _pointed: Dictionary = {}
var _marker: Node3D

var _speaker: StringName = &""
var _rng := RandomNumberGenerator.new()

## THE "!" OVER A TOWNSPONY WITH SOMETHING NEW TO SAY (owner playtest 2026-10-25: "i found
## marigold but it wasnt clear if you dont know the pony"). A gold speech bubble, an icon
## rather than floating words, bobbing over her head and seen through walls from across
## the valley, so "Marigold is on her way over" has a face to look for. Hidden while she is
## the one talking.
const NEWS_EVERY := 0.25
const NEWS_HEIGHT := 2.55
var _news_t := 0.0
var _news: Dictionary = {}
static var _news_tex: ImageTexture


func _ready() -> void:
	library = LibraryScript.new()
	library.load_all()
	runner = RunnerScript.new()
	runner.finished.connect(_on_finished)
	talk_box = TalkBoxScript.new()
	add_child(talk_box)
	talk_box.advanced.connect(_on_advanced)
	talk_box.chose.connect(_on_chose)
	babble = BabbleScript.new()
	add_child(babble)
	_rng.randomize()


## Stand every present character at her spot. Safe to call again (on a load, a new act).
func populate() -> void:
	# The same body as populate_paced(), with no pace: it never awaits, so it runs to the end
	# inside this call. call() by name because the parser insists a function that CAN await
	# is always awaited, and every existing caller of populate() is synchronous.
	call(&"populate_paced", Callable())


## populate(), handing a frame back after each character it stands: `await pace.call(done,
## total)` (the ranch's boot behind the loading screen, docs/playtest_fixes/loading.md).
func populate_paced(pace: Callable) -> void:
	var done := 0
	for id in CAST:
		var want: bool = presence.call(id)
		if want and not npcs.has(id):
			_spawn(id)
		elif not want and npcs.has(id):
			(npcs[id] as Node).queue_free()
			npcs.erase(id)
		done += 1
		if pace.is_valid():
			await pace.call(done, CAST.size())


func npc(id: StringName) -> Npc:
	return npcs.get(id) as Npc


func _spawn(id: StringName) -> void:
	var n: Npc = NpcScript.new()
	n.name = "Npc_%s" % id
	n.character_id = id
	var spot: Array = SPOTS.get(id, [Vector3.ZERO, 0.0])
	n.position = spot[0]
	n.rotation.y = deg_to_rad(float(spot[1]))
	add_child(n)
	n.watch = player
	if id == &"tumble" and player != null:
		n.global_position = _entry_point()
		n.set_mode_follow(player)
	npcs[id] = n


## TUMBLE WAITS AT THE DOOR. Her follow is a walk across the XZ plane toward the player, and
## the Palace's hall is under the map (game/world/palace_interior.gd), so following her in
## would mean standing on the grass over the hall's roof looking at nothing. She waits by the
## door instead and picks up following again when the player comes back out. Returns whether
## there was a companion following to park.
var _parked: Array[StringName] = []


func park_companions(at: Vector3) -> bool:
	_parked.clear()
	for id: StringName in npcs:
		var n: Npc = npcs[id]
		if n.mode == NpcScript.Mode.FOLLOW:
			n.set_mode_walk_to(at)
			_parked.append(id)
	return not _parked.is_empty()


func unpark_companions() -> void:
	for id: StringName in _parked:
		var n: Npc = npcs.get(id) as Npc
		if n != null and is_instance_valid(n):
			n.set_mode_follow(player)
	_parked.clear()


## WHERE TUMBLE COMES IN FROM (PS1, playtest 2026-11-05 item 13: "Tumble spawned
## mid-conversation, inside the player"). She used to be stood up 2.5 m from the player in
## the middle of Marigold's welcome. Now she is stood up ENTRY_M out, behind the camera (out
## of the shot), on the first bearing clear of buildings, and trots in to her heel.
const ENTRY_M := 10.0


func _entry_point() -> Vector3:
	var at := player.global_position
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var back: Vector3 = cam.global_transform.basis.z if cam != null else player.global_basis.z
	back.y = 0.0
	back = back.normalized() if back.length_squared() > 1e-6 else Vector3.BACK
	for deg: float in [0.0, 30.0, -30.0, 55.0, -55.0, 80.0, -80.0]:
		var p := at + back.rotated(Vector3.UP, deg_to_rad(deg)) * ENTRY_M
		if Building.rescue_point(p) == Vector3.INF:
			return p
	return at + back * ENTRY_M


## THE GROUND BETWEEN TWO TALKING IS KEPT CLEAR (PS1, playtest 2026-11-05 item 10: "A pony
## walked through the conversation"): while she talks, a keep-out zone from the player to the
## speaker (systems/body_space.gd), re-laid each frame as they shift; gone when the talk ends.
func _keep_talk_clear() -> void:
	var speaker := npc(_speaker) if is_talking() else null
	if speaker == null or player == null:
		if BodySpaceScript.has_zone(&"talk"):
			BodySpaceScript.clear_zone(&"talk")
		return
	BodySpaceScript.set_zone(&"talk", player.global_position, speaker.global_position,
		BodySpaceScript.TALK_RADIUS, [player, speaker])


## Interaction candidates: the nearest character in reach, as a TALK action.
func candidates(at: Vector3) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if talk_box != null and talk_box.is_open():
		return out
	var best: StringName = &""
	var best_d := TALK_RADIUS
	for id: StringName in npcs:
		var n: Node3D = npcs[id]
		var d := Vector2(at.x - n.global_position.x, at.z - n.global_position.z).length()
		# A COMPANION WITH NOTHING NEW IS TALKED TO ONLY WHEN LOOKED AT (PT4; playtest
		# 2026-11-05 item 18: aiming at Twilight, the prompt read "E: talk to Tumble").
		if d < best_d and (n as Npc).mode == NpcScript.Mode.FOLLOW and not has_news(id) \
				and not _looked_at(n):
			continue
		# A wild pony in the aim: a companion is not offered at all, news or none.
		if d < best_d and (n as Npc).mode == NpcScript.Mode.FOLLOW and _wild_in_aim(at):
			continue
		# NOBODY OFF SCREEN IS OFFERED (P8, playtest 2026-11-08 item 54: "E: talk to Tumble"
		# with Tumble out of view). A companion at her heels is often behind the camera; news
		# or none, she is offered only once she is in the frame.
		if d < best_d and (n as Npc).mode == NpcScript.Mode.FOLLOW and not _on_screen(n):
			continue
		if d < best_d:
			best_d = d
			best = id
	if best != &"":
		var c := InteractionScript.candidate(InteractionScript.Kind.TALK, best_d, _display_name(best))
		# A COMPANION AT YOUR HEELS IS NOT WHO E IS FOR. Tumble follows the player everywhere,
		# so she was always the nearest person, and talk outranks every building: E at the
		# mailbox, the Market or the Depot talked to her instead. With nothing new to say she
		# steps aside for whatever else is in reach (ranch.gd drops a "companion" talk when a
		# building is offered too).
		# With nothing new to say she steps aside for a building in reach (ranch.gd drops a
		# "companion" talk when a building is offered too): Tumble at your heels, Bramble at
		# her own counter, Pip by the mailbox. Somebody with news still has the key.
		if not has_news(best):
			c["companion"] = true
		out.append(c)
	return out


## AT CATCH TIME E IS FOR THE CATCH (PS8, playtest 2026-11-05 item 18: "her talk prompt
## steals E"): a wild pony the camera is turned toward, within beam range of `at`.
const AIM_RANGE := 16.0


func _wild_in_aim(at: Vector3) -> bool:
	for p in wild_provider.call():
		var pony := p as Node3D
		if pony != null and is_instance_valid(pony) \
				and pony.global_position.distance_to(at) < AIM_RANGE and _looked_at(pony):
			return true
	return false


## Whether the camera is turned toward `n` (within LOOK_CONE of straight ahead, flat).
## True with no camera (headless), so the rule above never hides anybody from a test.
const LOOK_CONE := 0.9


func _on_screen(n: Node3D) -> bool:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return true
	return cam.is_position_in_frustum(n.global_position + Vector3(0, 1.0, 0))


func _looked_at(n: Node3D) -> bool:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return true
	var to := n.global_position - cam.global_position
	var fwd := -cam.global_transform.basis.z
	to.y = 0.0
	fwd.y = 0.0
	if to.length_squared() < 1e-6 or fwd.length_squared() < 1e-6:
		return true
	return to.normalized().dot(fwd.normalized()) > LOOK_CONE


## Start talking to `id` (or the character called `display`). Returns false if she has
## nothing to say.
func talk(id_or_name: String) -> bool:
	var id := _id_for(id_or_name)
	if id == &"" or is_talking():
		return false
	var ctx: Dictionary = context_provider.call()
	var d := library.pick(id, ctx, _rng)
	if d == null:
		return false
	_speaker = id
	runner.start(d, ctx)
	var bus := get_node_or_null("/root/Events")
	if bus != null:
		bus.emit_signal("talk_started", id)
	_show()
	return true


## Run conversation `dialogue_id` with `speaker` regardless of what she would pick (the
## Factory's scripted lines). Returns false if there is no such conversation.
func talk_id(speaker: StringName, dialogue_id: StringName) -> bool:
	if is_talking():
		return false
	var d := library.by_id(dialogue_id)
	if d == null:
		return false
	_speaker = speaker
	runner.start(d, context_provider.call())
	var bus := get_node_or_null("/root/Events")
	if bus != null:
		bus.emit_signal("talk_started", speaker)
	_show()
	return true


## Adopt an Npc built elsewhere (the Factory's guide, Collectors, stewards) so she can talk.
func add_npc(id: StringName, n: Npc) -> void:
	npcs[id] = n
	if n.get_parent() == null:
		add_child(n)
	n.watch = player


func is_talking() -> bool:
	return _speaker != &""


## Something new to say (the "!" over her head).
func has_news(id: StringName) -> bool:
	return library.has_news(id, context_provider.call())


func _show() -> void:
	var line := runner.current()
	if line.is_empty():
		return
	var who: StringName = line.who
	var n := npc(who)
	line["who_name"] = _display_name(who)
	talk_box.camera = camera
	talk_box.show_line(line, n if n != null else npc(_speaker), _color_of(who))
	if n != null:
		n.act(line.mood, line.anim)
		var def := n.def
		if def != null:
			babble.set_voice(def.voice_pitch, def.voice_timbre)
	babble.stop()
	babble.say(str(line.text))


func _process(delta: float) -> void:
	_tumble_finder(delta)
	_update_news(delta)
	_keep_talk_clear()
	if not is_talking():
		return
	var who: StringName = runner.current().get("who", _speaker)
	var n := npc(who)
	if n != null:
		n.set_talking(babble.is_speaking(), babble.envelope)


func _on_advanced() -> void:
	runner.advance()
	_after_step()


func _on_chose(i: int) -> void:
	runner.choose(i)
	_after_step()


func _after_step() -> void:
	_flush_effects()
	if runner.is_running():
		_show()


func _flush_effects() -> void:
	for e: Dictionary in runner.effects:
		if e.has("flag"):
			effect.emit(&"flag", str(e.flag))
		if e.has("event"):
			effect.emit(&"event", str(e.event))
	runner.effects.clear()


func _on_finished(dialogue_id: StringName) -> void:
	_flush_effects()
	var d := library.by_id(dialogue_id)
	if d != null and d.once:
		library.mark_seen(dialogue_id)
	talk_box.close()
	babble.stop()
	for id: StringName in npcs:
		(npcs[id] as Npc).set_talking(false)
	var who := _speaker
	_speaker = &""
	_keep_talk_clear()
	var bus := get_node_or_null("/root/Events")
	if bus != null:
		bus.emit_signal("talk_ended", who)
	talk_finished.emit(who, dialogue_id)


func _id_for(s: String) -> StringName:
	if npcs.has(StringName(s)):
		return StringName(s)
	for id: StringName in npcs:
		if _display_name(id) == s:
			return id
	return &""


func _display_name(id: StringName) -> String:
	var n := npc(id)
	if n != null and n.def != null:
		return n.def.display_name
	return String(id).capitalize()


## Her signature colour for the bubble: the most saturated of her coat, mane and eyes,
## pulled to a mid value so a white mane or a cream coat still gives a visible outline.
func _color_of(id: StringName) -> Color:
	var n := npc(id)
	if n == null or n.def == null:
		return Color(0.55, 0.4, 0.75)
	var l := n.def.build_look()
	var best := l.mane
	for c: Color in [l.coat, l.mane, l.mane2, l.eyes]:
		if c.s > best.s:
			best = c
	return Color.from_hsv(best.h, clampf(maxf(best.s, 0.45), 0.0, 0.85), 0.62)


# --- Tumble, the finder (STORY.md beat 1.2) -----------------------------------------------

func _tumble_finder(delta: float) -> void:
	var tumble := npc(&"tumble")
	if tumble == null or is_talking():
		return
	_point_t -= delta
	if _marker != null and is_instance_valid(_marker):
		_marker.rotation.y += delta * 2.0
		_marker.position.y = 2.4 + sin(Time.get_ticks_msec() / 220.0) * 0.12
	if _point_t > 0.0:
		return
	_point_t = POINT_EVERY
	var best: Node3D = null
	var best_d := POINT_RADIUS
	var now := Time.get_ticks_msec()
	for p in wild_provider.call():
		var pony := p as Node3D
		if pony == null or not is_instance_valid(pony):
			continue
		if pony.has_method("is_leaving") and pony.call("is_leaving"):
			continue
		var key := pony.get_instance_id()
		if now - int(_pointed.get(key, -1000000)) < 30000:
			continue
		var d := pony.global_position.distance_to(tumble.global_position)
		if d < best_d:
			best_d = d
			best = pony
	if best == null:
		return
	_pointed[best.get_instance_id()] = now
	_point_at(tumble, best)


func _point_at(tumble: Npc, pony: Node3D) -> void:
	tumble.act(&"happy", &"look")
	if tumble.face() != null:
		tumble.face().look_target = pony.global_position + Vector3(0, 1.0, 0)
		tumble.face().look_weight = 1.0
	if _marker != null and is_instance_valid(_marker):
		_marker.queue_free()
	_marker = _sparkle_marker()
	pony.add_child(_marker)
	_marker.position = Vector3(0, 2.4, 0)
	# By id, not by reference: the marker rides on the pony, and a pony caught inside the
	# hold takes it with her, leaving a lambda holding a freed capture.
	var mid := _marker.get_instance_id()
	get_tree().create_timer(POINT_HOLD).timeout.connect(func() -> void:
		var m := instance_from_id(mid) as Node
		if m != null:
			m.queue_free())
	tumble_pointed.emit(pony)
	var sound := get_node_or_null("/root/Sound")
	if sound != null:
		sound.call("play_at", &"sparkle", pony.global_position)


## A floating four-point star over the pony she found, in Tumble's own mane blue.
func _sparkle_marker() -> Node3D:
	var root := Node3D.new()
	var q := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.7, 0.7)
	q.mesh = quad
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = BloomCeremony.star_texture()
	m.albedo_color = Color(0.55, 0.85, 1.0)
	m.no_depth_test = true
	m.render_priority = 10
	q.material_override = m
	root.add_child(q)
	return root


func _update_news(delta: float) -> void:
	var bob := sin(Time.get_ticks_msec() / 260.0) * 0.1
	for id: StringName in _news:
		var m: Node3D = _news[id]
		if is_instance_valid(m) and m.visible:
			m.position.y = NEWS_HEIGHT + bob
	_news_t -= delta
	if _news_t > 0.0 or context_provider == null or not context_provider.is_valid():
		return
	_news_t = NEWS_EVERY
	var ctx: Dictionary = context_provider.call()
	for id: StringName in npcs:
		var n: Npc = npcs[id]
		if n == null or not is_instance_valid(n):
			continue
		var want := n.is_visible_in_tree() and _speaker != id and library.has_news(id, ctx)
		var m: Node3D = _news.get(id)
		if want and (m == null or not is_instance_valid(m)):
			m = news_marker()
			n.add_child(m)
			m.position = Vector3(0, NEWS_HEIGHT, 0)
			_news[id] = m
		if m != null and is_instance_valid(m):
			m.visible = want


## Whether `id` wears the "!" right now. For the suite.
func shows_news(id: StringName) -> bool:
	var m: Node3D = _news.get(id)
	return m != null and is_instance_valid(m) and m.visible


## The gold speech bubble with a "!" in it, from the icon set.
static func news_marker() -> Node3D:
	if _news_tex == null:
		# The icon set's speech bubble (P8 S5; item 73: the old drawn "!" was a giant).
		_news_tex = IconSet.texture("news", 128, false)
	var root := Node3D.new()
	root.name = "NewsMarker"
	var q := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.72, 0.72)
	q.mesh = quad
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = _news_tex
	m.no_depth_test = true
	m.fixed_size = false
	m.render_priority = 10
	# A townspony beside the lens needs no bubble to be found, and one would fill the screen:
	# it fades out inside a few metres (round 2 evidence, catch_card_settled.png).
	m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	m.distance_fade_min_distance = 3.0
	m.distance_fade_max_distance = 6.0
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	q.material_override = m
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(q)
	return root
