class_name WheelMenu
extends "res://ui/casino_table.gd"
## THE BIG WHEEL'S FELT. One wheel of forty five segments on the left, painted in five tier
## colours with the tier on every segment; on the right, a pad per tier to stack chips on, the
## chip she is stacking with, Clear and a big Spin. The owner asked for "the rust wheel with
## different payout levels" and for it to look "so much prettier" (playtest 2026-11-05); the
## colour and number roulette with its bracket tabs is gone entirely.
##
## A BET IS A SET OF STACKS. Clicking a tier pad puts one chip of the chosen size on it
## (a right click takes one back), as many tiers as she likes, never more in total than she
## holds. Spin sends the whole set; ranch.gd takes it, spins Wheel.spin() and settles, then
## pushes the segment back through show_spin(). The stacks stay on the felt after a spin, so
## "again" is one press, and are cleared if the purse can no longer cover them.
##
## THE RESULT IS TOLD BY THE WHEEL. Nothing is printed under it: the pointer ticks over the
## segments as the wheel slows (an ease out over a constant SPIN_SECONDS), the landed segment
## and its tier pad flash, the hub shows the win, and a strip of coloured dots remembers the
## last few spins. The chip counter holds what she had until the wheel stops, so the number
## does not give the result away while it is still turning.
##
## NOTHING HERE ROLLS. The jitter that stops the pointer somewhere inside its segment rather
## than dead centre is a function of the spin count, not a generator (test_casino_paint.gd's
## last test forbids one anywhere under game/ui/).

const WheelScript := preload("res://systems/wheel.gd")

const TITLE := "The Wheel"

# --- the felt, in stage local pixels ---------------------------------------------------------
const STAGE_HEIGHT := 640.0
const WHEEL_CENTRE := Vector2(318.0, 324.0)
const WHEEL_OUTER := 292.0
const WHEEL_INNER := 104.0
const RIM_WIDTH := 16.0
const HUB_RADIUS := 92.0
const LABEL_RADIUS := 206.0
const BULBS := 30

const COLUMN_X := 660.0
const COLUMN_W := 460.0
const COUNTER := Rect2(660.0, 0.0, 190.0, 46.0)
const HISTORY := Rect2(866.0, 0.0, 254.0, 46.0)
const PAD_TOP := 62.0
const PAD_HEIGHT := 68.0
const PAD_GAP := 9.0
const CHIP_ROW_Y := 506.0
const CHIP_RADIUS := 34.0
const CHIP_PITCH := 96.0
const CLEAR := Rect2(970.0, 476.0, 150.0, 60.0)
const SPIN := Rect2(660.0, 556.0, 460.0, 80.0)
const HISTORY_MAX := 7

# --- the spin, and every one of these is a CONSTANT ------------------------------------------
## A spin whose length varied would be a generator living under game/ui/. TRANS_QUART with
## EASE_OUT is friction: fast off the hand, then individual clicks as it dies.
const SPIN_TURNS := 4
const SPIN_SECONDS := 4.6
const WIN_FLASH_SECONDS := 1.8
const COUNT_UP_SECONDS := 0.8

## The pointer's flap kicks back this far each time a segment boundary passes under it and
## springs home over RATCHET_SECONDS.
const RATCHET_DEGREES := 14.0
const RATCHET_SECONDS := 0.10

## How far from a segment's centre the pointer may stop, as a fraction of a segment, so a
## landing reads as a wheel that stopped rather than a list that was indexed.
const LAND_SPREAD := 0.62

signal bet_requested(bets: Array[int])

var _bets: Array[int] = WheelScript.empty_bets()
var _chip := 0
## Starts with segment 0, a 20x, under the pointer: the first thing she sees is the jackpot.
var _angle := -PI * 0.5
var _spinning := false
var _landed := -1
var _won := 0
var _flash := 0.0
var _ratchet := 0.0
var _last_segment := -1
var _spins := 0
var _history: Array[int] = []
var _shown_chips := 0.0
var _held_chips := -1
var _tween: Tween = null


func title_text() -> String:
	return TITLE


