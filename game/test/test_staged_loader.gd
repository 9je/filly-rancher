extends GutTest
## THE LOAD THAT CANNOT DEADLOCK (game/ui/staged_loader.gd). New game hung for good, now and
## then, on "Saddling up... 6%": ResourceLoader's worker thread stopped inside its load of
## world/ranch.tscn and never came back (caught by the input gate, 2026-10-25). The loading
## screen now loads the scene on the main thread, a dependency at a time, leaves first, so
## no thread is ever asked for it and every step moves the bar.

const StagedLoaderScript := preload("res://ui/staged_loader.gd")
const FIXTURE := "res://test/fixtures/staged_load/scene.tscn"
const ROOT := "res://test/fixtures/staged_load/root.gd"
const LEAF := "res://test/fixtures/staged_load/leaf.gd"


func _run(loader, budget_ms: float) -> int:
	var steps := 0
	while not loader.step(budget_ms) and steps < 200:
		steps += 1
	return steps + 1


func test_loads_the_scene_without_a_thread() -> void:
	var loader = StagedLoaderScript.new(FIXTURE)
	var steps := _run(loader, 0.0)
	assert_true(loader.is_done())
	assert_true(loader.result() is PackedScene, "the scene came back as a PackedScene")
	assert_eq(ResourceLoader.load_threaded_get_status(FIXTURE),
		ResourceLoader.THREAD_LOAD_INVALID_RESOURCE, "no threaded request was ever made")
	assert_gt(steps, 1, "a zero budget loads one thing a step, not the whole tree at once")
	# LEAVES FIRST. Checked on this first load only: the fixture's scripts stay in the script
	# cache from here on, and a cached path is skipped by design.
	var order: Array[String] = loader.loaded_order()
	assert_has(order, LEAF)
	assert_has(order, ROOT)
	assert_lt(order.find(LEAF), order.find(ROOT), "the preloaded leaf before its script")
	assert_lt(order.find(ROOT), order.find(FIXTURE), "the script before its scene")


func test_progress_climbs_to_one() -> void:
	var loader = StagedLoaderScript.new(FIXTURE)
	var last: float = loader.progress()
	assert_eq(last, 0.0)
	while not loader.step(0.0):
		assert_true(loader.progress() >= last, "progress never goes backwards")
		last = loader.progress()
	assert_eq(loader.progress(), 1.0)


func test_a_missing_scene_finishes_with_nothing() -> void:
	var loader = StagedLoaderScript.new("res://test/fixtures/staged_load/missing.tscn")
	_run(loader, 0.0)
	assert_true(loader.is_done())
	assert_null(loader.result())
