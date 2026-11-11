class_name HUD
extends CanvasLayer
## The player-facing overlay for the ranch: a crosshair, the saddlebag, the wallet, the
## hour and the weather in words, a toast when something happens, and a control-hints
## card. Mounted in game/world/ranch.tscn.
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
##   THE CATCH RING, AND THE WRIGGLE RING INSIDE IT. A capture is a race between two
##     clocks (magic_beam.gd): the beam needs its subdue time to take her, and she has a
##     struggle time of fight in her. Let go before the first and she slips out; let the
##     second run out and she wins. BOTH have to be on screen or the mechanic is a coin
##     toss, and which is which was rebuilt at the owner's direction after the third
##     playtest -- "outer green circle should be your catch (release click when full) and
##     maybe have the inside circle be red and be the wiggle out circle". It had been the
##     other way round, with the countdown on the outside, and it read backwards: the ring
##     you are trying to COMPLETE is the one your eye goes to first, and the eye goes to
##     the big one.
##       - the OUTER ring is GREEN and FILLS clockwise over the subdue time. It is the one
##         you act on: let go when it closes. It is the thickest thing on the reticle.
##       - the INNER ring is RED and DRAINS anticlockwise over her struggle time. It is
##         the one you are racing. Thinner, and smaller, so it never competes with the
##         ring the player is actually timing.
##     The reticle also snaps to a distinct colour AND grows the instant the outer ring
##     closes. That snap is the "let go NOW" cue, and it is deliberately a discontinuous
##     change rather than a gradual one -- a player watching it in peripheral vision while
##     a pony thrashes in front of them needs an event, not a gradient.
##
##     NOTHING HERE LEANS ON HUE ALONE, which matters because green-versus-red is exactly
##     the pair a red-green colourblind player cannot separate. Three other channels carry
##     the same distinction independently: radius (outer versus inner), thickness (7 px
##     versus 4 px), and direction of travel (one grows clockwise, the other shrinks
##     anticlockwise). Any one of them is enough to tell the two rings apart.
##
##     IT ALSO MAKES THE WRENCH LEGIBLE FOR FREE. A HARD pony can tear out of the beam
##     before it secures her (magic_beam.gd's WRENCH_CHANCE_HARD), which is implemented as
##     a struggle time rolled shorter than that attempt's subdue time -- so on screen the
##     red ring visibly outruns the green one and empties first. The player sees the catch
##     being taken away rather than being told about it afterwards, which is the whole
##     difference between a mechanic and a bug.
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

const PonyTraitsScript := preload("res://systems/pony_traits.gd")
const PonyDataScript := preload("res://systems/pony_data.gd")
const PonyInstanceScript := preload("res://systems/pony_instance.gd")
const MagicBeamScript := preload("res://actors/player/magic_beam.gd")
const InputDeviceScript := preload("res://systems/input_device.gd")
const MenuStyleScript := preload("res://ui/menu_style.gd")
const CatchCardScript := preload("res://ui/catch_card.gd")
const PantryIconScript := preload("res://ui/pantry_icon.gd")
const ShopIconScript := preload("res://ui/shop_icon.gd")
const HouseStyleScript := preload("res://ui/house_style.gd")
const PaintScript := preload("res://ui/casino_paint.gd")

## Radius of the reticle ring, in (1920x1080-base) pixels. Small: it has to mark a point
## precisely, and a big one would obscure the pony it is resting on.
const CROSSHAIR_RADIUS := 13.0
## Gap between the ring and the four ticks, and how long the ticks are.
const TICK_GAP := 5.0
const TICK_LENGTH := 7.0
## The CATCH ring: the outermost thing on the reticle, and the thickest. It is the meter
## the player is filling and the one they release on, so it gets the outside -- the eye
## reaches the biggest ring first -- and the extra weight, so "which ring do I act on?"
## is answered by shape before it is answered by colour.
##
## 32 px was sized up from a first pass at 21: rendered at 1600x900 that was a
## barely-legible sliver next to a held pony's own magic aura. 7 px of stroke is a
## deliberate 3 px more than the ring inside it, which is a ratio that survives both
## peripheral vision and a monochrome screenshot.
const CATCH_RADIUS := 32.0
const CATCH_WIDTH := 7.0

## The WRIGGLE ring: her fight, draining. Sits INSIDE the catch ring, in the gap between
## it and the reticle, and is drawn thinner. The two are different claims -- what you are
## building versus what you are racing -- and drawing them at the same weight makes one
## ring with two colours instead of two readings.
const WRIGGLE_RADIUS := 22.0
const WRIGGLE_WIDTH := 4.0

## The reticle's states. White at rest, so it reads against grass and sky alike;
## Twilight's own aura colour while the beam is on, so "the beam is live" is visible
## even when it is pointed at empty sky; a brighter lock colour when the crosshair has
## something grabbable within reach; amber while something is in the beam but not yet
## subdued; and a bright bloom of the beam's own pink the moment letting go would
## actually keep her.
const COLOR_IDLE := Color(1.0, 1.0, 1.0, 0.82)
const COLOR_BEAMING := Color(0.98, 0.55, 0.95, 0.95)
const COLOR_IN_RANGE := Color(1.0, 0.86, 0.42, 1.0)
const COLOR_HOLDING := Color(1.0, 0.82, 0.35, 1.0)
const COLOR_SECURED := Color(1.0, 0.86, 0.99, 1.0)
## The catch ring. It carries the MAGIC BEAM'S OWN PINK, one hue the whole way round,
## at the owner's direction. It was green, and green sat badly on a green field: the
## meter competed with the grass behind it. The beam's pink says whose magic is
## filling the ring, and nothing else in the world is that colour.
##
## One hue throughout rather than shading as it fills: a ring that changes colour as it
## grows is telling you two things with one channel, and the thing it needs to say is
## simply "this is the one you complete". What changes at completion is BRIGHTNESS and
## the reticle snap, not hue, so the cue survives for a player who cannot separate the
## two rings by colour at all.
const COLOR_CATCH := Color(0.98, 0.55, 0.95, 0.90)
const COLOR_CATCH_FULL := COLOR_SECURED

## The wriggle ring: her fight draining away. It warms from amber to red as it empties,
## so "she is about to win" is a colour AND a length AND a brightness, never one alone.
## Amber against the catch ring's pink, because the pair it replaced (green against red)
## is both the worst pair for a colour-blind player and the one that fought the grass.
const COLOR_WRIGGLE := Color(1.0, 0.66, 0.20, 0.85)
const COLOR_WRIGGLE_LOW := Color(0.95, 0.28, 0.24, 1.0)
## Every stroke is drawn twice, this colour first and one pixel wider. Without it the
## white reticle disappears against a bright sky and the pink one against the pink beam.
const COLOR_OUTLINE := Color(0.0, 0.0, 0.0, 0.55)

## The world line under the wallet: the hour and the weather, in words. A cool off-white
## rather than the Bits line's gold, because it is a statement about the world rather than
## a number the player owns, and the two must not read as one two-line block.
const COLOR_WORLD_LINE := Color(0.82, 0.88, 1.0, 0.92)

## The interaction prompt, sitting just under the reticle. Gold, like every other
## "you may act on this" cue in the game (the menus' COLOR_VALUE is the same number), and
## deliberately NOT the toast's white: a toast is something that happened, a prompt is
## something you can do.
const COLOR_PROMPT := Color(1.00, 0.86, 0.42, 1.0)

## THE SADDLEBAG IS A SADDLEBAG (Fable AAA round 6: "a 375x95 opaque purple panel with twelve
## 16 px dots and '0 bits' -- unreadable as inventory, covers the player's hooves"). No panel:
## a leather bag drawn on the field, its flap buckled with the count, the slots stitched
## pockets on its face that fill with gems in her ponies' rarity colours; beside it the wallet
## as a stack of bits and the number. Smaller than the old card and see-through round its
## shapes, so the pony at the centre is never under it. All drawn on the one control.
const PIP_SIZE := Vector2(20.0, 20.0)
const PIP_GAP := 4.0
const PIPS_PER_ROW := 6
## The bag's leather round the pockets (sides, foot) and the flap over them.
const BAG_PAD := Vector2(12.0, 10.0)
const BAG_FLAP := 28.0
## Headroom over the flap for the bag's strap.
const BAG_STRAP := 10.0
const BUCKLE := Vector2(54.0, 24.0)
const STRIP_GAP := 14.0
## The coin stack's width and the wallet number's size.
const COIN_W := 40.0
const BITS_PX := 36
const LEATHER := Color(0.66, 0.41, 0.23)
const LEATHER_FLAP := Color(0.56, 0.33, 0.18)
const LEATHER_DARK := Color(0.27, 0.14, 0.09)
const STITCH := Color(1.0, 0.86, 0.6, 0.6)

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

## WHAT A TOAST GETS WHEN SOMEBODY IS WAITING BEHIND IT. The owner, on the first full
## playtest: "text on top lags behind". Three quick actions queued three full holds, so the
## line about the third one arrived nine seconds after the thing it described and read as a
## bug in the game rather than in the overlay. A queue with anything in it now runs the
## current line short instead, so the text keeps pace with the play.
const TOAST_HOLD_BUSY := 1.5

## And a ceiling on the backlog itself. Past this the OLDEST waiting line is dropped, not the
## newest: nine seconds of stale news is worse than a line nobody read.
const TOAST_QUEUE_MAX := 3

## Input action that shows/hides the hints card. Bound in game/project.godot to H and to
## the gamepad Back button.
const HINTS_ACTION := &"toggle_hints"

## THE THREE THINGS TO DO FIRST, pinned until they are claimed. The owner, 2026-08-31: the
## how do I earn money path is not legible in the first minutes. These three requests have
## existed since Phase 2 slice 5 and were reachable only through the pause menu's Requests
## page, which a new player has no reason to open.
##
## THEY GO AWAY ON THEIR OWN. Once all three are claimed, tutorial_rows() answers empty and
## this whole block, title and all, stops being drawn: a permanent checklist in the corner
## of an experienced player's screen is clutter, and the board is where requests live after
## the first ten minutes.
const TASK_TITLE := "Getting started"
const TASK_DONE := "Done! "
const TASK_OPEN := "• "
const COLOR_TASK_DONE := Color(0.62, 0.86, 0.60, 0.92)
const COLOR_TASK_OPEN := Color(1.0, 1.0, 1.0, 0.88)

@onready var _crosshair: Control = $Crosshair
@onready var _prompt: Label = $Prompt
@onready var _pips: Control = $Bag/Pips
@onready var _bag_count: Label = $Bag/Count
@onready var _bits: Label = $Bag/Bits
@onready var _balance: Label = $Bag/Balance
@onready var _world_line: Label = $Bag/World
@onready var _bag_title: Label = $Bag/Title
@onready var _toast: Label = $Toast
@onready var _hints: PanelContainer = $Hints
@onready var _hints_grid: GridContainer = $Hints/Margin/Grid
@onready var _tasks: VBoxContainer = $Tasks

## Resolved by _bind(); both may be null until it succeeds.
var _beam: Node3D
var _storage: Storage