func stage_size() -> Vector2:
	return Vector2(STAGE_WIDTH, STAGE_HEIGHT)


func initial_focus() -> StringName:
	return &"tier:0"


func animating() -> bool:
	return _spinning


func open() -> bool:
	if not super.open():
		return false
	_shown_chips = float(_purse())
	_held_chips = -1
	_trim_bets()
	return true


func _purse() -> int:
	return int(chips_provider.call()) if chips_provider.is_valid() else 0


# --- the bet ----------------------------------------------------------------------------------

func bets() -> Array[int]:
	return _bets.duplicate()


func total_bet() -> int:
	return WheelScript.total_staked(_bets)


func chip_value() -> int:
	return STAKES[clampi(_chip, 0, STAKES.size() - 1)]


func chip_index() -> int:
	return _chip


## THE CHIP SHE IS STACKING WITH. Any size she could put down at all; a size bigger than her
## purse is drawn greyed and cannot be picked.
func set_chip(index: int) -> bool:
	if index < 0 or index >= STAKES.size() or STAKES[index] > _purse():
		return false
	_chip = index
	if _stage != null:
		_stage.queue_redraw()
	return true


## One chip of the chosen size onto `tier`. Refused mid spin, and refused (with the denied
## tick) when the purse cannot cover the stacks plus this one.
func add_bet(tier: int) -> bool:
	if _spinning or tier < 0 or tier >= WheelScript.TIERS:
		return false
	if total_bet() + chip_value() > _purse():
		MenuStyleScript.tick_denied()
		return false
	_bets[tier] += chip_value()
	_sound_call(&"play", [&"chip_clink"])
	if _stage != null:
		_stage.queue_redraw()
	return true


## One chip of the chosen size back off `tier`, or whatever is left on it if less.
func remove_bet(tier: int) -> bool:
	if _spinning or tier < 0 or tier >= WheelScript.TIERS or _bets[tier] <= 0:
		return false
	_bets[tier] = maxi(0, _bets[tier] - chip_value())
	MenuStyleScript.tick_back()
	if _stage != null:
		_stage.queue_redraw()
	return true


func clear_bets() -> bool:
	if _spinning or total_bet() <= 0:
		return false
	_bets = WheelScript.empty_bets()
	MenuStyleScript.tick_back()
	if _stage != null:
		_stage.queue_redraw()
	return true


func can_spin() -> bool:
	return not _spinning and total_bet() > 0 and total_bet() <= _purse()


## SPIN: the whole set of stacks goes to ranch.gd in one signal.
func spin() -> bool:
	if not can_spin():
		return false
	MenuStyleScript.tick_confirm()
	_sound_call(&"play", [&"chip_clink"])
	bet_requested.emit(bets())
	return true


## A set of stacks the purse can no longer cover is cleared rather than left to refuse.
func _trim_bets() -> void:
	if total_bet() > _purse():
		_bets = WheelScript.empty_bets()
	if chip_value() > _purse():
		_chip = 0


# --- the controls -----------------------------------------------------------------------------

func pad_rect(tier: int) -> Rect2:
	return Rect2(COLUMN_X, PAD_TOP + (PAD_HEIGHT + PAD_GAP) * float(tier), COLUMN_W, PAD_HEIGHT)


func chip_rect(index: int) -> Rect2:
	var centre := Vector2(COLUMN_X + CHIP_RADIUS + 8.0 + CHIP_PITCH * float(index), CHIP_ROW_Y)
	return Rect2(centre - Vector2(CHIP_RADIUS, CHIP_RADIUS) * 1.15,
		Vector2(CHIP_RADIUS, CHIP_RADIUS) * 2.3)


func clear_rect() -> Rect2:
	return CLEAR


func spin_rect() -> Rect2:
	return SPIN


func stage_buttons() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for tier: int in WheelScript.TIERS:
		out.append({"id": StringName("tier:%d" % tier), "rect": pad_rect(tier),
			"enabled": not _spinning})
	for i: int in STAKES.size():
		out.append({"id": StringName("chip:%d" % i), "rect": chip_rect(i),
			"enabled": not _spinning and STAKES[i] <= _purse()})
	out.append({"id": &"clear", "rect": CLEAR, "enabled": not _spinning and total_bet() > 0})
	out.append({"id": &"spin", "rect": SPIN, "enabled": can_spin()})
	return out


