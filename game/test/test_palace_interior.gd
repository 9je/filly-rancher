extends GutTest
## THE SPECTRA PALACE YOU WALK INTO (owner playtest 2026-10-25: "spectra palace not real yet?
## weird sign you gotta walk through to get in"). The door used to open a full screen lobby
## menu; now it opens onto a hall built inside the ranch scene, sealed and out of sight, with
## a station for every game. These tests pin the seams:
##
##   THE RESOLVER. Two new verbs, ranked, each prompt naming what E is about to do.
##   THE VISIT. In and out leaves the ranch alone: the wallet, the clock and the saddlebag are
##   the same numbers before and after, because nothing was unloaded or reloaded.
##   THE HALL. Inside, only the hall is offered; every station opens the EXISTING casino UI
##   straight at its own game.
##   THE DOOR. A closed Palace keeps its door shut, and a ban walks her out.
##
## A REAL ranch.tscn, like test_interaction.gd's last two tests, because what is under test is
## where things stand and what the interact key means there. Every menu opened here is shut
## again before the next await: an open panel pauses the tree, and this is GUT's tree.

const InteractionScript := preload("res://world/interaction.gd")
const PalaceInteriorScript := preload("res://world/palace_interior.gd")
const CasinoMenuScript := preload("res://ui/casino_menu.gd")
const RanchScene := preload("res://world/ranch.tscn")
const PlayerScript := preload("res://actors/player/player.gd")

var ranch: Node3D


func before_all() -> void:
	ranch = RanchScene.instantiate()
	add_child(ranch)
	await wait_for_signal(ranch.gate_report_finished, 120.0)


func after_all() -> void:
	if ranch != null and is_instance_valid(ranch):
		ranch.free()


func before_each() -> void:
	if ranch.call("is_in_palace"):
		ranch.call("exit_palace", true)
	ranch.set("_interactive", false)


# --- the resolver --------------------------------------------------------------------------

func test_the_two_new_verbs_are_ranked() -> void:
	for kind: int in [InteractionScript.Kind.PALACE_STATION, InteractionScript.Kind.PALACE_EXIT]:
		assert_gte(InteractionScript.rank_of(kind), 0, "kind %d can never win" % kind)


func test_every_station_prompt_names_its_game_and_carries_no_dash() -> void:
	var words := {&"slots": "slots", &"wheel": "wheel", &"blackjack": "blackjack",
		&"racing": "races", &"cage": "chips"}
	for id: StringName in PalaceInteriorScript.STATIONS:
		var line: String = InteractionScript.prompt_for(InteractionScript.candidate(
			InteractionScript.Kind.PALACE_STATION, 1.0, String(id)), "E")
		assert_true(line.begins_with("E: "), line)
		assert_true(line.to_lower().contains(String(words[id])), line)
		assert_false(line.contains("--") or line.contains(String.chr(0x2014)), line)
	var out: String = InteractionScript.prompt_for(
		InteractionScript.candidate(InteractionScript.Kind.PALACE_EXIT, 1.0), "E")
	assert_true(out.to_lower().contains("leave"), out)


func test_the_door_prompt_says_she_goes_in() -> void:
	var line: String = InteractionScript.prompt_for(
		InteractionScript.candidate(InteractionScript.Kind.PALACE, 1.0), "E")
	assert_true(line.to_lower().contains("go into"), line)


func test_the_hall_has_all_five_stations() -> void:
	for id: StringName in [&"slots", &"wheel", &"blackjack", &"racing", &"cage"]:
		assert_has(PalaceInteriorScript.STATIONS, id)


# --- the visit -----------------------------------------------------------------------------

