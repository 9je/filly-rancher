extends Node
## THE SOUND GATE. Everything about this game's audio that a unit test cannot see, because
## it needs a real engine with a real bus layout and real imported streams behind it: that
## the four buses came out of default_bus_layout.tres and route into Master, that every
## file in Sound.LIBRARY actually decoded, that the beds import as loops and the one shots
## do not, that all five verbs run without an error, and that the pools steal rather than
## grow when they are asked for more voices than they have.
##
## THIS GATE HOSTS NOTHING. No ranch, no player, no save. Every other gate instances
## world/ranch.tscn because a ranch is what it is checking; this one is checking four
## autoloads and a directory. It proves its innocence rather than promising it, and about TWO
## directories: the player's own user://saves, which nothing on an automated run may ever
## touch, and whatever FILLY_TEST_SAVE_DIR redirected this process to, which this gate has no
## business writing either. The first of those was the parked defect that slice R0 closed --
## a gate boot used to write the live slots -- and this is the check that keeps it closed.
##
## AudioSafety has muted Master before this file's _ready() runs, and the command line adds
## --audio-driver Dummy on top, so nothing here can make noise on the machine running it.
##
## Marker after verdict, exit code is the verdict. See docs/testing.md.
##
## Run it with:
##   tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/sound_test.tscn

const GateWatchdogScript := preload("res://scripts/gate_watchdog.gd")
const SoundScript := preload("res://systems/sound.gd")
const WorldStateScript := preload("res://systems/world_state.gd")
const SettingsScript := preload("res://systems/settings.gd")

const SaveIOScript := preload("res://systems/save_io.gd")

var _checks: Dictionary = {}
var _duplicates: Array[String] = []


## get_node(), not the bare `Sound` identifier: tools/run_tests.sh's parse sweep runs every
## .gd file through `--check-only --script`, and that pass never boots the scene tree, so
## an autoload's name is never registered as a resolvable global identifier there, even
## though it resolves fine in a real run (this scene, booted for real). Every function below
## that needs it opens with `var Sound := _sound_autoload()`, a local that shadows the global
## for the rest of that function, so the body reads exactly like a call on the autoload
## because it is one. Same convention as game/test/test_sound.gd.
func _sound_autoload() -> Node:
	return get_node("/root/Sound")


func _ready() -> void:
	GateWatchdogScript.arm(self, "SOUND", 120.0)
	# The two innocence checks below are only independent when the run is redirected; on a
	# bare manual boot they name the same directory and can only ever agree with each other.
	var redirected: bool = SaveIOScript.save_dir != SaveIOScript.DEFAULT_SAVE_DIR
	var live_before: PackedStringArray = _save_listing(SaveIOScript.DEFAULT_SAVE_DIR)
	var session_before: PackedStringArray = _save_listing(SaveIOScript.save_dir)
	print("SOUND saves live=%s session=%s" % [SaveIOScript.DEFAULT_SAVE_DIR,
		SaveIOScript.save_dir])
	_check_the_buses()
	_check_every_stream()
	_check_the_loop_flags()
	_check_the_verbs()
	_check_the_pools()
	_check_the_volume_sliders()
	if redirected:
		_set_check("the gate wrote nothing into the player's own save directory",
			_save_listing(SaveIOScript.DEFAULT_SAVE_DIR) == live_before)
		_set_check("the gate wrote nothing into this run's save directory",
			_save_listing(SaveIOScript.save_dir) == session_before)
	else:
		_set_check("the gate wrote nothing into the player's own save directory (run was not redirected)",
			_save_listing(SaveIOScript.DEFAULT_SAVE_DIR) == live_before)
	_finish()


# --- the checks ---------------------------------------------------------------------------

