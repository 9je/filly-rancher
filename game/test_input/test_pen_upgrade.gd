extends "res://test_input/input_test.gd"
## ROUND 2 (owner playtest 2026-10-25), notes 1, 2 and 4, played with keyboard and mouse only:
##   - a Paddock is built by walking onto the first plot, reading "build here", pressing the
##     key the prompt names and clicking the Paddock card;
##   - standing at it with an empty saddlebag, the prompt names the upgrade and its price,
##     and the key opens an upgrade card that keeps her residents;
##   - the third plot is under brambles: its prompt names the clearing and its price, and with
##     too few bits the card says "Not enough bits" and nothing is spent.
## SETUP, NOT PLAY: the wallet is seeded with 200 bits (the way test_loading seeds story
## flags), because earning them is the job of every other test.
## Screenshots go to build/playtest_evidence/round2/.

const InteractionScript := preload("res://world/interaction.gd")

var _shots := ""


func _play() -> void:
	_deadline_s = 420.0
	_shots = ProjectSettings.globalize_path("res://").path_join("../build/playtest_evidence/round2")
	DirAccess.make_dir_recursive_absolute(_shots)
	if not await boot_new_game():
		return
	if not await finish_creator():
		return
	await wait(1.0)
	await close_letter()
	await _settle(40.0)

	# PRICES FROM THE CATALOGUE, not pinned here (PS9 item 69 raised them by 15%): her bits
	# are the Big Pen's price and 50 more, so the upgrade leaves 50, short of any clearing.
	var big_cost := int((load("res://data/plots/pen_large.tres") as Resource).get("cost"))
	var econ: Object = ranch.call("get_economy")
	econ.set("bits", big_cost + 50)
	var slots: Array = ranch.call("plot_slots")
	var s1: Node3D = _slot(slots, "slot_1")
	var s3: Node3D = _slot(slots, "slot_3")
	if not check(s1 != null and s3 != null, "no slot_1 / slot_3 on the map"):
		return
	if not check(bool(s3.call("is_overgrown")), "plot 3 should start under brambles"):
		return
	if not check(not bool(s1.call("is_overgrown")), "plot 1 should start open"):
		return

	# 1. Build a Paddock on plot 1, from its gate side.
	if not await _stand_at(s1, InteractionScript.Kind.PLOT_BUILD, 4.55, true):
		return
	note("prompt at plot 1: '%s'" % _prompt())
	await tap(&"interact")
	await wait(0.5)
	var bm: Node = ranch.get("build_menu")
	if not check(bool(bm.call("is_open")), "E on plot 1 did not open the build menu (refusal: %s, prompt now '%s')"
			% [ranch.call("last_denial"), _prompt()]):
		return
	var rows: Array = bm.call("row_nodes")
	await click(rows[0])
	await wait(0.8)
	if not check(s1.call("get_built") != null, "clicking the Paddock card built nothing"):
		return
	note("built: %s" % s1.call("saved_plot_id"))

	# 2. Upgrade it.
	if not await _stand_at(s1, InteractionScript.Kind.PEN_UPGRADE, 4.5, false):
		return
	var tip := _prompt()
	note("prompt at the Paddock: '%s'" % tip)
	if not check(tip.contains("upgrade to Big Pen (%d bits)" % big_cost),
			"the Paddock's prompt does not name the upgrade: '%s'" % tip):
		return
	await wait(0.4)
	_shot("upgrade_prompt.png")
	await tap(&"interact")
	await wait(0.6)
	if not check(bool(bm.call("is_open")) and int(bm.call("mode")) == 1,
			"E at the Paddock did not open the upgrade card"):
		return
	await wait(0.3)
	_shot("upgrade_card.png")
	await click((bm.call("row_nodes") as Array)[0])
	await wait(0.8)
	var pen: Node = s1.call("get_built")
	if not check(String(s1.call("saved_plot_id")) == "pen_large" and int(pen.get("capacity")) == 6,
			"the upgrade did not make a Big Pen (%s)" % s1.call("saved_plot_id")):
		return
	if not check(int(econ.get("bits")) == 50, "it should have cost %d of %d bits, left %d"
			% [big_cost, big_cost + 50, int(econ.get("bits"))]):
		return
	note("upgraded: %s, %d bits left" % [s1.call("saved_plot_id"), int(econ.get("bits"))])

	# 3. The brambles on plot 3, with 50 bits to a dearer clearing.
	await _walk_round_to(s3)
	if not await _stand_at(s3, InteractionScript.Kind.PLOT_CLEAR, 4.5, false):
		return
	tip = _prompt()
	note("prompt at plot 3: '%s'" % tip)
	var clear_cost := int(s3.call("clear_cost"))
	if not check(tip.contains("clear this plot (%d bits), not enough bits" % clear_cost),
			"plot 3's prompt does not name the clearing and the shortfall: '%s'" % tip):
		return
	await look_at_point(s3.global_position + Vector3(0, 1.6, 0), true, 0.05, 60)
	await wait(0.4)
	_shot("clear_prompt.png")
	await tap(&"interact")
	await wait(0.6)
	if not check(bool(bm.call("is_open")) and int(bm.call("mode")) == 2,
			"E at plot 3 did not open the clearing card"):
		return
	await click((bm.call("row_nodes") as Array)[0])
	await wait(0.5)
	var short: Label = (bm.call("row_nodes") as Array)[0].find_child("Short", true, false)
	if not check(short != null and short.visible and short.text.contains("Not enough bits"),
			"the clearing card does not say not enough bits"):
		return
	_shot("clear_card_short.png")
	if not check(bool(s3.call("is_overgrown")) and int(econ.get("bits")) == 50,
			"an unaffordable clearing changed something"):
		return
	await tap(&"ui_cancel")
	ok("built a Paddock, upgraded it to a Big Pen for %d, and was told plot 3 needs %d" % [big_cost, clear_cost])


