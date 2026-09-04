extends GutTest
## Tests for game/systems/sound.gd: the pools, the private generator, the phase and zone
## bookkeeping, and the refusal path. Nothing here needs an audio file on disk; the corpus
## of real sounds is game/test/test_sound_library.gd's job.
##
## Sound is an autoload, so these tests drive the LIVE instance and put it back afterwards.
## The suite runs with --audio-driver Dummy and AudioSafety has muted Master, so a play()
## in here is silent by construction.

const SoundScript := preload("res://systems/sound.gd")


## get_node(), not the bare `Sound` identifier: tools/run_tests.sh's parse sweep runs every
## .gd file through `--check-only --script`, and that pass never boots the scene tree, so
## an autoload's name is never registered as a resolvable global identifier there, even
## though it resolves fine in a real run (the game, or GUT's own actual test pass). Every
## test below opens with `var Sound := _sound_autoload()`, a local that shadows the global
## for the rest of that function, so the body below it reads exactly like a call on the
## autoload because it is one.
func _sound_autoload() -> Node:
	return get_node("/root/Sound")


func after_each() -> void:
	var Sound := _sound_autoload()
	Sound.stop_all()


func test_the_four_buses_exist_and_route_into_master() -> void:
	assert_eq(AudioServer.bus_count, 4)
	assert_eq(AudioServer.get_bus_name(0), "Master")
	for bus: StringName in [SoundScript.BUS_AMBIENT, SoundScript.BUS_EFFECTS, SoundScript.BUS_UI]:
		var index: int = AudioServer.get_bus_index(String(bus))
		assert_gt(index, 0, "bus %s must exist and must not be Master" % bus)
		assert_eq(AudioServer.get_bus_send(index), &"Master")


func test_the_pools_are_built_at_the_declared_sizes() -> void:
	var Sound := _sound_autoload()
	assert_eq(Sound.pool_2d_size(), SoundScript.POOL_2D)
	assert_eq(Sound.pool_3d_size(), SoundScript.POOL_3D)
	assert_eq(Sound.bed_voice_size(), SoundScript.BED_VOICES)


func test_an_unknown_id_is_refused_and_does_not_crash() -> void:
	var Sound := _sound_autoload()
	# push_error is expected here: a caller who reaches for an id that is not in LIBRARY
	# has to be told, same house rule as game/test/test_economy.gd's refusal tests. Both
	# calls' errors are asserted together; assert_push_error counts every matching error
	# raised so far in this test, not just the ones since the previous assert.
	assert_false(Sound.play(&"no_such_sound_at_all"))
	assert_false(Sound.play_at(&"no_such_sound_at_all", Vector3.ZERO))
	assert_push_error(2, "an unknown id passed to play() and play_at() has to be reported")
	assert_false(Sound.has_id(&"no_such_sound_at_all"))
	assert_eq(Sound.entry(&"no_such_sound_at_all").size(), 0)


func test_variant_picks_stay_inside_the_set() -> void:
	var Sound := _sound_autoload()
	for i in range(200):
		var pick: int = Sound.pick_variant(3)
		assert_between(pick, 0, 2)
	assert_eq(Sound.pick_variant(1), 0)
	assert_eq(Sound.pick_variant(0), 0)


func test_pitch_picks_stay_inside_the_range_and_a_zero_range_is_exact() -> void:
	var Sound := _sound_autoload()
	for i in range(200):
		var pitch: float = Sound.pick_pitch(0.92, 1.08)
		assert_between(pitch, 0.92, 1.08)
	assert_almost_eq(Sound.pick_pitch(1.0, 1.0), 1.0, 0.0001)


func test_the_phase_and_zone_are_remembered_and_a_repeat_is_a_no_op() -> void:
	var Sound := _sound_autoload()
	Sound.ambient_set_phase(2)
	assert_eq(Sound.current_phase(), 2)
	Sound.ambient_set_phase(2)
	assert_eq(Sound.current_phase(), 2)
	Sound.ambient_set_zone(SoundScript.ZONE_STRIP)
	assert_eq(Sound.current_zone(), SoundScript.ZONE_STRIP)
	Sound.ambient_set_zone(SoundScript.ZONE_NONE)
	assert_eq(Sound.current_zone(), SoundScript.ZONE_NONE)


func test_stop_all_empties_the_beds() -> void:
	var Sound := _sound_autoload()
	Sound.ambient_set_phase(0)
	Sound.stop_all()
	assert_eq(Sound.active_bed_ids().size(), 0)
	assert_eq(Sound.current_phase(), -1)
	assert_eq(Sound.current_zone(), SoundScript.ZONE_NONE)


func test_the_generator_is_its_own_and_is_seeded() -> void:
	var Sound := _sound_autoload()
	# THE MATH DOES NOT CHANGE: Sound must never reach for a shared stream. The only
	# generator it may touch is its own, and it must not be sitting on the default seed.
	assert_true(Sound.has_private_rng())
	assert_ne(Sound.rng_seed(), 0)


func test_a_bed_that_re_enters_during_its_own_release_does_not_strand_its_voice() -> void:
	# _bed_voice_for and _tween_bed never touch LIBRARY (only _fade_bed_in and _pick_stream
	# do), so the crossfade state machine below can be driven directly even though LIBRARY
	# is empty in this task; the real content tasks exercise the same machine through
	# ambient_set_phase()/ambient_set_zone() once it has real beds to work with. This is
	# the "a phase that flips twice inside four seconds" scenario _tween_bed's own
	# docstring calls out: a bed drops out, then is asked for again before its departing
	# voice has finished fading to silence.
	var Sound := _sound_autoload()
	var id: StringName = &"__test_flip_flop_bed__"
	var voice_out: AudioStreamPlayer = Sound._bed_voice_for(id)
	Sound._tween_bed(id, voice_out, 0.0)
	var index_out: int = Sound.voice_index_for(id)
	Sound._fade_bed_out(id)
	assert_true(Sound.is_voice_releasing(index_out),
		"the departing voice must be marked releasing")
	var release_tween: Tween = Sound.release_tween_for(index_out)
	assert_not_null(release_tween, "a departing voice must own its own release tween")
	var voice_in: AudioStreamPlayer = Sound._bed_voice_for(id)
	var index_in: int = Sound.voice_index_for(id)
	assert_ne(index_in, index_out,
		"a still releasing voice must never be handed back to the bed that just vacated it")
	Sound._tween_bed(id, voice_in, 0.0)
	# THE BUG: the arrival's own tween and the voice it just vacated's departure tween used
	# to share one dictionary keyed by id, so this call would stop the departure tween too.
	assert_true(release_tween.is_valid(),
		"an arrival must never stop the departure tween of the voice it just vacated")
	# Advance the departure tween to completion deterministically, with no real waiting.
	release_tween.custom_step(SoundScript.CROSSFADE_SECONDS + 1.0)
	assert_false(Sound.is_voice_releasing(index_out),
		"a voice must be released once its own departure fade actually finishes")
	assert_eq(Sound.releasing_voice_indices().size(), 0)
