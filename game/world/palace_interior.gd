class_name PalaceInterior
extends Node3D
## THE SPECTRA PALACE, INSIDE (owner playtest 2026-10-25: "spectra palace not real yet? weird
## sign you gotta walk through to get in"). The door used to open a full screen lobby menu; it
## opens onto this hall now, and every game in the house has a place on its floor.
##
## WHERE IT IS. Inside the ranch scene, sixty metres under the Palace's own footprint, sealed
## on all six sides. Going in moves the player, it does not change the scene, so the wallet,
## the pens, the herd, the clock and the saddlebag are exactly where they were: nothing is
## unloaded, saved or rebuilt by a visit (DECISIONS.md 2026-10-26). Under the map rather than
## off its edge because a room off the edge is a room somebody on the valley rim can see; under
## the ground the terrain itself hides the roof. Ranch.enter_palace() turns the camera's
## terrain guard off while she is here, because that guard would otherwise lift the lens up to
## the grass sixty metres overhead.
##
## THE FLOOR PLAN, in this node's own metres (+Z is the door, -Z the far end):
##
##   z +16   the doors back out, a red mat, a rope lane, the arrival spot
##   east    the cashier's cage near the door, the racing window at the far end
##   west    a wall row of slot machines and an island of six more
##   middle  two blackjack tables, four columns, three chandeliers down the runner
##   z -12   the prize wheel on a lit round stage, neon stars either side
##
## EVERY PIECE IS A BLENDER MODEL (tools/blender_props/build_props.py, the pc_* kit), styled by
## ToonStyler like the Factory's kit, and every one is named in SCALE.md so test_scale measures
## it. The colliders are plain boxes and cylinders, because a pony bumping a slot machine
## wants a slab, not the machine's own lever.
##
## THE STATIONS. Each game has one or more spots on the floor (STATION_SPOTS) and E within
## STATION_RADIUS of one is Interaction.Kind.PALACE_STATION with the station's id as the
## subject. What that opens is ranch.gd's business (it owns the menus and the money); this file
## only knows where things stand.
##
## THE STAFF ARE ATTENDANTS, NOT PONIES (game/world/attendant.gd says why): a cashier, a race
## clerk, two dealers, a wheel host, and a few regulars at the machines and the tables. Their
## colours come from the random generator's own look draw, seeded, so the house is the same
## house on every visit.

const KIT := "res://assets/models/"
const ToonStylerScript := preload("res://systems/toon_styler.gd")
const LayersScript := preload("res://world/collision_layers.gd")
const AttendantScript := preload("res://world/attendant.gd")
const PonyRegistryScript := preload("res://systems/pony_registry.gd")
const StockPaletteScript := preload("res://systems/stock_palette.gd")
const InteractionScript := preload("res://world/interaction.gd")

## The hall's inside faces: x in [-HALF_WIDTH, HALF_WIDTH], z in [-HALF_DEPTH, HALF_DEPTH],
## floor at y = 0, ceiling at HEIGHT. tools/blender_props/build_props.py's PC_HW, PC_HD and
## PC_H are the same three numbers.
const HALF_WIDTH := 12.0
const HALF_DEPTH := 16.0
const HEIGHT := 7.5

## Where she stands on the way in, and the way she faces: two metres inside the doors, looking
## down the runner at the wheel.
const ARRIVAL := Vector3(0.0, 0.05, 12.8)
const ARRIVAL_YAW := 0.0

## The games, in the order the old lobby listed them. Ids, not menu rows: ranch.gd maps them.
const STATIONS: Array[StringName] = [&"cage", &"slots", &"wheel", &"blackjack", &"racing"]
## How near a spot she has to be for E to mean that game. Wide enough that "in front of the
## machine" is enough, narrow enough that two machines 1.3 m apart are both the slots anyway.
const STATION_RADIUS := 1.9
const EXIT_RADIUS := 2.4

