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
const LayersScript := preload("res://world/collision_layers.gd")
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
		_ceiling(room, spec)
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
	if file in SOLID_PIECES:
		make_solid(inst)
	return inst


## THE FURNITURE IS SOLID (playtest 2026-11-10 item 13: "i can walk through almost all props
## up here"). Pieces a pony stands beside, not under or on: one box over their meshes.
const SOLID_PIECES := ["fx_canisters", "fx_column", "fx_console", "fx_counter", "fx_crates",
	"fx_planter", "fx_stall", "fx_tank", "fx_lever", "fx_window_wall", "fx_ring"]


## A StaticBody3D with one box fitted to every mesh under `inst`, in its own space (so its
## scale carries over), on the props layer.
static func make_solid(inst: Node3D) -> void:
	var box := AABB()
	var first := true
	for m in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		# Its transform in `inst`'s space, walked up the parents (the tree may not be live yet).
		var xf := Transform3D.IDENTITY
		var n: Node = mi
		while n != null and n != inst:
			if n is Node3D:
				xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var b := xf * mi.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	if first or box.size.length() < 0.05:
		return
	var body := StaticBody3D.new()
	body.name = "Solid"
	body.collision_layer = LayersScript.PROPS
	body.collision_mask = 0
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box.size
	col.shape = shape
	col.position = box.get_center()
	body.add_child(col)
	inst.add_child(body)


func _floor(room: Node3D, spec: Dictionary) -> void:
	var file := "fx_floor_grate" if spec.metal else "fx_floor"
	var half := ROOM_SIZE * 0.5 - TILE * 0.5
	for x in [-half, 0.0, half]:
		for z in [-half, 0.0, half]:
			_piece(file, room, Vector3(x, 0, z))
	# A base slab under the tiles, so a bevelled seam shows floor, never what is beneath.
	var slab := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(ROOM_SIZE, 0.1, ROOM_SIZE)
	slab.mesh = bm
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.55, 0.58, 0.64) if spec.metal else Color(0.93, 0.88, 0.8)
	slab.material_override = sm
	slab.position = Vector3(0, -0.12, 0)
	room.add_child(slab)
	ToonStylerScript.style(slab, &"flat", {})
	var body := StaticBody3D.new()
	# What her hooves sound like on it (player.gd SURFACE_META): grating rings, tile clacks.
	body.set_meta(&"step_surface", &"hoof_metal" if spec.metal else &"hoof_stone")
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
		# The gallery's east wall is the window onto the processing floor beside it.
		_piece("fx_window_wall" if spec.name == &"gallery" else wall, room, Vector3(half, 0, along), -90.0)
	# The far wall: an arch into the next room, solid walls either side; the last room ends.
	var last := index == ROOMS.size() - 1
	for k in [-1, 0, 1]:
		var file := wall
		if k == 0 and not last:
			file = "fx_arch"
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