func activate(id: StringName) -> bool:
	var name: String = String(id)
	if name.begins_with("tier:"):
		return add_bet(int(name.substr(5)))
	if name.begins_with("chip:"):
		var ok: bool = set_chip(int(name.substr(5)))
		if ok:
			MenuStyleScript.tick_confirm()
		return ok
	if id == &"clear":
		return clear_bets()
	if id == &"spin":
		return spin()
	return false


func on_stage_alt(index: int) -> void:
	var buttons: Array[Dictionary] = stage_buttons()
	if index < 0 or index >= buttons.size():
		return
	var name: String = String(buttons[index]["id"])
	if name.begins_with("tier:"):
		remove_bet(int(name.substr(5)))


# --- the wheel, as geometry ---------------------------------------------------------------------

func wheel_centre() -> Vector2:
	return WHEEL_CENTRE


func wheel_outer() -> float:
	return WHEEL_OUTER


func wheel_angle() -> float:
	return _angle


func _per() -> float:
	return TAU / float(WheelScript.SEGMENTS)


## THE SEGMENT UNDER THE POINTER RIGHT NOW, derived from the live angle rather than
## remembered from the push, so the test that asks it is asking the drawing. Segment i is
## centred at _angle + i * per; the pointer is at twelve o'clock.
func segment_under_pointer() -> int:
	var at: float = fposmod(-PI * 0.5 - _angle, TAU)
	return posmod(roundi(at / _per()), WheelScript.SEGMENTS)


func landed_segment() -> int:
	return _landed


func history() -> Array[int]:
	return _history.duplicate()


## The chip count the counter is showing: held at the pre win figure while the wheel turns.
func shown_chips() -> int:
	return _held_chips if _held_chips >= 0 else _purse()


## TOLD, NEVER ASKED. ranch.gd's play_wheel() has taken the stakes, spun Wheel.spin() and
## settled by the time this is called. A segment that is not on the wheel is a still frame:
## this arrives over a dynamic call() and nothing type checks it at the call site.
func show_spin(segment: int, won: int, _staked: int) -> void:
	if segment < 0 or segment >= WheelScript.SEGMENTS:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_spinning = true
	_landed = -1
	_flash = 0.0
	_won = maxi(0, won)
	_spins += 1
	_held_chips = maxi(0, _purse() - _won)
	_shown_chips = float(_held_chips)
	var per: float = _per()
	# A deterministic spread inside the segment: the golden ratio walks the spin count round
	# the unit interval without repeating, so no two landings sit at the same spot.
	var spread: float = (fposmod(float(_spins) * 0.618034, 1.0) - 0.5) * LAND_SPREAD * per
	var target: float = -PI * 0.5 - per * float(segment) + spread
	while target < _angle + TAU * float(SPIN_TURNS):
		target += TAU
	var land_at := segment
	_tween = create_tween()
	_tween.tween_property(self, "_angle", target, SPIN_SECONDS) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(func() -> void: _on_landed(land_at))
	if _won > 0:
		_tween.tween_property(self, "_flash", 1.0, 0.15)
		_tween.parallel().tween_property(self, "_shown_chips", float(_purse()),
			COUNT_UP_SECONDS)
		_tween.tween_property(self, "_flash", 0.0, WIN_FLASH_SECONDS)
	else:
		_tween.tween_property(self, "_flash", 0.4, 0.12)
		_tween.tween_property(self, "_flash", 0.0, 0.5)
	_tween.tween_callback(func() -> void:
		_spinning = false
		_held_chips = -1
		_trim_bets()
		refresh())


func _on_landed(segment: int) -> void:
	_landed = segment
	_history.push_front(WheelScript.tier_of(segment))
	while _history.size() > HISTORY_MAX:
		_history.pop_back()
	_sound_call(&"play", [&"wheel_settle"])
	if _won > 0:
		_sound_call(&"play", [&"slots_win"])
	if _won <= 0:
		_held_chips = -1


