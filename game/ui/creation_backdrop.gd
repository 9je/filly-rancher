class_name CreationBackdrop
extends Control
## THE SKY BEHIND THE PONY, AND IT IS OPAQUE ON PURPOSE. The owner's first full playtest saw
## the ranch through the creation screen: a frame of raw map, the farmhouse clipping, a camera
## somewhere it should not have been. The screen is a stage now, and this is its backcloth.
##
## DRAWN RATHER THAN SOURCED. The MLP cloud sprites in assets-inbox are Source engine .vtf
## files and are not in game/assets/converted/; converting a sprite pack is R2's business, not
## R1's, and a full screen wash of sky with soft puffs on it is four draw calls. If R2 lands
## the cloud sprites, this Control is where they replace the puffs, and nothing above it moves.
##
## THE PUFFS ARE A CONSTANT TABLE, NOT A ROLL. No random number generator may live under
## game/ui/ (game/test/test_menu_sound.gd sweeps for one), and a backdrop that looked
## different every boot would be a backdrop nobody could screenshot twice.

const SKY_TOP := Color(0.38, 0.68, 0.95, 1.0)
const SKY_BOTTOM := Color(0.82, 0.92, 0.99, 1.0)
const GROUND := Color(0.52, 0.78, 0.44, 1.0)
const CLOUD := Color(1.0, 1.0, 1.0, 0.92)
const CLOUD_SHADE := Color(0.86, 0.91, 0.97, 0.92)

## Where the horizon sits, as a fraction of the height.
const HORIZON := 0.78

## One puff each: x fraction, y fraction, radius as a fraction of the WIDTH. Hand placed so
## the clusters read as three clouds rather than as nine circles.
const CLOUDS: Array[Vector3] = [
	Vector3(0.13, 0.18, 0.055), Vector3(0.18, 0.16, 0.070), Vector3(0.24, 0.19, 0.048),
	Vector3(0.62, 0.11, 0.046), Vector3(0.67, 0.09, 0.062), Vector3(0.72, 0.12, 0.040),
	Vector3(0.86, 0.31, 0.038), Vector3(0.90, 0.29, 0.052), Vector3(0.95, 0.32, 0.034),
]


func _ready() -> void:
	# OPAQUE AND FULL SCREEN. Nothing behind this may reach the player's eye.
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _draw() -> void:
	var box := Rect2(Vector2.ZERO, size)
	var horizon: float = box.size.y * HORIZON
	# THE SKY, AS A VERTICAL GRADIENT, drawn as one polygon with per vertex colours rather
	# than as a stack of rectangles: one call, no banding.
	draw_polygon(
		PackedVector2Array([Vector2(0.0, 0.0), Vector2(box.size.x, 0.0),
			Vector2(box.size.x, horizon), Vector2(0.0, horizon)]),
		PackedColorArray([SKY_TOP, SKY_TOP, SKY_BOTTOM, SKY_BOTTOM]))
	draw_rect(Rect2(0.0, horizon, box.size.x, box.size.y - horizon), GROUND)
	for puff: Vector3 in CLOUDS:
		var centre := Vector2(puff.x * box.size.x, puff.y * box.size.y)
		var radius: float = puff.z * box.size.x
		draw_circle(centre + Vector2(0.0, radius * 0.18), radius, CLOUD_SHADE)
		draw_circle(centre, radius, CLOUD)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
