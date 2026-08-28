class_name HUD
extends CanvasLayer
## The player-facing overlay for the ranch: a crosshair, the saddlebag, a toast when
## something happens, and a control-hints card. Mounted in game/world/ranch.tscn.
##
## WHY EACH PIECE IS HERE. None of these is decoration -- each one answers a question a
## player could not otherwise answer, and three of the four came directly out of playing
## the build offscreen and noticing the answer was missing.
##
##   CROSSHAIR. The magic beam aims along a ray from the camera through the SCREEN
##     CENTRE (game/actors/player/magic_beam.gd, camera_rig.gd's get_aim_ray()), and
##     nothing on screen said where that was. In a third-person rig the player's own
##     body sits near the centre, so "aim at the middle of the pony" is not even a good
##     guess -- the centre of the SCREEN is several degrees off the centre of the
##     character. A reticle is the whole of the fix.
##
##   THE STRUGGLE RING, AND THE SECURE ARC INSIDE IT. A capture is a contest between two
##     clocks (magic_beam.gd's SECURE_SECONDS and STRUGGLE_*): the beam needs 1.15 s to
##     subdue her, and she has 2.3 s (BOLD) / 3.0 s (CURIOUS) / 4.6 s (SHY) of fight in
##     her. Let go inside the first and she slips out; hold past the second and she wins.
##     BOTH of those have to be on screen or the mechanic is a coin toss:
##       - the OUTER ring drains clockwise from full over her struggle time, green to red,
##         so "she is about to win" is a shape rather than a number;
##       - the INNER arc FILLS over the secure time, and the whole reticle snaps to a
##         distinct colour and grows the instant it completes. That snap is the "let go
##         NOW" cue, and it is deliberately a discontinuous change rather than a gradual
##         one -- a player watching it in peripheral vision while a pony thrashes about in
##         front of them needs an event, not a gradient.
##     Before the ring was made to mean this, the outer countdown was drawn over a
##     decision that had already been made: releasing at any moment stored her, so the
##     timer was information about nothing.
##
##   THE IN-RANGE RETICLE. "Hard to gauge distance of beam" was the owner's report, and
##     half the answer is in the world (magic_beam.gd's landing ring) and half is here:
##     when the crosshair has something grabbable within MagicBeam.REACH, the reticle
##     says so before you press anything. Without it, "am I close enough?" is a question
##     you can only answer by trying and failing.
##
##   THE SADDLEBAG. Capacity is finite (magic_beam.gd's storage_capacity) and a full bag
##     REFUSES a capture and sets the pony back down. Without a visible count the first
##     time a player learns the bag is full is when a catch mysteriously fails.
##
##   THE TOAST. A capture frees the pony's node instantly. Without a line of text naming
##     who just went in, a successful capture and a pony wandering out of frame look
##     identical.
##
## BOUND TO `Storage.changed`, NOT POLLED, per the task brief -- and the binding is
## deferred rather than done in _ready(). Godot readies children depth-first, so whether
## the Player's MagicBeam (which CONSTRUCTS the Storage in its own _ready) exists yet
## when this node readies depends on sibling order in ranch.tscn. Depending on that
## order is exactly the kind of thing that works until someone drags a node in the
## editor, so _bind() is retried from _process() until it takes.
##
## LAYOUT IS AUTHORED AT 1920x1080 and scales with the window: game/project.godot sets
## `window/stretch/mode="canvas_items"` against a 1920x1080 base viewport, so every size
## below is in those units on every screen.

const PonyDataScript := preload("res://systems/pony_data.gd")
const PonyInstanceScript := preload("res://systems/pony_instance.gd")
const MagicBeamScript := preload("res://actors/player/magic_beam.gd")

## Radius of the reticle ring, in (1920x1080-base) pixels. Small: it has to mark a point
## precisely, and a big one would obscure the pony it is resting on.
const CROSSHAIR_RADIUS := 13.0
## Gap between the ring and the four ticks, and how long the ticks are.
const TICK_GAP := 5.0
const TICK_LENGTH := 7.0
## Radius of the struggle ring, outside the reticle so the two never overlap. Sized up
## from a first pass at 21 x 4: rendered at 1600x900 that was a barely-legible sliver
## next to a held pony's own aura, and this ring is the only thing on screen telling the
## player how long she has left before the catch fails.
const STRUGGLE_RADIUS := 32.0
const STRUGGLE_WIDTH := 6.0

