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


func _process(_delta: float) -> void:
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


func _color_of(id: StringName) -> Color:
	var n := npc(id)
	if n != null and n.def != null:
		var l := n.def.build_look()
		return l.mane.darkened(0.15)
	return Color(0.55, 0.4, 0.75)