func _check_the_buses() -> void:
	_set_check("the layout carries exactly four buses", AudioServer.bus_count == 4)
	_set_check("bus zero is Master", AudioServer.get_bus_name(0) == "Master")
	for bus: StringName in [SoundScript.BUS_AMBIENT, SoundScript.BUS_EFFECTS,
			SoundScript.BUS_UI]:
		var index: int = AudioServer.get_bus_index(String(bus))
		_set_check("the %s bus exists" % bus, index > 0)
		if index > 0:
			_set_check("the %s bus sends into Master" % bus,
				AudioServer.get_bus_send(index) == &"Master")


func _check_every_stream() -> void:
	var Sound := _sound_autoload()
	var missing: Array[String] = []
	var total := 0
	for id: StringName in Sound.ids():
		var entry: Dictionary = Sound.entry(id)
		var paths: PackedStringArray = entry.get("paths", PackedStringArray())
		for path: String in paths:
			total += 1
			if Sound.stream_for(path) == null:
				missing.append("%s (%s)" % [path, id])
	for line: String in missing:
		push_error("SOUND: stream did not load: %s" % line)
	print("SOUND streams=%d ids=%d" % [total, Sound.ids().size()])
	_set_check("every file in the library decoded", missing.is_empty())
	_set_check("the library is not empty", Sound.ids().size() > 0)


## THE IMPORT FLAGS, WHICH ONLY A REAL ENGINE KNOWS. A bed whose .import says loop=false
## plays forty five seconds of birdsong and then leaves the ranch silent for the rest of
## the phase, and no unit test can see it: the flag lives in the imported resource, not in
## the source file and not in LIBRARY.
func _check_the_loop_flags() -> void:
	var Sound := _sound_autoload()
	var wrong: Array[String] = []
	for id: StringName in Sound.ids():
		var entry: Dictionary = Sound.entry(id)
		var wants_loop: bool = bool(entry.get("loop", false))
		var paths: PackedStringArray = entry.get("paths", PackedStringArray())
		for path: String in paths:
			var stream: AudioStream = Sound.stream_for(path)
			if stream == null:
				continue
			var loops := false
			if stream is AudioStreamOggVorbis:
				loops = (stream as AudioStreamOggVorbis).loop
			elif stream is AudioStreamWAV:
				loops = (stream as AudioStreamWAV).loop_mode != AudioStreamWAV.LOOP_DISABLED
			else:
				wrong.append("%s is neither ogg nor wav" % path)
				continue
			if loops != wants_loop:
				wrong.append("%s imported loop=%s, library says %s"
					% [path, loops, wants_loop])
	for line: String in wrong:
		push_error("SOUND: %s" % line)
	_set_check("every bed imported as a loop and every one shot did not", wrong.is_empty())


func _check_the_verbs() -> void:
	var Sound := _sound_autoload()
	var refused: Array[String] = []
	for id: StringName in Sound.ids():
		if not Sound.play(id):
			refused.append("play(%s)" % id)
		if not Sound.play_at(id, Vector3(3.0, 0.0, -4.0)):
			refused.append("play_at(%s)" % id)
	Sound.stop_all()
	for line: String in refused:
		push_error("SOUND: %s was refused" % line)
	_set_check("play and play_at accept every id in the library", refused.is_empty())

	# Every phase, then every zone on top of every phase, then back to nothing. Any
	# combination that wanted more beds than there are voices would push_error here.
	var beds_seen := 0
	for phase: int in [WorldStateScript.Phase.DAWN, WorldStateScript.Phase.DAY,
			WorldStateScript.Phase.DUSK, WorldStateScript.Phase.NIGHT]:
		Sound.ambient_set_phase(phase)
		beds_seen = maxi(beds_seen, Sound.active_bed_ids().size())
		for zone: StringName in [SoundScript.ZONE_STRIP, SoundScript.ZONE_CASINO,
				SoundScript.ZONE_NONE]:
			Sound.ambient_set_zone(zone)
			beds_seen = maxi(beds_seen, Sound.active_bed_ids().size())
	print("SOUND beds_peak=%d voices=%d" % [beds_seen, SoundScript.BED_VOICES])
	_set_check("no phase and zone pair outran the bed voices",
		beds_seen > 0 and beds_seen <= SoundScript.BED_VOICES)

	Sound.stop_all()
	_set_check("stop_all clears the beds and the bookkeeping",
		Sound.active_bed_ids().is_empty() and Sound.current_phase() == -1
			and Sound.current_zone() == SoundScript.ZONE_NONE)

	var crowd_started: bool = Sound.play_loop(&"race_crowd_loop")
	var gallop_started: bool = Sound.play_loop(&"race_gallop")
	_set_check("the held loops start", crowd_started and gallop_started)
	Sound.stop_loop(&"race_crowd_loop")
	Sound.stop_loop(&"race_gallop")
	_set_check("the held loops stop", Sound.looping_ids().is_empty())


