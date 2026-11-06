class_name SlotsMenu
extends "res://ui/casino_table.gd"
## THE SLOT MACHINE. A cabinet with a lit marquee, three reel windows, a lever, a Spin button,
## the three stake chips and a paytable that fits, and it spins nothing: ranch.gd rolls the
## seeded generator, settles the chips and pushes the three symbols back through show_spin().
##
## WHAT THE OWNER'S PLAYTEST (2026-11-05) SAW, AND WHERE EACH WENT:
##   - "text spoils the roll": a log under the reels ("Gem Apple Bell", "Nothing this time.",
##     rows of "= = ="). Gone: the reels tell the result, a win flashes the payline and pops a
##     banner, and the chip counter holds its old figure until the last reel stops.
##   - "its clipping": symbols poked out of the reel windows and the rainbow crossed the
##     SPECTRA SLOTS sign. Each window is now its own Control with clip_contents on, so a
##     symbol physically cannot be drawn outside it.
##   - "all 3 the same": one sorted strip showed three apples in a window. Each reel has its
##     own real strip now (Slots.REEL_STRIPS), and the window shows the true neighbours of the
##     landed position, three different symbols every time.
##   - "it wont let me change bet size": the drawn 50 and 200 chips were never click targets;
##     an invisible row column under the stage was. The chips are the buttons now.
##   - a paytable line cut off: the table is icons and a number per row, fitted to its column.
##
## THE LEVER IS REAL. Press it and drag it down past half way (or just click it) and the
## machine spins; let go early and it springs back. Spin, Enter and a click do the same thing.
##
## NOTHING HERE ROLLS. Which of a symbol's places on a strip a reel stops at walks with the
## spin count; the symbol itself is ranch.gd's roll.

const SlotsScript := preload("res://systems/slots.gd")

const TITLE := "Slots"

# --- the cabinet, in stage local pixels ------------------------------------------------------
const STAGE_HEIGHT := 580.0
const MARQUEE := Rect2(20.0, 0.0, 700.0, 86.0)
const HOUSING := Rect2(20.0, 100.0, 700.0, 340.0)
const REEL_TOP := 120.0
const REEL_LEFT := 50.0
const REEL_PITCH := 220.0
const REEL_SIZE_PX := Vector2(200.0, 300.0)
const CELL_HEIGHT := 100.0
const LEVER_PIVOT := Vector2(758.0, 300.0)
const LEVER_LENGTH := 210.0
const LEVER_HIT := Rect2(728.0, 60.0, 60.0, 270.0)
const CHIP_ROW_Y := 512.0
const CHIP_RADIUS := 36.0
const CHIP_PITCH := 98.0
const COUNTER := Rect2(330.0, 484.0, 180.0, 56.0)
const SPIN := Rect2(530.0, 466.0, 250.0, 92.0)
const PAYTABLE := Rect2(808.0, 0.0, 312.0, 580.0)
const BANNER := Rect2(170.0, 360.0, 400.0, 70.0)
const BULBS := 14
const BULB_CHASE_SECONDS := 1.2

## How far down the pointer must drag the knob, in stage pixels, for a full pull.
const LEVER_DRAG_PX := 150.0

# --- the spin, and every one of these is a CONSTANT ------------------------------------------
const LEVER_DROP_SECONDS := 0.12
const LEVER_RISE_SECONDS := 0.35
const LAND_FIRST := 0.75
const LAND_STAGGER := 0.40
const LAND_SECONDS := 0.45
const WIN_FLASH_SECONDS := 1.6
const SPIN_TURNS := 3
const REEL_LANDED_SPEED := 1.2

signal spin_requested(stake: int)

## Each reel's position: the strip index sitting on the payline, as a float while it rolls.
var _reel_pos: Array[float] = [0.0, 0.0, 0.0]
var _lever := 0.0
var _flash := 0.0
var _spinning := false
var _won := 0
var _held_chips := -1
var _spins := 0
var _stake := 0
var _dragging := false
var _drag_from := 0.0
var _drag_moved := 0.0
var _tween: Tween = null
var _reels: Array[Control] = []
var _overlay: Control = null

var _reel_step: Array[int] = [-1, -1, -1]
var _reel_prev: Array[float] = [0.0, 0.0, 0.0]
var _reel_landed: Array[bool] = [true, true, true]


