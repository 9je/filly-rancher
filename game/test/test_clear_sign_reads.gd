extends GutTest
## THE PLOT'S PRICE READS (PS4, playtest 2026-11-05 item 26: '"CLEAR ME / 250 bits" signs:
## dark on brown, no light backing, unreadable [24]'). The board is paper faced (PT7), and
## nothing stands in front of it: the post holds it up from below and stops at its bottom
## edge (it used to run up through the middle of the board, over the price).

const PlotSlotScript := preload("res://world/plot_slot.gd")


func test_the_post_stops_under_the_board() -> void:
	var slot: Node3D = PlotSlotScript.new()
	add_child_autofree(slot)
	slot.call("set_overgrown", true, 250)
	await wait_frames(2)
	var sign := slot.find_child("Sign", true, false) as Node3D
	assert_not_null(sign, "an overgrown plot has its price sign")
	if sign == null:
		return
	var board := sign.get_node(^"Board") as Node3D
	var board_bottom := board.position.y - 0.55 * 0.5
	for c in sign.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh is BoxMesh:
			var top: float = (c as Node3D).position.y + ((c as MeshInstance3D).mesh as BoxMesh).size.y * 0.5
			assert_lte(top, board_bottom + 0.06, "the post ends at the board's bottom edge, not over the price")