## THE SLOT MACHINES, wall row then island: [x, z, yaw degrees]. A machine is 0.92 m across, so
## a 1.3 m pitch leaves a pony's shoulder between two of them.
const SLOT_ROW: Array = [
	[-11.55, -8.0, 90.0], [-11.55, -6.7, 90.0], [-11.55, -5.4, 90.0], [-11.55, -4.1, 90.0],
	[-11.55, -2.8, 90.0], [-11.55, -1.5, 90.0], [-11.55, -0.2, 90.0], [-11.55, 1.1, 90.0],
	[-6.95, -5.2, -90.0], [-6.95, -3.9, -90.0], [-6.95, -2.6, -90.0],
	[-5.95, -5.2, 90.0], [-5.95, -3.9, 90.0], [-5.95, -2.6, 90.0],
]
## The machines a regular is already playing (indices into SLOT_ROW); E is not offered at those.
const SLOT_TAKEN: Array[int] = [1, 4, 10]
const TABLES: Array[Vector3] = [Vector3(5.6, 0.0, 2.6), Vector3(5.6, 0.0, -3.6)]
const CAGE_AT := Vector3(11.7, 0.0, 9.4)
const BOOTH_AT := Vector3(11.7, 0.0, -9.6)
const STAGE_AT := Vector3(0.0, 0.0, -11.8)
const WHEEL_AT := Vector3(0.0, 0.27, -12.6)
## The wheel's hub over its stand's origin (pc_wheel_stand's own `hub`).
const WHEEL_HUB := 2.7
const EXIT_AT := Vector3(0.0, 0.0, 15.95)
const COLUMNS: Array[Vector3] = [Vector3(-3.4, 0, 7.5), Vector3(3.4, 0, 7.5),
	Vector3(-3.4, 0, -6.5), Vector3(3.4, 0, -6.5)]
const CHANDELIERS: Array[Vector3] = [Vector3(0, HEIGHT - 0.44, 8.0),
	Vector3(0, HEIGHT - 0.44, 0.0), Vector3(0, HEIGHT - 0.44, -7.0),
	Vector3(-8.6, HEIGHT - 0.44, -3.4), Vector3(8.6, HEIGHT - 0.44, -0.6)]
## How fast the wheel idles round while nobody is betting on it, in radians a second: slow
## enough to read the numbers, fast enough to say it is a wheel.
const WHEEL_IDLE_SPIN := 0.22

## The spots E is offered from, in this node's space. Built in build() from the furniture above
## rather than typed twice.
var _spots: Dictionary = {}
var _exit_spot := Vector3.ZERO
var _wheel: Node3D = null
var _staff: Node3D = null
var _pieces: Node3D = null
var _cache: Dictionary = {}
var _built := false

## Emitted when the player walks into the doors, the same as E at them.
signal exit_walked_into()


func is_built() -> bool:
	return _built


## Build the hall. `pony_dir` is where the stock pony records live (the spawner's own
## pony_dir), for the staff. Safe to call twice: the second call does nothing.
func build(pony_dir: String = "res://data/ponies") -> void:
	if _built:
		return
	_built = true
	_pieces = Node3D.new()
	_pieces.name = "Pieces"
	add_child(_pieces)
	_shell()
	_furniture()
	_lights()
	_triggers()
	_stand_staff(pony_dir)
	set_process(false)


## Whether the wheel idles round. On while she is inside, off while she is not, so a hall
## nobody is in costs nothing.
func set_active(on: bool) -> void:
	set_process(on and _wheel != null)


func _process(delta: float) -> void:
	if _wheel != null:
		_wheel.rotate_object_local(Vector3.FORWARD, -WHEEL_IDLE_SPIN * delta)


# --- what is offered -----------------------------------------------------------------------

## Every station spot and the door within reach of world point `at`, as Interaction candidates.
func candidates(at: Vector3) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var local := to_local(at)
	var flat := Vector2(local.x, local.z)
	for id: StringName in STATIONS:
		var best := INF
		for p: Vector3 in _spots.get(id, []):
			best = minf(best, flat.distance_to(Vector2(p.x, p.z)))
		if best <= STATION_RADIUS:
			out.append(InteractionScript.candidate(InteractionScript.Kind.PALACE_STATION, best,
				String(id)))
	var gap := flat.distance_to(Vector2(_exit_spot.x, _exit_spot.z))
	if gap <= EXIT_RADIUS:
		out.append(InteractionScript.candidate(InteractionScript.Kind.PALACE_EXIT, gap))
	return out


## The first spot for station `id` (or &"exit" for the doors), in WORLD space. For tests, the
## capture script and the real-input driver: where a person would walk to.
func station_point(id: StringName) -> Vector3:
	if id == &"exit":
		return to_global(_exit_spot)
	var spots: Array = _spots.get(id, [])
	return to_global(spots[0]) if not spots.is_empty() else global_position


## All the spots for `id`, world space.
func station_points(id: StringName) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for p: Vector3 in _spots.get(id, []):
		out.append(to_global(p))
	return out


func staff_count() -> int:
	return _staff.get_child_count() if _staff != null else 0


