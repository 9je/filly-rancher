class_name RaceTrack
extends Node3D
## SIX LANES BEHIND THE SPECTRA PALACE, and the rail the player watches from.
##
## THE TRACK HAS NO OPINION ABOUT WHO WINS. game/systems/race_card.gd decides the finish
## order and hands back a finishing time per lane; this node advances one clock and puts each
## runner at elapsed over her own time down her own lane. Because those times are strictly
## ordered by the finish order, the runner who crosses first IS the winner the arithmetic
## named, and race_finished carries the card's own order rather than anything measured off
## the screen. A dropped frame cannot settle a bet.
##
## THE SIX RUNNERS ARE BUILT ONCE AND KEPT. They are RaceRunners, not ponies (see that file's
## class comment), and they stand in the paddock between races. Nothing here creates or frees
## a Pony, and the pony the player entered is in her pen the whole time.
##
## BUILT IN CODE, seated on Terrain.height_at() like the fences and the Strip's lamps, for
## the reason game/world/region_fence.gd gives: the ground does not exist when ranch.tscn is
## loaded.

const RaceCardScript := preload("res://systems/race_card.gd")
const RaceRunnerScript := preload("res://world/race_runner.gd")
const PonyInstanceScript := preload("res://systems/pony_instance.gd")
const LayersScript := preload("res://world/collision_layers.gd")
const PaintScript := preload("res://ui/casino_paint.gd")

const LANES := 6
const LANE_WIDTH := 2.2

## Read from the card rather than declared twice: the times the card computes are this length
## over a speed, so a track of a different length would be a track the race does not fit.
const LENGTH := RaceCardScript.TRACK_LENGTH

const CENTRE := Vector2(0.0, 80.0)
const START_X := -20.0
const FINISH_X := 20.0

## Where a runner stands when there is no race: two metres behind the gate, in her own lane.
const PADDOCK_X := START_X - 2.0

const RAIL_HEIGHT := 1.05
const RAIL_THICKNESS := 0.12
const RAIL_SEGMENTS := 10
const RAIL_MARGIN := 1.2
const RAIL_COLOR := Color(0.86, 0.84, 0.90)
const POST_COLOR := Color(0.30, 0.27, 0.34)
const FINISH_COLOR := Color(1.00, 0.84, 0.32)

signal race_finished(order: Array, winner: int)

var _ground := Callable()
var _runners: Array[RaceRunner] = []
var _built := false
var _running := false
var _elapsed := 0.0
var _times: Array[float] = []
var _order: Array[int] = []


func configure(ground_sampler: Callable) -> void:
	_ground = ground_sampler


## Lay the lanes, the rails and the wire, and stand six runners in the paddock. Idempotent.
func build() -> void:
	if _built:
		return
	_built = true
	for lane in LANES:
		var runner: RaceRunner = RaceRunnerScript.new()
		runner.name = "Lane%d" % lane
		add_child(runner)
		runner.global_position = _paddock_point(lane)
		_runners.append(runner)
	_rail(lane_z(0) - LANE_WIDTH * 0.5 - RAIL_MARGIN, "RailSouth")
	_rail(lane_z(LANES - 1) + LANE_WIDTH * 0.5 + RAIL_MARGIN, "RailNorth")
	_wire()
	_gate_posts()


func runner_count() -> int:
	return _runners.size()


func runner(lane: int) -> RaceRunner:
	if lane < 0 or lane >= _runners.size():
		return null
	return _runners[lane]


func is_running() -> bool:
	return _running


func lane_z(lane: int) -> float:
	return CENTRE.y + (float(lane) - (float(LANES) - 1.0) * 0.5) * LANE_WIDTH


## A point `t` of the way down `lane`, seated on the ground. t of 0 is the gate and t of 1 is
## the wire.
func lane_point(lane: int, t: float) -> Vector3:
	var x: float = lerpf(START_X, FINISH_X, clampf(t, 0.0, 1.0))
	var z: float = lane_z(lane)
	return Vector3(x, _y(x, z), z)


## Put the field's six bodies on the six lanes. Returns how many actually got a model; fewer
## than LANES on a checkout with no converted assets, which is the documented degraded state
## and not an error.
##
## A lane's data_id is resolved through PonyInstance.resolve_data(), which reaches the hidden
## stock records as well as the named roster (game/systems/pony_registry.gd's hidden index),
## so a Company runner built on stock_bold resolves exactly as the player's own stock pony
## does.
func dress(field: Array[Dictionary]) -> int:
	var dressed := 0
	for entry in field:
		var lane: int = int(entry["lane"])
		var body: RaceRunner = runner(lane)
		if body == null:
			continue
		var data: PonyData = PonyInstanceScript.resolve_data(StringName(entry["data_id"]))
		if body.dress(data, entry["stock"] as Dictionary, String(entry["name"]), lane):
			dressed += 1
		body.set_pose(_paddock_point(lane), Vector3(1.0, 0.0, 0.0), 0.0)
	return dressed


