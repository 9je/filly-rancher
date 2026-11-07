class_name Attendant
extends StaticBody3D
## SOMEBODY BEHIND THE COUNTER: the vendor at the Market and the teller at the Palace. A
## dressed pony body standing still, and deliberately NOT a Pony.
##
## WHY NOT A PONY. The project's hardest rule is that no pony ever dies and that only
## Pony._state_leaving may free one, and the whole census the ranch gate asserts on is
## "how many ponies are standing in the world". A shopkeeper who was a Pony would be in
## that count, would be something the magic beam could take out of her own shop, and would
## have a leash, a detection area and a state machine she has no use for. So she is built
## exactly the way game/world/race_runner.gd builds a lane: PonyVisuals.build() for the
## body, StockTint for the colours, the idle clip, and nothing else. MagicBeam._is_grabbable()
## tests `body is Pony`, so there is nothing here for the beam to take.
##
## SHE IS SOLID, THOUGH. A StaticBody3D on CollisionLayers.PROPS with no mask, like a lamp
## post or a building: the player bumps into her instead of walking through her, and she is
## looking for nothing.
##
## NO DIALOGUE. Phase 3 slice 4 brings the talk box and the town NPCs; until then she is a
## place that is staffed, which is the whole of what this task is for.
##
## SHE IS COUNTED SEPARATELY. ranch.gd stands her under an `Attendants` node that is neither
## `Props` nor `Buildings`, so neither of the two numbers the ranch gate prints moves, and
## the report prints its own `RANCH attendants=` line beside them.

const PonyVisualsScript := preload("res://actors/pony/pony_visuals.gd")
const StockTintScript := preload("res://systems/stock_tint.gd")
const StockPaletteScript := preload("res://systems/stock_palette.gd")
const LayersScript := preload("res://world/collision_layers.gd")

## Her collider: roughly a pony, standing. Not measured off the model, deliberately, because
## a shopkeeper who is exactly her own silhouette is a shopkeeper the player gets wedged
## against; a simple capsule around her barrel is what a prop wants.
const BODY_RADIUS := 0.55
const BODY_HEIGHT := 1.60

var _model: Node3D = null
var _facing := Vector3.FORWARD


func _ready() -> void:
	collision_layer = LayersScript.PROPS
	collision_mask = 0
	_ensure_collider()


## Stand her up: `data` is the hidden record she is built from, `look` her palette indices
## and her base model (StockPalette.MANE_STYLES), and `facing` the direction she looks in.
## Returns whether a body was actually built; false on a checkout with no converted assets,
## which is a reported state and not an error (docs/ci.md section 4).
##
## Safe to call again: the previous body is replaced. Freed outright rather than
## queue_free()'d, for race_runner.gd's reason: a queued node is still among get_children()
## until the end of the frame, and "she has one body" would be false for that frame.
func dress(data: PonyData, look: Dictionary, facing: Vector3) -> bool:
	if _model != null and is_instance_valid(_model):
		remove_child(_model)
		_model.free()
		_model = null
	if data == null:
		return false
	var built: Node3D = PonyVisualsScript.build(data,
		StockPaletteScript.mane_style_path(int(look.get("mane_style", 0))))
	if built == null:
		return false
	_model = built
	add_child(_model)
	# INDEX 0, ALWAYS -- matching game/actors/player/player.gd's own convention. _ready()
	# already gave her the "Body" CollisionShape3D before dress() is ever called, so a plain
	# add_child() would leave the model at index 1; every reader of "her body" (this file's
	# own tests included) reads it as get_child(0).
	move_child(_model, 0)
	StockTintScript.apply(_model, StockPaletteScript.load_stock(), look)
	if facing.length_squared() > 0.0:
		_facing = facing.normalized()
		# The asset's forward is minus Z (baked in by tools/export_blend.py), the same
		# convention game/actors/pony/pony.gd and race_runner.gd turn by.
		rotation.y = atan2(-_facing.x, -_facing.z)
	var anim := _model.get_node_or_null(PonyVisualsScript.ANIMATION_PLAYER_PATH) \
		as AnimationPlayer
	if anim != null and anim.has_animation(&"idle"):
		anim.play(&"idle")
	return true


