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
	# Defensive: the pause-contract tests below pause the live tree on purpose. A failed
	# assertion partway through one must never leave every later test in the suite running
	# under a paused SceneTree, so this puts it back regardless of how the test ended.
	get_tree().paused = false


func test_the_six_buses_exist_and_route_into_master() -> void:
	assert_eq(AudioServer.bus_count, 6)
	assert_eq(AudioServer.get_bus_name(0), "Master")
	for bus: StringName in [SoundScript.BUS_AMBIENT, SoundScript.BUS_EFFECTS, SoundScript.BUS_UI,
			SoundScript.BUS_MUSIC, SoundScript.BUS_VOICE]:
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
	# Save and restore the live autoload's private seed: this test is the one place in the
	# suite that has to pin it for a deterministic distribution, but the class comment
	# promises "seeded from entropy at boot" for every test that runs after this one, and a
	# permanent reseed here would quietly make that false for the rest of the process.
	var saved_seed: int = Sound._rng.seed
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
	Sound._rng.seed = saved_seed


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


## C1 + I1's regression test, reproducing the final review's exact scenario end to end.
## ranch.gd pauses the tree for every casino panel (_on_menu_opened_any -> get_tree().paused
## = true) one line before _update_interaction() falls through to _update_sound_zone(),
## which pushes ambient_set_zone(&"casino") into a tree that is already paused
## (ranch.gd:4279-4284). Before the fix, _fade_bed_in()'s idempotency guard read
## AudioStreamPlayer.playing, which reports false for a paused-but-current voice, so this
## exact sequence slammed every settled phase bed to SILENT_DB and left the casino's own
## bed frozen there for the whole visit (see final-review.md, C1 and I1). The ruling: bed
## voices are PROCESS_MODE_ALWAYS and their tweens TWEEN_PAUSE_PROCESS, so a bed already
## sounding survives the push untouched and the casino bed can still climb to its target
## while the panel is open. This also closes the Task 6 parked gap for the zone hook path.
func test_a_zone_push_onto_a_paused_tree_leaves_the_phase_beds_alone_and_reaches_the_casino_bed() -> void:
	var Sound := _sound_autoload()
	Sound.stop_all()
	Sound.ambient_set_phase(1)  # DAY: bed_day_meadow, bed_wind_soft
	var phase_ids: Array[StringName] = Sound.active_bed_ids()
	assert_eq(phase_ids, [&"bed_day_meadow", &"bed_wind_soft"] as Array[StringName])
	# Settle every phase bed's arrival tween to its target, deterministically and with no
	# real waiting, exactly as test_a_bed_that_re_enters... does above.
	for id: StringName in phase_ids:
		var arrival: Variant = Sound._bed_tweens.get(id, null)
		if arrival is Tween and arrival.is_valid():
			arrival.custom_step(SoundScript.CROSSFADE_SECONDS + 1.0)
	var settled_db: Dictionary = {}
	for id: StringName in phase_ids:
		settled_db[id] = Sound._bed_voices[Sound.voice_index_for(id)].volume_db

	get_tree().paused = true
	Sound.ambient_set_zone(SoundScript.ZONE_CASINO)

	for id: StringName in phase_ids:
		var voice: AudioStreamPlayer = Sound._bed_voices[Sound.voice_index_for(id)]
		assert_false(is_equal_approx(voice.volume_db, SoundScript.SILENT_DB),
			"'%s' must not be slammed to silence by a zone push onto a paused tree" % id)
		assert_almost_eq(voice.volume_db, float(settled_db[id]), 0.01,
			"'%s' must be left entirely alone by an unchanged phase bed re-ask" % id)

	# The casino bed must have a voice and an arrival tween that can advance WHILE the tree
	# stays paused -- TWEEN_PAUSE_PROCESS is what makes that possible.
	var casino_index: int = Sound.voice_index_for(&"bed_casino_room")
	assert_true(casino_index >= 0, "the casino bed must have been handed a voice")
	var casino_arrival: Variant = Sound._bed_tweens.get(&"bed_casino_room", null)
	assert_true(casino_arrival is Tween and casino_arrival.is_valid(),
		"the casino bed must own an arrival tween")
	var casino_voice: AudioStreamPlayer = Sound._bed_voices[casino_index]
	var db_before_ticking: float = casino_voice.volume_db
	# get_tree().process_frame fires every frame regardless of pause (an engine level
	# signal, not gated by any node's process_mode), so two real ticks proves the tween is
	# advancing on its OWN, automatically, while the tree stays paused -- the actual
	# behaviour TWEEN_PAUSE_PROCESS buys, not merely that a manual step can still move it
	# (custom_step() would succeed on a frozen TWEEN_PAUSE_BOUND tween too, and would prove
	# nothing about this ruling).
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(get_tree().paused, "the tree must still be paused at this point")
	assert_gt(casino_voice.volume_db, db_before_ticking,
		"the casino bed's arrival must advance on its own while the tree is paused")
	# Fast forward the rest deterministically, with no real waiting, to pin the destination.
	(casino_arrival as Tween).custom_step(SoundScript.CROSSFADE_SECONDS + 1.0)
	assert_almost_eq(casino_voice.volume_db, -3.0, 0.01,
		"the casino bed must reach its target while the tree is still paused")

	# Unpause, and check the steady state the visit leaves behind.
	get_tree().paused = false
	assert_false(Sound.is_voice_releasing(casino_index),
		"nothing should be mid-departure after a settled arrival")
	var after: Array[StringName] = Sound.active_bed_ids()
	assert_true(after.has(&"bed_day_meadow") and after.has(&"bed_wind_soft")
		and after.has(&"bed_casino_room"), "all three beds must still read as playing")


