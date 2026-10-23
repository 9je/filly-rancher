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

const NpcScript := preload("res://actors/npc/npc.gd")
const LibraryScript := preload("res://systems/talk_library.gd")
const RunnerScript := preload("res://systems/dialogue_runner.gd")
const TalkBoxScript := preload("res://ui/talk_box.gd")
const BabbleScript := preload("res://systems/babble.gd")
const InteractionScript := preload("res://world/interaction.gd")

## Where each character stands by default (ranch space), and the way she faces (degrees).
const SPOTS := {
	&"marigold": [Vector3(11.5, 0.0, 6.5), 210.0],
	&"fennel": [Vector3(-9.0, 0.0, 7.5), 120.0],
	&"bramble": [Vector3(-3.2, 0.0, 0.4), 140.0],
	&"pip": [Vector3(9.2, 0.0, -1.0), 200.0],
	&"static": [Vector3(14.0, 0.0, 12.0), 230.0],
	&"clover": [Vector3(-10.5, 0.0, 8.5), 120.0],
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
	for id in CAST:
		var want: bool = presence.call(id)
		if want and not npcs.has(id):
			_spawn(id)
		elif not want and npcs.has(id):
			(npcs[id] as Node).queue_free()
			npcs.erase(id)


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
		n.position = player.global_position + Vector3(2.0, 0.0, 1.5)
		n.set_mode_follow(player)
	npcs[id] = n


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
		if d < best_d:
			best_d = d
			best = id
	if best != &"":
		out.append(InteractionScript.candidate(InteractionScript.Kind.TALK, best_d,
			_display_name(best)))
	return out


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
	var m := _marker
	get_tree().create_timer(POINT_HOLD).timeout.connect(func() -> void:
		if is_instance_valid(m):
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