## A camera pose for a named view, [eye, target] in this node's space, for
## scenes/test/palace_shot.gd.
func view_pose(view: StringName) -> Array:
	match view:
		&"hall":
			return [Vector3(-1.5, 3.4, 14.6), Vector3(0.6, 2.2, -8.0)]
		&"slots":
			return [Vector3(-3.0, 2.6, 4.0), Vector3(-10.5, 1.4, -4.5)]
		&"wheel":
			return [Vector3(1.2, 2.4, -3.0), Vector3(0.0, 2.6, -12.6)]
		&"tables":
			return [Vector3(-1.0, 3.0, -1.0), Vector3(6.8, 0.9, 0.0)]
		&"cage":
			return [Vector3(2.5, 2.6, 6.0), Vector3(10.5, 2.0, 10.0)]
		&"racing":
			return [Vector3(3.0, 2.6, -5.0), Vector3(11.0, 2.8, -10.0)]
		&"door":
			return [Vector3(0.5, 2.6, 2.0), Vector3(0.0, 2.4, 16.0)]
	return [Vector3(0, 3, 10), Vector3(0, 2, 0)]


# --- building ------------------------------------------------------------------------------

func _piece(file: String, at: Vector3, yaw_deg: float = 0.0, parent: Node3D = null) -> Node3D:
	var path := KIT + file + ".glb"
	if not ResourceLoader.exists(path):
		push_error("PalaceInterior: no %s" % path)
		return null
	var scene: PackedScene = _cache.get(path)
	if scene == null:
		scene = load(path)
		_cache[path] = scene
	var inst: Node3D = scene.instantiate()
	inst.name = "%s_%d" % [file, _pieces.get_child_count()]
	inst.set_meta(&"asset", file)
	inst.position = at
	inst.rotation.y = deg_to_rad(yaw_deg)
	(parent if parent != null else _pieces).add_child(inst)
	ToonStylerScript.style(inst, &"building")
	return inst


func _box_body(layer: int, size: Vector3, at: Vector3, yaw_deg: float = 0.0,
		surface: StringName = &"") -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	if surface != &"":
		body.set_meta(&"step_surface", surface)
	var shape := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	shape.shape = b
	body.add_child(shape)
	body.position = at
	body.rotation.y = deg_to_rad(yaw_deg)
	add_child(body)
	return body