## A ranch push of the old result lines lands here and is not printed: the wheel tells it.
func show_result(lines: Array[String]) -> void:
	_result = lines.duplicate()


## super(delta) FIRST: TableMenu's _process advances anim_time() and queues the redraw. The
## ratchet's crossing detection lives here and not in paint(), for the reason the old wheel
## recorded: a draw pass is not a frame tick.
func _process(delta: float) -> void:
	super(delta)
	var now: int = segment_under_pointer()
	if now != _last_segment:
		_last_segment = now
		if _spinning:
			_ratchet = 1.0
			_sound_call(&"play", [&"wheel_ratchet"])
	_ratchet = maxf(0.0, _ratchet - delta / RATCHET_SECONDS)


## The text model: every word this felt draws, for the dash test.
func drawn_lines() -> Array[String]:
	var lines: Array[String] = []
	for tier: int in WheelScript.TIERS:
		lines.append(WheelScript.TIER_LABELS[tier])
		lines.append(_pays_text(tier))
	lines.append("Spin")
	lines.append("Clear")
	lines.append(_edge_text())
	return lines


func _pays_text(tier: int) -> String:
	return "pays %d to 1" % WheelScript.MULTIPLIERS[tier]


func _edge_text() -> String:
	return "house keeps %.1f to %.1f%%" % [WheelScript.best_edge() * 100.0,
		WheelScript.house_edge() * 100.0]


# --- the paint ----------------------------------------------------------------------------------

func paint(ci: Control) -> void:
	var t: float = anim_time()
	var title_font: Font = MenuStyleScript.title_font()
	var numeral_font: Font = MenuStyleScript.numeral_font()
	_paint_wheel(ci, t, title_font)
	_paint_column(ci, t, title_font, numeral_font)
	paint_focus(ci)


