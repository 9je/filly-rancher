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
const PaintScript := preload("res://ui/casino_paint.gd")
const RaceCardScript := preload("res://systems/race_card.gd")

## THE SIX NAMES ARE GONE AND THEIR INFORMATION IS IN GEOMETRY. They existed for a real
## reason, stated here before: "so the player can tell six recoloured ponies apart from the
## rail". Six billboarded names bobbing over six galloping ponies is also the most Roblox
## looking thing in a 3D scene, and the two questions they answered ("which one is which" and
## "which one is mine") are both better answered by colour.
##
## ONE RAINBOW, THREE PLACES. CasinoPaint.BAND_COLORS is the wheel's six bands, the six race
## lanes and the slot machine's RAINBOW symbol. The preload is CONSTANT ONLY and one
## directional: game/world/ reads the palette, and nothing under game/ui/ has ever read
## anything under game/world/.
const SADDLECLOTH_SIZE := Vector3(0.62, 0.02, 0.52)
const SADDLECLOTH_HEIGHT := 1.02

## A gold chevron over the pony the player has money on, and over nobody else. Geometry, not
## text, bobbing on a sine so it reads at a distance without turning to face the camera.
const CHEVRON_HEIGHT := 2.4
const CHEVRON_BOB := 0.12
const CHEVRON_PERIOD := 1.6
const CHEVRON_SIZE := 0.28

var _model: Node3D = null
var _anim: AnimationPlayer = null
var _runner_name := ""
var _lane := -1
var _chevron: MeshInstance3D = null


## Give this lane a body and a name. Returns whether a model was actually built; false on a
## checkout with no converted assets, which is a reported state and not an error (see
## docs/ci.md section 4). Safe to call again: the previous model is replaced.
##
## `lane` is the lane this runner is standing in, or -1 for a runner not on the card (a
## gallery, a unit test). A lane gives her a saddlecloth in that lane's colour; RaceCard's own
## PLAYER_LANE also gets the chevron, because that is the only lane a player's bet can be on.
func dress(data: PonyData, triple: Dictionary, display: String, lane := -1) -> bool:
	_runner_name = display
	_lane = lane
	if _model != null:
		# Removed from the tree AND freed immediately, not just marked: dress() can be
		# called twice in the same frame (a re-entered race), and a model only
		# queue_free()'d would still be among get_children(), and still alive as an
		# orphan, until the next idle frame processed the deferred call. Once
		# remove_child() has detached it, it is no longer in the tree and not mid signal,
		# so free() outright is safe and leaves nothing for GUT's orphan check to catch.
		remove_child(_model)
		_model.free()
		_model = null
		_anim = null
	if data == null:
		return false
	var built: Node3D = PonyVisualsScript.build(data,
		StockPaletteScript.mane_style_path(int(triple.get("mane_style", 0))) \
			if not triple.is_empty() else "")
	if built == null:
		return false
	_model = built
	add_child(_model)
	if not triple.is_empty():
		StockTintScript.apply(_model, StockPaletteScript.load_stock(), triple)
	_anim = _model.get_node_or_null(PonyVisualsScript.ANIMATION_PLAYER_PATH) as AnimationPlayer
	rest()
	_dress_lane()
	return true


func lane() -> int:
	return _lane


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


## The colour instead of the name. `dress()` can be called again on a re-entered race, so any
## saddlecloth or chevron from a previous dressing is cleared before this one is built, the
## same way a previous _model is freed rather than stacked.
func _dress_lane() -> void:
	var old_cloth := get_node_or_null(^"Saddlecloth")
	if old_cloth != null:
		remove_child(old_cloth)
		old_cloth.free()
	if _chevron != null and is_instance_valid(_chevron):
		remove_child(_chevron)
		_chevron.free()
	_chevron = null
	if _lane < 0 or _lane >= PaintScript.BAND_COLORS.size():
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = PaintScript.BAND_COLORS[_lane]
	mat.roughness = 0.8
	var box := BoxMesh.new()
	box.size = SADDLECLOTH_SIZE
	box.material = mat
	var cloth := MeshInstance3D.new()
	cloth.name = "Saddlecloth"
	cloth.mesh = box
	cloth.position = Vector3(0.0, SADDLECLOTH_HEIGHT, 0.0)
	add_child(cloth)
	if _lane != RaceCardScript.PLAYER_LANE:
		return
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = CHEVRON_SIZE
	cone.height = CHEVRON_SIZE * 1.4
	var gold := StandardMaterial3D.new()
	gold.albedo_color = PaintScript.GOLD
	gold.emission_enabled = true
	gold.emission = PaintScript.GOLD
	gold.emission_energy_multiplier = 1.4
	cone.material = gold
	_chevron = MeshInstance3D.new()
	_chevron.name = "Chevron"
	_chevron.mesh = cone
	# Point down at her, which is the whole message: this one is yours.
	_chevron.rotation.z = PI
	_chevron.position = Vector3(0.0, CHEVRON_HEIGHT, 0.0)
	add_child(_chevron)


func _process(_delta: float) -> void:
	if _chevron == null or not is_instance_valid(_chevron):
		return
	_chevron.position.y = CHEVRON_HEIGHT \
		+ sin(Time.get_ticks_msec() / 1000.0 * TAU / CHEVRON_PERIOD) * CHEVRON_BOB
