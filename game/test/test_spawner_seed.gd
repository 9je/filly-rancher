extends GutTest
## THE TWO PLACES THE WORLD SEED IS WRITTEN DOWN, pinned to each other.
##
## game/world/spawner.gd exports the seed the wild world is drawn from, and
## game/systems/game_state.gd holds the seed a brand new save is created with. ranch.gd
## pushes each into the other depending on whether a save was loaded, so while they agree
## nothing can tell them apart. When they DRIFT, a first launch and a first save describe
## two different maps, and the symptom is not an error: it is a herd that quietly rearranges
## itself the first time the player quits and comes back. Nothing else in this suite would
## see that, because every other test that touches the seed sets its own.
##
## The seed is a CONTENT decision as well as a technical one (spawner.gd's own comment
## records the search that picked it), so this test deliberately does not assert a number.
## Re-picking the seed is allowed; re-picking it in only one of the two files is not.

const SpawnerScript := preload("res://world/spawner.gd")
const GameStateScript := preload("res://systems/game_state.gd")


func test_the_spawner_and_a_new_save_agree_on_the_world_seed() -> void:
	var spawner: Spawner = SpawnerScript.new()
	var seed_value: int = spawner.spawn_seed
	# A Node3D, so it is not reference counted: without this it leaks for the rest of the
	# run and GUT reports an orphan.
	spawner.free()
	assert_eq(seed_value, GameStateScript.DEFAULT_WORLD_SEED,
		"spawner.gd's spawn_seed and GameState.DEFAULT_WORLD_SEED must be the same number")
