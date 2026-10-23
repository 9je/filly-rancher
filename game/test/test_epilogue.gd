extends GutTest
## The ending's epilogue (game/ui/epilogue.gd): it takes every press first, lets the cursor
## go, and hands the world back exactly once however fast somebody clicks through it.

const EpilogueScript := preload("res://ui/epilogue.gd")
const EndingsScript := preload("res://systems/endings.gd")


func _make() -> CanvasLayer:
	var holder := Node3D.new()
	add_child_autofree(holder)
	var ep: CanvasLayer = EpilogueScript.new()
	ep.ending = EndingsScript.LIGHTS_OUT
	holder.add_child(ep)
	return ep


func test_clicks_reach_it_and_the_cursor_is_free() -> void:
	var ep := _make()
	var veil: ColorRect = ep.get("_veil")
	assert_eq(veil.mouse_filter, Control.MOUSE_FILTER_IGNORE, "the veil does not eat clicks")
	assert_true(ep.has_method("_input"), "presses are taken in _input, ahead of the world")
	assert_eq(Input.mouse_mode, Input.MOUSE_MODE_VISIBLE)
	assert_true(ep.is_open())


func test_done_fires_once_however_many_presses() -> void:
	var ep := _make()
	var count := [0]
	ep.done.connect(func() -> void: count[0] += 1)
	for i in 8:
		ep.advance()
	assert_eq(count[0], 1)
	assert_false(ep.is_open())
