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
const ShopIconScript := preload("res://ui/shop_icon.gd")

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

## WHAT A TOAST GETS WHEN SOMEBODY IS WAITING BEHIND IT. The owner, on the first full
## playtest: "text on top lags behind". Three quick actions queued three full holds, so the
## line about the third one arrived nine seconds after the thing it described and read as a
## bug in the game rather than in the overlay. A queue with anything in it now runs the
## current line short instead, so the text keeps pace with the play.
const TOAST_HOLD_BUSY := 0.6

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
## Toasts raised while another one is on screen, oldest first. See toast().
var _toast_queue: Array[String] = []
## Whether a letter or a menu is on screen right now, and whether the player had asked for
## the control card before one appeared. See set_overlay_open().
var _overlay_open := false
var _hints_wanted := false
var _task_lines: Array[String] = []
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
	_catch_card = CatchCardScript.new()
	add_child(_catch_card)

	_bind()


func _process(delta: float) -> void:
	if _hints_device != InputDeviceScript.last():
		_build_hints()

	_elapsed += delta

	# See the class comment: sibling ready order is not something to depend on.
	if _storage == null:
		_bind()

	if _toast_left > 0.0:
		# A LINE WITH SOMEBODY BEHIND IT RUNS SHORT. Applied here rather than in toast(),
		# because the queue can grow after the current line has already started, and the
		# player who just did three things quickly is the player this is for.
		if not _toast_queue.is_empty():
			_toast_left = minf(_toast_left, TOAST_HOLD_BUSY + TOAST_FADE)
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
	_toast.text = text
	_toast_left = TOAST_HOLD + TOAST_FADE
	_toast.modulate.a = 1.0
	_fit_pill(_toast)
	# A little pop on arrival, the way a show title card bounces in.
	_toast.pivot_offset = _toast.size * 0.5
	_toast.scale = Vector2(0.86, 0.86)
	create_tween().tween_property(_toast, "scale", Vector2.ONE, 0.22).set_trans(
		Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## The line that is ON SCREEN now, whether or not it has faded, which since the queue above
## is the OLDEST toast still unspoken rather than the newest one raised. Exposed for the
## same reason get_bits_text() is: what the player is told is a real requirement (the
## market gate reads the sale line back), and a gate has no other way to see it.
func toast_text() -> String:
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
	var title := Label.new()
	title.text = TASK_TITLE
	MenuStyleScript.style_label(title, 24, COLOR_WORLD_LINE)
	title.add_theme_constant_override("outline_size", 0)
	title.add_theme_color_override("font_color", INK)
	title.add_theme_font_override("font", MenuStyleScript.title_font())
	_tasks.add_child(title)
	# A CHECKLIST, NOT A BULLETED PARAGRAPH (overnight bot review, 2026-10-26): a drawn tick
	# box that fills green when the job is done, the job, and its reward as a coin and a
	# number. task_lines() still reads as it always has.
	for entry in rows:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = entry
		_tasks.add_child(_task_row(String(row.get("text", "")), bool(row.get("done", false)),
			int(row.get("reward_bits", 0))))
	var card := get_node_or_null("TasksCard") as Panel
	if card != null:
		_fit_card.call_deferred(card, _tasks, Vector2(18, 12))


const TASK_TICK := Color(0.36, 0.68, 0.36)


func _task_row(text: String, done: bool, reward: int) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override(&"separation", 10)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := Control.new()
	box.custom_minimum_size = Vector2(22, 22)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.draw.connect(func() -> void:
		var r := Rect2(Vector2(1, 1), box.size - Vector2(2, 2))
		if done:
			box.draw_rect(r, TASK_TICK, true)
			box.draw_polyline(PackedVector2Array([Vector2(5, 11), Vector2(9.5, 16),
				Vector2(17, 6)]), Color(1, 1, 1), 3.0, true)
		else:
			box.draw_rect(r, Color(1, 1, 1, 0.6), true)
			box.draw_rect(r, INK_SOFT, false, 2.0))
	line.add_child(box)
	var label := Label.new()
	label.text = text
	MenuStyleScript.style_label(label, 20, COLOR_TASK_DONE if done else COLOR_TASK_OPEN)
	label.add_theme_constant_override("outline_size", 0)
	label.add_theme_color_override("font_color", TASK_TICK.darkened(0.2) if done else INK_SOFT)
	line.add_child(label)
	if reward > 0:
		var coin: Control = ShopIconScript.new()
		coin.kind = &"sell_all"
		coin.custom_minimum_size = Vector2(20, 20)
		coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		coin.modulate = Color(1, 1, 1, 0.5) if done else Color(1, 1, 1)
		line.add_child(coin)
		var bits := Label.new()
		bits.text = "%d" % reward
		MenuStyleScript.style_label(bits, 20, COLOR_TASK_OPEN)
		bits.add_theme_constant_override("outline_size", 0)
		bits.add_theme_color_override("font_color", Color(0.62, 0.45, 0.1, 0.5 if done else 1.0))
		bits.add_theme_font_override("font", MenuStyleScript.numeral_font())
		line.add_child(bits)
	return line


## Every line the checklist is drawing, in order, title first. For the tests, which
## otherwise have no way to read it without walking Label nodes.
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
	_pips.queue_redraw()


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
		# Outer first, inner second: the inner ring is the smaller of the two and drawing
		# it last keeps it on top where the two outlines meet.
		_draw_catch_ring(centre)
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
	for i in range(_capacity):
		var at := Vector2(float(i) * (PIP_SIZE.x + PIP_GAP), 0.0)
		var rect := Rect2(at, PIP_SIZE)
		var fill := PIP_EMPTY
		if i < _rarities.size():
			fill = RARITY_COLORS.get(_rarities[i], RARITY_COLORS[PonyDataScript.Rarity.COMMON])
		# Rounded tiles in the card's own ink (v1): a filled slot is her rarity colour.
		var sb := StyleBoxFlat.new()
		sb.bg_color = fill if i < _rarities.size() else Color(0.92, 0.88, 0.96)
		sb.border_color = CARD_LINE
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(5)
		_pips.draw_style_box(sb, rect)


## One ring, drawn twice: an outline pass and then the colour, so the reticle stays
## visible over a bright sky as well as over grass.
func _ring(centre: Vector2, radius: float, color: Color, width: float) -> void:
	_crosshair.draw_arc(centre, radius, 0.0, TAU, 48, COLOR_OUTLINE, width + 2.0, true)
	_crosshair.draw_arc(centre, radius, 0.0, TAU, 48, color, width, true)


# --- text ------------------------------------------------------------------------

## The wallet line under the saddlebag. Driven by ranch.gd off Economy.bits_changed, so
## it repaints on a change and never per frame.
func set_bits(total: int) -> void:
	_bits.text = "%d bits" % maxi(0, total)


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


static func card_box(radius := 22, border := 4) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = CARD_FILL
	sb.border_color = CARD_LINE
	sb.set_border_width_all(border)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	sb.shadow_color = Color(0.15, 0.05, 0.2, 0.22)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 3)
	return sb


