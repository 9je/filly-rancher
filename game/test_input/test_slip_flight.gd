extends "res://test_input/input_test.gd"
## OWNER PLAYTEST 2026-10-25: "i beamed this pony and they just flew". A pony who slips out
## of the beam (let go too soon) must come down onto the ground and run off along it: never
## more than MAX_ABOVE m over the terrain, landed within LAND_S, and never faster than a
## pony can run. Played from a fresh save with real input, five slips.

const MAX_ABOVE := 1.6
const LAND_S := 1.5
const MAX_SPEED := 9.0

var _beam_action := &"beam"


func _play() -> void:
	_deadline_s = 400.0
	if not await boot_new_game():
		return
	if not await finish_creator():
		return
	await wait(1.0)
	await close_letter()
	var people: Node = ranch.get("people")
	var t := 0.0
	while t < 45.0 and not bool(people.call("is_talking")):
		await wait(0.2)
		t += 0.2
	await talk_through()
	var beam: Node = player.call("get_magic_beam")
	var slips := 0
	var worst := ""
	var tries := 0
	while slips < 5 and tries < 25:
		tries += 1
		if bool(people.call("is_talking")):
			await talk_through()
			continue
		var pony := _nearest_pony()
		if pony == null:
			RI.look(Vector2(200, 0))
			await wait(0.5)
			continue
		var tw := 0.0
		while is_instance_valid(pony) and pony.global_position.distance_to(player.global_position) > 6.0 \
				and tw < 20.0:
			await walk_to(pony.global_position, 5.5, 0.5)
			tw += 0.5
		if not is_instance_valid(pony):
			continue
		await look_at_point(pony.global_position + Vector3(0, 0.6, 0), true, 0.02, 60)
		RI.press(_beam_action)
		var h := 0.0
		while h < 2.0 and not bool(beam.call("is_holding")):
			await physics_frame
			h += 1.0 / 60.0
		if not bool(beam.call("is_holding")):
			RI.release(_beam_action)
			await wait(0.3)
			continue
		var held: Node3D = beam.call("get_held_body")
		await wait(0.35)
		RI.release(_beam_action)
		slips += 1
		var r := await _track(held)
		note("slip %d (%s): %s" % [slips, held.name, r])
		if r.begins_with("BAD"):
			worst = r
			break
		await wait(1.0)
	if worst != "":
		fail("a slipped pony flew: %s" % worst)
		return
	if not check(slips >= 3, "only %d slips in %d tries" % [slips, tries]):
		return
	ok("%d slipped ponies all came down and ran along the ground" % slips)


## Follow her for three seconds after the slip.
func _track(p: Node3D) -> String:
	var top := 0.0
	var landed := -1.0
	var fastest := 0.0
	var last := p.global_position
	var s := 0.0
	while s < 3.0 and is_instance_valid(p):
		await physics_frame
		s += 1.0 / 60.0
		var pos := p.global_position
		var above: float = pos.y - ranch.get_node("Terrain").call("surface_height_at", pos.x, pos.z)
		top = maxf(top, above)
		if landed < 0.0 and above < 0.15:
			landed = s
		fastest = maxf(fastest, (pos - last).length() * 60.0)
		last = pos
	var r := "top %.2f m over the ground, landed at %.2f s, fastest %.1f m/s" % [top, landed, fastest]
	if top > MAX_ABOVE or landed < 0.0 or landed > LAND_S or fastest > MAX_SPEED:
		return "BAD " + r
	return r


func _nearest_pony() -> Node3D:
	var best: Node3D = null
	var bd := INF
	for p: Node3D in ranch.get("spawner").call("get_spawned"):
		var d := p.global_position.distance_to(player.global_position)
		if d < bd:
			bd = d
			best = p
	return best