var _toast_left := 0.0
## The card a catch slides in (game/ui/catch_card.gd). See _on_captured().
var _catch_card: Control = null
var _catch_layer: CanvasLayer = null
## Whether the HUD is hidden behind a catch moment (_veil_for_catch).
var _veiled := false
## Toasts raised while another one is on screen, oldest first. See toast().
var _toast_queue: Array[String] = []
## Whether a letter or a menu is on screen right now, and whether the player had asked for
## the control card before one appeared. See set_overlay_open().
var _overlay_open := false
var _hints_wanted := false
var _task_lines: Array[String] = []
var _rarities: Array[int] = []
var _capacity := 0
var _bits_total := 0
var _elapsed := 0.0
## Whether the beam was on last frame, so the reticle gets one final redraw when it
## switches off instead of being left frozen in its "beaming" colour.
var _was_beaming := false
## ...and whether it had a target in range last frame, for the same reason: the in-range
## reticle has to repaint on the frame the crosshair leaves her, not on the next time
## something else happens to trigger a redraw.
var _was_in_range := false

## Which device the card was last built for, so _process() can rebuild it when she puts one
## down and picks the other up. Cheap: fourteen Labels, and only on an actual change.
var _hints_device: int = -1


func _ready() -> void:
	# Toasts fired from the Market and pause menus must keep fading while the world
	# is paused; the crosshair redraw is harmless while paused, so run always.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_crosshair.draw.connect(_draw_crosshair)
	_pips.draw.connect(_draw_pips)

	MenuStyleScript.style_label(_bag_title, 20, Color(1.0, 1.0, 1.0, 0.62))
	MenuStyleScript.style_label(_bag_count, 26, Color(1.0, 1.0, 1.0, 0.92))
	MenuStyleScript.style_label(_bits, 22, Color(1.00, 0.80, 0.25, 1.0))
	_bits.text = "0 bits"
	MenuStyleScript.style_label(_balance, 16, COLOR_WORLD_LINE)
	MenuStyleScript.style_label(_world_line, 22, COLOR_WORLD_LINE)
	_world_line.text = ""
	# Owner, 2026-10-23, "the text is random": the HUD is pictures and counts, not readouts.
	# The sky already says the hour and the weather, and the Company balance belongs to the
	# Depot's own page, so neither line is drawn here any more.
	_world_line.visible = false
	_balance.visible = false
	MenuStyleScript.style_label(_prompt, 26, COLOR_PROMPT)
	_prompt.text = ""
	MenuStyleScript.style_label(_toast, 40, Color(1.0, 0.96, 0.86, 1.0))

	_bag_title.text = "SADDLEBAG"
	_build_pantry()
	_build_hints()
	# I7, final-review.md I5: THE CARD IS THE PRE-BRANCH DEFAULT -- visible on a fresh
	# interactive game until dismissed with H. `_hints_wanted` starting true is not enough
	# on its own: ranch.gd only ever calls set_overlay_open() from its own menu opened/
	# closed handlers, so a Continue boot that opens no menu at all would leave `_hints.
	# visible` stuck at whatever this line set it to, forever. set_overlay_open(false) is
	# the one function that already knows how to compute it (_hints_wanted and not
	# _overlay_open, and _overlay_open starts false, the state boot is actually in), so
	# this calls that rather than hard-coding a value a second place.
	# v1: CLOSED by default; the ControlsChip names the key instead (see _restyle()).
	_hints_wanted = false
	set_overlay_open(false)
	_toast.modulate.a = 0.0
	_restyle()
	# THE CATCH IS THE WHOLE SCREEN FOR ITS MOMENT (Fable AAA round 2, #10: "dim behind and hide
	# the rest of the HUD for the beat"): the card rides a layer of its own above the HUD, so
	# the HUD can step out (see _veil_for_catch) while the card stays.
	_catch_layer = CanvasLayer.new()
	_catch_layer.name = "CatchLayer"
	_catch_layer.layer = layer + 1
	add_child(_catch_layer)
	_catch_card = CatchCardScript.new()
	_catch_layer.add_child(_catch_card)

	_bind()


func _process(delta: float) -> void:
	if _hints_device != InputDeviceScript.last():
		_build_hints()
	_veil_for_catch()

	_elapsed += delta
	_fade_tip(delta)

	# See the class comment: sibling ready order is not something to depend on.
	if _storage == null:
		_bind()

	if _toast_left > 0.0:
		# A LINE WITH SOMEBODY BEHIND IT RUNS SHORT. Applied here rather than in toast(),
		# because the queue can grow after the current line has already started, and the
		# player who just did three things quickly is the player this is for.
		if not _toast_queue.is_empty():
			_toast_left = minf(_toast_left, TOAST_HOLD_BUSY + TOAST_FADE)
		# HELD WHILE THE WORLD IS PAUSED OR A MENU IS UP (PT5; playtest 2026-11-05: "some
		# dialogue ... dissapears when paused"): the line waits for her to come back to it.
		if not (get_tree().paused or _overlay_open):
			_toast_left -= delta
		_toast.modulate.a = clampf(_toast_left / TOAST_FADE, 0.0, 1.0)
		# The queue is drained here rather than on a timer, so a toast raised while the
		# world is paused still waits its turn rather than being written over.
		if _toast_left <= 0.0 and not _toast_queue.is_empty():
			_show_toast(_toast_queue.pop_front())

	# The reticle animates (the beam pulse, the catch ring filling, the wriggle ring
	# draining) so it is redrawn every frame the beam is on. It ALSO has to redraw when the
	# in-range state flips with the beam off, which is a thing the player causes by turning
	# on the spot -- so that transition is tracked rather than polled into a repaint every
	# frame for the whole session.
	var beaming: bool = _beam != null and _beam.is_active()
	var in_range: bool = _beam != null and _beam.has_target()
	if beaming or _was_beaming or in_range != _was_in_range:
		_crosshair.queue_redraw()
	_was_beaming = beaming
	_was_in_range = in_range
	# THE RETICLE COMES WHEN IT HAS SOMETHING TO SAY (Fable AAA round 5: "the centre
	# crosshair dot shows in every world frame"). It fades up while the beam is on, while a
	# pony or a townspony is under it, and while a tip is teaching (the tip that says "Hold
	# Right Mouse on a pony" points at it), and fades away over an empty view.
	var want := crosshair_wanted()
	_crosshair.modulate.a = move_toward(_crosshair.modulate.a, 1.0 if want else 0.0,
		delta * (8.0 if want else 3.0))


## Whether the reticle is asked for now (see _process). Public for the tests.
func crosshair_wanted() -> bool:
	if _beam != null and (_beam.is_active() or _beam.is_holding() or _beam.has_target()):
		return true
	return _aiming_person or not _tip_text.is_empty()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(HINTS_ACTION):
		# H UNDER A LETTER WOULD PUT THE CARD STRAIGHT BACK OVER IT. The overlay owns the
		# screen while it is up; the key is remembered rather than refused, so the card she
		# asks for arrives the moment the letter closes.
		_hints_wanted = not _hints_wanted
		if not _overlay_open:
			_hints.visible = _hints_wanted
		_refresh_chip()
		get_viewport().set_input_as_handled()


## Show `text` as a toast for TOAST_HOLD + TOAST_FADE seconds. Public so anything else
## that wants to say something to the player (a later quest, a tutorial prompt) has one
## place to say it through.
##
## A SECOND TOAST RAISED WHILE THE FIRST IS STILL UP IS QUEUED, NOT WRITTEN OVER IT. One
## action routinely says two things: selling a gem is "Sold 1 gem for 5 bits." and then
## "Request done: ...", both inside the same frame, and the sale line used to be replaced
## before anybody could read a word of it. So the line on screen is left alone to live out
## its hold and its fade, and the next one starts the moment it is finished. Nothing is
## dropped and nothing jumps the line: the queue is first in, first out.
##
## THE BACKLOG IS CAPPED, AND THE LINE ALREADY ON SCREEN RUNS SHORT. See TOAST_QUEUE_MAX and
## TOAST_HOLD_BUSY: rapid play can raise more than anyone reads in time, and nine seconds of
## stale news is worse than a line nobody saw, so past the cap the OLDEST waiting line goes,
## never the newest.
func toast(text: String) -> void:
	if _toast_left > 0.0:
		_toast_queue.append(text)
		while _toast_queue.size() > TOAST_QUEUE_MAX:
			_toast_queue.pop_front()
		return
	_show_toast(text)


