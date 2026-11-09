class_name TileStyle
extends RefCounted
## THE CASINO LOBBY'S TILE, FOR EVERY COUNTER IN TOWN (overnight bot review, 2026-10-26).
## The owner's one kind word in the September playtest was for the casino's screens; the
## Market and the Depot were dark lists of words beside it. A tile is plum with a gold edge,
## brighter with a thick gold edge when it is the pick, lifted under the pointer, and it
## carries its picture on a cream disc. Colours are the casino's own (game/ui/casino_paint.gd).

const PaintScript := preload("res://ui/casino_paint.gd")
const MenuStyleScript := preload("res://ui/menu_style.gd")


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
	# Hovered, the tile lifts off the page (FS6.1).
	b.shadow_color = Color(0, 0, 0, 0.35 if hovered else 0.18)
	b.shadow_size = 10 if hovered else 3
	b.shadow_offset = Vector2(0, 6 if hovered else 2)
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


## THE PICTURE'S STAGE (Fable AAA round 2, #8: "nine identical cards each a grey circle with a
## one-colour line glyph"). A rounded square in the thing's own family colour, lit from above
## like a shop window, with a soft shadow for the picture to stand on and a gold inner rim.
## The picture goes in as its child and fills it. `dim` greys it for what she cannot buy.
const WELL_TINTS := {
	&"food": Color(0.45, 0.70, 0.36), &"gear": Color(0.36, 0.56, 0.84),
	&"place": Color(0.86, 0.44, 0.52), &"build": Color(0.78, 0.54, 0.30),
	&"decor": Color(0.60, 0.46, 0.86), &"gem": Color(0.94, 0.72, 0.30),
}


static func well(side: float, tint: Color, dim := false) -> Control:
	var w := Control.new()
	w.name = "Well"
	w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	w.custom_minimum_size = Vector2(side, side)
	w.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	w.set_meta(&"tint", tint)
	w.set_meta(&"dim", dim)
	w.draw.connect(func() -> void:
		# Read at draw time, so a well can be recoloured (set_meta, queue_redraw) in place.
		var base: Color = w.get_meta(&"tint")
		var dim_now: bool = w.get_meta(&"dim")
		if dim_now:
			base = base.lerp(Color(0.5, 0.48, 0.52), 0.65)
		var r := Rect2(Vector2.ZERO, w.size)
		var radius := side * 0.2
		# The window: deep at the rim, a pool of light behind the picture.
		PaintScript.rounded(w, r, radius, base.darkened(0.42), PaintScript.PLUM_DARK, 0.0)
		var c := r.get_center() - Vector2(0.0, side * 0.06)
		for k in 12:
			var t := float(k) / 12.0
			var col := base.lerp(Color(1.0, 0.97, 0.88), 0.1 + 0.55 * t)
			col.a = 0.22
			w.draw_circle(c, side * (0.47 - 0.033 * float(k)), col)
		# Where the picture stands.
		var floor_c := r.get_center() + Vector2(0.0, side * 0.33)
		var pts := PackedVector2Array()
		for i in 24:
			var a := TAU * float(i) / 24.0
			pts.append(floor_c + Vector2(cos(a) * side * 0.3, sin(a) * side * 0.07))
		w.draw_colored_polygon(pts, Color(0.1, 0.03, 0.12, 0.28))
		# The rim: gold, with a cream catch of light along the top.
		var rim := StyleBoxFlat.new()
		rim.draw_center = false
		rim.border_color = Color(PaintScript.GOLD, 0.85 if not dim_now else 0.4)
		rim.set_border_width_all(2)
		rim.border_width_top = 3
		rim.set_corner_radius_all(int(radius))
		rim.anti_aliasing = true
		w.draw_style_box(rim, r))
	return w


## A price as the world's coin: the bits coin and the amount in gold numerals, no word "bits".
## `amount` < 0 shows `word` instead (OWNED, FREE), in cream on a plum pill.
static func price_tag(amount: int, word := "", px := 24, enabled := true) -> HBoxContainer:
	var tag := HBoxContainer.new()
	tag.name = "PriceTag"
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_theme_constant_override(&"separation", 6)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var words := Label.new()
	words.name = "Price"
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_theme_font_override(&"font", MenuStyleScript.numeral_font())
	if amount >= 0:
		var coin := MenuStyleScript.coin_icon(float(px) + 6.0)
		coin.modulate = Color(1, 1, 1) if enabled else Color(1, 1, 1, 0.5)
		tag.add_child(coin)
		words.text = str(amount)
		MenuStyleScript.style_label(words, px, PaintScript.GOLD if enabled
			else MenuStyleScript.COLOR_UNAFFORDABLE)
		words.add_theme_color_override(&"font_outline_color", PaintScript.PLUM_DARK)
		words.add_theme_constant_override(&"outline_size", 6)
	else:
		words.text = word
		MenuStyleScript.style_label(words, px - 4, MenuStyleScript.COLOR_TITLE)
		var pill := StyleBoxFlat.new()
		pill.bg_color = Color(0.36, 0.62, 0.36) if word == "OWNED" else PaintScript.PLUM
		pill.set_corner_radius_all(12)
		pill.content_margin_left = 10.0
		pill.content_margin_right = 10.0
		pill.content_margin_top = 1.0
		pill.content_margin_bottom = 2.0
		words.add_theme_stylebox_override(&"normal", pill)
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tag.add_child(words)
	return tag


## Keep `row` in the tile look: MouseRows' own exit handler puts the old dark row box back
## when the pointer leaves a row that is not the pick, so this one runs after it.
static func dress(row: PanelContainer, picked: bool, hovered: bool) -> void:
	row.add_theme_stylebox_override(&"panel", box(picked, hovered))
	if not picked:
		row.mouse_exited.connect(func() -> void:
			row.add_theme_stylebox_override(&"panel", box(false, false)))
