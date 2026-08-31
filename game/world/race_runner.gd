class_name RaceRunner
extends Node3D
## ONE OF THE SIX THINGS RUNNING DOWN THE TRACK, and it is deliberately not a pony.
##
## WHY THIS EXISTS AT ALL. The project rule is that only Pony._state_leaving may free a pony,
## and the spec's rule for this slice is that racing never frees, harms or removes one. A
## race that instanced six Pony nodes and freed them at the wire would break both, and a race
## that took the player's pony out of her pen to run in would break the second. So the track
## runs stand ins: a RaceRunner builds the SAME model PonyVisuals.build() builds for every
## pony on the map, tints it the way StockTint tints a stock pony, and plays the same gallop
## clip at the same Gait playback scale. It has no state machine, no leash, no detection
## area and no capture path, so there is nothing here for the beam to grab and nothing here
## that was ever a resident of anything.
##
## THE PONY YOU ENTERED NEVER LEAVES HER PEN. ranch.gd hides her pen body for the length of
## the race so the world does not show her in two places, and shows it again when the race
## settles. Everything that actually happens to her is RaceCard.apply_race_effects(): two
## clamped numbers on her own record.
##
## dress() FREES A MODEL, NOT A PONY. Re dressing a lane replaces the visual it was carrying.
## That node is a glTF instance, never a Pony and never adopted by one, which is the whole
## reason this class is separate from game/actors/pony/pony.gd rather than a mode of it.

const PonyVisualsScript := preload("res://actors/pony/pony_visuals.gd")
const StockTintScript := preload("res://systems/stock_tint.gd")
const StockPaletteScript := preload("res://systems/stock_palette.gd")
const GaitScript := preload("res://systems/gait.gd")

const NAMEPLATE_HEIGHT := 2.5
const NAMEPLATE_SIZE := 0.28

var _model: Node3D = null
var _anim: AnimationPlayer = null
var _plate: Label3D = null
var _runner_name := ""


## Give this lane a body and a name. Returns whether a model was actually built; false on a
## checkout with no converted assets, which is a reported state and not an error (see
## docs/ci.md section 4). Safe to call again: the previous model is replaced.
func dress(data: PonyData, triple: Dictionary, display: String) -> bool:
	_runner_name = display
	_ensure_plate()
	_plate.text = display
	if _model != null:
		# Removed from the tree immediately, not just marked: dress() can be called twice in
		# the same frame (a re-entered race), and a model only queue_free()'d would still be
		# among get_children() until the next idle frame, making "one model at a time" a lie
		# for exactly one frame.
		remove_child(_model)
		_model.queue_free()
		_model = null
		_anim = null
	if data == null:
		return false
	var built: Node3D = PonyVisualsScript.build(data)
	if built == null:
		return false
	_model = built
	add_child(_model)
	if not triple.is_empty():
		StockTintScript.apply(_model, StockPaletteScript.load_stock(), triple)
	_anim = _model.get_node_or_null(PonyVisualsScript.ANIMATION_PLAYER_PATH) as AnimationPlayer
	rest()
	return true


func runner_name() -> String:
	return _runner_name


func has_model() -> bool:
	return _model != null and is_instance_valid(_model)


## Stand her at `at`, facing `heading`, with the hooves matching `speed`. Called once per
## frame per lane while a race is running.
func set_pose(at: Vector3, heading: Vector3, speed: float) -> void:
	global_position = at
	if heading.length_squared() > 0.0:
		# The asset's forward is minus Z (baked in by tools/export_blend.py), the same
		# convention game/actors/pony/pony.gd's _update_facing() turns by.
		rotation.y = atan2(-heading.x, -heading.z)
	if _anim == null:
		return
	var clip: StringName = GaitScript.clip_for_speed(speed)
	if _anim.has_animation(clip) and _anim.current_animation != clip:
		_anim.play(clip)
	_anim.speed_scale = GaitScript.playback_scale_for_clip(clip, speed)


## Between races: standing about, breathing.
func rest() -> void:
	if _anim == null:
		return
	if _anim.has_animation(&"idle") and _anim.current_animation != &"idle":
		_anim.play(&"idle")
	_anim.speed_scale = 1.0


## The name above her, so the player can tell six recoloured ponies apart from the rail.
func _ensure_plate() -> void:
	if _plate != null and is_instance_valid(_plate):
		return
	_plate = Label3D.new()
	_plate.name = "Nameplate"
	_plate.font_size = 48
	_plate.pixel_size = NAMEPLATE_SIZE / 48.0
	_plate.position = Vector3(0.0, NAMEPLATE_HEIGHT, 0.0)
	_plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_plate.shaded = false
	_plate.outline_size = 8
	add_child(_plate)