func _show_toast(text: String) -> void:
	var card := toast_card_for(text)
	_toast_full = text
	_toast.text = String(card.words)
	_toast_left = toast_hold_for(String(card.words)) + TOAST_FADE
	_toast.modulate.a = 1.0
	_set_toast_icon(String(card.icon))
	_set_toast_chips(card.chips)
	_fit_pill(_toast)
	# Its minimum width recomputed now it wraps: the cached one-line minimum held the label
	# at the unwrapped width (1957 px for a long toast, test_hud_layout) whatever its offsets.
	_toast.update_minimum_size()
	_place_toast()
	_toast.size = Vector2(float(_toast.get_meta(&"pill_width", _toast.size.x)), _toast.size.y)
	_place_toast_icon()
	_place_toast_chips()
	# A little pop on arrival, the way a show title card bounces in, from its left end.
	_toast.pivot_offset = Vector2(0.0, _toast.size.y * 0.5)
	_toast.scale = Vector2(0.86, 0.86)
	create_tween().tween_property(_toast, "scale", Vector2.ONE, 0.22).set_trans(
		Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A TOAST IS AN EVENT CARD (P8 S5; docs/aaa-review-2026-11-08.md 2.4): a picture from the
## icon set at its left says what kind of news it is before a word is read. Picked from the
## line's own words, first match wins, so every caller's toast gets one without a new argument.
const TOAST_ICONS := [
	["bloom", "bloom"], ["shipment", "sold"], ["deliver", "sold"], ["sold", "sold"],
	["bits", "coin"], ["pen", "fence"], ["full", "full"], ["caught", "catch"],
	["catch", "catch"], ["letter", "letter"], ["post", "letter"], ["mail", "letter"],
	["spotted", "sighting"], ["sighting", "sighting"], ["saw ", "sighting"], ["lake", "lake_open"],
	["night", "moon"], ["dawn", "sun"], ["color day", "sun"], ["rain", "rain"],
	["market", "market"], ["depot", "crate"], ["saddlebag", "bag"], ["gem", "reel_gem"],
	["pantry", "pantry"], ["food", "pantry"], ["permit", "letter"], ["unlock", "upgrade"],
]
const TOAST_ICON_PX := 40.0

var _toast_icon: TextureRect


static func toast_icon_for(text: String) -> String:
	var t := text.to_lower()
	for pair: Array in TOAST_ICONS:
		if t.contains(String(pair[0])):
			return String(pair[1])
	return "star"


func _set_toast_icon(icon_name: String) -> void:
	if _toast_icon == null:
		_toast_icon = TextureRect.new()
		_toast_icon.name = "ToastIcon"
		_toast_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_toast_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_toast_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# The picture sits on a cream disc in a gold ring, the casino's chip as a frame.
		var disc := Panel.new()
		disc.name = "Disc"
		disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		disc.show_behind_parent = true
		disc.add_theme_stylebox_override(&"panel", HouseStyleScript.disc_box(TOAST_ICON_PX + 10.0,
			HouseStyleScript.KEY_FACE, HouseStyleScript.GOLD, 3))
		disc.position = Vector2(-5, -5)
		disc.size = Vector2(TOAST_ICON_PX + 10.0, TOAST_ICON_PX + 10.0)
		_toast_icon.add_child(disc)
		_toast.add_child(_toast_icon)
		var box := _toast.get_theme_stylebox(&"normal").duplicate() as StyleBox
		box.content_margin_left = 16.0 + TOAST_ICON_PX + 14.0
		_toast.add_theme_stylebox_override(&"normal", box)
		# A Label centres its text in its whole rect, not between uneven margins, so a
		# centred line slid under the picture. The pill is fitted to the line anyway.
		_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_toast_icon.texture = IconSet.texture(icon_name, 96, false)


## A TOAST IS A PICTURE AND A FEW WORDS (Fable AAA round 5: "toasts are sentences"). The
## lines the game says most often are cut to their news and their numbers: "Lark Wish moved
## into the pen. It is now full." is the fence, "Lark Wish penned" and a Full tag; "Request
## done: Catch a pony with your magic beam. (+20 bits)" is the board's picture, "Request done"
## and a gold coin chip reading +20. Every number that matters survives as a chip; a line
## no rule knows (a letter's title, the Company's notices, Spike) is drawn whole, because
## those words are the story. toast_text() still answers the whole line for the gates.
##   -> {words, icon, chips: [{kind: "coin" | "chips" | "tag", text}]}
const TOAST_RULES := [
	# [pattern, words ($1.. from the match), icon, [[chip kind, chip text], ...]]
	["^(.+) moved into the pen\\. It is now full\\.$", "$1 penned", "fence", [["tag", "Full"]]],
	["^(.+) moved into the pen\\.$", "$1 penned", "fence", []],
	["^Request done: .*\\(\\+(\\d+) bits and (\\d+) (.+)\\)$", "Request done", "objective",
		[["coin", "+$1"], ["tag", "+$2 $3"]]],
	["^Request done: .*\\(\\+(\\d+) bits\\)$", "Request done", "objective", [["coin", "+$1"]]],
	["^Sold everything for (\\d+) bits\\.$", "Sold it all", "sell_all", [["coin", "+$1"]]],
	["^Sold (\\d+) (.+) for (\\d+) bits\\.$", "Sold $1 $2", "sold", [["coin", "+$3"]]],
	["^Set complete: (.+)! (\\d+) bits\\.$", "$1 complete!", "star", [["coin", "+$2"]]],
	["^Contract met: \\+(\\d+) bits\\.$", "Contract met", "objective", [["coin", "+$1"]]],
	["^Paid (\\d+) bits\\. Balance: (\\d+)\\.$", "Paid", "crate", [["coin", "-$1"], ["tag", "Owed $2"]]],
	["^(\\d+) chips\\. Good luck!$", "Good luck!", "chip_gold", [["chips", "+$1"]]],
	["^(\\d+) bits\\. Come back soon!$", "Cashed out", "coin", [["coin", "+$1"]]],
	["^(.+) takes it\\. You win (\\d+) chips!$", "$1 wins!", "chip_gold", [["chips", "+$2"]]],
	["^(.+) takes it\\. Your pony was not in front today\\.$", "$1 wins", "chip_red", []],
	["^Good morning! Day (\\d+)\\. The ranch is saved\\.$", "Good morning!", "sun",
		[["tag", "Day $1"]]],
	["^Upgraded to a (.+)\\. Room for (\\d+) now\\.$", "$1", "upgrade", [["tag", "Room for $2"]]],
	["^The Express Chute took (\\d+) in the night\\. \\+(\\d+) bits on your statement\\.$",
		"Chute took $1", "express_chute", [["coin", "+$2"]]],
	["^(.+) came home at dawn\\.$", "$1 is home", "house", []],
	# SPIKE'S TIP AS A CARD (P9 item 33): his icon, a few words, the hint on a chip.
	["^(?:Spike|Tip)\\[(\\w+)\\]: (.+) \\| (.+)$", "$2", "$1", [["tag", "$3"]]],
]


static func toast_card_for(text: String) -> Dictionary:
	for rule: Array in TOAST_RULES:
		var re := RegEx.create_from_string(String(rule[0]))
		var m := re.search(text)
		if m == null:
			continue
		var chips: Array = []
		for c: Array in rule[3]:
			chips.append({"kind": String(c[0]), "text": _fill(String(c[1]), m)})
		return {"words": _fill(String(rule[1]), m), "icon": _fill(String(rule[2]), m), "chips": chips}
	return {"words": text, "icon": toast_icon_for(text), "chips": []}


static func _fill(template: String, m: RegExMatch) -> String:
	var out := template
	for i in range(m.get_group_count(), 0, -1):
		out = out.replace("$%d" % i, m.get_string(i))
	return out


## The line on screen in full, as it was raised (toast_text()).
var _toast_full := ""
var _toast_chip_row: HBoxContainer
const TOAST_CHIP_H := 38.0


## The numbers a toast keeps, as chips at the pill's right end: gold numerals on a dark coin
## chip with the coin (or a casino chip) at their left, or a cream tag for a state ("Full").
func _set_toast_chips(chips: Array) -> void:
	if _toast_chip_row == null:
		_toast_chip_row = HBoxContainer.new()
		_toast_chip_row.name = "ToastChips"
		_toast_chip_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_toast_chip_row.add_theme_constant_override(&"separation", 6)
		_toast.add_child(_toast_chip_row)
	for c in _toast_chip_row.get_children():
		_toast_chip_row.remove_child(c)
		c.queue_free()
	for chip: Dictionary in chips:
		_toast_chip_row.add_child(_toast_chip(chip))
	_toast_chip_row.visible = not chips.is_empty()
	_toast_chip_row.reset_size()
	var box := _toast.get_theme_stylebox(&"normal") as StyleBox
	if box != null:
		box.content_margin_right = 24.0 + (_chips_width() + 10.0 if not chips.is_empty() else 0.0)


func _toast_chip(chip: Dictionary) -> Control:
	var l := Label.new()
	l.text = String(chip.text)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.custom_minimum_size.y = TOAST_CHIP_H
	var kind := String(chip.kind)
	if kind == "tag":
		var tag := HouseStyleScript.pill_box(int(TOAST_CHIP_H * 0.5), 1.0, Vector2(14, 2))
		tag.bg_color = HouseStyleScript.KEY_FACE
		tag.border_color = HouseStyleScript.GOLD
		l.add_theme_stylebox_override(&"normal", tag)
		HouseStyleScript.ink_label(l, 22, HouseStyleScript.PLUM_DARK, false)
		l.add_theme_constant_override(&"outline_size", 0)
		return l
	var box := HouseStyleScript.pill_box(int(TOAST_CHIP_H * 0.5), 1.0, Vector2(12, 2))
	box.bg_color = HouseStyleScript.PLUM_DARK
	box.border_color = HouseStyleScript.GOLD
	box.content_margin_left = TOAST_CHIP_H - 4.0 + 8.0
	l.add_theme_stylebox_override(&"normal", box)
	HouseStyleScript.numeral_label(l, 26)
	var face := TextureRect.new()
	face.texture = IconSet.texture("coin" if kind == "coin" else "chip_gold", 96, false)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.size = Vector2(TOAST_CHIP_H - 6.0, TOAST_CHIP_H - 6.0)
	face.position = Vector2(4.0, 3.0)
	l.add_child(face)
	return l


func _chips_width() -> float:
	if _toast_chip_row == null or not _toast_chip_row.visible:
		return 0.0
	return _toast_chip_row.get_combined_minimum_size().x


func _place_toast_chips() -> void:
	if _toast_chip_row == null or not _toast_chip_row.visible:
		return
	var w := _toast.offset_right - _toast.offset_left
	var h := _toast.offset_bottom - _toast.offset_top
	var s := _toast_chip_row.get_combined_minimum_size()
	_toast_chip_row.size = s
	_toast_chip_row.position = Vector2(w - 18.0 - s.x, (h - s.y) * 0.5)


## The toast card's chips as drawn, [{kind, text}], for the tests.
func toast_chips() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if _toast_chip_row != null and _toast_chip_row.visible:
		for c in _toast_chip_row.get_children():
			if c.is_queued_for_deletion():
				continue
			out.append({"text": (c as Label).text})
	return out


## THE TOAST SITS ON THE SADDLEBAG (Fable AAA round 3, #9: "the toast pill sits dead centre
## over the player"). Its left end is the bag card's, its foot TOAST_GAP above the card's top,
## so news stacks over the strip it is mostly about (a catch, a pen, a sale) and the pony in
## the middle of the screen stays clear. Measured at each toast: the card grows with the bag.
const TOAST_GAP := 26.0


func _place_toast() -> void:
	# The width _fit_pill chose (its meta), placed above the bag. Kept on the scene's own
	# anchors (centre, bottom) and written as offsets from them: switched to the top left, the
	# label held on to a 2823 px width at 150% text (test_hud_layout).
	var w := float(_toast.get_meta(&"pill_width", _toast.offset_right - _toast.offset_left))
	var h := _toast.offset_bottom - _toast.offset_top
	var card := get_node_or_null(^"BagCard") as Control
	var canvas := _canvas_size()
	var left := 28.0
	var top := canvas.y - 200.0
	if card != null and card.visible:
		left = card.position.x
		top = card.position.y
	# Above the saddlebag as drawn (round 6 drew it on the field and left BagCard empty).
	var bag := get_node_or_null(^"Bag") as Control
	if bag != null and bag.is_visible_in_tree():
		top = minf(top, bag.get_global_rect().position.y)
	var ax := _toast.anchor_left * canvas.x
	var ay := _toast.anchor_top * canvas.y
	_toast.offset_left = left - ax
	_toast.offset_right = left + w - ax
	_toast.offset_bottom = top - TOAST_GAP - ay
	_toast.offset_top = top - TOAST_GAP - h - ay


func toast_rect() -> Rect2:
	return Rect2(_toast.position, _toast.size)


func _place_toast_icon() -> void:
	if _toast_icon == null:
		return
	_toast_icon.size = Vector2(TOAST_ICON_PX, TOAST_ICON_PX)
	_toast_icon.position = Vector2(16.0, (_toast.size.y - TOAST_ICON_PX) * 0.5)


## LONG ENOUGH TO READ (PT5; owner: "some dialogue i dont read it goes too fast"): a short
## line holds TOAST_HOLD, a long one about a third of a second a word, up to TOAST_HOLD_MAX.
const TOAST_HOLD_MAX := 7.0


static func toast_hold_for(text: String) -> float:
	var words := text.split(" ", false).size()
	return clampf(1.2 + float(words) * 0.32, TOAST_HOLD, TOAST_HOLD_MAX)


## The line that is ON SCREEN now, whether or not it has faded, which since the queue above
## is the OLDEST toast still unspoken rather than the newest one raised. Exposed for the
## same reason get_bits_text() is: what the player is told is a real requirement (the
## market gate reads the sale line back), and a gate has no other way to see it.
func toast_text() -> String:
	return _toast_full


## The few words the toast card actually draws for the line on screen (toast_card_for).
func toast_words() -> String:
	return _toast.text


## How long the line on screen has left, holding and fading together. For the tests, which
## otherwise have to infer the timer from an alpha.
func toast_seconds_left() -> float:
	return _toast_left


## The toasts raised but not yet shown, oldest first. A copy: a caller that emptied this
## would be silently swallowing something the player was promised. For the tests and gates
## that have to tell "queued behind the line on screen" from "never said at all".
func pending_toasts() -> Array[String]:
	return _toast_queue.duplicate()


## A LETTER OR A MENU IS ON SCREEN, OR IT IS NOT. The owner's playtest, on the welcome
## letter: the H control card bled through it. Every panel in this game is a CanvasLayer over
## the world and so is this overlay, so "over the world" was never going to be enough; the
## card has to be told.
##
## HER OWN TOGGLE IS REMEMBERED ACROSS THE OVERLAY. A player who had the card up gets it back
## when the letter closes; a player who did not is not handed one she never asked for.
func set_overlay_open(open: bool) -> void:
	_overlay_open = open
	if _hints != null:
		_hints.visible = _hints_wanted and not _overlay_open
	# The prompt and the monocle's card are about the world, and the world is behind the menu
	# (the round 1 review's Depot shot still had "Hold Right Mouse" under it). The tip fades
	# itself out in _fade_tip().
	if _prompt_card != null:
		_prompt_card.visible = not _overlay_open and not prompt_text().is_empty()
	if _target != null:
		_target.visible = not _overlay_open and not _target.text.is_empty()
	_refresh_chip()


func overlay_open() -> bool:
	return _overlay_open


func hints_visible() -> bool:
	return _hints != null and _hints.visible


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


## Push the checklist. `rows` is RequestBoard.tutorial_rows()'s output; an empty array
## clears the block entirely.
##
## TYPED `Array` RATHER THAN `Array[Dictionary]`, DELIBERATELY. This HUD is always reached
## through get_node_or_null()/has_method() (ranch.gd never declares a static HUD-typed
## var), so every call here goes through GDScript's dynamic dispatch, and an untyped array
## literal built at a call site with no static knowledge of this signature cannot coerce to
## a strictly typed Array[Dictionary] parameter across that boundary (Godot 4.5 raises
## "does not have the same element type as the expected typed array argument"). A real
## Array[Dictionary] (what ranch.gd actually passes, straight off tutorial_rows()) narrows
## into a plain Array with no coercion at all, so nothing is lost on the production path.
func set_tasks(rows: Array) -> void:
	_task_lines = []
	# DETACHED, THEN FREED: a queued child still counts toward the box's minimum height when
	# the deferred refit runs, so one task left kept a three-task card (render review
	# 2026-10-26).
	for child in _tasks.get_children():
		_tasks.remove_child(child)
		child.queue_free()
	if rows.is_empty():
		# The card goes with its lines. The labels above are only QUEUED for deletion, so a
		# refit now would still find them; left up, the card was an empty white box in the
		# corner for the rest of the game (owner playtest 2026-10-25).
		var empty := get_node_or_null("TasksCard") as Panel
		if empty != null:
			empty.visible = false
		return
	_task_lines.append(TASK_TITLE)
	for entry in rows:
		# GUARDED, NOT TRUSTED: `rows` is a plain Array (see the signature comment above),
		# so a junk element (an int, a String, null) reaches here as Variant rather than
		# being refused at the call boundary the way a real Array[Dictionary] would refuse
		# it. A typed `for row: Dictionary in rows` loop over an untyped Array crashes the
		# instant one element is not actually a Dictionary; skipping it here instead means
		# one bad row loses itself rather than the whole checklist.
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = entry
		var done: bool = bool(row.get("done", false))
		_task_lines.append("%s%s  (%d bits)" % [TASK_DONE if done else TASK_OPEN,
			String(row.get("text", "")), int(row.get("reward_bits", 0))])
	# THE TITLE IS KEPT FOR THE RECORD, NOT DRAWN (Fable AAA round 5: "Getting started" over
	# "+20 +30 +50" read as text scaffolding). task_lines() still opens with it.
	var title := Label.new()
	title.text = TASK_TITLE
	title.visible = false
	_tasks.add_child(title)
	# ICONS ROUND A PROGRESS RING (round 5): a medallion whose ring is cut into one arc per
	# lesson, gold for each one done, and the lessons beside it as picture discs that go felt
	# green with a tick when done. No words and no reward numerals on the HUD: the sentence
	# and the pay are each chip's hover card, and the objective card says what to do next
	# (game/ui/objective_card.gd).
	_chips = []
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override(&"separation", 8)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tasks.add_child(strip)
	var done_count := 0
	for entry in rows:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = entry
		var kind: Array = TASK_CHIPS.get(String(row.get("id", "")),
			[String(row.get("text", "")).get_slice(" ", 0), PlaceSign.Icon.STAR])
		var chip := {"word": String(kind[0]), "done": bool(row.get("done", false)),
			"icon": IconSet.texture(String(kind[2]), 96, false) if kind.size() > 2
				else PlaceSign.icon_texture(int(kind[1])), "reward": int(row.get("reward_bits", 0)),
			"text": String(row.get("text", ""))}
		_chips.append(chip)
		done_count += 1 if bool(chip.done) else 0
	# EACH CHIP HAS A STATE (Fable AAA round 6: "four unlabeled icons with no state"): done
	# (felt green, ticked), next (the first open one: lit cream in a glowing gold ring), or
	# locked (every open one after it: dark, its picture faded, a padlock on it).
	var next_found := false
	for chip: Dictionary in _chips:
		if bool(chip.done):
			chip["state"] = &"done"
		elif not next_found:
			chip["state"] = &"next"
			next_found = true
		else:
			chip["state"] = &"locked"
	strip.add_child(_task_ring(done_count, _chips.size()))
	for chip: Dictionary in _chips:
		strip.add_child(_task_chip(chip))
	var card := get_node_or_null("TasksCard") as Panel
	if card != null:
		_fit_card.call_deferred(card, _tasks, Vector2(18, 12))


const TASK_TICK := Color(0.36, 0.68, 0.36)
## Each lesson's chip: one word and its action's place icon (the catch: a Drifter's head, the
## objective card's own picture for a catch).
const TASK_CHIPS := {
	"tutorial_catch": ["Catch", PlaceSign.Icon.STAR, "drifter"],
	"tutorial_pen": ["Pen", PlaceSign.Icon.FENCE],
	"tutorial_sell": ["Sell", PlaceSign.Icon.COIN],
}
var _chips: Array[Dictionary] = []


## The checklist's chips as drawn: [{word, done, icon, reward, text, state}], state one of
## &"done", &"next", &"locked".
func task_chips() -> Array[Dictionary]:
	return _chips.duplicate()


## A LESSON CHIP TAKES THE POINTER (PS10, G1; FS1.4 promised it and the chips were built
## ignoring the mouse). The chip is one word; resting the pointer on it brings up the lesson's
## whole sentence on one of the HUD's own cards, with what it pays, so the word never has to
## carry the instruction alone. PASS, not STOP: the chip wants the hover, never the click.
class LessonChip extends VBoxContainer:
	var reward := 0
	var done := false

	func _make_custom_tooltip(for_text: String) -> Object:
		var card := VBoxContainer.new()
		card.add_theme_constant_override(&"separation", 2)
		var line := Label.new()
		line.text = for_text
		MenuStyleScript.style_label(line, 19, MenuStyleScript.TOOLTIP_INK)
		line.add_theme_constant_override("outline_size", 0)
		line.add_theme_font_override("font", MenuStyleScript.title_font())
		card.add_child(line)
		var pay := Label.new()
		pay.text = ("Done!  +%d bits" if done else "Worth %d bits") % reward
		MenuStyleScript.style_label(pay, 16, TASK_TICK.darkened(0.2) if done else Color(0.6, 0.45, 0.12))
		pay.add_theme_constant_override("outline_size", 0)
		card.add_child(pay)
		return card


func _task_chip(chip: Dictionary) -> VBoxContainer:
	var col := LessonChip.new()
	col.add_theme_constant_override(&"separation", 0)
	col.custom_minimum_size = Vector2(54, 0)
	col.mouse_filter = Control.MOUSE_FILTER_PASS
	col.tooltip_text = String(chip.get("text", ""))
	col.reward = int(chip.reward)
	col.done = bool(chip.done)
	var done: bool = chip.done
	# A CASINO CHIP PER LESSON (Fable AAA review round 1, #3): a plum disc in a gold ring with
	# the action's picture, felt green with a tick once it is done.
	var tile := Control.new()
	tile.custom_minimum_size = Vector2(TASK_DISC, TASK_DISC)
	tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon: Texture2D = chip.icon
	var state: StringName = chip.get("state", &"done" if done else &"next")
	tile.draw.connect(func() -> void:
		var r := Rect2(Vector2.ZERO, tile.size)
		var mid := r.get_center()
		if state == &"next":
			# The one to do now: a warm halo round a lit disc.
			for k in 3:
				tile.draw_circle(mid, r.size.x * 0.5 + 7.0 - k * 2.5,
					Color(HouseStyleScript.GOLD, 0.12 + 0.1 * k))
		var fill := Color(1.0, 0.97, 0.9)
		var ring := HouseStyleScript.GOLD
		if done:
			fill = HouseStyleScript.FELT
			ring = HouseStyleScript.TICK_GREEN
		elif state == &"locked":
			fill = HouseStyleScript.PLUM_DARK
			ring = Color(HouseStyleScript.GOLD_DIM, 0.7)
		tile.draw_style_box(HouseStyleScript.disc_box(r.size.x, fill, ring,
			4 if state == &"next" else 3), r)
		if icon != null:
			var tint := Color.WHITE
			if done:
				tint = Color(1, 1, 1, 0.45)
			elif state == &"locked":
				tint = Color(0.75, 0.68, 0.8, 0.4)
			tile.draw_texture_rect(icon, r.grow(-8.0), false, tint)
		if state == &"locked":
			# A small gold padlock at the corner: later, not yet.
			var p := Vector2(tile.size.x - 8.0, tile.size.y - 9.0)
			tile.draw_arc(p + Vector2(0, -3), 4.2, PI, TAU, 10, HouseStyleScript.PLUM_DARK, 4.5, true)
			tile.draw_arc(p + Vector2(0, -3), 4.2, PI, TAU, 10, HouseStyleScript.GOLD_DIM, 2.2, true)
			PaintScript.rounded(tile, Rect2(p + Vector2(-6.5, -3.5), Vector2(13, 10)), 2.5,
				HouseStyleScript.GOLD, HouseStyleScript.PLUM_DARK, 1.5)
			tile.draw_circle(p + Vector2(0, 1.2), 1.4, HouseStyleScript.PLUM_DARK)
		if done:
			# The tick, on a gold badge at the corner.
			var c := Vector2(tile.size.x - 7, 7)
			tile.draw_circle(c, 8, HouseStyleScript.GOLD)
			tile.draw_polyline(PackedVector2Array([c + Vector2(-4, 0), c + Vector2(-1, 3),
				c + Vector2(4.5, -3)]), HouseStyleScript.PLUM_DARK, 2.5, true))
	col.add_child(tile)
	# The word and the pay are the hover card's (round 5); the picture carries the chip.
	return col


## The lesson chips' disc, across.
const TASK_DISC := 48.0
## The progress medallion, across.
const TASK_RING := 58.0


## THE PROGRESS RING: one arc per lesson round a plum medallion with a star, gold for each
## lesson done and a dim track for each still open, so how far through she is reads at a
## glance without a number.
func _task_ring(done: int, total: int) -> Control:
	var ring := Control.new()
	ring.name = "TaskRing"
	ring.custom_minimum_size = Vector2(TASK_RING, TASK_RING)
	ring.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.set_meta(&"done", done)
	ring.set_meta(&"total", total)
	var star := IconSet.texture("star", 96, false)
	ring.draw.connect(func() -> void:
		var c := ring.size * 0.5
		var r := ring.size.x * 0.5
		ring.draw_circle(c, r - 1.0, HouseStyleScript.PLUM_DARK)
		var n := maxi(total, 1)
		var gap := 0.24
		for i in n:
			var a0 := -PI * 0.5 + TAU * float(i) / n + gap * 0.5
			var a1 := a0 + TAU / n - gap
			ring.draw_arc(c, r - 6.0, a0, a1, 24, Color(0, 0, 0, 0.4), 9.0, true)
			ring.draw_arc(c, r - 6.0, a0, a1, 24,
				HouseStyleScript.GOLD if i < done else Color(1.0, 0.96, 0.86, 0.25), 6.5, true)
		ring.draw_circle(c, r - 12.0, HouseStyleScript.PLUM)
		if star != null:
			var s := (r - 12.0) * 2.1
			ring.draw_texture_rect(star, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false))
	return ring


func task_lines() -> Array[String]:
	return _task_lines.duplicate()


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
	# Seeded here and refreshed on every Storage.changed below, because the bag can GROW
	# after binding: buying the shop's saddlebag calls Storage.set_capacity() on the very
	# object this HUD is already holding.
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
	# Capacity first, and re-read rather than trusted from bind time: Storage.changed now
	# fires for a bag that grew as well as for a bag that filled, and a stale _capacity
	# would print "n / 12" and draw twelve pips over an eighteen-slot saddlebag.
	_capacity = _storage.capacity
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
	_size_bag()


## The bag strip's size: the bag (none before the Scoop is hers), the coins and the number.
func _size_bag() -> void:
	var bag := _bag_size()
	var font := MenuStyleScript.numeral_font()
	var num := font.get_string_size(str(_bits_total), HORIZONTAL_ALIGNMENT_LEFT, -1, BITS_PX).x
	_pips.custom_minimum_size = Vector2(
		(bag.x + STRIP_GAP if bag.x > 0.0 else 0.0) + COIN_W + 8.0 + num + 8.0,
		maxf(bag.y, 56.0))
	_pips.queue_redraw()


func _slots_width() -> float:
	return float(mini(maxi(_capacity, 1), PIPS_PER_ROW)) * (PIP_SIZE.x + PIP_GAP) - PIP_GAP


func _slots_height() -> float:
	var rows := maxi(1, ceili(float(_capacity) / float(PIPS_PER_ROW)))
	return float(rows) * (PIP_SIZE.y + PIP_GAP) - PIP_GAP


## The drawn bag's size, strap to foot; zero before there is a bag.
func _bag_size() -> Vector2:
	if _capacity <= 0:
		return Vector2.ZERO
	return Vector2(_slots_width() + BAG_PAD.x * 2.0,
		BAG_STRAP + BAG_FLAP + 6.0 + _slots_height() + BAG_PAD.y)


## A CATCH IS A CARD, NOT A TOAST (owner playtest 2026-10-25: "i think the text and traits
## on catch can be better maybe icons and stuff instead of basic text on the top"). Her
## portrait, name, rarity stars and trait icons slide in at the top right; see
## game/ui/catch_card.gd. The body is read for her portrait inside this same frame, before
## the beam's queue_free() lands.
func _on_captured(instance: PonyInstance) -> void:
	if instance == null or _catch_card == null:
		return
	var body: Node3D = null
	if _beam != null and _beam.has_method("last_captured_body"):
		body = _beam.last_captured_body()
	_catch_card.show_catch(instance, body)


## While the catch card holds its centre moment the rest of the HUD is hidden, and it comes
## back the moment the card flies to its corner. Only a HUD this hid is shown again, so a HUD a
## cinematic put away stays away.
func _veil_for_catch() -> void:
	if _catch_card == null:
		return
	if _catch_layer != null:
		_catch_layer.layer = layer + 1
	var moment: bool = _catch_card.call("in_moment")
	if moment and not _veiled and visible:
		_veiled = true
		visible = false
	elif not moment and _veiled:
		_veiled = false
		visible = true


func catch_veiled() -> bool:
	return _veiled


## The catch card, for the tests and gates.
func catch_card() -> Control:
	return _catch_card


## The bag was full, so she was set down instead of stored -- the one capture outcome
## with nothing at all to show for it on screen otherwise.
func _on_capture_refused(_body: Node3D) -> void:
	toast("Saddlebag full!")


## Three very different endings reach this signal (MagicBeam.Loss), and saying which one
## just happened is the only teaching the capture window ever gets. "She wriggled free" on
## a hold the player abandoned after half a second would be a straight lie, and would teach
## exactly the wrong lesson -- let go SOONER next time.
##
## WRENCHED IS THE ONE THAT IS NOT A MISTAKE AT ALL. A HARD pony can tear out before the
## beam has secured her (magic_beam.gd's WRENCH_CHANCE_HARD) and there was nothing the
## player could have done differently -- so the line says so, and promises the thing the
## code actually guarantees: she tires, and the next attempt is easier. Telling a player
## "hold her longer" for a hold that was never winnable is how a fair mechanic acquires a
## reputation for cheating.
func _on_escaped(_body: Node3D) -> void:
	if _beam == null:
		toast("She wriggled free!")
		return
	match _beam.get_last_loss():
		MagicBeamScript.Loss.SLIPPED:
			toast("She slipped out! Hold her a little longer.")
		MagicBeamScript.Loss.WRENCHED:
			toast("She wrenched free! She will tire, so try again.")
		_:
			toast("She wriggled free! Let go sooner.")


# --- drawing ---------------------------------------------------------------------

## Whether the crosshair is resting on a townspony (Ranch._update_person_aim, PT8).
var _aiming_person := false


func set_aiming_person(on: bool) -> void:
	if on != _aiming_person:
		_aiming_person = on
		_crosshair.queue_redraw()


func aiming_person() -> bool:
	return _aiming_person


## A little speech bubble beside the reticle: a person to talk to, not a pony to catch.
func _draw_person_badge(centre: Vector2) -> void:
	var at := centre + Vector2(38.0, -38.0)
	_crosshair.draw_circle(at, 23.0, Color(0.25, 0.18, 0.32, 0.55))
	_crosshair.draw_circle(at, 20.0, Color(1.0, 0.98, 0.93))
	_crosshair.draw_colored_polygon(PackedVector2Array([at + Vector2(-14, 11), at + Vector2(-4, 14),
		at + Vector2(-19, 25)]), Color(1.0, 0.98, 0.93))
	for k in 3:
		_crosshair.draw_circle(at + Vector2(-8.0 + 8.0 * k, 0.0), 3.0, Color(0.45, 0.3, 0.55))


func _draw_crosshair() -> void:
	var centre: Vector2 = _crosshair.size * 0.5
	if _aiming_person and not (_beam != null and (_beam.is_holding() or _beam.has_target())):
		_draw_person_badge(centre)
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
		# Outer first, inner second: the inner ring is the smaller of the two and drawing
		# it last keeps it on top where the two outlines meet.
		_draw_catch_ring(centre)
		# One clean catch (P8): a pony has no struggle clock to drain, so no inner ring.
		if is_finite(_beam.get_struggle_seconds()):
			_draw_wriggle_ring(centre)


## THE CATCH METER: how far the beam has got toward subduing her, drawn as the OUTER ring
## FILLING CLOCKWISE from the top. "Release click when full" is the whole instruction, and
## a meter that fills toward a closed circle is the one shape that says it without words.
##
## Drawn from the beam's ROLLED subdue time (get_secure_progress), not from the nominal
## constant, which is what makes the per-attempt jitter fair rather than random: the ring
## closes exactly when this particular hold is ready, so a player who watches it is never
## wrong and a player who counts always is.
##
## Once it completes it is drawn as a full ring in the "she is yours" colour rather than
## being hidden -- a control that disappears at the moment of truth teaches the player
## nothing about why. The empty track behind it is drawn whatever the progress, so the
## circle the player is trying to close is visible from the first frame of the hold.
func _draw_catch_ring(centre: Vector2) -> void:
	var progress: float = _beam.get_secure_progress()
	_crosshair.draw_arc(centre, CATCH_RADIUS, 0.0, TAU, 64,
		COLOR_OUTLINE, CATCH_WIDTH + 2.0, true)
	if progress <= 0.0:
		return
	var color: Color = COLOR_CATCH_FULL if progress >= 1.0 else COLOR_CATCH
	var start := -PI * 0.5
	_crosshair.draw_arc(centre, CATCH_RADIUS, start, start + TAU * progress, 64,
		color, CATCH_WIDTH, true)


## HER FIGHT, DRAINING: the INNER ring, emptying ANTICLOCKWISE from the top over her
## struggle time. Time REMAINING rather than elapsed, so "the ring is nearly gone" means
## "she is nearly gone".
##
## THE DIRECTION IS LOAD-BEARING, not decoration. It runs the opposite way round the dial
## to the catch ring outside it, so the two are distinguishable in motion by a player who
## cannot separate them by hue -- which is the whole reason a green ring and a red ring
## are allowed to sit two millimetres apart on the same reticle at all.
##
## A body with no struggle time at all (a loose prop -- magic_beam.gd's STRUGGLE_NEVER is
## INF) gets a complete, static ring: it is never going anywhere.
##
## WHEN A HARD PONY WRENCHES (magic_beam.gd's WRENCH_CHANCE_HARD) THIS IS WHERE THE PLAYER
## SEES IT: her struggle time was rolled shorter than the subdue time, so this ring simply
## empties while the green one outside it is still two thirds of the way round. No special
## case here, and none wanted -- the drawing is honest about the clocks and the clocks are
## where the design lives.
func _draw_wriggle_ring(centre: Vector2) -> void:
	var total: float = _beam.get_struggle_seconds()
	var remaining := 1.0
	if is_finite(total) and total > 0.0:
		remaining = clampf(1.0 - _beam.get_hold_seconds() / total, 0.0, 1.0)

	# Brighter as it runs out, so "she is about to win" is legible in the corner of the
	# eye as well as in the ring's length.
	var color: Color = COLOR_WRIGGLE.lerp(COLOR_WRIGGLE_LOW, 1.0 - remaining)
	var start := -PI * 0.5
	_crosshair.draw_arc(centre, WRIGGLE_RADIUS, 0.0, TAU, 48,
		COLOR_OUTLINE, WRIGGLE_WIDTH + 2.0, true)
	if remaining > 0.0:
		# start - TAU * remaining .. start: an arc that ENDS at the top and whose tail
		# retreats anticlockwise as she runs out.
		_crosshair.draw_arc(centre, WRIGGLE_RADIUS, start - TAU * remaining, start, 48,
			color, WRIGGLE_WIDTH, true)


func _draw_pips() -> void:
	var h := _pips.size.y
	var bag := _bag_size()
	var x := 0.0
	if bag.x > 0.0:
		_draw_bag(Rect2(Vector2(0.0, h - bag.y), bag))
		x = bag.x + STRIP_GAP
	_draw_wallet(Vector2(x, h))


## The saddlebag: strap, leather body with a stitched seam, the pockets, then the flap over
## their top with the count on its buckle (warm red when full).
func _draw_bag(r: Rect2) -> void:
	var body := Rect2(r.position + Vector2(0.0, BAG_STRAP), r.size - Vector2(0.0, BAG_STRAP))
	var cx := r.position.x + r.size.x * 0.5
	# The saddle band the bag hangs from (the piece that lies over her back), behind the bag,
	# two brass rivets on it.
	var band := Rect2(Vector2(cx - r.size.x * 0.32, r.position.y),
		Vector2(r.size.x * 0.64, BAG_STRAP + 16.0))
	PaintScript.rounded(_pips, band, 8.0, LEATHER_FLAP.darkened(0.12), LEATHER_DARK, 3.0)
	for side in [-1.0, 1.0]:
		_pips.draw_circle(Vector2(cx + side * band.size.x * 0.36, r.position.y + 6.5), 2.6,
			HouseStyleScript.GOLD)
	# A soft shadow so it sits on grass and on sky alike, then the body.
	_pouch(Rect2(body.position + Vector2(3, 5), body.size), 10.0, 24.0, Color(0, 0, 0, 0.3), 0)
	_pouch(body, 10.0, 24.0, LEATHER)
	_pips.draw_line(body.position + Vector2(10, body.size.y - 5), body.end - Vector2(10, 5),
		Color(0, 0, 0, 0.18), 3.0, true)
	_stitch(body.grow(-6.0), 5.0, 18.0)
	# The pockets: stitched sockets in the leather, a gem in each one that holds a pony.
	var origin := body.position + Vector2(BAG_PAD.x, BAG_FLAP + 6.0)
	for i in range(_capacity):
		var at := origin + Vector2(float(i % PIPS_PER_ROW) * (PIP_SIZE.x + PIP_GAP),
			float(i / PIPS_PER_ROW) * (PIP_SIZE.y + PIP_GAP))
		var rect := Rect2(at, PIP_SIZE)
		PaintScript.rounded(_pips, rect, 6.0, Color(0.2, 0.09, 0.05, 0.6),
			Color(LEATHER.lightened(0.35), 0.7), 1.0)
		if i < _rarities.size():
			_gem(rect.get_center(), PIP_SIZE.x * 0.5, _rarities[i])
	# The flap over the pockets' tops, a tongue and the buckle with the count.
	var flap := Rect2(body.position + Vector2(-2.0, -2.0), Vector2(body.size.x + 4.0, BAG_FLAP))
	_pouch(flap, 10.0, 18.0, LEATHER_FLAP)
	_pips.draw_line(flap.position + Vector2(12, 5), Vector2(flap.end.x - 12, flap.position.y + 5),
		Color(1, 0.9, 0.75, 0.35), 2.0, true)
	_stitch(Rect2(flap.position + Vector2(7, 7), flap.size - Vector2(14, 12)), 4.0, 11.0)
	var tongue := Rect2(Vector2(cx - 15.0, flap.end.y - 14.0), Vector2(30.0, 20.0))
	PaintScript.rounded(_pips, tongue, 8.0, LEATHER_FLAP, LEATHER_DARK, 3.0)
	var full := _rarities.size() >= _capacity
	var buckle := Rect2(Vector2(cx - BUCKLE.x * 0.5, flap.end.y - BUCKLE.y * 0.62), BUCKLE)
	PaintScript.rounded(_pips, buckle, 7.0,
		Color(0.86, 0.32, 0.28) if full else HouseStyleScript.GOLD, LEATHER_DARK, 2.5)
	_pips.draw_line(buckle.position + Vector2(6, 4), Vector2(buckle.end.x - 6, buckle.position.y + 4),
		Color(1, 1, 1, 0.45), 2.0, true)
	PaintScript.label(_pips, MenuStyleScript.numeral_font(), buckle.grow(-4.0),
		"%d/%d" % [_rarities.size(), _capacity], 20,
		Color.WHITE if full else HouseStyleScript.INK)


## A pouch of leather: square-ish shoulders (`top` radius), a full round foot (`foot`), the
## dark seam round it, so the bag reads as a saddlebag and not a box.
func _pouch(r: Rect2, top: float, foot: float, fill: Color, border := 3) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.corner_radius_top_left = int(top)
	box.corner_radius_top_right = int(top)
	box.corner_radius_bottom_left = int(foot)
	box.corner_radius_bottom_right = int(foot)
	box.set_border_width_all(border)
	box.border_color = LEATHER_DARK
	box.anti_aliasing = true
	box.draw(_pips.get_canvas_item(), r)


## A dashed seam round `r`, the stitching that makes leather read as leather.
## Its corners follow the pouch's: `top` and `foot` radii.
func _stitch(r: Rect2, top: float, foot: float) -> void:
	var pts := PackedVector2Array()
	var corners := [[Vector2(r.end.x - top, r.position.y + top), top, -PI * 0.5],
		[Vector2(r.end.x - foot, r.end.y - foot), foot, 0.0],
		[Vector2(r.position.x + foot, r.end.y - foot), foot, PI * 0.5],
		[Vector2(r.position.x + top, r.position.y + top), top, PI]]
	for c: Array in corners:
		for k in 5:
			var a: float = float(c[2]) + PI * 0.5 * float(k) / 4.0
			pts.append(Vector2(c[0]) + Vector2(cos(a), sin(a)) * float(c[1]))
	pts.append(pts[0])
	# Dashes laid along the whole path, so the corners keep the rhythm.
	var on := true
	var left := 5.0
	for k in pts.size() - 1:
		var a: Vector2 = pts[k]
		var b: Vector2 = pts[k + 1]
		while a.distance_to(b) > 0.01:
			var step := minf(left, a.distance_to(b))
			var n := a.move_toward(b, step)
			if on:
				_pips.draw_line(a, n, STITCH, 1.5, true)
			left -= step
			a = n
			if left <= 0.01:
				on = not on
				left = 5.0


## A pony in the bag: a cut gem in her rarity's colour in a gold bezel, lit at its top left,
## her rarity's shape in white on it, so the tier never rests on colour alone (FS8.3).
func _gem(c: Vector2, r: float, rarity: int) -> void:
	var col: Color = RARITY_COLORS.get(rarity, RARITY_COLORS[PonyDataScript.Rarity.COMMON])
	_pips.draw_circle(c, r, HouseStyleScript.GOLD)
	_pips.draw_circle(c, r - 2.0, col.darkened(0.25))
	_pips.draw_circle(c + Vector2(-0.8, -0.8), r - 3.4, col)
	_pips.draw_circle(c + Vector2(-r * 0.32, -r * 0.36), r * 0.22, Color(1, 1, 1, 0.75))
	_pips.draw_colored_polygon(RarityGlyph.outline(rarity, c + Vector2(0.5, 0.8), r * 0.42),
		Color(1, 1, 1, 0.92))


## The wallet: a stack of bits (one coin, more as it grows) and the number in the casino's
## gold numerals, outlined to stand on grass or sky. `foot` is the strip's bottom left.
func _draw_wallet(foot: Vector2) -> void:
	var coins := 1 + int(_bits_total >= 50) + int(_bits_total >= 500) + int(_bits_total >= 5000)
	var c := Vector2(foot.x + COIN_W * 0.5, foot.y - 12.0)
	var rx := COIN_W * 0.5
	var ry := rx * 0.42
	for k in coins:
		var at := c - Vector2(0.0, 7.0 * k)
		PaintScript.ellipse(_pips, at + Vector2(0, 4), rx, ry, HouseStyleScript.GOLD_DIM,
			LEATHER_DARK)
		_pips.draw_rect(Rect2(at - Vector2(rx, 0), Vector2(rx * 2.0, 4.0)), HouseStyleScript.GOLD_DIM)
		PaintScript.ellipse(_pips, at, rx, ry, HouseStyleScript.GOLD, LEATHER_DARK)
		_pips.draw_line(at + Vector2(-rx, 0), at + Vector2(-rx, 4), LEATHER_DARK, 2.0, true)
		_pips.draw_line(at + Vector2(rx, 0), at + Vector2(rx, 4), LEATHER_DARK, 2.0, true)
	var top := c - Vector2(0.0, 7.0 * (coins - 1))
	PaintScript.ellipse(_pips, top, rx * 0.66, ry * 0.62, Color(1.0, 0.88, 0.45),
		Color(HouseStyleScript.GOLD_DIM, 0.9))
	_pips.draw_circle(top + Vector2(-rx * 0.35, -ry * 0.35), 2.2, Color(1, 1, 1, 0.8))
	var font := MenuStyleScript.numeral_font()
	var base := Vector2(foot.x + COIN_W + 8.0, foot.y - 6.0)
	_pips.draw_string_outline(font, base, str(_bits_total), HORIZONTAL_ALIGNMENT_LEFT, -1,
		BITS_PX, 8, HouseStyleScript.PLUM_DARK)
	_pips.draw_string(font, base, str(_bits_total), HORIZONTAL_ALIGNMENT_LEFT, -1, BITS_PX,
		HouseStyleScript.GOLD)


## The rarity shapes the filled saddlebag slots carry (FS8.3), first slot first.
func pip_shapes() -> Array[StringName]:
	var out: Array[StringName] = []
	for r: int in _rarities:
		out.append(RarityGlyph.shape_of(r))
	return out


## One ring, drawn twice: an outline pass and then the colour, so the reticle stays
## visible over a bright sky as well as over grass.
func _ring(centre: Vector2, radius: float, color: Color, width: float) -> void:
	_crosshair.draw_arc(centre, radius, 0.0, TAU, 48, COLOR_OUTLINE, width + 2.0, true)
	_crosshair.draw_arc(centre, radius, 0.0, TAU, 48, color, width, true)


# --- text ------------------------------------------------------------------------

## The wallet line under the saddlebag. Driven by ranch.gd off Economy.bits_changed, so
## it repaints on a change and never per frame.
## THE PANTRY, SHOWN (PS9, playtest 2026-11-05 item 64: "Feeding is automatic from the
## pantry, and nothing says so; show the pantry stock and the hungry state"). A row under the
## bits: a bale, the word, the food in stock, and when anypony penned is hungry a sad face and
## how many. Warm red when hungry ponies meet an empty pantry: they cannot eat.
## On the field beside the bag (no card since round 6), so outlined like the wallet.
const PANTRY_WARN := Color(1.0, 0.56, 0.5)
var _pantry: HBoxContainer
var _pantry_food: Label
var _pantry_hungry: Label
var _pantry_face: Control
var _pantry_warn := false


func _build_pantry() -> void:
	_pantry = HBoxContainer.new()
	_pantry.name = "Pantry"
	_pantry.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pantry.add_theme_constant_override(&"separation", 8)
	_pantry.visible = false
	$Bag.add_child(_pantry)
	$Bag.move_child(_pantry, _bits.get_index() + 1)
	var bale := PantryIconScript.new()
	bale.kind = &"bale"
	_pantry.add_child(bale)
	var word := Label.new()
	word.text = "Pantry"
	word.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Outlined: the row stands on the field now, not on a card (round 6).
	HouseStyleScript.ink_label(word, 18, HouseStyleScript.CREAM)
	word.add_theme_constant_override(&"outline_size", 6)
	word.add_theme_color_override(&"font_outline_color", HouseStyleScript.PLUM_DARK)
	_pantry.add_child(word)
	_pantry_food = Label.new()
	_pantry_food.mouse_filter = Control.MOUSE_FILTER_IGNORE
	HouseStyleScript.numeral_label(_pantry_food, 22, HouseStyleScript.CREAM)
	_pantry.add_child(_pantry_food)
	_pantry_face = PantryIconScript.new()
	_pantry_face.kind = &"hungry"
	_pantry.add_child(_pantry_face)
	_pantry_hungry = Label.new()
	_pantry_hungry.mouse_filter = Control.MOUSE_FILTER_IGNORE
	HouseStyleScript.numeral_label(_pantry_hungry, 22, HouseStyleScript.CREAM)
	_pantry.add_child(_pantry_hungry)


## `food` items of feed in the pantry and `hungry` penned ponies; `food` below zero hides the
## row (no pen yet, nothing to feed).
func set_pantry(food: int, hungry: int) -> void:
	if _pantry == null:
		return
	_pantry.visible = food >= 0
	_pantry_food.text = str(maxi(0, food))
	_pantry_face.visible = hungry > 0
	_pantry_hungry.visible = hungry > 0
	_pantry_hungry.text = str(hungry) if hungry > 0 else ""
	_pantry_warn = hungry > 0 and food <= 0
	var c := PANTRY_WARN if _pantry_warn else HouseStyleScript.CREAM
	_pantry_food.add_theme_color_override(&"font_color", c)
	_pantry_hungry.add_theme_color_override(&"font_color", c)


## The pantry row as read: {visible, food, hungry, warn}.
func pantry_state() -> Dictionary:
	if _pantry == null:
		return {"visible": false, "food": "", "hungry": "", "warn": false}
	return {"visible": _pantry.visible, "food": _pantry_food.text,
		"hungry": _pantry_hungry.text if _pantry_hungry.visible else "", "warn": _pantry_warn}


func set_bits(total: int) -> void:
	_bits.text = "%d bits" % maxi(0, total)
	_bits_total = maxi(0, total)
	if _pips != null:
		_size_bag()


func get_bits_text() -> String:
	return _bits.text


## The Company's account, on screen from minute one and never hidden. Shown beside the
## wallet on purpose: the two numbers are the whole of the game's tension and reading one
## without the other is what lets a player feel rich.
func set_balance(total: int) -> void:
	_balance.text = _balance_text(total)


func get_balance_text() -> String:
	return _balance.text


## A NEGATIVE BALANCE IS CREDIT, AND SAYS SO. A minus sign in front of a debt is the one
## place a player will misread this number, and a delivered legendary really can push it
## under zero.
static func _balance_text(total: int) -> String:
	if total < 0:
		return "CWC balance: %d bits in credit" % absi(total)
	return "CWC balance: %d bits" % total


## THE HOUR AND THE SKY, IN WORDS. Set by game/world/ranch.gd from WorldState.describe()
## ("Dusk, rain") at boot and again on every phase or weather change, so it repaints on a
## change and never per frame; the same contract set_bits() above has.
##
## SAYING IT IN WORDS IS NOT REDUNDANT WITH THE SKY ITSELF. A player who has just walked
## into a barn, or who is looking at the ground, or who is playing on a screen with the
## brightness down, cannot read a phase off the light; and the weather is what decides
## how far a pony notices her from. The one line is the only place the world's own state is
## ever stated rather than implied.
##
## The text is taken verbatim, with no dash of any kind inserted: this line is read back by
## game/test/test_hud.gd and by the ranch gate, and a decorative separator here would be a
## house-style violation nothing else would catch.
func set_world_line(text: String) -> void:
	_world_line.text = text


func get_world_line() -> String:
	return _world_line.text


## WHAT THE INTERACT KEY WILL DO IF YOU PRESS IT NOW. Pushed every physics frame by
## game/world/ranch.gd's resolver and cleared the moment nothing is in range.
##
## A PERSISTENT LABEL, NOT A TOAST, and that is the whole fix. Every one of these lines
## used to go through toast(), which holds for TOAST_HOLD and fades over TOAST_FADE: a
## player standing on a plot saw "Press E / X to build here." once, three seconds later saw
## nothing, and had no way at all to find out what E was currently bound to. A prompt is
## the state of the world, so it is drawn for as long as the state holds.
##
## SET UNCONDITIONALLY RATHER THAN ONLY ON CHANGE. Assigning the same string to a Label is
## free, and the "only on change" version of this is exactly the latch bookkeeping that
## went stale in ranch.gd and caused the bug this replaces.
# --- v1 look: cards and pills in the show's UI language ---------------------------------

const CARD_FILL := Color(1.0, 0.97, 0.91, 0.94)
const CARD_LINE := Color(0.47, 0.31, 0.64)
const INK := Color(0.24, 0.17, 0.3)
const INK_SOFT := Color(0.42, 0.34, 0.48)
const GOLD_INK := Color(0.72, 0.5, 0.08)

var _chip: Label


## THE HUD'S ONE SURFACE IS THE CASINO'S PLUM (Fable AAA review round 1, #3: "the HUD is six
## text rectangles"). It was the kit's cream paper, the letters' material, and six cream boxes
## over a green field read as a word processor's windows. Every card and pill on the HUD is
## now game/ui/house_style.gd's pill: plum, a gold hairline, a soft drop, cream words, gold
## numbers. The second argument is kept for the callers' sake.
static func card_box(radius := 22, _border := 4) -> StyleBox:
	return HouseStyleScript.pill_box(radius, 0.9, Vector2(18, 10))


## Dress the HUD in the house style: a plum pill behind the bag and the lessons, plum pills for
## the toast, the prompt and the tip, cream words and gold numbers.
func _restyle() -> void:
	var bag := $Bag as VBoxContainer
	# The bag's contents sit on the box's floor, so its card hugs the screen's bottom edge.
	bag.alignment = BoxContainer.ALIGNMENT_END
	bag.add_theme_constant_override(&"separation", 4)
	# The title and the count are drawn on the slot strip now: the bag's picture at its left,
	# the count in a gold chip at its right. The labels keep their text for the gates.
	_bag_title.visible = false
	_bag_count.visible = false
	for l: Label in [_balance, _world_line]:
		HouseStyleScript.ink_label(l, 18, HouseStyleScript.CREAM_DIM, false)
	_style_bits()
	_add_card_behind(bag, Vector2(16, 12))
	# The bag is drawn standing on the field, not on a card (round 6); the card node stays,
	# empty, because the toast measures where to stand from it.
	(get_node(^"BagCard") as Panel).add_theme_stylebox_override(&"panel", StyleBoxEmpty.new())
	_add_card_behind(_tasks, Vector2(14, 10))
	_toast.add_theme_stylebox_override("normal", HouseStyleScript.pill_box(30, 0.92, Vector2(24, 10)))
	HouseStyleScript.ink_label(_toast, 28, HouseStyleScript.CREAM)
	_prompt.visible = false
	_build_prompt_card()
	_hints.add_theme_stylebox_override("panel", HouseStyleScript.pill_box(20, 0.94, Vector2(10, 8)))
	_chip = Label.new()
	_chip.name = "ControlsChip"
	_chip.add_theme_stylebox_override("normal", HouseStyleScript.pill_box(18, 0.78,
		Vector2(14, 6)))
	HouseStyleScript.ink_label(_chip, 17, HouseStyleScript.CREAM)
	_chip.anchor_left = 1.0
	_chip.anchor_right = 1.0
	_chip.anchor_top = 1.0
	_chip.anchor_bottom = 1.0
	_chip.offset_left = -190.0
	_chip.offset_right = -44.0
	_chip.offset_top = -84.0
	_chip.offset_bottom = -44.0
	_chip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_chip)
	# The key is a drawn keycap at the chip's left, not a letter in the sentence.
	_chip_key = HouseStyleScript.KeyGlyph.new()
	_chip_key.set("glyph_height", 28.0)
	_chip.add_child(_chip_key)
	# A gold disc with a question mark: help, in the one glyph every player knows.
	_chip_hint = Label.new()
	_chip_hint.name = "Hint"
	_chip_hint.text = "?"
	_chip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chip_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_chip_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	HouseStyleScript.ink_label(_chip_hint, 22, HouseStyleScript.PLUM_DARK)
	_chip_hint.add_theme_constant_override(&"outline_size", 0)
	_chip_hint.add_theme_stylebox_override(&"normal", HouseStyleScript.disc_box(CHIP_HINT_PX,
		HouseStyleScript.GOLD, HouseStyleScript.KEY_FACE, 2))
	_chip_hint.size = Vector2(CHIP_HINT_PX, CHIP_HINT_PX)
	_chip.add_child(_chip_hint)
	_refresh_chip()