func _ready() -> void:
	super._ready()
	if _stage == null:
		return
	# THE WINDOWS CLIP. One Control per reel with clip_contents on, drawn after the stage, so a
	# symbol rolling past the top or bottom edge is cut off by the engine, not by arithmetic.
	for reel: int in SlotsScript.REELS:
		var window := Control.new()
		window.name = "Reel%d" % reel
		window.clip_contents = true
		window.mouse_filter = Control.MOUSE_FILTER_IGNORE
		window.position = reel_rect(reel).position
		window.size = reel_rect(reel).size
		window.draw.connect(_paint_reel.bind(reel, window))
		_stage.add_child(window)
		_reels.append(window)
	_overlay = Control.new()
	_overlay.name = "Overlay"
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.size = stage_size()
	_overlay.draw.connect(_paint_overlay)
	_stage.add_child(_overlay)
	# Every reel opens on a different place on its strip, so the first look is three columns
	# of different symbols rather than three copies of one.
	_reel_pos = [3.0, 7.0, 11.0]


func title_text() -> String:
	return TITLE


func stage_size() -> Vector2:
	return Vector2(STAGE_WIDTH, STAGE_HEIGHT)


func initial_focus() -> StringName:
	return &"spin"


func animating() -> bool:
	return _spinning


func open() -> bool:
	if not super.open():
		return false
	_held_chips = -1
	_fit_stake()
	return true


func _purse() -> int:
	return int(chips_provider.call()) if chips_provider.is_valid() else 0


# --- the stake ---------------------------------------------------------------------------------

## The stakes she can cover, in order. Kept for the callers that ask (the trailer, the gate).
func stakes() -> Array[int]:
	var out: Array[int] = []
	for stake: int in STAKES:
		if stake <= _purse():
			out.append(stake)
	return out


func stake_index() -> int:
	return _stake


## The chip that is up, or 0 when she cannot cover even the smallest.
func selected_stake() -> int:
	if STAKES[_stake] <= _purse():
		return STAKES[_stake]
	return 0


func set_stake_index(index: int) -> void:
	if index < 0 or index >= STAKES.size() or STAKES[index] > _purse():
		MenuStyleScript.tick_denied()
		return
	_stake = index
	if _stage != null:
		_stage.queue_redraw()


## A chip she can no longer cover drops to the biggest one she can.
func _fit_stake() -> void:
	while _stake > 0 and STAKES[_stake] > _purse():
		_stake -= 1


func can_spin() -> bool:
	return not _spinning and selected_stake() > 0


## PULL. The one place a spin is asked for, whether by the lever, the button or a key.
func pull() -> bool:
	if not can_spin():
		MenuStyleScript.tick_denied()
		return false
	MenuStyleScript.tick_confirm()
	_sound_call(&"play", [&"chip_clink"])
	spin_requested.emit(selected_stake())
	return true


# --- the controls -------------------------------------------------------------------------------

func reel_rect(index: int) -> Rect2:
	return Rect2(Vector2(REEL_LEFT + REEL_PITCH * float(index), REEL_TOP), REEL_SIZE_PX)


func payline_y() -> float:
	return REEL_TOP + REEL_SIZE_PX.y * 0.5


func stake_chip_rect(index: int) -> Rect2:
	var centre := Vector2(REEL_LEFT + CHIP_RADIUS + CHIP_PITCH * float(index), CHIP_ROW_Y)
	return Rect2(centre - Vector2(CHIP_RADIUS, CHIP_RADIUS) * 1.15,
		Vector2(CHIP_RADIUS, CHIP_RADIUS) * 2.3)


func lever_rect() -> Rect2:
	return LEVER_HIT


func spin_rect() -> Rect2:
	return SPIN


func paytable_rect() -> Rect2:
	return PAYTABLE


func marquee_rect() -> Rect2:
	return MARQUEE


func stage_buttons() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: int in STAKES.size():
		out.append({"id": StringName("stake:%d" % i), "rect": stake_chip_rect(i),
			"enabled": not _spinning and STAKES[i] <= _purse()})
	out.append({"id": &"spin", "rect": SPIN, "enabled": can_spin()})
	out.append({"id": &"lever", "rect": LEVER_HIT, "enabled": can_spin()})
	return out