func _paint_wheel(ci: Control, t: float, title_font: Font) -> void:
	var per: float = _per()
	var landed_tier: int = WheelScript.tier_of(_landed)
	# The drop shadow and the rim: a dark disc a little low, then the gold rim ring.
	ci.draw_circle(WHEEL_CENTRE + Vector2(0.0, 10.0), WHEEL_OUTER + RIM_WIDTH + 4.0,
		Color(0.0, 0.0, 0.0, 0.35))
	ci.draw_circle(WHEEL_CENTRE, WHEEL_OUTER + RIM_WIDTH, PaintScript.GOLD_DIM.darkened(0.25))
	ci.draw_circle(WHEEL_CENTRE, WHEEL_OUTER + RIM_WIDTH - 3.0, PaintScript.PLUM_DARK)
	for segment: int in WheelScript.SEGMENTS:
		var tier: int = WheelScript.tier_of(segment)
		var mid: float = _angle + per * float(segment)
		var colour: Color = PaintScript.TIER_COLOURS[tier]
		# Every other segment a shade darker, so a run of different tiers still reads as
		# separate slices from across the room.
		if segment % 2 == 1:
			colour = colour.darkened(0.10)
		if segment == _landed and _flash > 0.0:
			colour = colour.lerp(Color.WHITE, 0.55 * _flash * (0.6 + 0.4 * sin(t * 18.0)))
		ci.draw_colored_polygon(PaintScript.sector_points(WHEEL_CENTRE, WHEEL_INNER,
			WHEEL_OUTER, mid - per * 0.5, mid + per * 0.5), colour)
		# An inner band in the tier's deep shade gives each slice a lip.
		ci.draw_colored_polygon(PaintScript.sector_points(WHEEL_CENTRE, WHEEL_INNER,
			WHEEL_INNER + 22.0, mid - per * 0.5, mid + per * 0.5), colour.darkened(0.30))
		var edge: float = mid - per * 0.5
		ci.draw_line(WHEEL_CENTRE + Vector2(cos(edge), sin(edge)) * WHEEL_INNER,
			WHEEL_CENTRE + Vector2(cos(edge), sin(edge)) * WHEEL_OUTER,
			Color(PaintScript.GOLD, 0.85), 2.0, true)
		_paint_segment_label(ci, title_font, mid, tier)
	# The rim's bulbs: a chase while idle, a fast chase while spinning, all lit on a win.
	for bulb: int in BULBS:
		var a: float = TAU * float(bulb) / float(BULBS)
		var at: Vector2 = WHEEL_CENTRE + Vector2(cos(a), sin(a)) * (WHEEL_OUTER + RIM_WIDTH * 0.5)
		var speed: float = 3.0 if _spinning else 1.0
		var phase: float = fposmod(t * speed - float(bulb) / 6.0, 1.0)
		var lit: float = 0.30 + 0.70 * (1.0 if phase < 0.5 else 0.0)
		if _flash > 0.0 and _won > 0:
			lit = 0.5 + 0.5 * sin(t * 14.0 + float(bulb))
		ci.draw_circle(at, 5.0, Color(1.0, 0.95, 0.70, lit))
	# The hub, with a burst of light behind it on a win.
	if _won > 0 and _flash > 0.0:
		for ray: int in 16:
			var a: float = TAU * float(ray) / 16.0 + t * 0.8
			ci.draw_colored_polygon(PaintScript.sector_points(WHEEL_CENTRE, HUB_RADIUS,
				HUB_RADIUS + 40.0 * _flash, a - 0.07, a + 0.07),
				Color(1.0, 0.92, 0.55, 0.75 * _flash))
	ci.draw_circle(WHEEL_CENTRE, HUB_RADIUS + 6.0, PaintScript.GOLD_DIM)
	ci.draw_circle(WHEEL_CENTRE, HUB_RADIUS, PaintScript.PLUM)
	ci.draw_arc(WHEEL_CENTRE, HUB_RADIUS - 8.0, 0.0, TAU, 64, Color(PaintScript.GOLD, 0.6),
		2.0, true)
	var hub_box := Rect2(WHEEL_CENTRE - Vector2(HUB_RADIUS * 0.78, HUB_RADIUS * 0.42),
		Vector2(HUB_RADIUS * 1.56, HUB_RADIUS * 0.84))
	if _landed >= 0 and _won > 0:
		var pulse: float = 1.0 + 0.08 * _flash * sin(t * 12.0)
		PaintScript.label(ci, title_font, Rect2(hub_box.get_center() - hub_box.size * pulse
			* 0.5, hub_box.size * pulse), "+%d" % _won, 44, PaintScript.GOLD)
	elif _landed >= 0 and landed_tier >= 0:
		PaintScript.label(ci, title_font, hub_box, WheelScript.TIER_LABELS[landed_tier], 44,
			PaintScript.TIER_COLOURS[landed_tier].lightened(0.25))
	else:
		var star := Rect2(WHEEL_CENTRE - Vector2(44.0, 44.0), Vector2(88.0, 88.0))
		ci.draw_colored_polygon(PaintScript.star_points(star), PaintScript.GOLD)
	_paint_pointer(ci)