## The secure arc sits INSIDE the struggle ring, in the gap between it and the reticle,
## and is thinner: the two are different claims (how far the beam has got, versus how
## long she will last) and drawing them at the same weight makes one ring with two
## colours instead of two readings.
const SECURE_RADIUS := 24.0
const SECURE_WIDTH := 4.0

## The reticle's states. White at rest, so it reads against grass and sky alike;
## Twilight's own aura colour while the beam is on, so "the beam is live" is visible
## even when it is pointed at empty sky; a brighter lock colour when the crosshair has
## something grabbable within reach; amber while something is in the beam but not yet
## subdued; and green the moment letting go would actually keep her.
const COLOR_IDLE := Color(1.0, 1.0, 1.0, 0.82)
const COLOR_BEAMING := Color(0.98, 0.55, 0.95, 0.95)
const COLOR_IN_RANGE := Color(1.0, 0.86, 0.42, 1.0)
const COLOR_HOLDING := Color(1.0, 0.82, 0.35, 1.0)
const COLOR_SECURED := Color(0.42, 1.0, 0.52, 1.0)
## The secure arc while it is still filling. Cool, so it is clearly not the "go" colour.
const COLOR_SECURING := Color(0.55, 0.80, 1.0, 0.95)
## Every stroke is drawn twice, this colour first and one pixel wider. Without it the
## white reticle disappears against a bright sky and the pink one against the pink beam.
const COLOR_OUTLINE := Color(0.0, 0.0, 0.0, 0.55)

## Saddlebag pip geometry.
const PIP_SIZE := Vector2(26.0, 26.0)
const PIP_GAP := 8.0
const PIP_EMPTY := Color(1.0, 1.0, 1.0, 0.14)
const PIP_BORDER := Color(0.0, 0.0, 0.0, 0.5)

## Filled-pip colour by PonyData.Rarity. The bag is the only place the player ever sees
## what she has actually collected, so a caught pony's TIER being legible at a glance is
## most of what makes a row of pips worth drawing instead of a bare number.
##
## RARITY IS A PROPERTY OF THE CHARACTER, NOT OF THE INDIVIDUAL. Storage holds
## PonyInstances now (one per pony you own), and rarity lives on the shared PonyData behind
## her `data_id` -- so the pip colour comes from `instance.data().rarity`, resolved through
## PonyRegistry. An instance whose character this build does not carry resolves to null and
## draws as COMMON rather than crashing the overlay; see _on_storage_changed().
const RARITY_COLORS := {
	PonyDataScript.Rarity.COMMON: Color(0.72, 0.78, 0.72),
	PonyDataScript.Rarity.UNCOMMON: Color(0.47, 0.82, 0.45),
	PonyDataScript.Rarity.RARE: Color(0.40, 0.66, 0.98),
	PonyDataScript.Rarity.LEGENDARY: Color(1.00, 0.80, 0.25),
}

## Seconds a toast holds at full opacity, and seconds it then takes to fade out.
const TOAST_HOLD := 2.4
const TOAST_FADE := 0.7

## Input action that shows/hides the hints card. Bound in game/project.godot to H and to
## the gamepad Back button.
const HINTS_ACTION := &"toggle_hints"

@onready var _crosshair: Control = $Crosshair
@onready var _pips: Control = $Bag/Pips
@onready var _bag_count: Label = $Bag/Count
@onready var _bag_title: Label = $Bag/Title
@onready var _toast: Label = $Toast
@onready var _hints: PanelContainer = $Hints
@onready var _hints_grid: GridContainer = $Hints/Margin/Grid

## Resolved by _bind(); both may be null until it succeeds.
var _beam: Node3D
var _storage: Storage

var _toast_left := 0.0
var _rarities: Array[int] = []
var _capacity := 0
var _elapsed := 0.0
## Whether the beam was on last frame, so the reticle gets one final redraw when it
## switches off instead of being left frozen in its "beaming" colour.
var _was_beaming := false
## ...and whether it had a target in range last frame, for the same reason: the in-range
## reticle has to repaint on the frame the crosshair leaves her, not on the next time
## something else happens to trigger a redraw.
var _was_in_range := false