func activate(id: StringName) -> bool:
	var name: String = String(id)
	if name.begins_with("stake:"):
		var index: int = int(name.substr(6))
		if STAKES[index] > _purse() or _spinning:
			return false
		_stake = index
		MenuStyleScript.tick_confirm()
		if _stage != null:
			_stage.queue_redraw()
		return true
	if id == &"spin" or id == &"lever":
		return pull()
	return false


## THE LEVER'S DRAG. A press on the knob's column takes the pointer; dragging pulls the arm;
## letting go past half way (or after barely moving, which is a click) spins, and anything
## else springs it back.
func stage_pointer(event: InputEvent) -> bool:
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed and LEVER_HIT.has_point(button.position) and can_spin():
			_dragging = true
			_drag_from = button.position.y
			_drag_moved = 0.0
			focus_on(&"lever")
			return true
		if not button.pressed and _dragging:
			_dragging = false
			if _lever >= 0.5 or _drag_moved < 6.0:
				if not pull():
					_spring_lever()
			else:
				_spring_lever()
			return true
	var motion := event as InputEventMouseMotion
	if motion != null and _dragging:
		_drag_moved = maxf(_drag_moved, absf(motion.position.y - _drag_from))
		_lever = clampf((motion.position.y - _drag_from) / LEVER_DRAG_PX, 0.0, 1.0)
		return true
	return false


func _spring_lever() -> void:
	var spring: Tween = create_tween()
	spring.tween_property(self, "_lever", 0.0, LEVER_RISE_SECONDS) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# --- the spin ---------------------------------------------------------------------------------

func reel_position(index: int) -> float:
	return _reel_pos[clampi(index, 0, SlotsScript.REELS - 1)]


## The three symbols a window shows, top to bottom, read off the live reel position: what the
## drawing draws, for the tests to ask.
func window_symbols(reel: int) -> Array[int]:
	var strip: Array[int] = SlotsScript.reel_strip(reel)
	var at: int = roundi(_reel_pos[reel])
	return [strip[posmod(at + 1, strip.size())], strip[posmod(at, strip.size())],
		strip[posmod(at - 1, strip.size())]]


## The symbol on the payline of every reel, left to right.
func payline_symbols() -> Array[int]:
	var out: Array[int] = []
	for reel: int in SlotsScript.REELS:
		out.append(window_symbols(reel)[1])
	return out


func shown_chips() -> int:
	return _held_chips if _held_chips >= 0 else _purse()


## TOLD, NEVER ASKED. ranch.gd's play_slots() has already taken the stake, rolled
## Slots.spin() and settled the win by the time this is called; `reels` is that roll. A symbol
## that is not on the machine is a still frame: this arrives over a dynamic call().
func show_spin(reels: Array[int], won: int, _stake_played: int) -> void:
	if reels.size() != SlotsScript.REELS:
		return
	for symbol: int in reels:
		if symbol < 0 or symbol >= SlotsScript.SYMBOL_NAMES.size():
			return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_spinning = true
	_spins += 1
	_won = maxi(0, won)
	_held_chips = maxi(0, _purse() - _won)
	_flash = 0.0
	for reel: int in SlotsScript.REELS:
		_reel_prev[reel] = _reel_pos[reel]
		_reel_landed[reel] = true
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "_lever", 1.0, LEVER_DROP_SECONDS)
	_tween.tween_property(self, "_lever", 0.0, LEVER_RISE_SECONDS) \
		.set_delay(LEVER_DROP_SECONDS)
	var size: float = float(SlotsScript.REEL_SIZE)
	for reel: int in SlotsScript.REELS:
		var target: float = float(_stop_for(reel, reels[reel]))
		var landing: float = LAND_FIRST + LAND_STAGGER * float(reel)
		var run_to: float = _reel_pos[reel] + float(SPIN_TURNS) * size
		var settle: float = run_to + size - fposmod(run_to - target, size)
		var set_pos: Callable = (func(v: float) -> void: _reel_pos[reel] = v)
		# tween_method and not a property path: an Array element has no property name a
		# tweener can bind to (the old cabinet's own finding).
		_tween.tween_method(set_pos, _reel_pos[reel], run_to, landing) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		_tween.tween_method(set_pos, run_to, settle, LAND_SECONDS) \
			.set_delay(landing).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.set_parallel(false)
	_tween.tween_callback(func() -> void:
		_held_chips = -1
		if _won > 0:
			_sound_call(&"play", [&"slots_win"]))
	if _won > 0:
		_tween.tween_property(self, "_flash", 1.0, 0.12)
		_tween.tween_property(self, "_flash", 0.0, WIN_FLASH_SECONDS)
	_tween.tween_callback(func() -> void:
		for reel: int in SlotsScript.REELS:
			_reel_pos[reel] = fposmod(_reel_pos[reel], size)
		_spinning = false
		_fit_stake()
		refresh())
	# A PUSH INTO A CLOSED TABLE LANDS AT ONCE: nobody is watching, and a felt left mid
	# animation would refuse the next bet when it is opened.
	if not is_open():
		finish_animation()


