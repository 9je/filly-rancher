class_name FactoryInterior
extends Node3D
## THE RAINBOW FACTORY, INSIDE (STORY.md, "The Reveal" and both climaxes). Built at load
## from the Blender kit in game/assets/models/fx_*.glb (tools/blender_props/build_props.py),
## as a straight run of rooms along -Z so a walk through it is a walk down the story:
##
##   0 landing     where the cloud-lift sets you down          dread 0.00
##   1 welcome     posters, columns, the Chairmare's welcome    dread 0.05
##   2 classroom   an "Academy" classroom painted on a wall     dread 0.12
##   3 giftshop    Rainbow Dye, every shade a name              dread 0.20
##   4 walkway     grey metal, a catwalk over a patrolled floor dread 0.45
##   5 gallery     the long window over the processing floor    dread 0.80
##   6 holding     long-term holding: stalls, tags              dread 0.85
##   7 control     the lever                                    dread 0.90
##
## Each room is ROOM_SIZE square with walls on its sides and an arch into the next. Each has
## an Area3D (`Rooms/<name>/Trigger`) that emits Events.area_entered(&"factory_<name>") and
## a set of named markers its scripts use (Marker3D under `Rooms/<name>/Markers`). The
## scripts that run the tour, the stealth and the window are game/world/factory_*.gd.

const KIT := "res://assets/models/"
const ToonStylerScript := preload("res://systems/toon_styler.gd")
const ROOM_SIZE := 12.0
const TILE := 4.0

const ROOMS: Array[Dictionary] = [
	{"name": &"landing", "dread": 0.0, "metal": false, "light": Color(1.0, 0.95, 0.85)},
	{"name": &"welcome", "dread": 0.05, "metal": false, "light": Color(1.0, 0.94, 0.86)},
	{"name": &"classroom", "dread": 0.12, "metal": false, "light": Color(0.98, 0.95, 0.9)},
	{"name": &"giftshop", "dread": 0.2, "metal": false, "light": Color(0.96, 0.94, 0.92)},
	{"name": &"walkway", "dread": 0.45, "metal": true, "light": Color(0.78, 0.84, 0.92)},
	{"name": &"gallery", "dread": 0.8, "metal": true, "light": Color(0.66, 0.72, 0.8)},
	{"name": &"holding", "dread": 0.85, "metal": true, "light": Color(0.62, 0.66, 0.74)},
	{"name": &"control", "dread": 0.9, "metal": true, "light": Color(0.7, 0.66, 0.72)},
]

var rooms: Dictionary = {}
var _cache: Dictionary = {}


func _ready() -> void:
	build()


func build() -> void:
	var root := Node3D.new()
	root.name = "Rooms"
	add_child(root)
	for i in range(ROOMS.size()):
		var spec: Dictionary = ROOMS[i]
		var room := Node3D.new()
		room.name = String(spec.name)
		room.position = Vector3(0, 0, -i * ROOM_SIZE)
		root.add_child(room)
		rooms[spec.name] = room
		_floor(room, spec)
		_walls(room, spec, i)
		_light(room, spec)
		_trigger(room, spec)
		var markers := Node3D.new()
		markers.name = "Markers"
		room.add_child(markers)
		_dress(room, spec, markers)


## Where room `name` starts (its entry edge centre), in this node's space.
func room_origin(name: StringName) -> Vector3:
	var r: Node3D = rooms.get(name)
	return r.position + Vector3(0, 0, ROOM_SIZE * 0.5) if r != null else Vector3.ZERO


func marker(room_name: StringName, marker_name: String) -> Marker3D:
	var r: Node3D = rooms.get(room_name)
	return r.get_node_or_null("Markers/" + marker_name) as Marker3D if r != null else null


static func dread_of(room_name: StringName) -> float:
	for spec in ROOMS:
		if spec.name == room_name:
			return float(spec.dread)
	return 0.0


# --- building --------------------------------------------------------------------------

func _piece(file: String, parent: Node3D, at: Vector3, yaw_deg: float = 0.0, s: float = 1.0) -> Node3D:
	var path := KIT + file + ".glb"
	if not ResourceLoader.exists(path):
		return null
	var scene: PackedScene = _cache.get(path)
	if scene == null:
		scene = load(path)
		_cache[path] = scene
	var inst: Node3D = scene.instantiate()
	inst.position = at
	inst.rotation.y = deg_to_rad(yaw_deg)
	inst.scale = Vector3.ONE * s
	parent.add_child(inst)
	ToonStylerScript.style(inst, &"building")
	return inst


func _floor(room: Node3D, spec: Dictionary) -> void:
	var file := "fx_floor_grate" if spec.metal else "fx_floor"
	var half := ROOM_SIZE * 0.5 - TILE * 0.5
	for x in [-half, 0.0, half]:
		for z in [-half, 0.0, half]:
			_piece(file, room, Vector3(x, 0, z))
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(ROOM_SIZE, 0.2, ROOM_SIZE)
	shape.shape = box
	shape.position = Vector3(0, -0.1, 0)
	body.add_child(shape)
	room.add_child(body)


