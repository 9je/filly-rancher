extends GutTest
## THE CORPUS TEST. Sound.LIBRARY, tools/sound_manifest.txt and
## game/assets/audio/sound_report.txt are three lists of the same set of files, maintained
## by three different hands, and this file is what keeps them one set. It never plays
## anything; it reads.
##
## THE ORPHAN RULE RUNS BOTH WAYS on purpose. A manifest row nobody plays is a file that
## was downloaded, committed and forgotten. A LIBRARY path with no manifest row is a file
## nobody can reproduce, which is the same as no file at all the first time somebody
## re-runs the pipeline on a clean checkout.

const SoundScript := preload("res://systems/sound.gd")
const WorldStateScript := preload("res://systems/world_state.gd")

const AUDIO_ROOT := "res://assets/audio/"
const REPORT := "res://assets/audio/sound_report.txt"


## tools/ sits beside the Godot project root rather than inside it, so res:// cannot reach
## it; globalize and walk up one.
static func manifest_path() -> String:
	return ProjectSettings.globalize_path("res://").path_join("../tools/sound_manifest.txt").simplify_path()


## dest path (relative to game/assets/audio/) for every non comment manifest row.
static func manifest_dests() -> PackedStringArray:
	var out := PackedStringArray()
	var file := FileAccess.open(manifest_path(), FileAccess.READ)
	if file == null:
		return out
	while not file.eof_reached():
		var line: String = file.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		out.append(line.split("|", true, 1)[0])
	return out


## Every path any LIBRARY entry names, once each.
static func library_paths() -> PackedStringArray:
	var out := PackedStringArray()
	for id: StringName in SoundScript.LIBRARY.keys():
		var entry: Dictionary = SoundScript.LIBRARY[id]
		var paths: PackedStringArray = entry.get("paths", PackedStringArray())
		for path: String in paths:
			if not out.has(path):
				out.append(path)
	return out


func test_the_library_is_not_empty() -> void:
	assert_gt(SoundScript.LIBRARY.size(), 0)


func test_every_id_follows_the_naming_scheme() -> void:
	var pattern := RegEx.new()
	pattern.compile("^[a-z][a-z0-9_]*$")
	for id: StringName in SoundScript.LIBRARY.keys():
		assert_not_null(pattern.search(String(id)), "id '%s' must be lower snake case" % id)


func test_every_entry_carries_the_whole_shape() -> void:
	for id: StringName in SoundScript.LIBRARY.keys():
		var entry: Dictionary = SoundScript.LIBRARY[id]
		for key: String in ["paths", "bus", "volume_db", "pitch_min", "pitch_max", "loop"]:
			assert_true(entry.has(key), "entry '%s' is missing '%s'" % [id, key])
		var paths: PackedStringArray = entry.get("paths", PackedStringArray())
		assert_gt(paths.size(), 0, "entry '%s' names no file" % id)


func test_every_path_is_under_the_audio_root_and_exists_on_disk() -> void:
	for path: String in library_paths():
		assert_true(path.begins_with(AUDIO_ROOT), "'%s' is outside %s" % [path, AUDIO_ROOT])
		assert_true(FileAccess.file_exists(path), "'%s' is not on disk" % path)
		assert_true(FileAccess.file_exists(path + ".import"),
			"'%s' has no committed .import sidecar" % path)


func test_no_orphans_in_either_direction() -> void:
	var dests: PackedStringArray = manifest_dests()
	assert_gt(dests.size(), 0, "the manifest could not be read at %s" % manifest_path())
	var from_library: PackedStringArray = PackedStringArray()
	for path: String in library_paths():
		from_library.append(path.trim_prefix(AUDIO_ROOT))
	for dest: String in dests:
		assert_true(from_library.has(dest), "manifest row '%s' is played by nothing" % dest)
	for dest: String in from_library:
		assert_true(dests.has(dest), "LIBRARY path '%s' has no manifest row" % dest)


func test_variant_sets_are_contiguous_from_one() -> void:
	var checked: int = 0
	for id: StringName in SoundScript.LIBRARY.keys():
		var entry: Dictionary = SoundScript.LIBRARY[id]
		var paths: PackedStringArray = entry.get("paths", PackedStringArray())
		checked += 1
		if paths.size() < 2:
			continue
		for index in paths.size():
			var stem: String = paths[index].get_file().get_basename()
			assert_eq(stem, "%s_%d" % [String(id), index + 1],
				"variant %d of '%s' must be named %s_%d" % [index + 1, id, id, index + 1])
	assert_gt(checked, 0, "the rule ran over a real library; variant sets arrive with Task 4")


func test_pitch_ranges_are_sane() -> void:
	for id: StringName in SoundScript.LIBRARY.keys():
		var entry: Dictionary = SoundScript.LIBRARY[id]
		var low: float = float(entry.get("pitch_min", 1.0))
		var high: float = float(entry.get("pitch_max", 1.0))
		assert_gte(low, 0.5, "'%s' pitch_min is below 0.5" % id)
		assert_lte(high, 2.0, "'%s' pitch_max is above 2.0" % id)
		assert_lte(low, high, "'%s' has pitch_min above pitch_max" % id)


func test_every_bus_is_one_of_the_three() -> void:
	for id: StringName in SoundScript.LIBRARY.keys():
		var entry: Dictionary = SoundScript.LIBRARY[id]
		var bus: StringName = StringName(entry.get("bus", &""))
		assert_true(bus == SoundScript.BUS_AMBIENT or bus == SoundScript.BUS_EFFECTS
			or bus == SoundScript.BUS_UI, "'%s' routes to '%s'" % [id, bus])


