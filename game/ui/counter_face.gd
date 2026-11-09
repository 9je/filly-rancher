class_name CounterFace
extends RefCounted
## THE FACE BEHIND A COUNTER (Fable AAA round 4: the Depot and the Market "read as admin
## panels"): a pony's baked portrait (scenes/test/counter_portraits.gd) clipped to a disc of
## `backdrop`, a gold ring over its edge. The Depot shows Marigold, the Market Bramble.
##
## Static only. Preload by path.

const PaintScript := preload("res://ui/casino_paint.gd")


static func build(portrait: String, px: float, backdrop: Color) -> Control:
	var holder := Control.new()
	holder.name = "Face"
	holder.custom_minimum_size = Vector2(px, px)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var face := Panel.new()
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.set_anchors_preset(Control.PRESET_FULL_RECT)
	face.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	var disc := StyleBoxFlat.new()
	disc.bg_color = backdrop
	disc.set_corner_radius_all(int(px * 0.5))
	disc.anti_aliasing = true
	face.add_theme_stylebox_override(&"panel", disc)
	holder.add_child(face)
	if ResourceLoader.exists(portrait):
		var pic := TextureRect.new()
		pic.texture = load(portrait) as Texture2D
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		pic.set_anchors_preset(Control.PRESET_FULL_RECT)
		# A little closer than the bake, the eyes at the disc's middle.
		pic.offset_left = -px * 0.14
		pic.offset_right = px * 0.06
		pic.offset_top = -px * 0.04
		pic.offset_bottom = px * 0.16
		face.add_child(pic)
	var ring := Panel.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	var rb := StyleBoxFlat.new()
	rb.draw_center = false
	rb.border_color = PaintScript.GOLD
	rb.set_border_width_all(4 if px >= 90.0 else 3)
	rb.set_corner_radius_all(int(px * 0.5))
	rb.anti_aliasing = true
	ring.add_theme_stylebox_override(&"panel", rb)
	holder.add_child(ring)
	return holder