## WHICH OF THE SYMBOL'S PLACES ON THIS REEL'S STRIP the reel stops at. Every place carrying the
## symbol shows the same payline; which one walks with the spin count and the reel, so the
## neighbours above and below vary the way a real machine's do.
func _stop_for(reel: int, symbol: int) -> int:
	var strip: Array[int] = SlotsScript.reel_strip(reel)
	var places: Array[int] = []
	for i: int in strip.size():
		if strip[i] == symbol:
			places.append(i)
	if places.is_empty():
		return 0
	return places[(_spins + reel * 2) % places.size()]


## A ranch push of the old result lines lands here and is not printed: the reels tell it.
func show_result(lines: Array[String]) -> void:
	_result = lines.duplicate()


func _process(delta: float) -> void:
	super(delta)
	for window: Control in _reels:
		window.queue_redraw()
	if _overlay != null:
		_overlay.queue_redraw()
	_sound_reels(delta)


## ONE TICK PER SYMBOL WHILE A REEL RUNS, ONE CLUNK WHEN IT STOPS, read off the positions the
## paint already reads.
func _sound_reels(delta: float) -> void:
	if not is_open() or delta <= 0.0:
		return
	for reel: int in SlotsScript.REELS:
		var pos: float = _reel_pos[reel]
		var speed: float = absf(pos - _reel_prev[reel]) / delta
		_reel_prev[reel] = pos
		if speed > REEL_LANDED_SPEED:
			_reel_landed[reel] = false
			var step: int = int(floor(pos))
			if step != _reel_step[reel]:
				_reel_step[reel] = step
				_sound_call(&"play", [&"reel_tick"])
		elif not _reel_landed[reel]:
			_reel_landed[reel] = true
			_sound_call(&"play", [&"reel_stop"])


## The text model, for the dash test and test_published_payouts' neighbours.
func drawn_lines() -> Array[String]:
	var lines: Array[String] = ["SPECTRA SLOTS", "Spin"]
	for line in SlotsScript.paytable_lines():
		lines.append(line)
	return lines


# --- the paint ----------------------------------------------------------------------------------

