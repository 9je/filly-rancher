class_name BlobShadow
extends Decal
## A SOFT OVAL OF SHADE UNDER EVERYONE WHO MOVES (P8 S4; docs/aaa-review-2026-11-08.md 2.1
## and 2.2). The show, Slime Rancher and Animal Crossing all stand their characters on the
## ground this way: with hard sun shadows a pony's own cast shadow falls off to one side, or
## nowhere at noon and inside a building's shade, and she floated. A Decal on the body's root
## (not her visuals, so it never tips with her), projecting straight down onto whatever she
## stands on, faded out above her hooves so her legs are not painted.

const HEIGHT := 0.8

static var _texture: GradientTexture2D


## Put one under `body`, `length` metres nose to tail and `width` across.
static func attach(body: Node3D, length: float, width: float) -> BlobShadow:
	var b := BlobShadow.new()
	b.name = "BlobShadow"
	b.size = Vector3(width, HEIGHT, length)
	b.position = Vector3(0, HEIGHT * 0.25, 0)
	b.texture_albedo = _tex()
	b.modulate = Color(0.16, 0.14, 0.3, 0.42)
	b.upper_fade = 0.15
	b.lower_fade = 0.3
	b.distance_fade_enabled = true
	b.distance_fade_begin = 45.0
	b.distance_fade_length = 15.0
	body.add_child(b)
	return b


static func _tex() -> GradientTexture2D:
	if _texture != null:
		return _texture
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.55, Color(1, 1, 1, 0.85))
	_texture = GradientTexture2D.new()
	_texture.gradient = g
	_texture.fill = GradientTexture2D.FILL_RADIAL
	_texture.fill_from = Vector2(0.5, 0.5)
	_texture.fill_to = Vector2(0.5, 0.0)
	_texture.width = 64
	_texture.height = 64
	return _texture