func _ready() -> void:
	_crosshair.draw.connect(_draw_crosshair)
	_pips.draw.connect(_draw_pips)

	_style_label(_bag_title, 20, Color(1.0, 1.0, 1.0, 0.62))
	_style_label(_bag_count, 26, Color(1.0, 1.0, 1.0, 0.92))
	_style_label(_toast, 40, Color(1.0, 0.96, 0.86, 1.0))

	_bag_title.text = "SADDLEBAG"
	_build_hints()
	_toast.modulate.a = 0.0

	_bind()


func _process(delta: float) -> void:
	_elapsed += delta

	# See the class comment: sibling ready order is not something to depend on.
	if _storage == null:
		_bind()

	if _toast_left > 0.0:
		_toast_left -= delta
		_toast.modulate.a = clampf(_toast_left / TOAST_FADE, 0.0, 1.0)

	# The reticle animates (the beam pulse, the struggle ring draining, the secure arc
	# filling) so it is redrawn every frame the beam is on. It ALSO has to redraw when the
	# in-range state flips with the beam off, which is a thing the player causes by turning
	# on the spot -- so that transition is tracked rather than polled into a repaint every
	# frame for the whole session.
	var beaming: bool = _beam != null and _beam.is_active()
	var in_range: bool = _beam != null and _beam.has_target()
	if beaming or _was_beaming or in_range != _was_in_range:
		_crosshair.queue_redraw()
	_was_beaming = beaming
	_was_in_range = in_range


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(HINTS_ACTION):
		_hints.visible = not _hints.visible
		get_viewport().set_input_as_handled()


## Show `text` as a toast for TOAST_HOLD + TOAST_FADE seconds. Public so anything else
## that wants to say something to the player (a later quest, a tutorial prompt) has one
## place to say it through.
func toast(text: String) -> void:
	_toast.text = text
	_toast_left = TOAST_HOLD + TOAST_FADE
	_toast.modulate.a = 1.0


## The magic beam this HUD is reading, or null if it has not been found yet. Exposed for
## gates and tests, which otherwise have no way to tell "bound and idle" apart from
## "never bound at all" -- the two look identical on screen.
func get_beam() -> Node3D:
	return _beam


## Contents of the bag as rarity tiers, oldest first -- what the pips are drawn from.
## Exposed so a gate can assert the HUD is showing what Storage actually holds rather
## than only that it drew something.
func get_shown_rarities() -> Array[int]:
	return _rarities.duplicate()


func get_capacity() -> int:
	return _capacity


# --- binding ---------------------------------------------------------------------

## Find the Player's magic beam and its Storage, and connect to everything that changes
## what this HUD shows. Idempotent and safe to call every frame until it succeeds.
func _bind() -> void:
	var player := get_parent().get_node_or_null("Player") if get_parent() != null else null
	if player == null or not player.has_method("get_magic_beam"):
		return
	var beam: Node3D = player.get_magic_beam()
	if beam == null or not beam.has_method("get_storage"):
		return
	var storage: Storage = beam.get_storage()
	if storage == null:
		return

	_beam = beam
	_storage = storage
	_capacity = storage.capacity

	# THE BINDING THE BRIEF ASKS FOR: the bag redraws when the bag changes, not once per
	# frame forever. Storage.changed fires exactly on a real store or a real release
	# (storage.gd is explicit that a refused store does NOT fire it), so this cannot
	# repaint on a non-event either.
	storage.changed.connect(_on_storage_changed)
	beam.captured.connect(_on_captured)
	beam.capture_refused.connect(_on_capture_refused)
	beam.escaped.connect(_on_escaped)

	_on_storage_changed()


func _on_storage_changed() -> void:
	_rarities.clear()
	for instance: PonyInstance in _storage.contents():
		# Two separate nulls to survive, both reachable: a hole in the bag (which
		# Storage.store() refuses, so this is belt and braces), and an instance whose
		# character is not on this build's roster -- a save from a build with a pony this
		# one lacks, or a traded pony. Neither may take the whole overlay down; both draw
		# as the most conservative tier instead.
		var data: PonyData = instance.data() if instance != null else null
		_rarities.append(data.rarity if data != null else PonyDataScript.Rarity.COMMON)
	_bag_count.text = "%d / %d" % [_storage.count(), _capacity]
	_pips.queue_redraw()