## THE WALLET IS DRAWN ON THE BAG'S STRIP (_draw_wallet, Fable AAA round 6): a coin stack and
## the number. The label keeps the line's text for the gates and is not shown.
func _style_bits() -> void:
	_bits.visible = false


var _chip_key: Control
var _chip_hint: Label
const CHIP_HINT_PX := 28.0
const CHIP_WORD := "controls"


## What the corner chip stands for, as words, now that it draws none.
func controls_chip_word() -> String:
	return CHIP_WORD


func _refresh_chip() -> void:
	if _chip != null:
		# NO WORD (Fable AAA round 5: the "H controls" pill read as text scaffolding): the
		# drawn keycap and a hint picture beside it, the way a console game marks its help
		# button. The word is the chip's name for the gates (controls_chip_word()).
		var key := InputDeviceScript.hint(&"toggle_hints")
		_chip.text = ""
		if _chip_key != null:
			_chip_key.set("key", key)
			var box := _chip.get_theme_stylebox(&"normal") as StyleBoxFlat
			var kw: float = _chip_key.custom_minimum_size.x
			box.content_margin_left = 0.0
			box.content_margin_right = 0.0
			_chip_key.position = Vector2(8.0, 6.0)
			if _chip_hint != null:
				_chip_hint.position = Vector2(8.0 + kw + 6.0, 6.0)
			_chip.offset_left = _chip.offset_right - (8.0 + kw + 6.0 + CHIP_HINT_PX + 8.0)
		_chip.visible = _chip_enabled and not _hints.visible and not _overlay_open


