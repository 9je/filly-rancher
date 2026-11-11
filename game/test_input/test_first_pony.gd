extends "res://test_input/input_test.gd"
## PLAYTEST NOTE 1, "I could not collect the first pony". A fresh save, played from the title
## screen with keyboard and mouse only, following nothing but the onboarding prompts: the
## first beam attempt on the first pony must put her in the Scoop's bag.

var attempts := 0
## The action the prompt told us to hold, read off the tip text and nothing else.
var _beam_action := &""


func _play() -> void:
	_deadline_s = 300.0
	if not await boot_new_game():
		return
	if not await finish_creator():
		return
	await wait(1.0)
	await close_letter()
	note("in the ranch; waiting for Marigold")
	var people: Node = ranch.get("people")
	var t := 0.0
	var lp: Node = ranch.get("letter_panel")
	while t < 45.0 and not bool(people.call("is_talking")):
		# A person closes a letter that pops up while they wait.
		if bool(lp.call("is_open")):
			note("a letter opened; closing it")
			await click(lp.call("close_button_node"))
		await wait(0.2)
		t += 0.2
	if not check(bool(people.call("is_talking")), "Marigold never opened the welcome"):
		return
	await talk_through()
	note("welcome done; tip: '%s'" % hud_tip())
	var beam: Node = player.call("get_magic_beam")
	var bag: Object = beam.call("get_storage")
	t = 0.0
	while t < 120.0:
		var tip := hud_tip()
		if bool(people.call("is_talking")):
			note("a conversation opened (%s); reading it" % people.get("_speaker"))
			await talk_through()
		elif tip.contains("Scoop"):
			_beam_action = _action_named_in(tip)
			if not check(_beam_action != &"", "the Scoop prompt names no button: '%s'" % tip):
				return
			note("the prompt says to hold %s (%s)" % [_beam_action, tip])
			await _scoop_one(beam)
			if bag.call("count") >= 1:
				if check(attempts == 1, "caught her, but only on attempt %d" % attempts):
					ok("caught on the first try")
				return
			fail("attempt %d failed: %s" % [attempts, _why])
			return
		elif int(t * 10) % 50 == 0:
			note("waiting: talking=%s tip='%s' guide=%s" % [people.call("is_talking"), tip, ranch.call("guide_goal")])
			# THE TRAIL, AS A PERSON WOULD (2026-11-11): since the round-8 world the nearest
			# Drifter is not in reach of the arrival spot; the card says "Catch a Drifter" and
			# the compass points at one. Walk most of the way toward it, then look about.
			var target: Node3D = ranch.call("guide_target")
			if target != null and player.global_position.distance_to(target.global_position) > 7.0:
				var to := target.global_position - player.global_position
				await walk_to(player.global_position + to * 0.8, 2.0, 12.0)
				await look_at_point(target.global_position + Vector3(0, 0.8, 0), true)
			elif target != null:
				# Close: face her from a few metres off, the way you line up a catch.
				var away := player.global_position - target.global_position
				away.y = 0.0
				if away.length() < 5.0:
					await walk_to(target.global_position + away.normalized() * 6.0, 1.0, 6.0)
				await look_at_point(target.global_position + Vector3(0, 0.8, 0), true)
			else:
				RI.look(Vector2(60, 0))
		else:
			# No prompt yet: a person looks around for ponies.
			RI.look(Vector2(60, 0))
		await wait(0.1)
		t += 0.1
	fail("the Scoop prompt never appeared (last tip '%s')" % hud_tip())


var _why := ""


## Which action's key or button the tip names, as a person reading it would work it out.
func _action_named_in(tip: String) -> StringName:
	for a: StringName in InputMap.get_actions():
		if String(a).begins_with("ui_"):
			continue
		var n: String = RI.binding_name(a)
		if n.length() > 1 and tip.contains(" %s " % n):
			return a
	return &""


func _nearest_pony() -> Node3D:
	var best: Node3D = null
	var bd := INF
	for p: Node3D in ranch.get("spawner").call("get_spawned"):
		var d := p.global_position.distance_to(player.global_position)
		if d < bd:
			bd = d
			best = p
	return best


func _scoop_one(beam: Node) -> void:
	var pony := _nearest_pony()
	if pony == null:
		_why = "no pony in the world"
		return
	note("going for a pony %.1f m away; tip '%s'" % [pony.global_position.distance_to(player.global_position), hud_tip()])
	# The prompt says hold the beam on a pony: walk until she is comfortably in beam range.
	var tw := 0.0
	while is_instance_valid(pony) and pony.global_position.distance_to(player.global_position) > 6.5 \
			and tw < 25.0:
		await walk_to(pony.global_position, 6.0, 0.5)
		tw += 0.5
	if not is_instance_valid(pony):
		_why = "she vanished"
		return
	attempts += 1
	note("attempt %d at %.1f m, pony state %s" % [attempts, pony.global_position.distance_to(player.global_position), pony.get("state")])
	await look_at_point(pony.global_position + Vector3(0, 0.6, 0), true, 0.02, 60)
	# Evidence: lined up on her, before the button: her target ring and the Scoop line.
	await wait(0.3)
	var shots := ProjectSettings.globalize_path("res://").path_join("../build/playtest_evidence/first_pony")
	DirAccess.make_dir_recursive_absolute(shots)
	root.get_texture().get_image().save_png(shots.path_join("scoop_tip.png"))
	note("screenshot %s (beam target %s, she is %s, tip '%s')" % [shots.path_join("scoop_tip.png"),
		beam.call("get_target"), pony.name if is_instance_valid(pony) else "gone", hud_tip()])
	RI.press(_beam_action)
	var hold := 0.0
	var ever_held := false
	while hold < 8.0:
		await physics_frame
		hold += 1.0 / 60.0
		if is_instance_valid(pony) and not bool(beam.call("is_holding")):
			await look_at_point(pony.global_position + Vector3(0, 0.6, 0), true, 0.02, 2)
		ever_held = ever_held or bool(beam.call("is_holding"))
		if bool(beam.call("is_secured")):
			await physics(6)
			break
		if not is_instance_valid(pony):
			# Caught: the Scoop took her body (a freed node has no name to report).
			break
		if ever_held and not bool(beam.call("is_holding")):
			_why = "she got out of the beam after %.1fs (%s, loss %d)" % [hold, pony.name,
				int(beam.call("get_last_loss"))]
			break
	RI.release(_beam_action)
	await wait(0.5)
	if _why == "" and not ever_held:
		_why = "the beam never took hold (pony at %.1f m)" % (pony.global_position.distance_to(player.global_position) if is_instance_valid(pony) else -1.0)