func _ceiling(room: Node3D, spec: Dictionary) -> void:
	var half := ROOM_SIZE * 0.5 - TILE * 0.5
	for x in [-half, 0.0, half]:
		for z in [-half, 0.0, half]:
			var file := "fx_ceiling_metal" if spec.metal else ("fx_skylight" if x == 0.0 and z == 0.0 else "fx_ceiling")
			_piece(file, room, Vector3(x, 0, z))
	if not spec.metal:
		# THE PUBLIC ROOMS ARE CHEERFUL. A rainbow runner down the middle, banners on the
		# walls, cloud topiaries in the corners: the tour should feel like a birthday party,
		# so the grey metal behind the service door lands.
		for z in [-4.0, 0.0, 4.0]:
			_piece("fx_runner", room, Vector3(0, 0.01, z))
		for z in [-3.5, 3.5]:
			_piece("fx_banner", room, Vector3(-ROOM_SIZE * 0.5 + 0.5, 5.6, z), 90.0)
			_piece("fx_banner", room, Vector3(ROOM_SIZE * 0.5 - 0.5, 5.6, z), -90.0)
		for c in [Vector3(-4.6, 0, -4.6), Vector3(4.6, 0, -4.6), Vector3(-4.6, 0, 4.6), Vector3(4.6, 0, 4.6)]:
			_piece("fx_planter", room, c)
	else:
		for z in [-3.0, 3.0]:
			_piece("fx_lamp_hanging", room, Vector3(0, 0, z))


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
			var lift := _piece("cloud_lift", room, Vector3(0, 0, 2.5), 0.0, 1.2)
			# NO CLOUD ROOF INDOORS (playtest 2026-11-10 item 7): the lift's canopy (its third
			# surface) hung at 1.8 to 4 m, right where the camera sits, a grey slab over the
			# whole first look at the Factory. Under the Factory's own ceiling it is not needed.
			if lift != null:
				for mi in lift.find_children("*", "MeshInstance3D", true, false):
					var m := mi as MeshInstance3D
					if m.mesh != null and m.mesh.get_surface_count() > 2:
						var clear := StandardMaterial3D.new()
						clear.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
						clear.albedo_color = Color(1, 1, 1, 0)
						m.set_surface_override_material(2, clear)
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
			# Below the walkway, the floor the Collectors patrol: tanks of what the Works
			# makes, crates of it, racks of it.
			for z in [-3.5, 3.5]:
				_piece("fx_tank", room, Vector3(4.6, 0, z))
			_piece("fx_crates", room, Vector3(-4.4, 0, 0.5), 15.0)
			_piece("fx_canisters", room, Vector3(-5.0, 0, -4.0), 90.0)
			_mark(markers, "patrol_a", Vector3(-4.0, 0, 3.0))
			_mark(markers, "patrol_b", Vector3(-4.0, 0, -3.0))
			_mark(markers, "patrol_c", Vector3(4.0, 0, -3.0))
		&"gallery":
			_mark(markers, "window", Vector3(half - 1.6, 0, 0))
			_piece("fx_canisters", room, Vector3(-5.0, 0, -3.0), 90.0)
			_piece("fx_canisters", room, Vector3(-5.0, 0, 3.0), 90.0)
			_piece("fx_console", room, Vector3(-2.5, 0, -5.0), 0.0)
			_piece("fx_lamp_hanging", room, Vector3(0, 0, 0))
			# Beside the gallery, not beyond it: the rooms run on down -Z, so a hall past
			# the far wall would sit inside the holding room. 3 m down, so the ring is in
			# the natural look down from the glass.
			_mark(markers, "floor_below", Vector3(half + 9.0, -3.0, 0))
			_processing_floor(room, Vector3(half + 9.0, -3.0, 0))
		&"holding":
			for x in [-4.0, 4.0]:
				for z in [-3.0, 0.0, 3.0]:
					_piece("fx_stall", room, Vector3(x, 0, z), 90.0 if x < 0 else -90.0)
			_mark(markers, "clover", Vector3(4.0, 0, -3.0))
			_piece("fx_crates", room, Vector3(0, 0, -4.5), -20.0)
			_piece("fx_lamp_hanging", room, Vector3(0, 0, 0))
		&"control":
			_piece("fx_lever", room, Vector3(0, 0, -3.5))
			# The room the whole valley's sky is run from: desks of dials, tanks either side.
			for x in [-3.6, 3.6]:
				_piece("fx_console", room, Vector3(x, 0, -1.0), 90.0 if x < 0 else -90.0)
				_piece("fx_tank", room, Vector3(x * 1.35, 0, -4.4))
				_piece("fx_tank", room, Vector3(x * 1.35, 0, 3.2))
			_piece("fx_lamp_hanging", room, Vector3(0, 0, 1.0))
			var handle := _piece("fx_lever_handle", room, Vector3(0.6, 1.1, -3.5))
			if handle != null:
				handle.name = "LeverHandle"
			_mark(markers, "lever", Vector3(0, 0, -2.2))


## The processing floor seen through the gallery window: a sunken metal hall below it and
## off its east side, the ring at its centre, a queue lane leading in. Built here; the set piece
## (game/world/factory_window.gd) stands the line of silhouettes on it and runs the light.
func _processing_floor(room: Node3D, centre: Vector3) -> void:
	var hall := Node3D.new()
	hall.name = "ProcessingFloor"
	hall.position = centre
	room.add_child(hall)
	for x in [-6.0, -2.0, 2.0, 6.0]:
		for z in [-6.0, -2.0, 2.0, 6.0]:
			_piece("fx_floor_grate", hall, Vector3(x, 0, z))
	# Three walls: the fourth side is under the gallery's glass, and a wall there would
	# rise past the sill and hide the floor.
	for k in [-6.0, -2.0, 2.0, 6.0]:
		_piece("fx_wall_metal", hall, Vector3(8.0, 0, k), -90.0)
		_piece("fx_wall_metal", hall, Vector3(k, 0, -8.0), 0.0)
		_piece("fx_wall_metal", hall, Vector3(k, 0, 8.0), 180.0)
	_piece("fx_ring", hall, Vector3(0, 0, 0))
	# Pipes along the far wall, high: never between the glass and the ring.
	for z in [-4.0, 0.0, 4.0]:
		_piece("fx_pipe", hall, Vector3(6.5, 6.0, z), 90.0)
	var glow := OmniLight3D.new()
	glow.name = "RingLight"
	glow.light_color = Color(1.0, 0.95, 0.9)
	glow.light_energy = 2.0
	glow.omni_range = 9.0
	glow.position = Vector3(0, 2.0, 0)
	hall.add_child(glow)
	var m := Marker3D.new()
	m.name = "QueueStart"
	m.position = Vector3(5.0, 0, 3.0)
	hall.add_child(m)