func test_the_directory_a_file_sits_in_decides_its_bus() -> void:
	for id: StringName in SoundScript.LIBRARY.keys():
		var entry: Dictionary = SoundScript.LIBRARY[id]
		var bus: StringName = StringName(entry.get("bus", &""))
		var paths: PackedStringArray = entry.get("paths", PackedStringArray())
		for path: String in paths:
			var folder: String = path.trim_prefix(AUDIO_ROOT).get_base_dir()
			match folder:
				"ambient": assert_eq(bus, SoundScript.BUS_AMBIENT, "'%s' is a bed" % id)
				"ui": assert_eq(bus, SoundScript.BUS_UI, "'%s' is a menu tick" % id)
				_: assert_eq(bus, SoundScript.BUS_EFFECTS, "'%s' is a world sound" % id)


func test_ogg_entries_loop_and_wav_entries_do_not() -> void:
	for id: StringName in SoundScript.LIBRARY.keys():
		var entry: Dictionary = SoundScript.LIBRARY[id]
		var wants_loop: bool = bool(entry.get("loop", false))
		var paths: PackedStringArray = entry.get("paths", PackedStringArray())
		for path: String in paths:
			var is_ogg: bool = path.get_extension() == "ogg"
			assert_eq(wants_loop, is_ogg,
				"'%s': ogg means a loop and wav means a one shot, and '%s' disagrees"
					% [id, path])


func test_the_bed_tables_name_only_real_looping_ambient_entries() -> void:
	var tables: Array[Dictionary] = [SoundScript.BEDS, SoundScript.ZONE_BEDS]
	for table: Dictionary in tables:
		for key: Variant in table.keys():
			var rows: Array = table[key]
			assert_gt(rows.size(), 0, "bed table key '%s' is empty" % str(key))
			for row: Dictionary in rows:
				var id: StringName = StringName(row.get("id", &""))
				assert_true(SoundScript.LIBRARY.has(id), "bed '%s' is not in LIBRARY" % id)
				var entry: Dictionary = SoundScript.LIBRARY[id]
				assert_eq(StringName(entry.get("bus", &"")), SoundScript.BUS_AMBIENT)
				assert_true(bool(entry.get("loop", false)), "bed '%s' must loop" % id)
				assert_lte(float(row.get("volume_db", 0.0)), 0.0,
					"bed '%s' is mixed above its mastered level" % id)


func test_the_phase_table_covers_exactly_the_four_phases() -> void:
	assert_eq(SoundScript.BEDS.size(), 4)
	for phase: int in [WorldStateScript.Phase.DAWN, WorldStateScript.Phase.DAY,
			WorldStateScript.Phase.DUSK, WorldStateScript.Phase.NIGHT]:
		assert_true(SoundScript.BEDS.has(phase), "no beds for phase %d" % phase)


func test_the_zone_table_covers_exactly_the_two_zones() -> void:
	assert_eq(SoundScript.ZONE_BEDS.size(), 2)
	assert_true(SoundScript.ZONE_BEDS.has(SoundScript.ZONE_STRIP))
	assert_true(SoundScript.ZONE_BEDS.has(SoundScript.ZONE_CASINO))
	assert_false(SoundScript.ZONE_BEDS.has(SoundScript.ZONE_NONE))


func test_no_phase_and_zone_pair_asks_for_more_beds_than_there_are_voices() -> void:
	for phase: Variant in SoundScript.BEDS.keys():
		var phase_rows: Array = SoundScript.BEDS[phase]
		for zone: Variant in SoundScript.ZONE_BEDS.keys():
			var ids: Dictionary = {}
			for row: Dictionary in phase_rows:
				ids[StringName(row.get("id", &""))] = true
			for row: Dictionary in SoundScript.ZONE_BEDS[zone]:
				ids[StringName(row.get("id", &""))] = true
			assert_lte(ids.size(), SoundScript.BED_VOICES,
				"phase %s in zone %s wants %d beds" % [str(phase), str(zone), ids.size()])


func test_every_library_file_passed_the_loudness_report() -> void:
	var file := FileAccess.open(REPORT, FileAccess.READ)
	assert_not_null(file, "no report at %s; run bash tools/fetch_sounds.sh" % REPORT)
	if file == null:
		return
	var passed: Dictionary = {}
	while not file.eof_reached():
		var line: String = file.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var fields: PackedStringArray = line.split(" ", false)
		if fields.size() < 2:
			continue
		passed[fields[1]] = fields[0] == "PASS"
	for path: String in library_paths():
		var dest: String = path.trim_prefix(AUDIO_ROOT)
		assert_true(passed.has(dest), "'%s' is not in the loudness report" % dest)
		assert_true(bool(passed.get(dest, false)), "'%s' FAILED the loudness report" % dest)


func test_no_id_and_no_path_carries_a_dash_of_either_kind() -> void:
	# The house rule, checked on the one corpus a hand edit is most likely to slip into.
	for id: StringName in SoundScript.LIBRARY.keys():
		assert_false(String(id).contains("--"))
		assert_false(String(id).contains(char(0x2014)))
	for path: String in library_paths():
		assert_false(path.contains("--"))
		assert_false(path.contains(char(0x2014)))