func _on_captured(instance: PonyInstance) -> void:
	# display_name() falls back nickname -> character's name -> raw data_id, so this line
	# always names somebody even for a pony whose record is missing on this machine.
	var who := instance.display_name() if instance != null else "a pony"
	toast("Caught %s!" % (who if not who.is_empty() else "a pony"))


## The bag was full, so she was set down instead of stored -- the one capture outcome
## with nothing at all to show for it on screen otherwise.
func _on_capture_refused(_body: Node3D) -> void:
	toast("Saddlebag full!")


## Two very different mistakes reach this signal (MagicBeam.Loss), and saying which one
## just happened is the only teaching the capture window ever gets. "She wriggled free"
## on a hold the player abandoned after half a second would be a straight lie, and would
## teach exactly the wrong lesson -- let go SOONER next time.
func _on_escaped(_body: Node3D) -> void:
	if _beam != null and _beam.get_last_loss() == MagicBeamScript.Loss.SLIPPED:
		toast("She slipped out -- hold her longer!")
		return
	toast("She wriggled free!")


# --- drawing ---------------------------------------------------------------------

func _draw_crosshair() -> void:
	var centre: Vector2 = _crosshair.size * 0.5
	var holding: bool = _beam != null and _beam.is_holding()
	var beaming: bool = _beam != null and _beam.is_active()
	var secured: bool = holding and _beam.is_secured()
	# Deliberately NOT conditioned on the beam being on: the whole value of this state is
	# that it answers "can I take her from here?" before the button is pressed.
	var in_range: bool = not holding and _beam != null and _beam.has_target()

	var color := COLOR_IDLE
	if secured:
		color = COLOR_SECURED
	elif holding:
		color = COLOR_HOLDING
	elif in_range:
		# Steady, not pulsing: "she is in range" is a fact, and a fact that blinks reads
		# as a warning.
		color = COLOR_IN_RANGE
	elif beaming:
		# A slow pulse, so a beam that is on but has caught nothing still reads as live.
		color = COLOR_BEAMING
		color.a *= 0.72 + 0.28 * sin(_elapsed * 7.0)

	# The reticle GROWS at both of the moments that matter -- something is in range, and
	# she is secured -- so the state change is legible without reading a colour.
	var scale := 1.0
	if secured:
		scale = 1.45
	elif holding:
		scale = 1.25
	elif in_range:
		scale = 1.18
	var radius := CROSSHAIR_RADIUS * scale

	_ring(centre, radius, color, 2.0)
	for direction: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		var a: Vector2 = centre + direction * (radius + TICK_GAP)
		var b: Vector2 = a + direction * TICK_LENGTH
		_crosshair.draw_line(a, b, COLOR_OUTLINE, 4.0, true)
		_crosshair.draw_line(a, b, color, 2.0, true)
	_crosshair.draw_circle(centre, 2.0, color)

	if holding:
		_draw_struggle_ring(centre)
		_draw_secure_arc(centre)


## The countdown on the current hold, drawn as a ring that drains clockwise from the
## top. Time REMAINING rather than elapsed, so "the ring is nearly gone" means "let go".
## A body with no struggle time at all (a loose prop -- magic_beam.gd's STRUGGLE_NEVER
## is INF) gets a complete, static ring: it is never going anywhere.
func _draw_struggle_ring(centre: Vector2) -> void:
	var total: float = _beam.get_struggle_seconds()
	var remaining := 1.0
	if is_finite(total) and total > 0.0:
		remaining = clampf(1.0 - _beam.get_hold_seconds() / total, 0.0, 1.0)

	# Green with time in hand, red when it is nearly out -- the same reading as the
	# ring's length, in a channel that survives peripheral vision.
	var color := Color(0.45, 0.90, 0.45).lerp(Color(1.0, 0.35, 0.30), 1.0 - remaining)
	var start := -PI * 0.5
	_crosshair.draw_arc(centre, STRUGGLE_RADIUS, 0.0, TAU, 64,
		COLOR_OUTLINE, STRUGGLE_WIDTH + 2.0, true)
	if remaining > 0.0:
		_crosshair.draw_arc(centre, STRUGGLE_RADIUS, start, start + TAU * remaining, 64,
			color, STRUGGLE_WIDTH, true)