## Dress the plain labels as the show's UI: cards behind the bag and the tasks, pills for
## the toast and the prompt, dark ink instead of white text with an outline.
func _restyle() -> void:
	for l: Label in [_bag_title, _bag_count, _balance, _world_line]:
		l.add_theme_color_override("font_color", INK_SOFT if l != _bag_count else INK)
		l.add_theme_constant_override("outline_size", 0)
	_bits.add_theme_color_override("font_color", GOLD_INK)
	_bits.add_theme_constant_override("outline_size", 0)
	_bits.add_theme_font_size_override("font_size", 30)
	_bits.add_theme_font_override("font", MenuStyleScript.numeral_font())
	_bag_title.add_theme_font_override("font", MenuStyleScript.title_font())
	_add_card_behind($Bag as Control, Vector2(18, 14))
	_add_card_behind(_tasks, Vector2(18, 12))
	for pill: Label in [_toast, _prompt]:
		pill.add_theme_stylebox_override("normal", card_box(26, 4))
		pill.add_theme_color_override("font_color", INK)
		pill.add_theme_constant_override("outline_size", 0)
		pill.add_theme_font_override("font", MenuStyleScript.title_font())
	_toast.add_theme_font_size_override("font_size", 30)
	_prompt.add_theme_font_size_override("font_size", 24)
	_hints.add_theme_stylebox_override("panel", card_box(22, 4))
	for c in _hints_grid.get_children():
		if c is Label:
			(c as Label).add_theme_color_override("font_color", INK)
			(c as Label).add_theme_constant_override("outline_size", 0)
	_prompt.visible = false
	_chip = Label.new()
	_chip.name = "ControlsChip"
	_chip.add_theme_stylebox_override("normal", card_box(16, 3))
	_chip.add_theme_color_override("font_color", INK)
	_chip.add_theme_font_size_override("font_size", 18)
	_chip.anchor_left = 1.0
	_chip.anchor_right = 1.0
	_chip.anchor_top = 1.0
	_chip.anchor_bottom = 1.0
	_chip.offset_left = -190.0
	_chip.offset_right = -44.0
	_chip.offset_top = -86.0
	_chip.offset_bottom = -44.0
	_chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_chip)
	_refresh_chip()


