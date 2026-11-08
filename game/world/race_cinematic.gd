class_name RaceCinematic
extends RefCounted
## WATCH THE RACE YOU BACKED (P8 S8; owner playtest 2026-11-08 items 63 and 64: "wants to see
## the race, maybe a cinematic", "i also idk who i bet on"; reference GTA Online's Inside Track).
## When a bet goes down the camera leaves the hall for the track on the Strip: the field at the
## gate, then alongside her the length of the straight, then the wire. Her own runner wears the
## beam's gold ring (outline.gdshader `highlight`) and her name stays on screen as the caption,
## so there is no doubt who is yours. The result itself is the ranch's toast at the wire.

const RaceCardScript := preload("res://systems/race_card.gd")
const PICK_RING := Color(1.0, 0.82, 0.25, 1.0)


static func play(ranch: Node, track: Node3D, result: Dictionary, pick_name: String) -> void:
	if ranch == null or track == null or not ranch.is_inside_tree():
		return
	var lane: int = RaceCardScript.PLAYER_LANE
	var times: Array = result.get("times", [])
	var total := 0.0
	for t in times:
		total = maxf(total, float(t))
	if total <= 0.0:
		total = 12.0
	var runner: Node3D = track.call("runner", lane)
	_ring(runner, PICK_RING)
	var sky: Node = ranch.get("sky_rig")
	var was_indoors: bool = sky != null and bool(sky.call("is_indoors"))
	if was_indoors:
		sky.call("set_indoors", false)
	var p := func(l: int, t: float) -> Vector3:
		return track.to_global(track.call("lane_point", l, t))
	var gate: Vector3 = p.call(lane, 0.0)
	var mid_lane := 2
	var stands := Vector3(0.0, 0.0, -1.0)
	var caption := "Your pick: %s" % pick_name
	var shots := [
		{"from": gate + Vector3(-7.0, 3.2, -9.0), "to": gate + Vector3(-5.0, 2.6, -7.5),
			"look": p.call(mid_lane, 0.04) + Vector3.UP, "time": 1.8,
			"caption": "And they're off!  %s" % caption},
		{"from": p.call(lane, 0.08) + stands * 6.0 + Vector3.UP * 2.2,
			"to": p.call(lane, 0.78) + stands * 6.0 + Vector3.UP * 2.2,
			"look_node": runner, "look_height": 1.0, "time": total * 0.72, "fov": 50.0,
			"caption": caption},
		{"from": p.call(mid_lane, 1.0) + Vector3(5.0, 2.4, -7.0),
			"to": p.call(mid_lane, 1.0) + Vector3(4.0, 2.0, -6.0),
			"look": p.call(mid_lane, 0.9) + Vector3.UP, "time": total * 0.3 + 1.6,
			"caption": "Down to the wire!  %s" % caption},
	]
	var player: Node = ranch.get("player")
	await Cinematic.shared(ranch.get_tree()).play(shots, {"freeze": [player], "host": ranch})
	if was_indoors and sky != null and bool(ranch.call("is_in_palace")):
		sky.call("set_indoors", true)
	_ring(runner, Color(0, 0, 0, 0))


static func _ring(runner: Node3D, colour: Color) -> void:
	if runner == null or not is_instance_valid(runner):
		return
	for mi: MeshInstance3D in runner.find_children("*", "MeshInstance3D", true, false):
		mi.set_instance_shader_parameter(&"highlight", colour)