func has_model() -> bool:
	return _model != null and is_instance_valid(_model)


func facing() -> Vector3:
	return _facing


func _ensure_collider() -> void:
	if get_node_or_null(^"Body") != null:
		return
	var capsule := CapsuleShape3D.new()
	capsule.radius = BODY_RADIUS
	capsule.height = BODY_HEIGHT
	var shape := CollisionShape3D.new()
	shape.name = "Body"
	shape.shape = capsule
	shape.position = Vector3(0.0, BODY_HEIGHT * 0.5, 0.0)
	add_child(shape)


# --- a routine, so she is not a statue (PS5, playtest 2026-11-05 item 44: "Casino patrons
# frozen in place" [38]) ------------------------------------------------------------------------

## The clips she runs through between idles, and how long she idles between them (seconds).
const ROUTINE_GAP := Vector2(3.0, 9.0)
## How fast she walks to another machine, metres a second (the walk clip's own pace).
const WALK_SPEED := 1.1

var _routine: Array[StringName] = []
var _rng := RandomNumberGenerator.new()
var _until_next := 0.0
var _acting := 0.0
var _clips_started := 0
var _walk_to := Vector3.ZERO
var _walk_face := Vector3.ZERO
var _walking := false


## Give her a routine: `clips` she plays one at a time, every few seconds, starting at a time
## drawn from `seed_value` so the hall's patrons are never in step.
func start_routine(clips: Array[StringName], seed_value: int) -> void:
	_routine = []
	var anim := _anim()
	for c: StringName in clips:
		if anim == null or anim.has_animation(c):
			_routine.append(c)
	_rng.seed = seed_value
	_until_next = _rng.randf_range(0.5, ROUTINE_GAP.y)


func clips_started() -> int:
	return _clips_started


func is_walking() -> bool:
	return _walking


## Walk to `to` (this node's parent's space), then turn to look at `face`.
func walk_to(to: Vector3, face: Vector3) -> void:
	_walk_to = to
	_walk_face = face
	_walking = true
	_acting = 0.0
	_play(&"walk")


## One step of her routine (driven by whoever stands her: the Palace hall's tick_patrons()): walking, acting out a clip, or idling until the next one.
func tick(delta: float) -> void:
	if _walking:
		var to := _walk_to - position
		to.y = 0.0
		var step := WALK_SPEED * delta
		if to.length() <= step:
			position = Vector3(_walk_to.x, position.y, _walk_to.z)
			_walking = false
			_turn_to(_walk_face - position)
			_play(&"idle")
			_until_next = _rng.randf_range(ROUTINE_GAP.x, ROUTINE_GAP.y)
		else:
			position += to.normalized() * step
			_turn_to(to)
		return
	if _routine.is_empty():
		return
	if _acting > 0.0:
		_acting -= delta
		if _acting <= 0.0:
			_play(&"idle")
			_until_next = _rng.randf_range(ROUTINE_GAP.x, ROUTINE_GAP.y)
		return
	_until_next -= delta
	if _until_next > 0.0:
		return
	var clip: StringName = _routine[_rng.randi_range(0, _routine.size() - 1)]
	_play(clip)
	_clips_started += 1
	var anim := _anim()
	_acting = anim.get_animation(clip).length if anim != null and anim.has_animation(clip) else 2.0
	_acting = clampf(_acting, 1.0, 4.0)


func _turn_to(dir: Vector3) -> void:
	dir.y = 0.0
	if dir.length_squared() < 1e-6:
		return
	_facing = dir.normalized()
	rotation.y = atan2(-_facing.x, -_facing.z)


func _anim() -> AnimationPlayer:
	if _model == null or not is_instance_valid(_model):
		return null
	return _model.get_node_or_null(PonyVisualsScript.ANIMATION_PLAYER_PATH) as AnimationPlayer


func _play(clip: StringName) -> void:
	var anim := _anim()
	if anim != null and anim.has_animation(clip):
		anim.play(clip, 0.25)