## THE SETTINGS MENU'S GAMEPLAY TAB. The corner "H controls" chip and the Getting started
## list can each be switched off by a player who knows the game (game/ui/settings_menu.gd);
## the H key still opens the card either way.
var _chip_enabled := true


func set_controls_chip_enabled(on: bool) -> void:
	_chip_enabled = on
	_refresh_chip()


func controls_chip_visible() -> bool:
	return _chip != null and _chip.visible


func set_checklist_enabled(on: bool) -> void:
	if _tasks != null:
		_tasks.visible = on


## A rounded card drawn behind `node`, padded by `pad`, kept matched to its rect.
func _add_card_behind(node: Control, pad: Vector2) -> void:
	if node == null:
		return
	var card := Panel.new()
	card.name = node.name + "Card"
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", card_box())
	add_child(card)
	move_child(card, node.get_index())
	var fit := _fit_card.bind(card, node, pad)
	node.resized.connect(fit)
	node.visibility_changed.connect(fit)
	# A box with a fixed rect never resizes when its contents grow (the bag's strip gains a
	# row, the bits line a digit), so its card follows the contents' minimum size too.
	node.minimum_size_changed.connect(func() -> void: fit.call_deferred())
	fit.call_deferred()


func _fit_card(card: Panel, node: Control, pad: Vector2) -> void:
	if not is_instance_valid(card) or not is_instance_valid(node) or not node.is_inside_tree():
		return
	var r := node.get_global_rect()
	# The content's own height, not the box's: a three-line checklist gets a three-line card.
	var h := minf(r.size.y, node.get_combined_minimum_size().y)
	# And its own width: one chip left, a one-chip card (FS1.4).
	var w := minf(r.size.x, node.get_combined_minimum_size().x)
	card.visible = node.visible and h > 2.0 and _has_content(node)
	card.position = r.position - pad
	# A box whose contents sit on its floor gets its card on the floor too.
	var box := node as BoxContainer
	if box != null and box.alignment == BoxContainer.ALIGNMENT_END:
		card.position.y = r.end.y - h - pad.y
	card.size = Vector2(w, h) + pad * 2.0