func _refresh_chip() -> void:
	if _chip != null:
		_chip.text = "%s  controls" % InputDeviceScript.hint(&"toggle_hints")
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
	fit.call_deferred()


func _fit_card(card: Panel, node: Control, pad: Vector2) -> void:
	if not is_instance_valid(card) or not is_instance_valid(node) or not node.is_inside_tree():
		return
	var r := node.get_global_rect()
	# The content's own height, not the box's: a three-line checklist gets a three-line card.
	var h := minf(r.size.y, node.get_combined_minimum_size().y)
	card.visible = node.visible and h > 2.0 and _has_content(node)
	card.position = r.position - pad
	card.size = Vector2(r.size.x, h) + pad * 2.0


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
	var w := font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 56.0
	var centre := (l.offset_left + l.offset_right) * 0.5
	l.offset_left = centre - w * 0.5
	l.offset_right = centre + w * 0.5


## The onboarding tip (game/systems/onboarding.gd): one friendly line in a pill above the
## bottom of the screen, never blocking, gone when there is nothing to teach.
var _tip: Label


func set_tip(text: String) -> void:
	if _tip == null:
		_tip = Label.new()
		_tip.name = "Tip"
		_tip.add_theme_stylebox_override("normal", card_box(24, 4))
		_tip.add_theme_color_override("font_color", INK)
		_tip.add_theme_font_size_override("font_size", 24)
		_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_tip.anchor_left = 0.5
		_tip.anchor_right = 0.5
		_tip.anchor_top = 1.0
		_tip.anchor_bottom = 1.0
		_tip.offset_left = -300.0
		_tip.offset_right = 300.0
		_tip.offset_top = -150.0
		_tip.offset_bottom = -100.0
		# Hidden until there is something to say: the first call is often "", and the
		# early return below would otherwise leave an empty pill on screen.
		_tip.visible = false
		add_child(_tip)
	if _tip.text == text:
		return
	_tip.text = text
	_tip.visible = not text.is_empty() and not _overlay_open
	_fit_pill(_tip)


func tip_text() -> String:
	return _tip.text if _tip != null else ""


## THE MONOCLE'S CARD: who is under the crosshair, and what she is like ("Daisy Dapple --
## Night Owl, loves carrots"). A small pill just under the reticle, gone when nothing is.
var _target: Label


func set_target_info(text: String) -> void:
	if _target == null:
		_target = Label.new()
		_target.name = "TargetInfo"
		_target.add_theme_stylebox_override("normal", card_box(18, 3))
		_target.add_theme_color_override("font_color", INK)
		_target.add_theme_font_size_override("font_size", 20)
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


func set_prompt(text: String) -> void:
	if _prompt != null:
		_prompt.text = text
		_prompt.visible = not text.is_empty()
		_fit_pill(_prompt)


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
	["", "creep quietly, and ponies notice you from half as far", ""],
	["JUMP", "Space", "A"],
	["INTERACT", "E", "X"],
	["", "the line under the crosshair says what it will do", ""],
	["LOOK", "Mouse", "Right stick"],
	["ZOOM", "Scroll / = -", "D-pad up down"],
	["MAGIC BEAM", "Right mouse (hold)", "Right trigger (hold)"],
	["", "hold until the OUTER PINK ring fills, then let go to stow her", ""],
	["", "the INNER AMBER ring is her fight. Let it empty and she wriggles free", ""],
	["SELL GEMS", "E at the Market", "X at the Market"],
	["PAUSE", "Esc", "Start"],
	["THIS CARD", "H", "Back"],
]


func _build_hints() -> void:
	_hints_grid.columns = 2
	for child in _hints_grid.get_children():
		child.queue_free()
	var column: int = 2 if InputDeviceScript.using_gamepad() else 1
	for row: Array in HINTS:
		var label_text := String(row[0])
		var note: bool = label_text == ""
		for pair: Array in [[label_text, 0.60], [String(row[column if not note else 1]), 0.92]]:
			var label := Label.new()
			label.text = String(pair[0])
			MenuStyleScript.style_label(label, 20, Color(1.0, 1.0, 1.0, float(pair[1])))
			_hints_grid.add_child(label)
	_hints_device = InputDeviceScript.last()
