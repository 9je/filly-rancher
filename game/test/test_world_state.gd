extends GutTest
## The world clock as arithmetic: game/systems/world_state.gd. Nothing here renders.

const WorldStateScript := preload("res://systems/world_state.gd")


func test_phases_partition_the_cycle_in_order() -> void:
	var sum := 0.0
	for s in WorldStateScript.PHASE_SECONDS:
		sum += s
	assert_almost_eq(sum, WorldStateScript.CYCLE_SECONDS, 0.001)
	assert_eq(WorldStateScript.phase_at(0.0), WorldStateScript.Phase.DAWN)
	assert_eq(WorldStateScript.phase_at(119.9), WorldStateScript.Phase.DAWN)
	assert_eq(WorldStateScript.phase_at(120.0), WorldStateScript.Phase.DAY)
	assert_eq(WorldStateScript.phase_at(659.9), WorldStateScript.Phase.DAY)
	assert_eq(WorldStateScript.phase_at(660.0), WorldStateScript.Phase.DUSK)
	assert_eq(WorldStateScript.phase_at(780.0), WorldStateScript.Phase.NIGHT)
	assert_eq(WorldStateScript.phase_at(1199.9), WorldStateScript.Phase.NIGHT)
	assert_eq(WorldStateScript.phase_at(1200.0), WorldStateScript.Phase.DAWN, "the cycle wraps")


func test_advance_emits_on_a_phase_flip_and_not_otherwise() -> void:
	var w = WorldStateScript.new(7)
	watch_signals(w)
	w.advance(60.0)
	assert_signal_not_emitted(w, "phase_changed")
	w.advance(60.0)
	assert_signal_emitted_with_parameters(w, "phase_changed", [WorldStateScript.Phase.DAY])
	assert_eq(w.phase(), WorldStateScript.Phase.DAY)
	assert_almost_eq(w.phase_progress(), 0.0, 0.001)


func test_weather_is_deterministic_in_the_seed_and_varies_across_phases() -> void:
	var a := WorldStateScript.weather_for(42, 0, 0)
	var b := WorldStateScript.weather_for(42, 0, 0)
	assert_eq(a, b, "same seed, cycle and phase: same weather")
	var seen := {}
	for cycle in range(40):
		for phase in range(4):
			seen[WorldStateScript.weather_for(42, cycle, phase)] = true
	assert_eq(seen.size(), 4, "over 160 rolls every kind of weather appears")


func test_weather_frequencies_follow_the_weights_roughly() -> void:
	var counts := [0, 0, 0, 0]
	var rolls := 4000
	for i in range(rolls):
		counts[WorldStateScript.weather_for(1000 + i, 0, 0)] += 1
	assert_between(float(counts[0]) / rolls, 0.50, 0.60, "clear about 55 percent")
	assert_between(float(counts[3]) / rolls, 0.06, 0.14, "storm about 10 percent")


func test_weather_changes_only_at_a_phase_boundary() -> void:
	var w = WorldStateScript.new(3)
	var before := w.weather()
	watch_signals(w)
	w.advance(100.0)
	assert_eq(w.weather(), before)
	assert_signal_not_emitted(w, "weather_changed")
	# Advance to each next phase boundary in turn; search for the first one whose roll differs.
	var boundary := 0.0
	var changed := false
	for i in range(8):
		boundary += WorldStateScript.PHASE_SECONDS[(WorldStateScript.Phase.DAWN + i) % 4]
		w.set_elapsed(boundary)
		if w.weather() != before:
			changed = true
			break
	assert_true(changed, "some later phase rolls a different weather")
	assert_signal_emitted(w, "weather_changed")


func test_set_elapsed_resumes_a_save_exactly() -> void:
	var w = WorldStateScript.new(9)
	w.advance(700.0)
	var copy = WorldStateScript.new(9, w.elapsed())
	assert_eq(copy.phase(), w.phase())
	assert_eq(copy.weather(), w.weather())
	assert_almost_eq(copy.elapsed(), 700.0, 0.001)


func test_pin_freezes_the_state() -> void:
	var w = WorldStateScript.new(1)
	w.pin(WorldStateScript.Phase.NIGHT, WorldStateScript.Weather.STORM)
	assert_true(w.is_pinned())
	w.advance(5000.0)
	assert_eq(w.phase(), WorldStateScript.Phase.NIGHT)
	assert_eq(w.weather(), WorldStateScript.Weather.STORM)
	assert_almost_eq(w.elapsed(), 0.0, 0.001, "a pinned clock does not run")


func test_names_and_describe_carry_no_dashes() -> void:
	var w = WorldStateScript.new(1)
	w.pin(WorldStateScript.Phase.DUSK, WorldStateScript.Weather.RAIN)
	assert_eq(w.describe(), "Dusk, rain")
	for p in range(4):
		assert_false(WorldStateScript.phase_name(p).contains("-"))
	for x in range(4):
		assert_false(WorldStateScript.weather_name(x).contains("-"))