func _has_content(node: Control) -> bool:
	for c in node.get_children():
		if c is Label and (c as Label).visible and not (c as Label).text.is_empty():
			return true
		if c is Control and not (c is Label) and (c as Control).visible:
			return true
	return false


## Shrink a pill label to its text and keep it centred where it was anchored.
func _fit_pill(l: Label) -> void:
	if l.text.is_empty():
		return
	var font := l.get_theme_font(&"font")
	var fs := l.get_theme_font_size(&"font_size")
	# NEVER WIDER THAN PILL_MAX_WIDTH (PT5; playtest 2026-11-05: "holy line of text", a toast
	# across the whole screen): a long line wraps onto a second and the pill grows down.
	if not l.has_meta(&"pill_height"):
		l.set_meta(&"pill_height", l.offset_bottom - l.offset_top)
	# Back to one line before measuring, so a short toast after a long one is short again.
	l.offset_bottom = l.offset_top + float(l.get_meta(&"pill_height"))
	# The toast's picture takes its own room at the left (P8 S5).
	var pad := 56.0 + (TOAST_ICON_PX + 14.0 if l == _toast and _toast_icon != null else 0.0)
	# And its chips their room at the right (round 5).
	if l == _toast and _chips_width() > 0.0:
		pad += _chips_width() + 10.0
	var one_line := font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + pad
	var w := minf(one_line, PILL_MAX_WIDTH)
	l.set_meta(&"pill_width", w)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if one_line > PILL_MAX_WIDTH \
		else TextServer.AUTOWRAP_OFF
	var h := font.get_multiline_string_size(l.text, HORIZONTAL_ALIGNMENT_CENTER, w - pad, fs).y \
		+ 22.0 if one_line > PILL_MAX_WIDTH else l.offset_bottom - l.offset_top
	var centre := (l.offset_left + l.offset_right) * 0.5
	l.offset_left = centre - w * 0.5
	l.offset_right = centre + w * 0.5
	if one_line > PILL_MAX_WIDTH:
		l.offset_bottom = l.offset_top + maxf(h, 60.0)


