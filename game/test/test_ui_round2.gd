extends GutTest
## Fable AAA round 2's UI items, the facts under the renders (docs/fable-aaa-round2-2026-11-09.md
## #8 to #10 and the lower list).

const StyleIconTintScript := preload("res://ui/style_icon_tint.gd")
const MouseRowsScript := preload("res://ui/mouse_rows.gd")
const MenuStyleScript := preload("res://ui/menu_style.gd")
const TileStyleScript := preload("res://ui/tile_style.gd")


## The creator's cards: the bake's two keys become her coat and mane, shade kept; nothing
## else on the card changes.
func test_the_style_cards_take_her_coat_and_mane() -> void:
	var img := Image.create(3, 1, false, Image.FORMAT_RGBA8)
	img.set_pixel(0, 0, StyleIconTintScript.KEY_COAT)
	img.set_pixel(1, 0, StyleIconTintScript.KEY_MANE)
	var eye := Color(0.3, 0.55, 0.85)
	img.set_pixel(2, 0, eye)
	var coat := Color(0.8, 0.72, 0.92)
	var mane := Color(0.15, 0.12, 0.3)
	StyleIconTintScript.recolour(img, coat, mane)
	assert_true(img.get_pixel(0, 0).is_equal_approx(coat) or
		_close(img.get_pixel(0, 0), coat, 0.03), "the coat key is her coat: %s" % img.get_pixel(0, 0))
	assert_true(_close(img.get_pixel(1, 0), mane, 0.03), "the mane key is her mane: %s" % img.get_pixel(1, 0))
	assert_true(_close(img.get_pixel(2, 0), eye, 0.01), "the eyes are left alone")


func _close(a: Color, b: Color, tol: float) -> bool:
	return absf(a.r - b.r) < tol and absf(a.g - b.g) < tol and absf(a.b - b.b) < tol


## Every menu's Back is the kit's one sized button, not a tiny pill.
func test_every_back_is_the_kit_back_button() -> void:
	var b: Button = MouseRowsScript.close_button(MouseRowsScript.CLOSE_TEXT, Callable())
	autofree(b)
	assert_gte(b.custom_minimum_size.x, MenuStyleScript.BACK_SIZE.x)
	assert_gte(b.custom_minimum_size.y, MenuStyleScript.BACK_SIZE.y)
	assert_not_null(b.get_node_or_null(^"Chevron"), "it points back")
	var box := b.get_theme_stylebox(&"normal") as StyleBoxFlat
	assert_not_null(box)
	assert_eq(box.bg_color, MenuStyleScript.BACK_FILL, "plum, the panel's own colour")


## A price is the coin and a number.
func test_a_price_is_a_coin_and_a_number() -> void:
	var tag: HBoxContainer = TileStyleScript.price_tag(140)
	autofree(tag)
	assert_true(tag.get_child(0) is TextureRect, "the coin first")
	assert_eq((tag.get_node(^"Price") as Label).text, "140", "no word 'bits'")


## No menu over a shot: nothing is playing until something plays.
func test_no_cinematic_is_playing_by_default() -> void:
	assert_false(Cinematic.is_playing())