func paint(ci: Control) -> void:
	var t: float = anim_time()
	var title_font: Font = MenuStyleScript.title_font()
	var numeral_font: Font = MenuStyleScript.numeral_font()

	# --- the cabinet body ----------------------------------------------------------------------
	PaintScript.rounded(ci, Rect2(0.0, 0.0, 790.0, STAGE_HEIGHT), 20.0,
		Color(PaintScript.PLUM_DARK, 0.85), Color(PaintScript.GOLD_DIM, 0.6), 2.0)

	# --- the marquee ---------------------------------------------------------------------------
	PaintScript.rounded(ci, MARQUEE, 18.0, PaintScript.PLUM, PaintScript.GOLD, 4.0)
	var sign := MARQUEE.grow_individual(-40.0, -14.0, -40.0, -14.0)
	var glow: float = 0.5 + 0.5 * sin(t * 2.0)
	if _flash > 0.0:
		glow = 0.5 + 0.5 * sin(t * 16.0)
	PaintScript.label(ci, title_font, Rect2(sign.position + Vector2(0.0, 3.0), sign.size),
		"SPECTRA SLOTS", 46, Color(0.0, 0.0, 0.0, 0.35))
	PaintScript.label(ci, title_font, sign, "SPECTRA SLOTS", 46,
		PaintScript.GOLD.lerp(Color(1.0, 0.98, 0.85), 0.35 * glow))
	for bulb: int in BULBS:
		var phase: float = fposmod(t / BULB_CHASE_SECONDS - float(bulb) / float(BULBS), 1.0)
		var lit: float = 0.35 + 0.65 * maxf(0.0, 1.0 - phase * 4.0)
		if _flash > 0.0:
			lit = 0.5 + 0.5 * sin(t * 18.0 + float(bulb))
		var x: float = MARQUEE.position.x + 22.0 + (MARQUEE.size.x - 44.0) * float(bulb) \
			/ float(BULBS - 1)
		ci.draw_circle(Vector2(x, MARQUEE.position.y + 10.0), 4.5, Color(1.0, 0.95, 0.7, lit))
		ci.draw_circle(Vector2(x, MARQUEE.end.y - 10.0), 4.5, Color(1.0, 0.95, 0.7, lit))

	# --- the reel housing (the windows draw themselves, clipped, on top of this) --------------
	PaintScript.rounded(ci, HOUSING, 18.0, Color(0.10, 0.06, 0.13), PaintScript.GOLD, 3.0)
	for reel: int in SlotsScript.REELS:
		PaintScript.rounded(ci, reel_rect(reel).grow(6.0), 12.0, PaintScript.GOLD_DIM,
			PaintScript.GOLD, 2.0)

	# --- the lever -----------------------------------------------------------------------------
	PaintScript.rounded(ci, Rect2(LEVER_PIVOT - Vector2(22.0, 34.0), Vector2(44.0, 68.0)), 10.0,
		PaintScript.GOLD_DIM, PaintScript.GOLD, 2.0)
	# At rest the arm stands up and leans out; pulled, it swings down past the pivot.
	var swing: float = lerpf(-PI * 0.5 - 0.10, PI * 0.5 - 0.35, _lever)
	# The arm swings toward the player, so it is seen foreshortened: mostly up and down, with
	# only a small lean outward, which keeps the knob off the paytable at every point of a pull.
	var knob: Vector2 = LEVER_PIVOT + Vector2(cos(swing) * 0.12, sin(swing)) * LEVER_LENGTH
	ci.draw_line(LEVER_PIVOT, knob, PaintScript.GOLD_DIM.darkened(0.2), 12.0, true)
	ci.draw_line(LEVER_PIVOT, knob, PaintScript.GOLD, 6.0, true)
	ci.draw_circle(LEVER_PIVOT, 12.0, PaintScript.GOLD)
	var lever_lit: bool = is_lit(&"lever") and can_spin()
	ci.draw_circle(knob + Vector2(0.0, 3.0), 23.0, Color(0.0, 0.0, 0.0, 0.3))
	var knob_colour: Color = Color(0.88, 0.20, 0.24) if can_spin() or _spinning \
		else Color(0.45, 0.40, 0.46)
	ci.draw_circle(knob, 22.0, knob_colour.lightened(0.15 if lever_lit else 0.0))
	ci.draw_circle(knob + Vector2(-7.0, -7.0), 7.0, Color(1.0, 1.0, 1.0, 0.45))

	# --- the stake chips ------------------------------------------------------------------------
	for i: int in STAKES.size():
		var box: Rect2 = stake_chip_rect(i)
		var usable: bool = STAKES[i] <= _purse()
		var chosen: bool = i == _stake and usable
		var centre: Vector2 = box.get_center() - Vector2(0.0, 8.0 if chosen else 0.0)
		var colour: Color = PaintScript.CHIP_COLORS[i] if usable else Color(0.30, 0.28, 0.32)
		if chosen:
			ci.draw_arc(centre, CHIP_RADIUS + 7.0, 0.0, TAU, 48,
				Color(PaintScript.GOLD, 0.75 + 0.25 * sin(t * 4.0)), 4.0, true)
		PaintScript.chip(ci, centre, CHIP_RADIUS, colour, true)
		PaintScript.label(ci, numeral_font, Rect2(centre - Vector2(CHIP_RADIUS * 0.66, 14.0),
			Vector2(CHIP_RADIUS * 1.32, 28.0)), str(STAKES[i]), 22,
			Color.WHITE if i == 2 or not usable else PaintScript.CARD_INK)

	# --- the chip counter, holding until the last reel stops -------------------------------------
	PaintScript.rounded(ci, COUNTER, 28.0, Color(0.0, 0.0, 0.0, 0.40),
		Color(PaintScript.GOLD, 0.5), 2.0)
	PaintScript.draw_chip_icon(ci, Rect2(COUNTER.position + Vector2(12.0, 13.0),
		Vector2(30.0, 30.0)))
	PaintScript.label(ci, numeral_font, Rect2(COUNTER.position + Vector2(50.0, 4.0),
		COUNTER.size - Vector2(60.0, 8.0)), "%d" % shown_chips(), 30, PaintScript.GOLD,
		HORIZONTAL_ALIGNMENT_LEFT)

	# --- spin ------------------------------------------------------------------------------------
	PaintScript.button(ci, SPIN, "Spin %d" % selected_stake() if selected_stake() > 0
		else "No chips", Color(0.95, 0.62, 0.18), can_spin(), is_lit(&"spin"))

	_paint_paytable(ci, title_font, numeral_font)
	paint_focus(ci)