const PILL_MAX_WIDTH := 900.0


## THE ONBOARDING TIP (game/systems/onboarding.gd): one friendly line in a pill above the
## bottom of the screen, never blocking, gone when there is nothing to teach.
##
## THE KEY IS A GLYPH, NOT A WORD (Fable AAA review round 1, #3): "Hold Right Mouse on a pony"
## draws as "Hold [a mouse, its right button lit] on a pony", the way every PC game teaches.
## The tip fades in and out rather than snapping, steps aside while a toast is speaking (the
## two used to stack on each other), and is not drawn under a letter or a menu. It retires on
## its own: onboarding.gd counts the action and drops the tip after RETIRE_AFTER, in the save.
var _tip: PanelContainer
var _tip_row: HBoxContainer
var _tip_text := ""
var _tip_alpha := 0.0
const TIP_FADE := 0.35
## Where the tip's pill sits: its bottom edge this far above the screen's (1920x1080 units).
const TIP_BOTTOM := 100.0


func set_tip(text: String) -> void:
	if _tip == null:
		_tip = PanelContainer.new()
		_tip.name = "Tip"
		_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tip.add_theme_stylebox_override("panel", HouseStyleScript.pill_box(26, 0.88,
			Vector2(22, 7)))
		_tip_row = HBoxContainer.new()
		_tip_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tip_row.add_theme_constant_override(&"separation", 10)
		_tip_row.alignment = BoxContainer.ALIGNMENT_CENTER
		_tip.add_child(_tip_row)
		_tip.modulate.a = 0.0
		_tip.visible = false
		add_child(_tip)
	if _tip_text == text:
		return
	_tip_text = text
	if not text.is_empty():
		HouseStyleScript.fill_glyph_row(_tip_row, HouseStyleScript.split_on_key(text,
			_glyph_keys()), 24, HouseStyleScript.CREAM, 42.0)
		_place_bottom_card.call_deferred(_tip, TIP_BOTTOM)