func test_going_in_and_out_leaves_the_ranch_alone() -> void:
	var player: Node3D = ranch.get("player")
	var econ: Object = ranch.call("get_economy")
	econ.set("bits", 321)
	var world: Object = ranch.get("_world")
	var clock_before: float = float(world.call("elapsed"))
	var bag: Object = player.call("get_magic_beam").call("get_storage")
	var bag_before: int = int(bag.call("count"))
	assert_true(ranch.call("enter_palace", true), "the door lets her in")
	assert_true(ranch.call("is_in_palace"))
	var interior: Node3D = ranch.get("palace_interior")
	assert_not_null(interior, "the hall was built on the way in")
	var arrival: Vector3 = interior.to_global(PalaceInteriorScript.ARRIVAL)
	assert_lt(player.global_position.distance_to(arrival), 0.6, "she stands at the hall's door")
	assert_eq(int(econ.get("bits")), 321, "the wallet did not move")
	assert_eq(int(bag.call("count")), bag_before, "the saddlebag did not move")
	assert_true(ranch.call("exit_palace", true))
	assert_false(ranch.call("is_in_palace"))
	var palace: Node3D = ranch.get_node(^"Buildings/Palace")
	var flat := Vector2(player.global_position.x - palace.global_position.x,
		player.global_position.z - palace.global_position.z).length()
	assert_lt(flat, 9.0, "she is back at the Palace (%.1f m from its origin)" % flat)
	assert_gt(player.global_position.y, palace.global_position.y - 2.0,
		"and back on the surface, not under it")
	assert_eq(int(econ.get("bits")), 321, "the wallet did not move on the way out either")
	assert_gte(float(world.call("elapsed")), clock_before, "the clock never went backwards")


func test_the_hall_is_sealed_and_out_of_sight() -> void:
	ranch.call("enter_palace", true)
	var interior: Node3D = ranch.get("palace_interior")
	var terrain: Node = ranch.get_node(^"Terrain")
	var ground: float = float(terrain.call("height_at", interior.global_position.x,
		interior.global_position.z))
	assert_lt(interior.global_position.y + PalaceInteriorScript.HEIGHT, ground - 20.0,
		"the whole hall, roof and all, is well under the ground")


func test_the_camera_ground_guard_is_off_inside_and_back_on_outside() -> void:
	var rig: Node = ranch.get("player").call("get_camera_pivot").get_node("CameraRig")
	ranch.call("enter_palace", true)
	assert_false(bool(rig.get("ground_guard")),
		"under the map the terrain guard would throw the lens up through the ceiling")
	ranch.call("exit_palace", true)
	assert_true(bool(rig.get("ground_guard")))


