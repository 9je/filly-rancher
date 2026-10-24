extends "res://test_input/input_test.gd"
## PLAYTEST NOTE 2, "beam selection feels weird". With the Scoop in hand, a person aims near
## a pony, not dead on her: the pony the beam would take must be visibly highlighted BEFORE
## the press, a crosshair resting beside her (not on her) must still take her, and pointing
## at empty grass must highlight nobody.

const OFFSET_M := 0.9


func _play() -> void:
	_deadline_s = 400.0
	if not await boot_new_game() or not await finish_creator():
		return
	await wait(1.0)
	await close_letter()
	var people: Node = ranch.get("people")
	var t := 0.0
	var lp: Node = ranch.get("letter_panel")
	while t < 45.0 and not bool(people.call("is_talking")):
		if bool(lp.call("is_open")):
			await click(lp.call("close_button_node"))
		await wait(0.2)
		t += 0.2
	await talk_through()
	var beam: Node = player.call("get_magic_beam")

	# 1. Empty grass: nobody highlighted.
	var pony := _nearest_pony()
	if not check(pony != null, "no pony in the world"):
		return
	var away := player.global_position + (player.global_position - pony.global_position).normalized() * 6.0
	await look_at_point(away + Vector3(0, 0.3, 0), true, 0.02, 90)
	await physics(10)
	if not check(_highlighted().is_empty(),
			"aiming at empty grass highlights %s" % [_highlighted()]):
		return

	# 2. Walk up, aim BESIDE her, and she is the one highlighted.
	var tw := 0.0
	while is_instance_valid(pony) and pony.global_position.distance_to(player.global_position) > 6.0 \
			and tw < 25.0:
		await walk_to(pony.global_position, 5.5, 0.5)
		tw += 0.5
	if not check(is_instance_valid(pony), "she vanished"):
		return
	var side := (pony.global_position - player.global_position).cross(Vector3.UP).normalized()
	var aim := pony.global_position + Vector3(0, 0.6, 0) + side * OFFSET_M
	await look_at_point(aim, true, 0.01, 90)
	await physics(8)
	var lit := _highlighted()
	note("aimed %.1f m beside her at %.1f m: highlighted %s" % [OFFSET_M,
		pony.global_position.distance_to(player.global_position), lit])
	if not check(pony in lit, "aimed %.1f m beside a pony %.1f m away: she is not highlighted (%s)"
			% [OFFSET_M, pony.global_position.distance_to(player.global_position), lit]):
		return

	# Evidence: what the player sees with her lit.
	await frames(3)
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://").path_join("../build/playtest_evidence/beam_highlight.png"))

	# 3. The press takes the highlighted pony.
	RI.press(&"beam")
	var took: Object = null
	for i in 30:
		await physics_frame
		if bool(beam.call("is_holding")):
			took = beam.get("_held")
			break
	RI.release(&"beam")
	if not check(took == pony, "the press took %s, not the highlighted pony" % [took]):
		return
	ok("highlight before the press, aim assist %.1f m, and the press took her" % OFFSET_M)


func _nearest_pony() -> Node3D:
	var best: Node3D = null
	var bd := INF
	for p: Node3D in ranch.get("spawner").call("get_spawned"):
		var d := p.global_position.distance_to(player.global_position)
		if d < bd:
			bd = d
			best = p
	return best


## Which ponies are wearing the beam's highlight, read off what is drawn: an outline lit in
## the beam's colour on her meshes.
func _highlighted() -> Array:
	var out := []
	for p: Node3D in ranch.get("spawner").call("get_spawned"):
		for m in p.find_children("*", "GeometryInstance3D", true, false):
			var g := m as GeometryInstance3D
			var h = g.get_instance_shader_parameter(&"highlight")
			if h is Color and (h as Color).a > 0.0 and g.is_visible_in_tree():
				out.append(p)
				break
	return out