func _place_bottom_card(card: Control, bottom: float) -> void:
	if not is_instance_valid(card):
		return
	var s := card.get_combined_minimum_size()
	card.size = s
	card.position = Vector2((_canvas_size().x - s.x) * 0.5, _canvas_size().y - bottom - s.y)


func _canvas_size() -> Vector2:
	return get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(1920, 1080)


## The tip fades toward shown when it has something to say, nothing is over it and no toast is
## speaking; toward hidden otherwise.
func _fade_tip(delta: float) -> void:
	if _tip == null:
		return
	var want := not _tip_text.is_empty() and not _overlay_open and _toast_left <= 0.0
	_tip_alpha = move_toward(_tip_alpha, 1.0 if want else 0.0, delta / TIP_FADE)
	_tip.modulate.a = _tip_alpha
	_tip.visible = _tip_alpha > 0.0


## The keys a tip may name, on the device in hand: the beam, interact, the treat.
func _glyph_keys() -> Array:
	var keys := []
	for a: StringName in [&"beam", &"interact", &"treat"]:
		var k := InputDeviceScript.hint(a)
		if not k.is_empty():
			keys.append(k)
	return keys


func tip_text() -> String:
	return _tip_text


## Whether the tip is on screen now (fully faded in, or on its way).
func tip_showing() -> bool:
	return _tip != null and _tip.visible and _tip.modulate.a > 0.0


## THE MONOCLE'S CARD: who is under the crosshair, and what she is like ("Daisy Dapple --
## Night Owl, loves carrots"). A small pill just under the reticle, gone when nothing is.
var _target: Label


func set_target_info(text: String) -> void:
	if _target == null:
		_target = Label.new()
		_target.name = "TargetInfo"
		_target.add_theme_stylebox_override("normal", HouseStyleScript.pill_box(18, 0.86,
			Vector2(16, 5)))
		HouseStyleScript.ink_label(_target, 20, HouseStyleScript.CREAM)
		_target.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_target.anchor_left = 0.5
		_target.anchor_right = 0.5
		_target.anchor_top = 0.5
		_target.anchor_bottom = 0.5
		_target.offset_left = -220.0
		_target.offset_right = 220.0
		_target.offset_top = 46.0
		_target.offset_bottom = 82.0
		_target.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_target.visible = false
		add_child(_target)
	if _target.text == text:
		return
	_target.text = text
	_target.visible = not text.is_empty() and not _overlay_open
	_fit_pill(_target)


func target_info() -> String:
	return _target.text if _target != null else ""


## WHAT THE INTERACT KEY WILL DO, AS A KEY AND A VERB (Fable AAA review round 1, #3: "E: talk
## to Tumble" was a typed key string). ranch.gd still hands over "E: talk to Tumble"; the card
## draws the E as a keycap and the rest as the verb, "Talk to Tumble". The Prompt label keeps
## the whole line for prompt_text() and for anything that reads it back.
var _prompt_card: PanelContainer
var _prompt_row: HBoxContainer


func _build_prompt_card() -> void:
	_prompt_card = PanelContainer.new()
	_prompt_card.name = "PromptCard"
	_prompt_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_card.add_theme_stylebox_override("panel", HouseStyleScript.pill_box(24, 0.9,
		Vector2(10, 6)))
	_prompt_row = HBoxContainer.new()
	_prompt_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_row.add_theme_constant_override(&"separation", 12)
	_prompt_card.add_child(_prompt_row)
	_prompt_card.visible = false
	add_child(_prompt_card)


func set_prompt(text: String) -> void:
	if _prompt == null:
		return
	var changed := _prompt.text != text
	_prompt.text = text
	_prompt.visible = false
	if _prompt_card == null:
		return
	_prompt_card.visible = not text.is_empty() and not _overlay_open
	if changed and not text.is_empty():
		var parts := HouseStyleScript.split_on_key(text, [InputDeviceScript.hint(&"interact")])
		HouseStyleScript.fill_glyph_row(_prompt_row, parts, 24, HouseStyleScript.CREAM, 36.0)
		_place_prompt_card.call_deferred()


func _place_prompt_card() -> void:
	if not is_instance_valid(_prompt_card):
		return
	var s := _prompt_card.get_combined_minimum_size()
	_prompt_card.size = s
	var c := _canvas_size() * 0.5
	_prompt_card.position = Vector2(c.x - s.x * 0.5, c.y + 58.0)


## The prompt as drawn: [words before the key, the key, the verb after it].
func prompt_parts() -> Array:
	return HouseStyleScript.split_on_key(prompt_text(), [InputDeviceScript.hint(&"interact")])


func clear_prompt() -> void:
	set_prompt("")


func prompt_text() -> String:
	return _prompt.text if _prompt != null else ""


## THE CONTROL CARD, IN THE GLYPHS OF ONE DEVICE. Every row here mirrors an action in
## game/project.godot's [input] block; a binding that changes there and not here is a hint
## card that lies.
##
## IT USED TO PRINT BOTH SCHEMES SIDE BY SIDE, on the stated grounds that "the build is
## handed to two people and only one of them is going to be at the keyboard". That is still
## true and it is now answered by showing the scheme in use rather than both at once
## (owner, 2026-08-31); game/systems/input_device.gd is what knows which.
##
## A GridContainer of Labels rather than one pre-aligned block of text: Godot's default UI
## font is proportional, so space-padded columns line up in the source file and nowhere
## else. Two columns now, not three.
##
## RUNNING IS THE DEFAULT AND SHIFT SLOWS YOU DOWN, which is the opposite of what every
## other game trains a player to expect, so the card says what the slow gait BUYS on its
## own continuation line.
const HINTS := [
	["MOVE (run)", "W A S D", "Left stick"],
	["SPRINT", "Shift (hold)", "Left stick click (hold)"],
	["WALK / SNEAK", "C (hold)", "LB (hold)"],
	["", "walk up behind a pony and she will not notice you", ""],
	["JUMP", "Space", "A"],
	["INTERACT", "E", "X"],
	["", "the line under the crosshair says what it will do", ""],
	["LOOK", "Mouse", "Right stick"],
	["ZOOM", "Scroll / = -", "D-pad up down"],
	["MAGIC BEAM", "Right mouse (hold)", "Right trigger (hold)"],
	["", "hold on her until the ring fills and she is yours", ""],
	["TREAT", "F", "Y"],
	["", "drop her favourite food: she comes to eat, and eating she is easy", ""],
	["SELL GEMS", "E at the Market", "X at the Market"],
	["PAUSE", "Esc", "Start"],
	["THIS CARD", "H", "Back"],
]


func _build_hints() -> void:
	_hints_grid.columns = 2
	_hints_grid.add_theme_constant_override(&"h_separation", 16)
	_hints_grid.add_theme_constant_override(&"v_separation", 6)
	for child in _hints_grid.get_children():
		child.queue_free()
	var column: int = 2 if InputDeviceScript.using_gamepad() else 1
	for row: Array in HINTS:
		var label_text := String(row[0])
		var note: bool = label_text == ""
		# The action in small gold caps; its key on a cream keycap (house style), or a note
		# in soft cream under the row it explains.
		var name_label := Label.new()
		name_label.text = label_text
		HouseStyleScript.ink_label(name_label, 16, HouseStyleScript.GOLD)
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_hints_grid.add_child(name_label)
		var value := Label.new()
		value.text = String(row[column if not note else 1])
		if note:
			HouseStyleScript.ink_label(value, 16, HouseStyleScript.CREAM_DIM, false)
		else:
			HouseStyleScript.ink_label(value, 18, HouseStyleScript.INK)
			var cap := StyleBoxFlat.new()
			cap.bg_color = HouseStyleScript.KEY_FACE
			cap.border_color = HouseStyleScript.KEY_LIP
			cap.border_width_bottom = 4
			cap.border_width_left = 1
			cap.border_width_right = 1
			cap.border_width_top = 1
			cap.set_corner_radius_all(7)
			cap.content_margin_left = 10
			cap.content_margin_right = 10
			cap.content_margin_top = 1
			cap.content_margin_bottom = 2
			value.add_theme_stylebox_override(&"normal", cap)
			value.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		_hints_grid.add_child(value)
	_hints_device = InputDeviceScript.last()