func test_the_hall_floor_sounds_like_wood() -> void:
	ranch.call("enter_palace", true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_eq(ranch.get("player").call("surface_under"), PlayerScript.SURFACE_WOOD)


# --- the hall ------------------------------------------------------------------------------

func test_inside_only_the_hall_is_offered() -> void:
	ranch.call("enter_palace", true)
	var interior: Node3D = ranch.get("palace_interior")
	ranch.get("player").global_position = interior.call("station_point", &"cage")
	await get_tree().physics_frame
	var offered: Array = ranch.call("interaction_candidates")
	assert_false(offered.is_empty(), "at the cage, the cage is offered")
	for c: Dictionary in offered:
		assert_true(int(c["kind"]) in [InteractionScript.Kind.PALACE_STATION,
			InteractionScript.Kind.PALACE_EXIT], "offered %s inside the hall" % c)


func test_each_station_opens_the_existing_game_straight_at_its_own_screen() -> void:
	ranch.call("enter_palace", true)
	var interior: Node3D = ranch.get("palace_interior")
	var player: Node3D = ranch.get("player")
	var menus := {&"slots": ranch.get("slots_menu"), &"wheel": ranch.get("wheel_menu"),
		&"blackjack": ranch.get("blackjack_menu"), &"racing": ranch.get("race_menu"),
		&"cage": ranch.get("casino_menu")}
	for id: StringName in PalaceInteriorScript.STATIONS:
		player.global_position = interior.call("station_point", id)
		await get_tree().physics_frame
		var action: Dictionary = ranch.call("current_interaction")
		assert_eq(int(action.get("kind", 0)), InteractionScript.Kind.PALACE_STATION,
			"standing at the %s, E means that station (%s)" % [id, action])
		assert_eq(String(action.get("subject", "")), String(id))
		var opened: bool = ranch.call("perform_interaction", action)
		var menu: CanvasLayer = menus[id]
		var shown: bool = bool(menu.call("is_open"))
		var tab := int(menu.call("tab")) if id == &"cage" else -1
		menu.call("close")
		assert_true(opened and shown, "E at the %s opened its screen (blocking: %s)" % [id,
			ranch.call("blocking_menu")])
		if id == &"cage":
			assert_eq(tab, CasinoMenuScript.Tab.CAGE, "the cage opens on the cage tab")
		await get_tree().process_frame
	assert_false(get_tree().paused, "every menu shut again")


func test_the_exit_door_takes_her_out() -> void:
	ranch.call("enter_palace", true)
	var interior: Node3D = ranch.get("palace_interior")
	ranch.get("player").global_position = interior.call("station_point", &"exit")
	await get_tree().physics_frame
	var action: Dictionary = ranch.call("current_interaction")
	assert_eq(int(action.get("kind", 0)), InteractionScript.Kind.PALACE_EXIT)
	assert_true(ranch.call("perform_interaction", action))
	assert_false(ranch.call("is_in_palace"))


func test_the_hall_has_staff() -> void:
	ranch.call("enter_palace", true)
	var interior: Node3D = ranch.get("palace_interior")
	assert_gte(int(interior.call("staff_count")), 4,
		"a cashier, a dealer, a wheel host and a race clerk at least")


# --- the door ------------------------------------------------------------------------------

## "WEIRD SIGN YOU GOTTA WALK THROUGH TO GET IN", AS IT STOOD ON THE SHIPPED MAP. The marquee is
## hung while the Palace is still at y = 0 and the Palace is seated afterwards, up onto a plinth
## 2.9 m over the Strip, so the board's lower edge ended up 1.7 m over the floor of the door:
## through a pony's head. Measured on the real ranch, off the seated building.
func test_the_marquee_hangs_over_the_seated_doorway() -> void:
	var palace: Node3D = ranch.get_node(^"Buildings/Palace")
	var strip: Node = ranch.get_node(^"Strip")
	var floor_y: float = float(palace.call("floor_top_y"))
	var bottom: float = float(strip.call("marquee_top_y")) \
		- (strip.call("marquee_board_size") as Vector2).y
	assert_gte(bottom - floor_y, 3.2,
		"the board's lower edge is over the doors and the camera, not across the doorway")
	var board: Node3D = strip.get_node(^"MarqueeBoard")
	assert_almost_eq(board.global_position.y, (strip.call("marquee_board_centre") as Vector3).y,
		0.01, "and the board itself went up with the number")
	var sponsor: Node3D = strip.get_node(^"MarqueeSponsor")
	assert_gt(sponsor.global_position.y, floor_y + 3.2, "its lettering too")

func test_walking_through_the_doorway_takes_her_in() -> void:
	var player: Node3D = ranch.get("player")
	player.global_position = ranch.call("palace_threshold_point")
	for i in 6:
		await get_tree().physics_frame
	assert_true(ranch.call("is_in_palace"), "stepping into the doorway is going in")


func test_a_closed_palace_keeps_its_door_shut() -> void:
	ranch.set("_interactive", true)
	var story: Object = ranch.get("_game_state").get("story")
	story.call("set_flag", "palace_open", false)
	assert_false(ranch.call("casino_can_enter"), "precondition: before the grand opening")
	assert_false(ranch.call("enter_palace", true), "the door stays shut")
	assert_false(ranch.call("is_in_palace"))
	ranch.set("_interactive", false)


func test_a_ban_walks_her_out() -> void:
	ranch.call("enter_palace", true)
	ranch.set("_interactive", true)
	var story: Object = ranch.get("_game_state").get("story")
	story.call("set_flag", "palace_open", false)
	assert_true(ranch.call("enforce_palace_ban"), "a ban with her inside does something")
	assert_false(ranch.call("is_in_palace"), "it walks her out")
	ranch.set("_interactive", false)
