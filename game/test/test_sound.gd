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


func test_a_phase_brings_its_beds_up_and_takes_the_previous_ones_down() -> void:
	var Sound := _sound_autoload()
	Sound.stop_all()
	Sound.ambient_set_phase(SoundScript.BEDS.keys()[0])
	var dawn: Array[StringName] = Sound.active_bed_ids()
	assert_true(dawn.has(&"bed_dawn_chorus"))
	assert_true(dawn.has(&"bed_wind_soft"))
	Sound.ambient_set_phase(3)
	var night: Array[StringName] = Sound.active_bed_ids()
	assert_true(night.has(&"bed_night_insects"))
	assert_false(night.has(&"bed_dawn_chorus"),
		"the dawn chorus must be released the moment night takes over")


func test_a_zone_overlays_the_phase_rather_than_replacing_it() -> void:
	var Sound := _sound_autoload()
	Sound.stop_all()
	Sound.ambient_set_phase(1)
	Sound.ambient_set_zone(SoundScript.ZONE_STRIP)
	var beds: Array[StringName] = Sound.active_bed_ids()
	assert_true(beds.has(&"bed_day_meadow"), "the meadow is still out there behind the lamps")
	assert_true(beds.has(&"bed_strip_hum"))
	assert_true(beds.has(&"bed_strip_crowd"))
	Sound.ambient_set_zone(SoundScript.ZONE_NONE)
	beds = Sound.active_bed_ids()
	assert_true(beds.has(&"bed_day_meadow"))
	assert_false(beds.has(&"bed_strip_hum"))


func test_leaving_a_zone_never_disturbs_the_phase_beds() -> void:
	var Sound := _sound_autoload()
	Sound.stop_all()
	Sound.ambient_set_phase(3)
	var before: Array[StringName] = Sound.active_bed_ids()
	Sound.ambient_set_zone(SoundScript.ZONE_CASINO)
	Sound.ambient_set_zone(SoundScript.ZONE_NONE)
	assert_eq(Sound.active_bed_ids(), before)


func test_every_world_sound_plays_and_reports_that_it_did() -> void:
	var Sound := _sound_autoload()
	for id: StringName in [&"mail_arrive", &"mail_open", &"mail_stamp", &"capture_charge",
			&"capture_success", &"hoofsteps_grass", &"hoofsteps_hard", &"gate_open",
			&"delivery_thud", &"coins_grant"]:
		assert_true(Sound.has_id(id), "'%s' is missing from LIBRARY" % id)
		assert_true(Sound.play_at(id, Vector3(1.0, 0.0, 2.0)), "'%s' would not play" % id)


func test_the_variant_sets_are_the_sizes_the_plan_asked_for() -> void:
	var Sound := _sound_autoload()
	assert_eq(PackedStringArray(Sound.entry(&"hoofsteps_grass").get("paths")).size(), 4)
	assert_eq(PackedStringArray(Sound.entry(&"hoofsteps_hard").get("paths")).size(), 4)


func test_no_pony_voice_ever_entered_the_library() -> void:
	# Owner directive: these ponies are cartoon characters, not livestock. A realistic
	# whinny or snort would break the register the whole slice exists to protect. The one
	# exemption is SoundScript.GAG_ID itself, the one sanctioned neigh, held to its own
	# rarity and provenance asserts below rather than skipped silently.
	var Sound := _sound_autoload()
	for id: StringName in Sound.ids():
		if id == SoundScript.GAG_ID:
			continue
		assert_false(String(id).contains("whinny"), "'%s' is a pony voice" % id)
		assert_false(String(id).contains("snort"), "'%s' is a pony voice" % id)
		assert_false(String(id).contains("neigh"), "'%s' is a pony voice" % id)
	assert_true(Sound.has_id(SoundScript.GAG_ID))
	assert_true(Sound.has_id(SoundScript.GAG_SOURCE))
	assert_true(SoundScript.GAG_CHANCE > 0.0 and SoundScript.GAG_CHANCE <= 0.1,
		"the gag must stay rare")


func test_hoofsteps_are_mixed_well_under_everything_else() -> void:
	# The most heard sound in the game. If it sits at the same level as a slots stinger the game
	# is exhausting inside a minute; the owner's knob for this is parked in the plan.
	var Sound := _sound_autoload()
	for id: StringName in [&"hoofsteps_grass", &"hoofsteps_hard"]:
		assert_lte(float(Sound.entry(id).get("volume_db", 0.0)), -6.0)


func test_the_3d_pool_steals_its_oldest_voice_rather_than_growing() -> void:
	var Sound := _sound_autoload()
	Sound.stop_all()
	for i in range(SoundScript.POOL_3D + 5):
		assert_true(Sound.play_at(&"hoofsteps_grass", Vector3(float(i), 0.0, 0.0)))
	assert_eq(Sound.pool_3d_size(), SoundScript.POOL_3D)