## The tier on its slice, reading along the radius, turned on the left half of the wheel so
## no label is ever upside down.
func _paint_segment_label(ci: Control, font: Font, mid: float, tier: int) -> void:
	var at: Vector2 = WHEEL_CENTRE + Vector2(cos(mid), sin(mid)) * LABEL_RADIUS
	var rotation: float = mid
	var facing_left: bool = cos(mid) < 0.0
	if facing_left:
		rotation += PI
	ci.draw_set_transform(at, rotation, Vector2.ONE)
	var size: int = 30 if tier >= WheelScript.Tier.TEN else 26
	var box := Rect2(Vector2(-70.0, -18.0), Vector2(140.0, 36.0))
	var ink: Color = PaintScript.CARD_INK if tier == WheelScript.Tier.ONE \
		else Color(1.0, 1.0, 1.0)
	# A soft dark copy one pixel down, so white on gold and white on red both read.
	PaintScript.label(ci, font, Rect2(box.position + Vector2(0.0, 2.0), box.size),
		WheelScript.TIER_LABELS[tier], size, Color(0.0, 0.0, 0.0, 0.30))
	PaintScript.label(ci, font, box, WheelScript.TIER_LABELS[tier], size, ink)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _paint_pointer(ci: Control) -> void:
	var pivot: Vector2 = WHEEL_CENTRE + Vector2(0.0, -(WHEEL_OUTER + RIM_WIDTH + 2.0))
	var kick: float = deg_to_rad(RATCHET_DEGREES) * _ratchet
	var down := Vector2(sin(-kick), cos(-kick))
	var side := Vector2(down.y, -down.x)
	var tip: Vector2 = pivot + down * 58.0
	ci.draw_colored_polygon(PackedVector2Array([pivot - side * 20.0 + down * 2.0,
		pivot + side * 20.0 + down * 2.0, tip + Vector2(0.0, 4.0)]), Color(0.0, 0.0, 0.0, 0.35))
	ci.draw_colored_polygon(PackedVector2Array([pivot - side * 20.0, pivot + side * 20.0, tip]),
		PaintScript.GOLD)
	ci.draw_polyline(PackedVector2Array([pivot - side * 20.0, tip, pivot + side * 20.0]),
		PaintScript.GOLD_DIM.darkened(0.3), 2.0, true)
	ci.draw_circle(pivot, 12.0, PaintScript.GOLD_DIM)
	ci.draw_circle(pivot, 6.0, PaintScript.GOLD)