## THEY'RE OFF. `result` is what RaceCard.run() answered for this exact field. Returns false
## for a field or a result that does not describe this track, having started nothing.
func start(field: Array[Dictionary], result: Dictionary) -> bool:
	if _running or field.size() != LANES:
		return false
	var times: Array = result.get("times", [])
	var order: Array = result.get("order", [])
	if times.size() != LANES or order.size() != LANES:
		return false
	_times = []
	for t in times:
		_times.append(maxf(float(t), 0.001))
	_order = order.duplicate()
	_elapsed = 0.0
	_running = true
	for lane in LANES:
		var body: RaceRunner = runner(lane)
		if body != null:
			body.set_pose(lane_point(lane, 0.0), Vector3(1.0, 0.0, 0.0), 0.0)
	return true


func _process(delta: float) -> void:
	if not _running:
		return
	_elapsed += delta
	var everybody_home := true
	for lane in LANES:
		var body: RaceRunner = runner(lane)
		if body == null:
			continue
		var t: float = clampf(_elapsed / _times[lane], 0.0, 1.0)
		if t < 1.0:
			everybody_home = false
		var speed: float = 0.0 if t >= 1.0 else LENGTH / _times[lane]
		body.set_pose(lane_point(lane, t), Vector3(1.0, 0.0, 0.0), speed)
		if t >= 1.0:
			body.rest()
	if everybody_home:
		_running = false
		# The card's own order, not one measured off the screen: see the class comment.
		race_finished.emit(_order.duplicate(), int(_order[0]) if not _order.is_empty() else -1)


func _paddock_point(lane: int) -> Vector3:
	var z: float = lane_z(lane)
	return Vector3(PADDOCK_X, _y(PADDOCK_X, z), z)


func _y(x: float, z: float) -> float:
	return float(_ground.call(x, z)) if _ground.is_valid() else 0.0


## One rail along the whole length, in segments so it follows the ground. Solid, on the PROPS
## layer, so the player leans on it rather than wandering into lane three.
func _rail(z: float, rail_name: String) -> void:
	var body := StaticBody3D.new()
	body.name = rail_name
	body.collision_layer = LayersScript.PROPS
	body.collision_mask = 0
	add_child(body)
	var step: float = (FINISH_X - START_X) / float(RAIL_SEGMENTS)
	for i in RAIL_SEGMENTS:
		var x: float = START_X + step * (float(i) + 0.5)
		var y: float = _y(x, z) + RAIL_HEIGHT * 0.5
		_slab(body, "%s_%d" % [rail_name, i],
			Vector3(step, RAIL_THICKNESS, RAIL_THICKNESS), Vector3(x, y, z), RAIL_COLOR)
		_slab(body, "%sPost_%d" % [rail_name, i],
			Vector3(RAIL_THICKNESS, RAIL_HEIGHT, RAIL_THICKNESS),
			Vector3(x - step * 0.5, _y(x, z) + RAIL_HEIGHT * 0.5, z), POST_COLOR)


## The wire: a bright post at each end of the finish line, so the eye knows where to look.
func _wire() -> void:
	var body := StaticBody3D.new()
	body.name = "Wire"
	body.collision_layer = LayersScript.PROPS
	body.collision_mask = 0
	add_child(body)
	for side in [-1.0, 1.0]:
		var z: float = CENTRE.y + side * (float(LANES) * LANE_WIDTH * 0.5 + RAIL_MARGIN)
		_slab(body, "WirePost%s" % ("N" if side > 0.0 else "S"),
			Vector3(0.22, 3.0, 0.22), Vector3(FINISH_X, _y(FINISH_X, z) + 1.5, z),
			FINISH_COLOR)


## SIX STARTING POSTS, ONE PER LANE, EACH IN ITS LANE'S COLOUR. The colour on the pony matches
## the colour on the gate she left and the colour on her card in the form guide, which is the
## whole of what the six removed nameplates were carrying. See game/world/race_runner.gd.
const GATE_POST_SIZE := Vector3(0.18, 1.6, 0.18)
const GATE_POST_OFFSET := 0.9


func _gate_posts() -> void:
	# One body for the six, the same shape _rail() and _wire() have: a StaticBody3D on the
	# PROPS layer with mask 0, so the player leans on a gate post rather than walking through
	# it and nothing detects anything with it.
	var body := StaticBody3D.new()
	body.name = "GatePosts"
	body.collision_layer = LayersScript.PROPS
	body.collision_mask = 0
	add_child(body)
	for lane in LANES:
		var z: float = lane_z(lane)
		var x: float = START_X - GATE_POST_OFFSET
		_slab(body, "GatePost%d" % lane, GATE_POST_SIZE,
			Vector3(x, _y(x, z) + GATE_POST_SIZE.y * 0.5, z),
			PaintScript.BAND_COLORS[lane])


## One box with a matching collider, the same shape game/world/building.gd's _slab() has, so
## what you see and what you bump into cannot drift apart.
func _slab(parent: StaticBody3D, slab_name: String, size: Vector3, at: Vector3,
		colour: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = 0.85
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	var box := BoxMesh.new()
	box.size = size
	box.material = mat
	var mesh := MeshInstance3D.new()
	mesh.name = slab_name
	mesh.mesh = box
	parent.add_child(mesh)
	mesh.global_position = at
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.name = slab_name + "Col"
	collider.shape = shape
	parent.add_child(collider)
	collider.global_position = at