func _paint_paytable(ci: Control, title_font: Font, numeral_font: Font) -> void:
	PaintScript.rounded(ci, PAYTABLE, 16.0, Color(PaintScript.FELT_DARK, 0.92),
		PaintScript.GOLD_DIM, 2.0)
	PaintScript.label(ci, title_font, Rect2(PAYTABLE.position + Vector2(16.0, 10.0),
		Vector2(PAYTABLE.size.x - 32.0, 40.0)), "Chips back per chip", 22, PaintScript.GOLD)
	var row_h := 62.0
	var top: float = PAYTABLE.position.y + 60.0
	var rows: int = SlotsScript.SYMBOL_NAMES.size() + 2
	var winning_row: int = _winning_row()
	for row: int in rows:
		var y: float = top + row_h * float(row)
		var band := Rect2(PAYTABLE.position.x + 10.0, y, PAYTABLE.size.x - 20.0, row_h - 8.0)
		if row == winning_row and _flash > 0.0:
			PaintScript.rounded(ci, band, 10.0, Color(PaintScript.GOLD, 0.35 * _flash + 0.1),
				PaintScript.GOLD, 2.0)
		elif row % 2 == 0:
			PaintScript.rounded(ci, band, 10.0, Color(1.0, 1.0, 1.0, 0.04),
				Color(0, 0, 0, 0), 0.0)
		var icons: Array[int] = []
		var pay: int = 0
		if row < SlotsScript.SYMBOL_NAMES.size():
			icons = [row, row, row]
			pay = SlotsScript.TRIPLE_PAYS[row]
		elif row == SlotsScript.SYMBOL_NAMES.size():
			icons = [SlotsScript.Symbol.RAINBOW, SlotsScript.Symbol.RAINBOW, -1]
			pay = SlotsScript.TWO_RAINBOW_PAY
		else:
			icons = [SlotsScript.Symbol.RAINBOW, -1, -1]
			pay = SlotsScript.ONE_RAINBOW_PAY
		for i: int in 3:
			var box := Rect2(band.position + Vector2(8.0 + 50.0 * float(i), 4.0),
				Vector2(46.0, 46.0))
			if icons[i] >= 0:
				PaintScript.draw_symbol(ci, box, icons[i])
			else:
				# "ANY": a dim empty tile, so two rainbows and one rainbow read as pictures too.
				PaintScript.rounded(ci, box.grow(-6.0), 8.0, Color(1.0, 1.0, 1.0, 0.06),
					Color(1.0, 1.0, 1.0, 0.25), 1.5)
				PaintScript.label(ci, title_font, box.grow(-8.0), "any", 14,
					Color(1.0, 1.0, 1.0, 0.5))
		PaintScript.label(ci, numeral_font, Rect2(band.position + Vector2(162.0, 0.0),
			Vector2(band.size.x - 172.0, band.size.y)), "x%d" % pay, 32,
			PaintScript.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)


## Which paytable row the last spin hit, or -1.
func _winning_row() -> int:
	if _won <= 0 or _spinning and _flash <= 0.0:
		return -1
	var line: Array[int] = payline_symbols()
	if line[0] == line[1] and line[1] == line[2]:
		return line[0]
	var rainbows: int = line.count(SlotsScript.Symbol.RAINBOW)
	if rainbows == 2:
		return SlotsScript.SYMBOL_NAMES.size()
	if rainbows == 1:
		return SlotsScript.SYMBOL_NAMES.size() + 1
	return -1


