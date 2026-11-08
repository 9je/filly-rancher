class_name ShopIcon
extends "res://ui/catch_icon.gd"
## ONE PICTURE ON A MARKET TILE (game/ui/market_menu.gd), in the catch card's own drawn style
## and on its 30 x 30 grid: the foods are the catch card's (CatchIcon draws them), and this
## adds the gear, the permits, the four gems and the sell-everything coin pile. No image
## files and no font glyphs, so a fresh checkout has every picture.

## Every kind this draws, for the test that each one draws something.
const KINDS: Array[StringName] = [&"hay", &"carrot", &"apple", &"daisy", &"daffodil",
	&"bigger_saddlebag", &"calm_lamp", &"depot_cart", &"express_chute", &"gallop_shoes",
	&"gem_chute", &"long_beam", &"lure_post", &"pony_whistle", &"scoop_launcher",
	&"steward_monocle", &"yield_lens", &"permit_everfree", &"permit_lake",
	&"permit_nightmeadow", &"permit_orchard", &"gem_0", &"gem_1", &"gem_2", &"gem_3",
	&"sell_all", &"pen_small", &"pen_large", &"pen_grand", &"upgrade", &"clear"]
const FOODS: Array[StringName] = [&"hay", &"carrot", &"apple", &"daisy", &"daffodil"]

## A gem's colour by PonyData.Rarity: common, uncommon, rare, legendary.
const GEM_COLOURS: Array[Color] = [Color(0.72, 0.86, 0.95), Color(0.45, 0.85, 0.55),
	Color(0.45, 0.55, 1.0), Color(1.0, 0.72, 0.25)]
## A permit's seal by zone, the colour each region is known by.
const PERMIT_COLOURS := {&"permit_everfree": Color(0.30, 0.55, 0.32),
	&"permit_lake": Color(0.35, 0.62, 0.95), &"permit_nightmeadow": Color(0.45, 0.40, 0.85),
	&"permit_orchard": Color(0.92, 0.32, 0.30)}
const WOOD := Color(0.62, 0.42, 0.26)
const BRASS := Color(0.95, 0.76, 0.32)
const PAPER := Color(0.98, 0.94, 0.82)


## The kind a ShopItem is drawn as: its food, its gear, or its permit's zone.
static func kind_for(item: ShopItem) -> StringName:
	if item == null:
		return &""
	if item.food_id != &"":
		return item.food_id
	if item.gear_id != &"":
		return item.gear_id
	if item.permit_zone != &"":
		return StringName("permit_" + String(item.permit_zone))
	return item.id


## THE DECORATIONS ARE PICTURES OF THEMSELVES (PS6, G14: every decor tile on the Market was a
## blank grey disc, because no drawing here knew a single decoration). Each is the real prop,
## or the real pony in stone, baked to a cut-out picture by game/scenes/test/decor_icons.gd.
const DECOR_PICTURES := "res://assets/ui/decor_icons/"
const DecorScript := preload("res://systems/decor.gd")


static var _pictures: Dictionary = {}


## A decoration's baked picture (`kind` is its ShopItem id, "decor_<id>"), or null. Cached, and
## loaded in _ready() rather than first inside _draw(): a texture first loaded mid draw came out
## as a plain white square on the tile.
static func picture(k: StringName) -> Texture2D:
	if _pictures.has(k):
		return _pictures[k]
	var path := DECOR_PICTURES + String(k) + ".png"
	var tex: Texture2D = null
	if String(k).begins_with("decor_") and ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	_pictures[k] = tex
	return tex


func _ready() -> void:
	for d: Dictionary in DecorScript.CATALOGUE:
		picture(StringName("decor_" + String(d.id)))


static func draws(k: StringName) -> bool:
	return k in KINDS or picture(k) != null


func _draw() -> void:
	var baked := picture(kind)
	if baked != null:
		# Inset so the cut-out's corners stay inside the tile's round cream disc.
		var side: float = minf(size.x, size.y) * 0.84
		draw_texture_rect(baked, Rect2((size - Vector2(side, side)) * 0.5, Vector2(side, side)),
			false)
		return
	if kind in FOODS:
		super._draw()
		return
	if draw_from_set(self, String(kind), size):
		return
	var s: float = minf(size.x, size.y) / 30.0
	draw_set_transform(Vector2((size.x - 30.0 * s) * 0.5, (size.y - 30.0 * s) * 0.5),
		0.0, Vector2(s, s))
	var c := Vector2(15, 15)
	var k := String(kind)
	if k.begins_with("gem_"):
		_gem(c, 11.0, GEM_COLOURS[clampi(int(k.substr(4)), 0, 3)])
	elif k.begins_with("permit_"):
		_scroll(PERMIT_COLOURS.get(kind, BRASS))
	else:
		_gear(kind, c)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _gem(at: Vector2, r: float, fill: Color) -> void:
	var pts := PackedVector2Array([at + Vector2(-r, -r * 0.35), at + Vector2(-r * 0.5, -r * 0.85),
		at + Vector2(r * 0.5, -r * 0.85), at + Vector2(r, -r * 0.35), at + Vector2(0, r)])
	_poly(pts, fill)
	draw_line(at + Vector2(-r, -r * 0.35), at + Vector2(r, -r * 0.35), OUTLINE, 1.2, true)
	draw_line(at + Vector2(-r * 0.35, -r * 0.35), at + Vector2(0, r), Color(1, 1, 1, 0.55), 1.2, true)
	sparkle(self, at + Vector2(r * 0.45, -r * 0.55), 3.0, Color(1, 1, 1, 0.9))