## THE THIRTEENTH VOICE. A pool that grew instead of stealing would allocate a player per
## trigger for as long as the session lasts, and the symptom would be a machine getting
## slower over an hour rather than anything a test would notice.
func _check_the_pools() -> void:
	var Sound := _sound_autoload()
	Sound.stop_all()
	for i in range(SoundScript.POOL_2D + 1):
		Sound.play(&"ui_move")
	_set_check("the 2D pool steals rather than growing",
		Sound.pool_2d_size() == SoundScript.POOL_2D)
	for i in range(SoundScript.POOL_3D + 1):
		Sound.play_at(&"hoof_grass", Vector3(float(i), 0.0, 0.0))
	_set_check("the 3D pool steals rather than growing",
		Sound.pool_3d_size() == SoundScript.POOL_3D)
	Sound.stop_all()


func _check_the_volume_sliders() -> void:
	var settings: Settings = SettingsScript.new()
	settings.master_volume = 1.0
	settings.ambient_volume = 0.5
	settings.effects_volume = 0.0
	settings.apply_audio()
	var ambient: int = AudioServer.get_bus_index("Ambient")
	var effects: int = AudioServer.get_bus_index("Effects")
	var ui: int = AudioServer.get_bus_index("UI")
	_set_check("the ambient slider reaches its bus",
		ambient > 0 and not AudioServer.is_bus_mute(ambient)
			and absf(AudioServer.get_bus_volume_db(ambient) - linear_to_db(0.5)) < 0.05)
	_set_check("zero on the effects slider mutes effects and the menus with it",
		effects > 0 and ui > 0 and AudioServer.is_bus_mute(effects)
			and AudioServer.is_bus_mute(ui))
	settings.effects_volume = 1.0
	settings.apply_audio()
	# AudioSafety muted Master for this headless run and nothing here may undo that.
	_set_check("Master is still muted for an automated run",
		AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")))


# --- plumbing ------------------------------------------------------------------------------

func _save_listing(dir: String) -> PackedStringArray:
	if not DirAccess.dir_exists_absolute(dir):
		return PackedStringArray()
	return DirAccess.get_files_at(dir)


func _set_check(label: String, ok: bool) -> void:
	if _checks.has(label):
		_duplicates.append(label)
	_checks[label] = ok


func _finish() -> void:
	var Sound := _sound_autoload()
	var failed: Array[String] = []
	for label in _checks:
		if not bool(_checks[label]):
			failed.append(String(label))
	for label in _duplicates:
		failed.append("duplicate check label: %s" % label)
	for label in _checks:
		print("SOUND %s %s" % ["ok  " if bool(_checks[label]) else "FAIL", label])
	var all_ok: bool = failed.is_empty()
	# Marker after the verdict, exit code IS the verdict. See docs/testing.md.
	if all_ok:
		print("SOUND_OK ids=%d" % Sound.ids().size())
	else:
		print("SOUND_FAILED ids=%d failed=%d" % [Sound.ids().size(), failed.size()])
	get_tree().quit(0 if all_ok else 1)