## ONE REEL, drawn into its own clipped window. Symbols on a cream drum, the payline cell
## lit, shaded top and bottom so it reads as a cylinder.
func _paint_reel(reel: int, window: Control) -> void:
	var size: Vector2 = window.size
	window.draw_rect(Rect2(Vector2.ZERO, size), Color(0.97, 0.94, 0.86))
	var strip: Array[int] = SlotsScript.reel_strip(reel)
	var pos: float = _reel_pos[reel]
	var mid: float = size.y * 0.5
	var base: int = floori(pos)
	var speed: float = absf(pos - _reel_prev[reel])
	for i: int in range(base - 2, base + 4):
		# Rolling down: a higher strip index sits higher in the window.
		var y: float = mid + (pos - float(i)) * CELL_HEIGHT
		var cell := Rect2(Vector2(0.0, y - CELL_HEIGHT * 0.5), Vector2(size.x, CELL_HEIGHT))
		window.draw_line(Vector2(12.0, cell.position.y), Vector2(size.x - 12.0, cell.position.y),
			Color(0.0, 0.0, 0.0, 0.08), 2.0)
		var box := Rect2(cell.position + Vector2(size.x * 0.5 - 40.0, 10.0), Vector2(80.0, 80.0))
		var symbol: int = strip[posmod(i, strip.size())]
		if speed > 0.25:
			# A fast reel smears: the symbol drawn twice more, fainter, along its path.
			for ghost: int in 2:
				var off := Vector2(0.0, -CELL_HEIGHT * 0.18 * float(ghost + 1))
				var ghost_box := Rect2(box.position + off, box.size)
				PaintScript.draw_symbol(window, ghost_box, symbol)
				window.draw_rect(ghost_box, Color(0.97, 0.94, 0.86, 0.55))
		PaintScript.draw_symbol(window, box, symbol)
	# The cylinder: darker bands at the top and bottom.
	for band: int in 6:
		var a: float = 0.30 * (1.0 - float(band) / 6.0)
		window.draw_rect(Rect2(0.0, 8.0 * float(band), size.x, 8.0), Color(0.1, 0.05, 0.12, a))
		window.draw_rect(Rect2(0.0, size.y - 8.0 * float(band + 1), size.x, 8.0),
			Color(0.1, 0.05, 0.12, a))


## Over the windows: the payline and, on a win, the banner. Its own Control so it draws above
## the clipped reels.
func _paint_overlay() -> void:
	if _overlay == null:
		return
	var t: float = anim_time()
	var lit: bool = _flash > 0.0
	var colour: Color = PaintScript.GOLD if not lit \
		else PaintScript.BAND_COLORS[int(t * 10.0) % PaintScript.BAND_COLORS.size()]
	var left: float = reel_rect(0).position.x - 22.0
	var right: float = reel_rect(SlotsScript.REELS - 1).end.x + 22.0
	_overlay.draw_line(Vector2(left + 14.0, payline_y()), Vector2(right - 14.0, payline_y()),
		Color(colour, 0.35 + 0.55 * _flash), 2.0 + 3.0 * _flash, true)
	for side: float in [left, right]:
		var dir: float = 1.0 if side == left else -1.0
		_overlay.draw_colored_polygon(PackedVector2Array([Vector2(side, payline_y() - 14.0),
			Vector2(side, payline_y() + 14.0), Vector2(side + 18.0 * dir, payline_y())]), colour)
	if lit:
		for reel: int in SlotsScript.REELS:
			var cell := Rect2(reel_rect(reel).position + Vector2(4.0, REEL_SIZE_PX.y * 0.5
				- CELL_HEIGHT * 0.5 + 4.0), Vector2(REEL_SIZE_PX.x - 8.0, CELL_HEIGHT - 8.0))
			PaintScript.rounded(_overlay, cell, 12.0, Color(1.0, 0.9, 0.4, 0.0),
				Color(colour, _flash), 4.0)
		var pop: float = 1.0 + 0.06 * sin(t * 14.0)
		var banner := Rect2(BANNER.get_center() - BANNER.size * pop * 0.5, BANNER.size * pop)
		PaintScript.rounded(_overlay, banner, 35.0, Color(PaintScript.PLUM_DARK, 0.92),
			PaintScript.GOLD, 4.0)
		PaintScript.label(_overlay, MenuStyleScript.title_font(), banner.grow(-12.0),
			"WIN  +%d" % _won, 44, PaintScript.GOLD)
