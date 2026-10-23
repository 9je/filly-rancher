class_name FactoryWindow
extends Node3D
## THE WINDOW (STORY.md R.4). Below and beyond the gallery's frosted glass, a slow line of
## silhouettes. One steps into the ring of light; the light takes her coat colour, then turns
## white, then a rainbow pours up the glass column and away, and she is not there any more.
## The line moves up. At its end, a filly-sized shape with a tangerine rim.
##
## Silhouettes, colour and sound only: no close-up, no body, nothing shown but light. Built
## on the ProcessingFloor node FactoryInterior made (its ring at the origin).

signal cycled(index: int)
signal finished

const PonyScene := preload("res://actors/pony/pony.tscn")
const StockShy := preload("res://data/hidden/stock_shy.tres")
const SILHOUETTE := preload("res://shaders/silhouette.gdshader")
const GeneratorScript := preload("res://systems/pony_generator.gd")

## How many go before her (the scene does not wait for all of them; see play()).
@export var line_length := 5
@export var step_seconds := 2.2
@export var hold_seconds := 2.6

var _line: Array[Node3D] = []
var _rims: Array[Color] = []
var _ring_light: OmniLight3D
var _queue_start := Vector3(5.0, 0, 3.0)


func _ready() -> void:
	var floor := get_parent()
	_ring_light = floor.get_node_or_null("RingLight") as OmniLight3D
	var qs := floor.get_node_or_null("QueueStart") as Node3D
	if qs != null:
		_queue_start = qs.position
	_build_line()


func _build_line() -> void:
	for i in range(line_length + 1):
		var tumble := i == line_length
		var look: PonyLook
		if tumble:
			var def: CharacterDef = load("res://data/characters/tumble.tres")
			look = def.build_look()
		else:
			look = GeneratorScript.generate(9100 + i * 13)
		var p: CharacterBody3D = PonyScene.instantiate()
		get_parent().add_child(p)
		p.set_stock(look.to_dict())
		p.setup(StockShy)
		p.set_physics_process(false)
		p.position = _slot(i)
		p.rotation.y = deg_to_rad(120.0)
		_silhouette(p, look.coat if not tumble else Color(1.0, 0.6, 0.3))
		_line.append(p)
		_rims.append(look.coat)


## Where place `i` in the queue stands (0 is next into the ring).
func _slot(i: int) -> Vector3:
	return _queue_start + Vector3(1.1, 0, 0.9) * float(i)


func _silhouette(body: Node3D, rim: Color) -> void:
	var m := ShaderMaterial.new()
	m.shader = SILHOUETTE
	m.set_shader_parameter(&"rim_color", rim.lerp(Color(0.6, 0.65, 0.75), 0.5))
	for node in body.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in range(mi.mesh.get_surface_count()):
			mi.set_surface_override_material(s, m)
	body.set_meta(&"silhouette", m)


## Run the line until only Tumble is left at its head. Awaitable.
func play() -> void:
	for i in range(line_length):
		await _process_one(i)
		cycled.emit(i)
		await _advance_line(i + 1)
	finished.emit()


func _process_one(i: int) -> void:
	var p := _line[i]
	var t := create_tween()
	t.tween_property(p, "position", Vector3(0, 0, 0), step_seconds).set_trans(Tween.TRANS_SINE)
	await t.finished
	var sound := get_node_or_null("/root/Sound")
	if _ring_light != null:
		var c := _rims[i]
		var lt := create_tween()
		lt.tween_property(_ring_light, "light_color", c, 0.8)
		lt.parallel().tween_property(_ring_light, "light_energy", 6.0, 0.8)
		await lt.finished
		await get_tree().create_timer(hold_seconds * 0.4).timeout
		var flash := create_tween()
		flash.tween_property(_ring_light, "light_color", Color(1, 1, 1), 0.25)
		flash.parallel().tween_property(_ring_light, "light_energy", 12.0, 0.25)
		await flash.finished
	if sound != null and sound.call("has_sound", &"sparkle"):
		sound.call("play_at", &"sparkle", global_position)
	_rainbow_burst(_rims[i])
	var m: ShaderMaterial = p.get_meta(&"silhouette")
	var ft := create_tween()
	ft.tween_method(func(v: float) -> void: m.set_shader_parameter(&"fade", v), 1.0, 0.0, 1.2)
	await ft.finished
	p.visible = false
	if _ring_light != null:
		var back := create_tween()
		back.tween_property(_ring_light, "light_energy", 2.0, 1.4)
		back.parallel().tween_property(_ring_light, "light_color", Color(1.0, 0.95, 0.9), 1.4)
	await get_tree().create_timer(hold_seconds * 0.5).timeout


func _advance_line(from: int) -> void:
	var t := create_tween().set_parallel(true)
	for k in range(from, _line.size()):
		t.tween_property(_line[k], "position", _slot(k - from), 1.2).set_trans(Tween.TRANS_SINE)
	await t.finished


## The colour going up: a column of spectral sparkles rising out of the ring.
func _rainbow_burst(base: Color) -> void:
	var colors: Array[Color] = [base, Color(1.0, 0.85, 0.3), Color(0.4, 0.75, 1.0)]
	var p := BloomCeremony.sparkles(colors)
	p.amount = 90
	p.lifetime = 2.2
	var pm := p.process_material as ParticleProcessMaterial
	pm.direction = Vector3.UP
	pm.spread = 8.0
	pm.initial_velocity_min = 4.0
	pm.initial_velocity_max = 6.0
	pm.gravity = Vector3.ZERO
	pm.emission_sphere_radius = 0.4
	get_parent().add_child(p)
	p.position = Vector3(0, 1.2, 0)
	p.emitting = true
	get_tree().create_timer(3.0).timeout.connect(p.queue_free)


## Tumble, at the head of the line now (for the Rescue path's grab).
func tumble_body() -> Node3D:
	return _line[_line.size() - 1] if not _line.is_empty() else null