## How far the beam has got toward subduing her, drawn as an arc FILLING clockwise from
## the top inside the struggle ring. Filling rather than draining, and in the opposite
## sense to the ring outside it, precisely so the two cannot be mistaken for each other:
## one is growing toward the moment you may let go, the other is shrinking toward the
## moment she leaves.
##
## Once it completes it is drawn as a full ring in the "she is yours" colour rather than
## being hidden -- a control that disappears at the moment of truth teaches the player
## nothing about why.
func _draw_secure_arc(centre: Vector2) -> void:
	var progress: float = _beam.get_secure_progress()
	_crosshair.draw_arc(centre, SECURE_RADIUS, 0.0, TAU, 48,
		COLOR_OUTLINE, SECURE_WIDTH + 2.0, true)
	if progress <= 0.0:
		return
	var color := COLOR_SECURED if progress >= 1.0 else COLOR_SECURING
	var start := -PI * 0.5
	_crosshair.draw_arc(centre, SECURE_RADIUS, start, start + TAU * progress, 48,
		color, SECURE_WIDTH, true)


func _draw_pips() -> void:
	for i in range(_capacity):
		var at := Vector2(float(i) * (PIP_SIZE.x + PIP_GAP), 0.0)
		var rect := Rect2(at, PIP_SIZE)
		var fill := PIP_EMPTY
		if i < _rarities.size():
			fill = RARITY_COLORS.get(_rarities[i], RARITY_COLORS[PonyDataScript.Rarity.COMMON])
		_pips.draw_rect(rect, fill, true)
		_pips.draw_rect(rect, PIP_BORDER, false, 2.0)


## One ring, drawn twice: an outline pass and then the colour, so the reticle stays
## visible over a bright sky as well as over grass.
func _ring(centre: Vector2, radius: float, color: Color, width: float) -> void:
	_crosshair.draw_arc(centre, radius, 0.0, TAU, 48, COLOR_OUTLINE, width + 2.0, true)
	_crosshair.draw_arc(centre, radius, 0.0, TAU, 48, color, width, true)


# --- text ------------------------------------------------------------------------

## Every label gets the same treatment: a size, a colour, and a black outline. The
## outline is not styling -- this HUD is drawn over a bright green field under a bright
## sky, and unoutlined white text on the sky is genuinely unreadable.
func _style_label(label: Label, size: int, color: Color) -> void:
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 0.75))
	label.add_theme_constant_override(&"outline_size", 6)


## Both control schemes, side by side, because the build is handed to two people and
## only one of them is going to be at the keyboard. Every row here mirrors an action in
## game/project.godot's `[input]` block -- a binding that changes there and not here is
## a hint card that lies.
##
## A GridContainer of Labels rather than one pre-aligned block of text: Godot's default
## UI font is proportional, so space-padded columns line up in the source file and
## nowhere else.
## RUNNING IS THE DEFAULT AND SHIFT SLOWS YOU DOWN, which is the opposite of what every
## other game trains a player to expect -- so the card says what the slow gait BUYS on its
## own continuation line rather than leaving "why would I ever hold this?" as something
## the player has to work out from a speed change alone.
const HINTS := [
	["MOVE (run)", "W A S D", "Left stick"],
	["WALK / SNEAK", "Shift (hold)", "LB (hold)"],
	["", "creep quietly -- ponies notice you from half as far", ""],
	["JUMP", "Space", "A"],
	["INTERACT", "E", "X"],
	["", "build on an empty plot, move a pony in", ""],
	["LOOK", "Mouse", "Right stick"],
	["ZOOM", "Scroll / = -", "D-pad up/down"],
	["MAGIC BEAM", "Right mouse (hold)", "Right trigger (hold)"],
	["", "hold until the inner ring fills, then let go to stow her", ""],
	["", "let go too soon and she slips out; too late and she wriggles free", ""],
	["FREE CURSOR", "Esc", ""],
	["THIS CARD", "H", "Back"],
]


func _build_hints() -> void:
	for row: Array in HINTS:
		for column in range(3):
			var label := Label.new()
			label.text = String(row[column])
			var dim: float = 0.60 if column == 0 or String(row[0]) == "" else 0.92
			_style_label(label, 20, Color(1.0, 1.0, 1.0, dim))
			_hints_grid.add_child(label)
