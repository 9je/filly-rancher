extends GutTest
## A STUMBLE ON A HARD LANDING (PS10, known gap G4; FS4.3: "a stumble when the player lands
## hard"). A normal jump lands with the bounce alone; a real drop (STUMBLE_FROM and up) also
## pitches her forward and back and slows her for a moment.

const PlayerScript := preload("res://actors/player/player.gd")


func test_only_a_real_drop_stumbles() -> void:
	var jump := sqrt(2.0 * 9.8 * PlayerScript.JUMP_HEIGHT)
	assert_eq(PlayerScript.stumble_for(jump), 0.0, "a normal jump's landing (%.1f m/s) does not" % jump)
	assert_gt(PlayerScript.stumble_for(PlayerScript.STUMBLE_FROM + 0.5), 0.0, "a drop does")
	assert_lte(PlayerScript.stumble_for(40.0), 1.0, "however far")


func test_a_stumble_pitches_her_and_slows_her_for_a_moment() -> void:
	var p: CharacterBody3D = (load("res://actors/player/player.tscn") as PackedScene).instantiate()
	add_child_autofree(p)
	await wait_frames(2)
	assert_eq(float(p.call("stumble_slow")), 1.0, "before: full speed")
	p.call("stumble", 1.0)
	assert_lt(float(p.call("stumble_slow")), 0.8, "she is slowed")
	var most := 0.0
	for i in 40:
		await wait_physics_frames(1)
		most = maxf(most, absf((p.get("visuals") as Node3D).rotation.x))
	assert_gt(most, 0.2, "and pitches forward")
	await wait_seconds(PlayerScript.STUMBLE_SECONDS + 0.5)
	assert_eq(float(p.call("stumble_slow")), 1.0, "for a moment only")
	assert_almost_eq((p.get("visuals") as Node3D).rotation.x, 0.0, 0.02, "and stands straight again")
