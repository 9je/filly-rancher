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


## THE BOUTIQUE'S WALL, NOT A SKY (Fable AAA round 4: the creator is the Carousel Boutique
## now, ui/boutique_stage.gd): what shows round the two panels is the same striped lavender
## wallpaper with its gold diamonds, over a cream wainscot with a gold rail, so the screen is
## one room. The sky constants above stay for anything that still asks for them.
const PAPER := Color(0.80, 0.70, 0.92)
const PAPER_STRIPE := Color(0.88, 0.80, 0.97)
const DIAMOND := Color(0.96, 0.78, 0.36)
const WAINSCOT := Color(0.99, 0.95, 0.90)
const STRIPE_PX := 56.0
const WAINSCOT_AT := 0.8


func _draw() -> void:
	var box := Rect2(Vector2.ZERO, size)
	draw_rect(box, PAPER)
	var foot: float = box.size.y * WAINSCOT_AT
	var x := 0.0
	var k := 0
	while x < box.size.x:
		if k % 2 == 1:
			draw_rect(Rect2(x, 0.0, STRIPE_PX, foot), PAPER_STRIPE)
		else:
			# A gold diamond down the middle of every darker stripe.
			var y := STRIPE_PX * 0.9
			while y < foot - STRIPE_PX * 0.4:
				var c := Vector2(x + STRIPE_PX * 0.5, y)
				draw_colored_polygon(PackedVector2Array([c + Vector2(0.0, -9.0),
					c + Vector2(5.5, 0.0), c + Vector2(0.0, 9.0), c + Vector2(-5.5, 0.0)]),
					DIAMOND)
				y += STRIPE_PX * 1.8
		x += STRIPE_PX
		k += 1
	draw_rect(Rect2(0.0, foot, box.size.x, box.size.y - foot), WAINSCOT)
	draw_rect(Rect2(0.0, foot - 6.0, box.size.x, 12.0), DIAMOND)
	draw_rect(Rect2(0.0, foot + 6.0, box.size.x, 4.0), Color(0.0, 0.0, 0.0, 0.08))


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