func test_the_2d_pool_steals_its_oldest_voice_rather_than_growing() -> void:
	var Sound := _sound_autoload()
	Sound.stop_all()
	for i in range(SoundScript.POOL_2D + 5):
		assert_true(Sound.play(&"ui_move"))
	assert_eq(Sound.pool_2d_size(), SoundScript.POOL_2D)


func test_the_gag_id_is_rare_and_never_leaks_into_an_unrelated_sound() -> void:
	# The one sanctioned neigh: seeded so the distribution is deterministic. THE MATH DOES
	# NOT CHANGE means the roll lives entirely on _rng, so driving _resolve_play_id() directly
	# (the one internal path play() and play_at() both share) proves the gag both fires and
	# stays rare without touching any other RNG stream in the game.
	var Sound := _sound_autoload()
	Sound._rng.seed = 1234
	var gag_hits: int = 0
	for i in range(2000):
		if Sound._resolve_play_id(SoundScript.GAG_SOURCE) == SoundScript.GAG_ID:
			gag_hits += 1
	assert_gt(gag_hits, 0, "the gag must be able to come up")
	assert_lt(gag_hits, 400, "the gag must stay rare")
	for i in range(2000):
		assert_ne(Sound._resolve_play_id(&"gate_open"), SoundScript.GAG_ID,
			"only GAG_SOURCE may ever resolve to the gag")


func test_every_casino_and_ui_sound_plays() -> void:
	var Sound := _sound_autoload()
	for id: StringName in [&"chip_clink", &"card_slide", &"card_flip", &"reel_tick",
			&"reel_stop", &"slots_win", &"wheel_ratchet", &"wheel_settle",
			&"race_crowd_loop", &"race_gallop", &"race_cheer"]:
		assert_true(Sound.play(id), "'%s' would not play" % id)
	for id: StringName in [&"ui_move", &"ui_confirm", &"ui_back", &"ui_open", &"ui_denied",
			&"ui_page"]:
		assert_true(Sound.play(id), "'%s' would not play" % id)


func test_a_held_loop_starts_once_and_stops_when_told() -> void:
	var Sound := _sound_autoload()
	Sound.stop_all()
	assert_true(Sound.play_loop(&"race_crowd_loop"))
	assert_true(Sound.play_loop(&"race_gallop"))
	# Asking twice must not stack a second voice on the same id.
	assert_true(Sound.play_loop(&"race_crowd_loop"))
	assert_eq(Sound.looping_ids(), [&"race_crowd_loop", &"race_gallop"] as Array[StringName])
	Sound.stop_loop(&"race_crowd_loop")
	assert_eq(Sound.looping_ids(), [&"race_gallop"] as Array[StringName])
	Sound.stop_all()
	assert_eq(Sound.looping_ids().size(), 0)


func test_a_one_shot_is_refused_as_a_held_loop() -> void:
	var Sound := _sound_autoload()
	# play_loop() on a wav would start something nothing ever stops. push_error is expected
	# here, the same house rule test_an_unknown_id_is_refused_and_does_not_crash follows.
	assert_false(Sound.play_loop(&"chip_clink"))
	assert_push_error(1, "a non looping id passed to play_loop() has to be reported")


func test_the_rapid_triggers_are_mixed_far_down() -> void:
	# reel_tick fires per symbol step and wheel_ratchet per pocket; at the level of a chip
	# clink either one is a drill. This is a mix decision the plan makes on purpose.
	var reel_tick_entry: Dictionary = SoundScript.LIBRARY[&"reel_tick"]
	var wheel_ratchet_entry: Dictionary = SoundScript.LIBRARY[&"wheel_ratchet"]
	assert_lte(float(reel_tick_entry.get("volume_db", 0.0)), -10.0)
	assert_lte(float(wheel_ratchet_entry.get("volume_db", 0.0)), -10.0)


func test_there_is_exactly_one_slots_celebration() -> void:
	# The spec: ONE stinger, not escalating fanfares. Anything matching slots_win_ or
	# slots_jackpot would be the beginning of a skinner box.
	var celebrations := 0
	for id: StringName in SoundScript.LIBRARY.keys():
		if String(id).begins_with("slots_") and String(id).ends_with("win"):
			celebrations += 1
		assert_false(String(id).contains("jackpot"))
	assert_eq(celebrations, 1)


func test_ui_sounds_are_the_only_ones_that_survive_a_pause() -> void:
	# Sound.play() gives a UI bus entry PROCESS_MODE_ALWAYS and everything else PAUSABLE,
	# because menus are open while the tree is paused and the world is not.
	var Sound := _sound_autoload()
	for id: StringName in SoundScript.LIBRARY.keys():
		var entry: Dictionary = SoundScript.LIBRARY[id]
		var is_ui: bool = StringName(entry.get("bus", &"")) == SoundScript.BUS_UI
		Sound.stop_all()
		assert_true(Sound.play(id))
		assert_eq(Sound.last_process_mode() == Node.PROCESS_MODE_ALWAYS, is_ui,
			"'%s' has the wrong pause behaviour" % id)
