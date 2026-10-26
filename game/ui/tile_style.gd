class_name TileStyle
extends RefCounted
## THE CASINO LOBBY'S TILE, FOR EVERY COUNTER IN TOWN (overnight bot review, 2026-10-26).
## The owner's one kind word in the September playtest was for the casino's screens; the
## Market and the Depot were dark lists of words beside it. A tile is plum with a gold edge,
## brighter with a thick gold edge when it is the pick, lifted under the pointer, and it
## carries its picture on a cream disc. Colours are the casino's own (game/ui/casino_paint.gd).

const PaintScript := preload("res://ui/casino_paint.gd")


static func box(picked: bool, hovered: bool) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = PaintScript.PLUM if picked else \
		(PaintScript.PLUM_DARK.lightened(0.08) if hovered else PaintScript.PLUM_DARK)
	b.border_color = PaintScript.GOLD if picked or hovered else PaintScript.GOLD_DIM
	b.set_border_width_all(3 if picked else (2 if hovered else 1))
	b.set_corner_radius_all(14)
	b.content_margin_left = 14.0
	b.content_margin_right = 14.0
	b.content_margin_top = 10.0
	b.content_margin_bottom = 10.0
	return b


## The round plate a tile's picture sits on, `fill` (cream by default) and `size` across.
static func disc(size: float, fill: Color = PaintScript.CARD_FACE) -> PanelContainer:
	var plate := PanelContainer.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var round := StyleBoxFlat.new()
	round.bg_color = fill
	round.border_color = PaintScript.GOLD_DIM
	round.set_border_width_all(1)
	round.set_corner_radius_all(int(size * 0.5 + 6.0))
	round.set_content_margin_all(6.0)
	plate.add_theme_stylebox_override(&"panel", round)
	return plate


## Keep `row` in the tile look: MouseRows' own exit handler puts the old dark row box back
## when the pointer leaves a row that is not the pick, so this one runs after it.
static func dress(row: PanelContainer, picked: bool, hovered: bool) -> void:
	row.add_theme_stylebox_override(&"panel", box(picked, hovered))
	if not picked:
		row.mouse_exited.connect(func() -> void:
			row.add_theme_stylebox_override(&"panel", box(false, false)))