func _slot(slots: Array, id: String) -> Node3D:
	for s: Node3D in slots:
		if String(s.get("slot_id")) == id:
			return s
	return null


func _prompt() -> String:
	var hud := ranch.get_node_or_null(^"HUD")
	return str(hud.call("prompt_text")) if hud != null else ""


func _shot(file: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(_shots.path_join(file))
	note("screenshot %s" % _shots.path_join(file))


## Read the screen the way a person would: a conversation or a letter in the way is read
## and closed before anything else.
func _settle(secs: float) -> void:
	var people: Node = ranch.get("people")
	var lp: Node = ranch.get("letter_panel")
	var t := 0.0
	var quiet := 0.0
	while t < secs and quiet < 4.0:
		if bool(people.call("is_talking")):
			await talk_through()
			quiet = 0.0
		elif bool(lp.call("is_open")):
			await click(lp.call("close_button_node"))
			quiet = 0.0
		else:
			quiet += 0.2
		await wait(0.2)
		t += 0.2


## Walk to `slot`'s open side, `out` metres from its centre, and step in or out until the
## resolver offers `kind` there (and, for a build, says "build here" with no refusal).
func _stand_at(slot: Node3D, kind: int, out: float, need_clean: bool) -> bool:
	var side: Vector3 = slot.global_basis.x
	for i in 12:
		var at: Vector3 = slot.global_position + side * out
		await walk_to(at, 0.3, 15.0)
		await physics(6)
		# STANDING, not still gliding off the walk: a press while she drifts 6 cm over the
		# marker line is refused, and the prompt read a frame earlier was right (PT4 run).
		for settle in 60:
			if Vector2(player.velocity.x, player.velocity.z).length() < 0.01:
				break
			await physics(1)
		if bool(ranch.get("people").call("is_talking")):
			await talk_through()
		var act: Dictionary = ranch.call("current_interaction")
		var mine := int(act.get("kind", 0)) == kind \
			and str(act.get("subject", "")) == String(slot.name)
		if mine and (not need_clean or str(act.get("reason", "")) == ""):
			return true
		out = clampf(out + (0.12 if mine else -0.1), 4.3, 4.75)
	fail("never offered kind %d at %s (last: %s, prompt '%s')" % [kind, slot.name,
		ranch.call("current_interaction"), _prompt()])
	return false


## Round the outside of the plots, not through a fence.
func _walk_round_to(slot: Node3D) -> void:
	var p: Vector3 = player.global_position
	var far: Vector3 = slot.global_position + slot.global_basis.x * 4.6
	await walk_to(Vector3(p.x, p.y, 5.0), 0.8, 15.0)
	await walk_to(Vector3(far.x, p.y, 5.0), 0.8, 20.0)
	await walk_to(far, 0.6, 15.0)
