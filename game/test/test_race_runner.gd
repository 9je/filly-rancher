extends GutTest
## ONE VISUAL RUNNER. The claim under test is mostly a negative one: this is not a Pony, it
## cannot become one, and dressing it again does not free anything that was ever a pony.

const RaceRunnerScript := preload("res://world/race_runner.gd")
const PonyInstanceScript := preload("res://systems/pony_instance.gd")
const PonyScript := preload("res://actors/pony/pony.gd")
const GaitScript := preload("res://systems/gait.gd")
const PaintScript := preload("res://ui/casino_paint.gd")

var _runner: RaceRunner = null


func before_each() -> void:
	_runner = RaceRunnerScript.new()
	add_child_autofree(_runner)


func _stock_data() -> PonyData:
	return PonyInstanceScript.resolve_data(&"stock_bold")


func test_a_runner_is_not_a_pony_and_never_becomes_one() -> void:
	# is_instance_of() rather than `_runner is PonyScript`: RaceRunner (Node3D) and Pony
	# (CharacterBody3D) share no ancestor/descendant relation, so GDScript's static analyzer
	# proves the `is` form always false and refuses to parse it as a Parse Error. The runtime
	# check says exactly the same thing without tripping that.
	assert_false(is_instance_of(_runner, PonyScript), "a racer is scenery, not a resident")
	assert_false(_runner.has_method("leave"), "nothing here can take a pony off the map")
	assert_false(_runner.has_method("set_held"), "and the beam has nothing to grab")


func test_an_undressed_runner_has_no_model_and_poses_without_erroring() -> void:
	assert_false(_runner.has_model())
	_runner.set_pose(Vector3(1.0, 0.0, 2.0), Vector3(1.0, 0.0, 0.0), 3.5)
	assert_almost_eq(_runner.global_position.x, 1.0, 1e-4)


func test_dressing_builds_a_model_and_names_her() -> void:
	var data: PonyData = _stock_data()
	if data == null or not ResourceLoader.exists(data.model_path):
		pass_test("no converted assets on this machine; nothing to dress")
		return
	assert_true(_runner.dress(data, {"coat": 1, "mane": 2, "eyes": 3}, "Quarterly Dividend"))
	assert_true(_runner.has_model())
	assert_eq(_runner.runner_name(), "Quarterly Dividend")


func test_dressing_twice_replaces_the_model_and_leaves_one_behind() -> void:
	var data: PonyData = _stock_data()
	if data == null or not ResourceLoader.exists(data.model_path):
		pass_test("no converted assets on this machine; nothing to dress")
		return
	_runner.dress(data, {"coat": 0, "mane": 0, "eyes": 0}, "First")
	_runner.dress(data, {"coat": 1, "mane": 1, "eyes": 1}, "Second")
	assert_eq(_runner.runner_name(), "Second")
	var models: int = 0
	for child in _runner.get_children():
		# The saddlecloth and the chevron are dressing this runner OWNS, not models it was
		# built from; excluded by name because the nameplate they replaced was excluded by
		# type and there is no type that separates a box from a pony.
		if String(child.name) in ["Saddlecloth", "Chevron"]:
			continue
		if child is Node3D:
			models += 1
	assert_eq(models, 1, "the old model is replaced, not stacked")


func test_a_posed_runner_faces_the_way_she_is_running() -> void:
	_runner.set_pose(Vector3.ZERO, Vector3(1.0, 0.0, 0.0), 3.5)
	assert_almost_eq(_runner.rotation.y, atan2(-1.0, 0.0), 1e-4,
		"the asset's forward is minus Z, the same convention pony.gd turns by")


func test_a_running_speed_is_inside_the_gallop_band() -> void:
	assert_eq(GaitScript.clip_for_speed(3.4), &"gallop",
		"every speed the race uses must read as a gallop, or the runner slides")


## THE SIX NAMES ARE GONE AND THE COLOUR IS THERE INSTEAD.
func test_a_lane_gets_a_saddlecloth_in_its_colour_and_no_nameplate() -> void:
	var data: PonyData = _stock_data()
	if data == null or not ResourceLoader.exists(data.model_path):
		pass_test("no converted assets on this machine; nothing to dress")
		return
	_runner.dress(data, {"coat": 0, "mane": 0, "eyes": 0}, "Third", 3)
	assert_eq(_runner.lane(), 3)
	var cloth := _runner.get_node_or_null(^"Saddlecloth") as MeshInstance3D
	assert_not_null(cloth)
	var mat := (cloth.mesh as BoxMesh).material as StandardMaterial3D
	assert_eq(mat.albedo_color, PaintScript.BAND_COLORS[3])
	assert_null(_runner.get_node_or_null(^"Nameplate"),
		"the last billboarded text in the game is gone")
	assert_null(_runner.get_node_or_null(^"Chevron"),
		"only the player's own lane gets a chevron")