func _round_body(radius: float, height: float, at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = LayersScript.PROPS
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var c := CylinderShape3D.new()
	c.radius = radius
	c.height = height
	shape.shape = c
	body.add_child(shape)
	body.position = at + Vector3(0, height * 0.5, 0)
	add_child(body)
	return body


## The room: its model, and six slabs on the TERRAIN layer the camera probes and her hooves
## stand on. The floor names its own sound: parquet, so her steps are the timber set
## (player.gd SURFACE_META), carpet or not.
func _shell() -> void:
	_piece("pc_hall", Vector3.ZERO)
	var w := HALF_WIDTH * 2.0
	var d := HALF_DEPTH * 2.0
	_box_body(LayersScript.TERRAIN, Vector3(w + 1.0, 0.4, d + 1.0), Vector3(0, -0.15, 0), 0.0,
		&"hoof_wood").name = "Floor"
	_box_body(LayersScript.TERRAIN, Vector3(w + 1.0, 0.4, d + 1.0), Vector3(0, HEIGHT + 0.2, 0)) \
		.name = "Ceiling"
	for side in [-1.0, 1.0]:
		_box_body(LayersScript.TERRAIN, Vector3(0.4, HEIGHT + 1.0, d + 1.0),
			Vector3(side * (HALF_WIDTH + 0.2), HEIGHT * 0.5, 0)).name = "WallX"
		_box_body(LayersScript.TERRAIN, Vector3(w + 1.0, HEIGHT + 1.0, 0.4),
			Vector3(0, HEIGHT * 0.5, side * (HALF_DEPTH + 0.2))).name = "WallZ"


func _furniture() -> void:
	# The slots. Every machine is a station spot unless a regular is already at it.
	var slot_spots: Array[Vector3] = []
	for i in SLOT_ROW.size():
		var row: Array = SLOT_ROW[i]
		var at := Vector3(float(row[0]), 0.0, float(row[1]))
		var yaw := float(row[2])
		_piece("pc_slot" if i % 2 == 0 else "pc_slot_b", at, yaw)
		_box_body(LayersScript.PROPS, Vector3(0.92, 2.1, 0.86), at + Vector3(0, 1.05, 0), yaw)
		if not (i in SLOT_TAKEN):
			slot_spots.append(at + _facing(yaw) * 1.45)
	_spots[&"slots"] = slot_spots
	# The wheel on its stage, the clapper at the top, a spot in front of the stage.
	_piece("pc_stage", STAGE_AT)
	_round_body(3.2, 0.3, STAGE_AT)
	var stand := _piece("pc_wheel_stand", WHEEL_AT)
	_box_body(LayersScript.PROPS, Vector3(4.6, 5.0, 1.2), WHEEL_AT + Vector3(0, 2.5, -0.4))
	_wheel = _piece("pc_wheel", WHEEL_AT + Vector3(0, WHEEL_HUB, 0))
	if _wheel != null:
		_wheel.name = "WheelDisc"
	if stand != null:
		stand.name = "WheelStand"
	_spots[&"wheel"] = [STAGE_AT + Vector3(0, 0, 4.4), STAGE_AT + Vector3(-2.6, 0, 3.8),
		STAGE_AT + Vector3(2.6, 0, 3.8)] as Array[Vector3]
	# Two blackjack tables, the players' curve toward the room's middle.
	var table_spots: Array[Vector3] = []
	for t: Vector3 in TABLES:
		_piece("pc_blackjack", t, -90.0)
		_round_body(1.75, 1.0, t + Vector3(0.2, 0, 0))
		table_spots.append(t + Vector3(-2.55, 0, 0))
	_spots[&"blackjack"] = table_spots
	# The cage by the door and the racing window at the far end, both on the east wall.
	_piece("pc_cage", CAGE_AT, -90.0)
	_box_body(LayersScript.PROPS, Vector3(5.6, 4.5, 2.9), CAGE_AT + Vector3(-1.35, 2.25, 0), -90.0)
	_spots[&"cage"] = [CAGE_AT + Vector3(-3.6, 0, 0)] as Array[Vector3]
	_piece("pc_race_booth", BOOTH_AT, -90.0)
	_box_body(LayersScript.PROPS, Vector3(5.2, 4.9, 2.9), BOOTH_AT + Vector3(-1.35, 2.45, 0), -90.0)
	_spots[&"racing"] = [BOOTH_AT + Vector3(-3.6, 0, 0)] as Array[Vector3]
	# The doors back out, and the rope lane up to them.
	_piece("pc_exit_door", EXIT_AT, 180.0)
	_exit_spot = EXIT_AT + Vector3(0, 0, -1.6)
	for x in [-2.0, 2.0]:
		_piece("pc_rope", Vector3(x, 0, 11.6), 90.0)
		_box_body(LayersScript.PROPS, Vector3(0.12, 1.0, 2.7), Vector3(x, 0.5, 11.6))
	# Columns, palms, neon.
	for c: Vector3 in COLUMNS:
		_piece("pc_column", c)
		_round_body(0.62, HEIGHT, c)
	for p: Vector3 in [Vector3(-10.6, 0, 14.6), Vector3(10.6, 0, 14.6), Vector3(-10.6, 0, -14.6),
			Vector3(10.6, 0, -14.6)]:
		_piece("pc_palm", p)
		_round_body(0.45, 1.6, p)
	for x in [-6.5, 6.5]:
		_piece("pc_neon_star", Vector3(x, 4.4, -HALF_DEPTH + 0.1))
	_piece("pc_neon_shoe", Vector3(-HALF_WIDTH + 0.12, 3.5, -2.0), 90.0)
	_piece("pc_neon_shoe", Vector3(HALF_WIDTH - 0.12, 3.5, 2.0), -90.0)
	_piece("pc_neon_star", Vector3(HALF_WIDTH - 0.12, 3.5, -2.0), -90.0)
	for c: Vector3 in CHANDELIERS:
		_piece("pc_chandelier", c)


## The unit vector a piece turned `yaw_deg` faces, in this node's XZ.
static func _facing(yaw_deg: float) -> Vector3:
	var r := deg_to_rad(yaw_deg)
	return Vector3(sin(r), 0.0, cos(r))


## THE LIGHT IS THE ROOM'S OWN. ranch.gd's sky rig puts the sun out while she is in here
## (SkyRig.set_indoors()), so these are all there is: a warm pool under every chandelier, a
## pink wash and a spot on the wheel, a cool fill along the slots, a lamp over each counter.
## No shadows on any of them; the toon bands come from the lights, the depth from the
## colours.
func _lights() -> void:
	for c: Vector3 in CHANDELIERS:
		_omni(c + Vector3(0, -2.4, 0), Color(1.0, 0.84, 0.66), 1.7, 12.0)
	_omni(Vector3(0, 4.2, -9.0), Color(1.0, 0.45, 0.75), 1.6, 9.0)
	_omni(Vector3(-9.0, 3.2, -3.4), Color(0.55, 0.8, 1.0), 1.0, 8.0)
	_omni(Vector3(8.4, 3.4, 9.4), Color(1.0, 0.86, 0.6), 1.2, 7.0)
	_omni(Vector3(8.4, 3.4, -9.6), Color(1.0, 0.86, 0.6), 1.2, 7.0)
	_omni(Vector3(0, 3.0, 13.0), Color(1.0, 0.8, 0.7), 1.0, 7.0)
	var spot := SpotLight3D.new()
	spot.name = "WheelSpot"
	spot.light_color = Color(1.0, 0.95, 0.85)
	spot.light_energy = 4.0
	spot.spot_range = 14.0
	spot.spot_angle = 24.0
	spot.shadow_enabled = false
	add_child(spot)
	spot.position = Vector3(0, HEIGHT - 0.6, -5.0)
	spot.look_at_from_position(spot.position, WHEEL_AT + Vector3(0, WHEEL_HUB, 0), Vector3.UP)


func _omni(at: Vector3, colour: Color, energy: float, reach: float) -> void:
	var l := OmniLight3D.new()
	l.light_color = colour
	l.light_energy = energy
	l.omni_range = reach
	l.omni_attenuation = 0.8
	l.shadow_enabled = false
	l.position = at
	add_child(l)


## Walking into the doors is leaving, the same as E at them: an Area3D just in front of the
## leaves that watches for the player only.
func _triggers() -> void:
	var area := Area3D.new()
	area.name = "ExitTrigger"
	area.collision_layer = 0
	area.collision_mask = LayersScript.PLAYER
	var shape := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(2.6, 2.2, 0.8)
	shape.shape = b
	area.add_child(shape)
	area.position = EXIT_AT + Vector3(0, 1.1, -0.55)
	add_child(area)
	area.body_entered.connect(func(body: Node3D) -> void:
		if body.is_in_group(&"player"):
			exit_walked_into.emit())


## THE HOUSE STAFF AND ITS REGULARS. [where, facing (a point to look at), stock record index].
func _stand_staff(pony_dir: String) -> void:
	_staff = Node3D.new()
	_staff.name = "Staff"
	add_child(_staff)
	var registry := PonyRegistryScript.new()
	registry.load_all(pony_dir)
	var palette: StockPalette = StockPaletteScript.load_stock()
	var rng := RandomNumberGenerator.new()
	rng.seed = 26102026
	var cast: Array = [
		["Cashier", CAGE_AT + Vector3(-1.0, 0, 0), CAGE_AT + Vector3(-6, 0, 0)],
		["RaceClerk", BOOTH_AT + Vector3(-1.0, 0, 0), BOOTH_AT + Vector3(-6, 0, 0)],
		["WheelHost", STAGE_AT + Vector3(3.6, 0, 2.6), STAGE_AT + Vector3(0, 0, 8)],
	]
	for t: Vector3 in TABLES:
		cast.append(["Dealer", t + Vector3(1.3, 0, 0), t + Vector3(-4, 0, 0)])
	for i: int in SLOT_TAKEN:
		var row: Array = SLOT_ROW[i]
		var at := Vector3(float(row[0]), 0.0, float(row[1]))
		cast.append(["Regular", at + _facing(float(row[2])) * 1.35, at])
	cast.append(["Regular", TABLES[1] + Vector3(-1.6, 0, -2.0), TABLES[1]])
	cast.append(["Regular", Vector3(-1.8, 0, 3.4), Vector3(4.0, 0, 2.6)])
	for i in cast.size():
		var who: Array = cast[i]
		var data: PonyData = registry.by_id(StockPaletteScript.IDS[i % StockPaletteScript.IDS.size()])
		if data == null:
			continue
		var node: Attendant = AttendantScript.new()
		node.name = "%s%d" % [who[0], i]
		_staff.add_child(node)
		node.position = who[1]
		var look: Dictionary = palette.draw_look(rng) if palette != null else {}
		var to: Vector3 = (who[2] as Vector3) - (who[1] as Vector3)
		to.y = 0.0
		node.dress(data, look, global_transform.basis * to.normalized())