func _scroll(seal: Color) -> void:
	_poly(PackedVector2Array([Vector2(6, 6), Vector2(24, 6), Vector2(24, 24), Vector2(6, 24)]), PAPER)
	_circle(Vector2(6, 6), 2.6, PAPER.darkened(0.1))
	_circle(Vector2(24, 24), 2.6, PAPER.darkened(0.1))
	for y in [11.0, 14.5]:
		draw_line(Vector2(9, y), Vector2(21, y), Color(0.55, 0.48, 0.4), 1.3, true)
	_circle(Vector2(18, 20), 4.2, seal)
	star(self, Vector2(18, 20), 2.4, Color(1, 1, 1, 0.85), seal.darkened(0.3))


func _gear(k: StringName, c: Vector2) -> void:
	match k:
		&"bigger_saddlebag":
			_poly(PackedVector2Array([Vector2(5, 11), Vector2(25, 11), Vector2(23, 26),
				Vector2(7, 26)]), Color(0.70, 0.48, 0.30))
			_poly(PackedVector2Array([Vector2(5, 11), Vector2(25, 11), Vector2(21, 18),
				Vector2(9, 18)]), Color(0.58, 0.38, 0.22))
			_circle(Vector2(15, 17), 2.0, BRASS)
			draw_arc(Vector2(15, 11), 6.0, PI, TAU, 12, OUTLINE, 1.6, true)
			_poly(PackedVector2Array([Vector2(21, 3), Vector2(27, 3), Vector2(27, 9),
				Vector2(21, 9)]), Color(0.5, 0.85, 0.45))
			draw_line(Vector2(24, 4.5), Vector2(24, 7.5), Color(1, 1, 1), 1.6)
			draw_line(Vector2(22.5, 6), Vector2(25.5, 6), Color(1, 1, 1), 1.6)
		&"calm_lamp":
			draw_line(Vector2(15, 3), Vector2(15, 7), OUTLINE, 1.6, true)
			_poly(PackedVector2Array([Vector2(9, 7), Vector2(21, 7), Vector2(23, 23),
				Vector2(7, 23)]), Color(1.0, 0.92, 0.6))
			_circle(Vector2(15, 16), 3.6, Color(1.0, 0.7, 0.25))
			_poly(PackedVector2Array([Vector2(6, 23), Vector2(24, 23), Vector2(24, 27),
				Vector2(6, 27)]), BRASS)
		&"depot_cart":
			_poly(PackedVector2Array([Vector2(4, 9), Vector2(26, 9), Vector2(24, 20),
				Vector2(6, 20)]), WOOD)
			for x in [9.0, 15.0, 21.0]:
				draw_line(Vector2(x, 10), Vector2(x, 19), OUTLINE, 1.0, true)
			_circle(Vector2(9, 23), 3.8, Color(0.35, 0.25, 0.2))
			_circle(Vector2(21, 23), 3.8, Color(0.35, 0.25, 0.2))
		&"express_chute", &"gem_chute":
			_poly(PackedVector2Array([Vector2(4, 6), Vector2(10, 6), Vector2(26, 22),
				Vector2(26, 27), Vector2(20, 27), Vector2(4, 12)]), Color(0.75, 0.78, 0.85))
			if k == &"gem_chute":
				_gem(Vector2(19, 15), 5.0, GEM_COLOURS[2])
			else:
				CatchIcon.heart(self, Vector2(19, 14), 6.0, Color(1.0, 0.55, 0.7))
		&"gallop_shoes":
			horseshoe(self, Vector2(11, 16), 7.0, Color(0.75, 0.78, 0.85))
			for i in 3:
				draw_line(Vector2(19, 9 + i * 5), Vector2(27, 9 + i * 5), Color(1.0, 0.75, 0.3), 2.0, true)
		&"long_beam":
			draw_line(Vector2(4, 26), Vector2(26, 4), Color(1.0, 0.6, 0.9), 4.0, true)
			draw_line(Vector2(4, 26), Vector2(26, 4), Color(1, 1, 1, 0.8), 1.4, true)
			sparkle(self, Vector2(24, 6), 5.0, Color(1.0, 0.95, 0.6))
		&"lure_post":
			draw_line(Vector2(15, 27), Vector2(15, 9), WOOD, 3.0, true)
			CatchIcon.heart(self, Vector2(15, 9), 7.0, Color(1.0, 0.45, 0.6))
		&"pony_whistle":
			_poly(PackedVector2Array([Vector2(4, 13), Vector2(17, 13), Vector2(17, 20),
				Vector2(4, 20)]), BRASS)
			_circle(Vector2(19, 17), 5.5, BRASS)
			_circle(Vector2(19, 17), 2.0, Color(0.3, 0.22, 0.2))
			for i in 3:
				draw_arc(Vector2(19, 17), 8.0 + i * 3.0, -PI * 0.45, -PI * 0.1, 6,
					Color(0.55, 0.65, 0.95), 1.4, true)
		&"scoop_launcher":
			draw_arc(Vector2(15, 24), 12.0, PI * 1.1, PI * 1.9, 16, Color(1.0, 0.6, 0.9), 2.4, true)
			_poly(PackedVector2Array([Vector2(22, 9), Vector2(28, 12), Vector2(23, 16)]),
				Color(1.0, 0.6, 0.9))
			_circle(Vector2(6, 22), 4.0, Color(0.75, 0.78, 0.85))
		&"steward_monocle":
			draw_arc(Vector2(13, 13), 8.0, 0, TAU, 24, BRASS, 3.0, true)
			draw_circle(Vector2(13, 13), 6.6, Color(0.75, 0.9, 1.0, 0.55))
			draw_line(Vector2(19, 19), Vector2(26, 27), BRASS, 1.6, true)
		&"yield_lens":
			draw_arc(Vector2(12, 12), 8.0, 0, TAU, 24, Color(0.45, 0.35, 0.3), 3.0, true)
			draw_circle(Vector2(12, 12), 6.6, Color(0.75, 0.9, 1.0, 0.55))
			draw_line(Vector2(18, 18), Vector2(26, 26), Color(0.45, 0.35, 0.3), 4.0, true)
			_gem(Vector2(12, 12), 3.6, GEM_COLOURS[3])
		&"pen_small", &"pen_large", &"pen_grand":
			# A fence that grows with the pen: two, three or four bays, rails gold on the grand.
			var bays: int = {&"pen_small": 2, &"pen_large": 3, &"pen_grand": 4}[k]
			var rail := BRASS if k == &"pen_grand" else WOOD
			var w := 24.0 / bays
			for i in bays + 1:
				var x := 3.0 + i * w
				_poly(PackedVector2Array([Vector2(x - 1.3, 8), Vector2(x + 1.3, 8),
					Vector2(x + 1.3, 26), Vector2(x - 1.3, 26)]), WOOD.darkened(0.15))
			for y in [12.0, 19.0]:
				draw_line(Vector2(3, y), Vector2(27, y), rail, 2.6, true)
			CatchIcon.heart(self, Vector2(15, 5), 3.2, Color(1.0, 0.55, 0.7))
		&"upgrade":
			_gear(&"pen_large", c)
			_poly(PackedVector2Array([Vector2(19, 12), Vector2(25, 4), Vector2(31, 12),
				Vector2(27, 12), Vector2(27, 18), Vector2(23, 18), Vector2(23, 12)]),
				Color(0.45, 0.85, 0.45))
		&"clear":
			for a in [-0.9, -0.3, 0.3, 0.9]:
				var tip := Vector2(15, 26) + Vector2(sin(a), -cos(a)) * 16.0
				draw_line(Vector2(15, 26), tip, Color(0.28, 0.45, 0.22), 3.0, true)
				_circle(tip, 2.6, Color(0.42, 0.6, 0.3))
			draw_line(Vector2(6, 8), Vector2(24, 22), Color(0.75, 0.78, 0.85), 2.6, true)
			draw_line(Vector2(24, 8), Vector2(6, 22), Color(0.75, 0.78, 0.85), 2.6, true)
			_circle(Vector2(15, 15), 2.2, Color(0.9, 0.3, 0.3))
		&"sell_all":
			for i in 3:
				var y := 24.0 - i * 5.0
				draw_circle(Vector2(15, y), 8.0, BRASS.darkened(0.15 * (2 - i)))
				draw_arc(Vector2(15, y), 8.0, 0, TAU, 20, OUTLINE, 1.2, true)
			_circle(Vector2(15, 14), 8.0, BRASS)
			draw_arc(Vector2(15, 14), 5.2, 0, TAU, 16, Color(0.75, 0.55, 0.15), 1.4, true)
			sparkle(self, Vector2(22, 7), 4.0, Color(1, 1, 1, 0.95))