func _paint_column(ci: Control, t: float, title_font: Font, numeral_font: Font) -> void:
	# --- the chip counter and the last spins -----------------------------------------------
	PaintScript.rounded(ci, COUNTER, 23.0, Color(0.0, 0.0, 0.0, 0.35),
		Color(PaintScript.GOLD, 0.5), 2.0)
	PaintScript.draw_chip_icon(ci, Rect2(COUNTER.position + Vector2(10.0, 9.0),
		Vector2(28.0, 28.0)))
	var counting: int = roundi(_shown_chips) if _spinning else shown_chips()
	PaintScript.label(ci, numeral_font, Rect2(COUNTER.position + Vector2(46.0, 2.0),
		COUNTER.size - Vector2(56.0, 4.0)), "%d" % counting, 28, PaintScript.GOLD,
		HORIZONTAL_ALIGNMENT_LEFT)
	for i: int in _history.size():
		var dot := Rect2(Vector2(HISTORY.end.x - 34.0 - 36.0 * float(i), 6.0),
			Vector2(34.0, 34.0))
		var tier: int = _history[i]
		ci.draw_circle(dot.get_center(), 16.0, PaintScript.TIER_COLOURS[tier].darkened(0.1 if i > 0 else 0.0))
		if i == 0:
			ci.draw_arc(dot.get_center(), 18.0, 0.0, TAU, 32, PaintScript.GOLD, 2.0, true)
		PaintScript.label(ci, title_font, dot.grow(-5.0), WheelScript.TIER_LABELS[tier], 14,
			PaintScript.CARD_INK if tier == 0 else Color.WHITE)

	# --- the tier pads -------------------------------------------------------------------------
	var winning_tier: int = WheelScript.tier_of(_landed) if _landed >= 0 else -1
	for tier: int in WheelScript.TIERS:
		var pad: Rect2 = pad_rect(tier)
		var colour: Color = PaintScript.TIER_COLOURS[tier]
		var lit: bool = is_lit(StringName("tier:%d" % tier))
		var won_here: bool = tier == winning_tier and _won > 0 and _flash > 0.0
		var fill := Color(0.08, 0.05, 0.12, 0.82)
		if lit and not _spinning:
			fill = Color(0.16, 0.10, 0.22, 0.92)
		if won_here:
			fill = fill.lerp(colour, 0.6 * _flash * (0.6 + 0.4 * sin(t * 14.0)))
		PaintScript.rounded(ci, pad, 14.0, fill, colour if lit or won_here else
			Color(colour, 0.55), 3.0 if lit or won_here else 2.0)
		# The swatch: the tier as a big badge in its own colour.
		var badge := Rect2(pad.position + Vector2(8.0, 8.0), Vector2(112.0, pad.size.y - 16.0))
		PaintScript.rounded(ci, badge, 12.0, colour, colour.darkened(0.35), 2.0)
		PaintScript.label(ci, title_font, badge.grow(-6.0), WheelScript.TIER_LABELS[tier], 34,
			PaintScript.CARD_INK if tier == WheelScript.Tier.ONE else Color.WHITE)
		# Pays line and the odds as pips: one dot per segment the tier owns.
		PaintScript.label(ci, numeral_font, Rect2(pad.position + Vector2(132.0, 6.0),
			Vector2(170.0, 30.0)), _pays_text(tier), 20, MenuStyleScript.COLOR_NAME,
			HORIZONTAL_ALIGNMENT_LEFT)
		var count: int = WheelScript.segment_count(tier)
		for pip: int in count:
			var col: int = pip % 11
			var row: int = pip / 11
			ci.draw_circle(pad.position + Vector2(138.0 + 13.0 * float(col),
				44.0 + 11.0 * float(row)), 4.0, Color(colour, 0.9))
		# Her stack on this tier.
		var stake: int = _bets[tier]
		if stake > 0:
			var stack_at: Vector2 = pad.position + Vector2(pad.size.x - 132.0,
				pad.size.y - 18.0)
			PaintScript.chip_stack(ci, stack_at, clampi(stake / 10, 1, 6),
				_stack_colour(stake), 4.0)
			PaintScript.label(ci, numeral_font, Rect2(pad.position + Vector2(pad.size.x - 104.0,
				8.0), Vector2(96.0, pad.size.y - 16.0)), "%d" % stake, 30,
				PaintScript.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
		elif lit and not _spinning:
			PaintScript.label(ci, numeral_font, Rect2(pad.position + Vector2(pad.size.x - 140.0,
				8.0), Vector2(132.0, pad.size.y - 16.0)), "+%d" % chip_value(), 24,
				Color(PaintScript.GOLD, 0.55), HORIZONTAL_ALIGNMENT_RIGHT)

	# --- the chip she stacks with ------------------------------------------------------------
	for i: int in STAKES.size():
		var box: Rect2 = chip_rect(i)
		var usable: bool = STAKES[i] <= _purse()
		var chosen: bool = i == _chip
		var centre: Vector2 = box.get_center() - Vector2(0.0, 8.0 if chosen else 0.0)
		var colour: Color = PaintScript.CHIP_COLORS[i] if usable else Color(0.30, 0.28, 0.32)
		if chosen:
			ci.draw_arc(centre, CHIP_RADIUS + 7.0, 0.0, TAU, 48,
				Color(PaintScript.GOLD, 0.75 + 0.25 * sin(t * 4.0)), 4.0, true)
		PaintScript.chip(ci, centre, CHIP_RADIUS, colour, true)
		PaintScript.label(ci, numeral_font, Rect2(centre - Vector2(CHIP_RADIUS * 0.66, 14.0),
			Vector2(CHIP_RADIUS * 1.32, 28.0)), str(STAKES[i]), 22,
			Color.WHITE if i == 2 or not usable else PaintScript.CARD_INK)
	PaintScript.button(ci, CLEAR, "Clear", Color(0.42, 0.30, 0.52),
		button_enabled(&"clear"), is_lit(&"clear"))

	# --- spin ----------------------------------------------------------------------------------
	var spin_text: String = "Spin" if total_bet() <= 0 else "Spin  %d" % total_bet()
	if _spinning:
		spin_text = "Spinning"
	PaintScript.button(ci, SPIN, spin_text, Color(0.95, 0.62, 0.18), can_spin(),
		is_lit(&"spin"))


## A stack's colour is the biggest chip it could be built from.
func _stack_colour(stake: int) -> Color:
	if stake >= STAKES[2]:
		return PaintScript.CHIP_COLORS[2]
	if stake >= STAKES[1]:
		return PaintScript.CHIP_COLORS[1]
	return PaintScript.CHIP_COLORS[0]