## I2's regression test: the real pause contract play()'s PAUSABLE voices actually deliver,
## pinned so a future cleanup cannot silence the casino table SFX and the pause menu's mail
## sounds, all of which are fired while get_tree().paused is already true and are audible
## only because AudioStreamPlayer.play() clears the node's sticky stream_paused flag.
func test_a_one_shot_started_under_pause_plays_out_on_a_pausable_voice() -> void:
	var Sound := _sound_autoload()
	Sound.stop_all()
	get_tree().paused = true
	assert_true(Sound.play(&"chip_clink"), "'chip_clink' would not play")
	assert_eq(Sound.last_process_mode(), Node.PROCESS_MODE_PAUSABLE,
		"chip_clink is a world/casino sound; it must stay on a PAUSABLE voice")
	var voice: AudioStreamPlayer = Sound._pool_2d[(Sound._next_2d - 1 + Sound._pool_2d.size())
		% Sound._pool_2d.size()]
	assert_true(voice.playing, "a one shot started under pause must actually be playing")
	# THE MECHANISM, pinned directly: AudioStreamPlayer.play() clears the node's sticky
	# stream_paused flag regardless of the tree's own paused state, which is the entire
	# reason a PAUSABLE voice started under pause sounds at all. stream_paused is also what
	# actually gates the audio server's mix, independently of any node's process_mode, so
	# this one flag is the whole contract -- not an inference from watching it play out.
	assert_false(voice.stream_paused,
		"play() must clear the sticky stream_paused flag; that is the whole contract")
	var position_a: float = voice.get_playback_position()
	# get_playback_position() is fed by the audio server's own mix thread, not by the
	# SceneTree's per-frame delta the way a Tween is, so proving it moves needs real
	# wall-clock time to actually pass rather than a queued engine frame. Polled, with a
	# hard cap, rather than one blind sleep: the first mix tick that lands wins the loop
	# immediately, and a build where mixing genuinely stalled fails after POLL_CAP real
	# tries instead of hanging. Three seconds of tries, not half of one: a full-suite run on
	# a loaded machine starved the mix thread past 500 ms once (it passed alone every time).
	var poll_cap := 120
	var advanced := false
	for i in poll_cap:
		OS.delay_msec(25)
		if voice.get_playback_position() > position_a:
			advanced = true
			break
	assert_true(advanced,
		"a one shot started under pause must actually advance, not sit frozen at 0")
	get_tree().paused = false
