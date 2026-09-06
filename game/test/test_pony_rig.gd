extends GutTest
## HOW FREE THE HAIR IS ALLOWED TO BE AT THE SPEED SHE IS ACTUALLY MOVING.
##
## docs/notes-hair-sim.md section 11.1: Godot's spring solver pulls a joint's tail back
## toward its rest direction by `stiffness * delta`, an absolute displacement, so the
## configured stiffness IS a restoring speed in metres per second. A chain holds its shape
## only while that speed comfortably exceeds how fast its anchor is dragged through the
## world. The player's own rig runs its tail at 4.33 m/s and its mane locks at 3.70 m/s,
## measured, while Player.RUN_SPEED is 5.2 -- so at the default travel speed the hair has
## no authority at all and streams. Raising the profiles is not the way out: the same
## profiles are certified on Twilight at walking pace and would go rigid.
##
## So the simulator's `influence` is made a function of ground speed instead. Standing
## still and creeping keep exactly the hair that shipped; running pins it back toward the
## rig it hangs off.

const PonyRigScript := preload("res://scripts/pony_rig.gd")
const PlayerScript := preload("res://actors/player/player.gd")


func test_a_standing_pony_keeps_all_of_her_hair() -> void:
	assert_almost_eq(PonyRigScript.influence_for_speed(0.0), 1.0, 0.0001,
		"nothing is dragging the anchor, so nothing needs pinning")


func test_the_creep_costs_no_follow_through() -> void:
	# SNEAK_SPEED is the speed a player CHOOSES in order to be quiet and to look at things.
	# Every certified hair measurement in docs/notes-hair-sim.md was taken at or below it.
	assert_almost_eq(PonyRigScript.influence_for_speed(PlayerScript.SNEAK_SPEED), 1.0, 0.0001,
		"the sneak is inside the band the shipped profiles were tuned for")


func test_the_run_pins_the_hair_back() -> void:
	var at_run: float = PonyRigScript.influence_for_speed(PlayerScript.RUN_SPEED)
	assert_lte(at_run, 0.5,
		"at 5.2 m/s the chains have less restoring speed than the ground they cross")
	assert_gte(at_run, PonyRigScript.PIN_FLOOR,
		"never below the floor -- welded hair is the OTHER half of 'looks off'")


func test_the_hair_is_never_welded_to_the_skull() -> void:
	# docs/notes-hair-sim.md section 1b: a rest-pose track over the simulation is lockstep,
	# and lockstep was half of the original complaint. There is no speed at which the answer
	# is zero.
	var speed := 0.0
	while speed <= 20.0:
		assert_gt(PonyRigScript.influence_for_speed(speed), 0.0,
			"influence went to zero at %.1f m/s" % speed)
		speed += 0.25


func test_it_never_gets_freer_as_she_speeds_up() -> void:
	var previous := PonyRigScript.influence_for_speed(0.0)
	var speed := 0.0
	var samples := 0
	while speed <= 20.0:
		var here: float = PonyRigScript.influence_for_speed(speed)
		assert_lte(here, previous + 0.0001,
			"influence rose between %.2f and %.2f m/s" % [speed - 0.25, speed])
		previous = here
		samples += 1
		speed += 0.25
	assert_gt(samples, 40, "the sweep has to actually walk the range it claims to")


func test_negative_speed_is_read_as_speed() -> void:
	# get_ground_speed() is a length and cannot be negative, but a caller handing a signed
	# axis instead would otherwise get full influence at full reverse.
	assert_almost_eq(PonyRigScript.influence_for_speed(-PlayerScript.RUN_SPEED),
		PonyRigScript.influence_for_speed(PlayerScript.RUN_SPEED), 0.0001)


## THE SEAM, NOT THE FUNCTION. docs/notes-hair-sim.md section 10.2 is the story of a
## measurement that was right about a number the simulation could not move; the mirror of
## that mistake here would be a speed rule nothing ever calls. This drives the real player
## scene and reads the influence off the real simulator.
func test_the_player_holds_her_simulator_at_the_speed_rule() -> void:
	var player = load("res://actors/player/player.tscn").instantiate()
	add_child_autofree(player)
	await wait_frames(2)
	var sim = PonyRigScript.hair_simulator(player.get_node("Visuals").get_child(0))
	if sim == null:
		# An assetless checkout has no .glb to build a body from. Say so rather than pass
		# silently on nothing, which is the "passes with 0 items" shape this suite bans.
		pending("no converted pony model on this checkout, so there is no simulator to read")
		return
	player.velocity = Vector3.ZERO
	await wait_physics_frames(2)
	assert_almost_eq(player.hair_influence(), 1.0, 0.01,
		"a standing player keeps every bit of her hair")