func _walls(room: Node3D, spec: Dictionary, index: int) -> void:
	var wall := "fx_wall_metal" if spec.metal else "fx_wall"
	var half := ROOM_SIZE * 0.5
	for k in [-1, 0, 1]:
		var along := float(k) * TILE
		# Side walls face inward (east wall faces -X, west wall faces +X).
		_piece(wall, room, Vector3(-half, 0, along), 90.0)
		_piece(wall, room, Vector3(half, 0, along), -90.0)
	# The far wall: an arch into the next room, solid walls either side; the last room ends.
	var last := index == ROOMS.size() - 1
	for k in [-1, 0, 1]:
		var file := wall
		if k == 0 and not last:
			file = "fx_arch"
		if spec.name == &"gallery":
			file = "fx_window_wall" if k != 0 else "fx_arch"
		_piece(file, room, Vector3(float(k) * TILE, 0, -half), 0.0)
	if index == 0:
		for k in [-1, 1]:
			_piece(wall, room, Vector3(float(k) * TILE, 0, half), 180.0)
	_collide_walls(room, index)


func _collide_walls(room: Node3D, index: int) -> void:
	var half := ROOM_SIZE * 0.5
	var body := StaticBody3D.new()
	room.add_child(body)
	for side in [-1.0, 1.0]:
		var shape := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = Vector3(0.4, 6.0, ROOM_SIZE)
		shape.shape = b
		shape.position = Vector3(side * half, 3.0, 0)
		body.add_child(shape)
	# Far wall with a 2.2 m gap in the middle (the arch), except the last room.
	var last := index == ROOMS.size() - 1
	for seg in ([[-3.55, 4.9], [3.55, 4.9]] if not last else [[0.0, ROOM_SIZE]]):
		var shape2 := CollisionShape3D.new()
		var b2 := BoxShape3D.new()
		b2.size = Vector3(float(seg[1]), 6.0, 0.4)
		shape2.shape = b2
		shape2.position = Vector3(float(seg[0]), 3.0, -half)
		body.add_child(shape2)


func _light(room: Node3D, spec: Dictionary) -> void:
	for x in [-3.0, 3.0]:
		var l := OmniLight3D.new()
		l.light_color = spec.light
		l.light_energy = 1.1 if not spec.metal else 0.7
		l.omni_range = 11.0
		l.shadow_enabled = false
		l.position = Vector3(x, 5.0, 0)
		room.add_child(l)


func _trigger(room: Node3D, spec: Dictionary) -> void:
	var area := Area3D.new()
	area.name = "Trigger"
	var shape := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(ROOM_SIZE - 1.0, 4.0, ROOM_SIZE - 1.0)
	shape.shape = b
	shape.position = Vector3(0, 2.0, 0)
	area.add_child(shape)
	room.add_child(area)
	var area_name := StringName("factory_" + String(spec.name))
	area.body_entered.connect(func(body: Node3D) -> void:
		if body.is_in_group(&"player"):
			var bus := get_node_or_null("/root/Events")
			if bus != null:
				bus.emit_signal("area_entered", area_name))


func _mark(markers: Node3D, name: String, at: Vector3) -> void:
	var m := Marker3D.new()
	m.name = name
	m.position = at
	markers.add_child(m)


func _dress(room: Node3D, spec: Dictionary, markers: Node3D) -> void:
	var half := ROOM_SIZE * 0.5
	_mark(markers, "entry", Vector3(0, 0, half - 1.5))
	_mark(markers, "exit", Vector3(0, 0, -half + 1.0))
	match spec.name:
		&"landing":
			_piece("cloud_lift", room, Vector3(0, 0, 2.5), 0.0, 1.2)
			_mark(markers, "lift", Vector3(0, 0.4, 2.5))
		&"welcome":
			for x in [-3.5, 3.5]:
				for z in [-3.0, 3.0]:
					_piece("fx_column", room, Vector3(x, 0, z))
			for z in [-2.0, 2.0]:
				_piece("fx_poster", room, Vector3(-half + 0.35, 2.6, z), 90.0)
				_piece("fx_poster", room, Vector3(half - 0.35, 2.6, z), -90.0)
			_mark(markers, "guide", Vector3(0, 0, 0))
		&"classroom":
			_piece("fx_poster", room, Vector3(0, 2.8, -half + 0.45), 0.0, 2.4)
			_mark(markers, "guide", Vector3(2.0, 0, 0))
		&"giftshop":
			_piece("fx_counter", room, Vector3(-3.0, 0, -1.0), 90.0)
			_mark(markers, "guide", Vector3(1.5, 0, 1.0))
			_mark(markers, "service_door", Vector3(half - 1.2, 0, -3.5))
		&"walkway":
			for z in [-4.0, 0.0, 4.0]:
				_piece("fx_catwalk", room, Vector3(0, 2.4, z), 90.0)
				_piece("fx_pipe", room, Vector3(3.5, 4.2, z), 90.0)
			_mark(markers, "patrol_a", Vector3(-4.0, 0, 3.0))
			_mark(markers, "patrol_b", Vector3(-4.0, 0, -3.0))
			_mark(markers, "patrol_c", Vector3(4.0, 0, -3.0))
		&"gallery":
			_mark(markers, "window", Vector3(0, 0, -half + 1.6))
			_mark(markers, "floor_below", Vector3(0, -6.0, -half - 6.0))
			_piece("fx_ring", room, Vector3(0, -6.0, -half - 6.0))
		&"holding":
			for x in [-4.0, 4.0]:
				for z in [-3.0, 0.0, 3.0]:
					_piece("fx_stall", room, Vector3(x, 0, z), 90.0 if x < 0 else -90.0)
			_mark(markers, "clover", Vector3(4.0, 0, -3.0))
		&"control":
			_piece("fx_lever", room, Vector3(0, 0, -3.5))
			var handle := _piece("fx_lever_handle", room, Vector3(0.6, 1.1, -3.5))
			if handle != null:
				handle.name = "LeverHandle"
			_mark(markers, "lever", Vector3(0, 0, -2.2))
