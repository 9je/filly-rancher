extends GutTest
## RAINBOW RUSH, THE SECOND MACHINE (owner 2026-11-11: "i wanted 2 slot machines"): the same
## shape as the classic machine, its own return, rarer and bigger wins.

const ClassicScript := preload("res://systems/slots.gd")
const RushScript := preload("res://systems/slots_rush.gd")


func test_rainbow_rush_returns_near_ninety_six_and_a_half_percent() -> void:
	var r: float = RushScript.return_to_player()
	assert_between(r, 0.955, 0.975, "Rainbow Rush returns %.4f" % r)


func test_it_is_the_bigger_gamble() -> void:
	assert_gt(RushScript.TRIPLE_PAYS[5], ClassicScript.TRIPLE_PAYS[5], "a bigger jackpot")
	var hits := func(script: GDScript) -> int:
		var n := 0
		for a in script.reel_strip(0):
			for b in script.reel_strip(1):
				for c in script.reel_strip(2):
					var r: Array[int] = [a, b, c]
					if script.payout(r, 1) > 0:
						n += 1
		return n
	assert_lt(int(hits.call(RushScript)), int(hits.call(ClassicScript)), "wins less often")


func test_the_menu_switches_machines() -> void:
	var menu = load("res://ui/slots_menu.tscn").instantiate()
	add_child_autofree(menu)
	menu.set("chips_provider", func() -> int: return 500)
	menu.call("open_machine", 1)
	assert_eq(menu.get("rules"), RushScript)
	assert_eq(String(menu.call("title_text")), "Rainbow Rush")
	menu.call("close")
	menu.call("open_machine", 0)
	assert_eq(menu.get("rules"), ClassicScript)
