class_name SaveIO
extends RefCounted
## READING AND WRITING THE SAVE FILE. One slot is one file of human-readable JSON at
## `user://saves/slot_<n>.json`. Nothing in here knows what a pony is: it takes a
## Dictionary from game/systems/game_state.gd, stamps a format version on it, and puts it
## on disk in a way that cannot lose the previous save. That split is deliberate -- the
## rules about WHAT is saved change every phase, the rules about HOW a file is written
## safely do not.
##
## --- WHY THE FILE IS PLAIN, INDENTED, SORTED JSON ------------------------------------
##
## Not a default, a requirement. The design spec wants two players able to trade a pony by
## sending each other a blob, which only works if the blob is text a person can open, read
## and paste. Sorted keys and two-space indentation are for the same audience: a save file
## that diffs cleanly is one a human can reason about, and "what changed between these two
## saves" is a question this project will ask for real the first time somebody reports a
## pony going missing. The cost is size and parse speed, and at ranch scale both are noise.
##
## --- THE ATOMIC WRITE, AND WHAT IT ACTUALLY PROTECTS ----------------------------------
##
## save() is stage() then commit():
##
##   stage(slot, data)   validate -> serialise -> write `slot_<n>.json.tmp`
##   commit(slot)        copy the live save to `slot_<n>.json.bak` -> RENAME tmp over it
##
## A write that dies anywhere in stage() has touched nothing but the temp file, so the
## live save is still the last good one, byte for byte. A write that dies during commit()
## either has not renamed yet (live save intact) or has (new save complete). There is no
## point at which the live file is a half-written truncated thing -- which is the failure
## mode that actually eats saves, because a truncated JSON file parses to nothing and a
## naive loader treats "I could not read it" as "there was nothing there".
##
## THE TWO FUNCTIONS ARE PUBLIC SO THE INTERRUPTION IS PROVABLE. A guarantee about crashes
## that can only be reasoned about is not a guarantee. Splitting the write in two lets a
## test -- and the process-kill proof in this task's report, which SIGKILLs a real Godot
## between the two calls -- stop exactly where a crash would and then show the old save
## loading intact afterwards. See game/test/test_save_io.gd.
##
## WINDOWS IS WHY THE BACKUP EXISTS. On POSIX the rename is atomic and the backup is
## belt-and-braces. On Windows, Godot's DirAccess.rename REMOVES an existing destination
## first and then renames onto it (dir_access_windows.cpp), so there is a sub-millisecond
## window with no live save at all. The `.bak` copy is what covers that window, and it
## doubles as the thing a player can hand back to themselves after a bad save. It is NOT
## read automatically -- see load() -- because silently substituting an older ranch for
## the one the player thinks they are loading would be a worse bug than the one it fixes.
##
## --- THE VERSION POLICY (the whole of it) ---------------------------------------------
##
## Every file carries `"version": <int>`. On load:
##
##   version == FORMAT_VERSION   loaded as-is.
##   version <  FORMAT_VERSION   loaded, then run through migrate(). Fields a newer build
##                               added are simply absent, and every consumer of this
##                               dictionary (GameState.from_dict, PonyInstance.from_dict)
##                               is required to fill a missing field from its default
##                               rather than to fail -- which is what makes old saves
##                               loadable by construction instead of by remembering.
##   version >  FORMAT_VERSION   REFUSED. Returns {} and push_error()s. A newer build may
##                               have changed what an existing field MEANS; reading it
##                               with today's meaning would silently downgrade the ranch
##                               and then write the misreading back over it. Refusing
##                               leaves the file untouched, so reinstalling the newer
##                               build recovers it in full.
##   no version / not an int     REFUSED, same as corrupt: this is not one of our files
##                               and nothing can be said about what its fields mean.
##
## When FORMAT_VERSION is bumped, add a branch to migrate() for the old shape and a test
## that loads a fixture written in it. Bumping the number without doing that is how a
## "supported" old save quietly stops being one.
##
## Version 2 (Phase 2 slice 1) adds "gems" and "inventory"; both default to {}.
##
## Version 3 (Phase 2 slice 4) adds "world_time"; defaults to 0.0 (dawn).
##
## Version 4 (Phase 2 slice 5) adds "compendium" and "requests"; compendium defaults to {}
## (nobody marked seen or caught) and requests defaults to [] (none pending).
##
## Version 5 (Phase 3 slice 1) adds "ledger" and "player"; ledger defaults to {} (a brand
## new sponsorship balance) and player defaults to {} (the name Twilight and the shipped
## look). Both are read through their own from_dict(), each of which fills every missing
## field from its own default, so a version 4 file needs nothing else.
##
## --- JSON HAS NO INTEGER TYPE ---------------------------------------------------------
##
## Every number in a dictionary that came back from load() is a FLOAT, including the ones
## that were written as ints. Callers int() the ones that are counts -- GameState.from_dict
## does that for `bits` and `world_seed`, and PonyInstance.from_dict for `caught_at_ms`.
## The recovery is exact at the magnitudes this game uses: a double represents every
## integer below 2^53 exactly, and the largest number in a save is a millisecond Unix time
## of about 1.8e12. Pinned by a test rather than assumed.
##
## --- MISSING vs CORRUPT ---------------------------------------------------------------
##
## A missing slot is NOT an error -- it is a new game, the state every first run is in --
## so it returns {} SILENTLY. A corrupt slot returns {} LOUDLY (push_error) and leaves the
## file exactly where it is: never deleted, never rewritten, never "repaired". A player
## whose file went bad can still send it to somebody who knows JSON, but not if the game
## helpfully overwrote it on the next boot. Callers must therefore distinguish the two by
## asking has_slot() rather than by treating {} as "no save".
##
## RefCounted with only static members: nothing here needs a tree, a frame or an instance,
## so it is all callable as SaveIO.save(...) and testable in milliseconds
## (game/test/test_save_io.gd), the pattern every system under game/systems/ follows.

## The format this build writes, and the highest it will read. See the version policy in
## the class comment before changing it.
const FORMAT_VERSION := 5

## The key the version is stamped under. Reserved: a caller's payload must not use it --
## save() overwrites it, and load() reads it back out.
const VERSION_KEY := "version"

## Where saves live when nobody has said otherwise. `user://` on purpose and never a
## constructed path: it is `~/.local/share/godot/app_userdata/Filly Rancher/` on Linux and
## `%APPDATA%\Godot\app_userdata\Filly Rancher\` on Windows, which is not a path anything
## should ever try to spell for itself (docs/windows-testing.md has the empirical
## confirmation of the Windows one, taken under Proton).
const DEFAULT_SAVE_DIR := "user://saves"

const SLOT_PREFIX := "slot_"
const SLOT_EXTENSION := ".json"
## Extensions of the two files that live BESIDE a save: the in-flight write and the
## previous good copy. Both are deliberately not `.json`, so anything that lists the
## directory looking for saves cannot mistake one for a slot.
const TEMP_EXTENSION := ".json.tmp"
const BACKUP_EXTENSION := ".json.bak"

## Indentation JSON.stringify writes with. Two spaces, so a save file opens readably in
## anything, including a chat window with a pony blob pasted into it.
const INDENT := "  "

## The directory saves are read from and written to. A plain static var rather than a
## constant for exactly one reason: the test suite points it at a scratch directory under
## user:// so that running `bash tools/run_tests.sh` can never overwrite the developer's
## own game. Production code never assigns it.
static var save_dir := DEFAULT_SAVE_DIR


## The file a slot lives in, e.g. `user://saves/slot_0.json`.
static func slot_path(slot: int) -> String:
	return save_dir.path_join("%s%d%s" % [SLOT_PREFIX, slot, SLOT_EXTENSION])


## The in-flight write for a slot. Only ever exists between stage() and commit(), or after
## a crash in between -- and a leftover one is inert: load() never reads it.
static func temp_path(slot: int) -> String:
	return save_dir.path_join("%s%d%s" % [SLOT_PREFIX, slot, TEMP_EXTENSION])


## The previous good save for a slot, kept by commit(). Never read automatically; it is
## there so a person can rename it back.
static func backup_path(slot: int) -> String:
	return save_dir.path_join("%s%d%s" % [SLOT_PREFIX, slot, BACKUP_EXTENSION])


## Is there a save in this slot? The only correct way to tell "no save yet" from "a save
## that failed to load" -- both of which come back from load() as {}.
static func has_slot(slot: int) -> bool:
	return slot >= 0 and FileAccess.file_exists(slot_path(slot))


## Whether this build will load a file stamped with `version`. The version policy in the
## class comment, expressed as a function so it is pinned by a test rather than only
## described in a comment.
static func can_load_version(version: int) -> bool:
	return version >= 1 and version <= FORMAT_VERSION


## Write `data` to `slot`, atomically. Returns false -- having changed nothing on disk --
## if the slot is invalid, the payload cannot be represented as JSON, or the write fails.
##
## `data` is NOT modified: the version stamp goes into the file, not into the caller's
## live game state.
static func save(slot: int, data: Dictionary) -> bool:
	if not stage(slot, data):
		return false
	return commit(slot)


## First half of a save: validate, serialise and write the temp file. The live save is not
## touched. Returns false (loudly) rather than writing something unreadable.
static func stage(slot: int, data: Dictionary) -> bool:
	if slot < 0:
		push_error("SaveIO.stage: slot %d is not a valid slot (slots start at 0)" % slot)
		return false

	# Checked BEFORE anything is written, and by walking the payload rather than by
	# trusting the serialiser: JSON.stringify turns an Object into the literal `null`
	# without complaining, so a roster of objects would produce a perfectly valid file
	# with every pony replaced by null. That file would then load, and the ranch would be
	# gone -- with no error anywhere, which is the worst shape a save bug can have.
	var offender := _first_unrepresentable(data, "the payload")
	if offender != "":
		push_error("SaveIO.stage: refusing to write slot %d -- %s cannot be represented in JSON" % [
			slot, offender])
		return false

	var payload := data.duplicate(true)
	payload[VERSION_KEY] = FORMAT_VERSION

	var dir_error := DirAccess.make_dir_recursive_absolute(save_dir)
	if dir_error != OK and dir_error != ERR_ALREADY_EXISTS:
		push_error("SaveIO.stage: cannot create save directory '%s' (%s)" % [
			save_dir, error_string(dir_error)])
		return false

	# sort_keys=true so two saves of the same ranch diff cleanly, and full_precision=true
	# so a float survives the round trip as the float it was rather than as a rounded
	# print of it -- happiness and hunger are floats and a save that shaves them is a save
	# that changes the game slightly every time it is written.
	var text := JSON.stringify(payload, INDENT, true, true) + "\n"

	var path := temp_path(slot)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("SaveIO.stage: cannot open '%s' for writing (%s)" % [
			path, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(text)
	# Flushed and closed explicitly rather than left to the FileAccess going out of scope:
	# the whole point of the temp file is that commit() renames a COMPLETE file over the
	# live save, and a rename that overtakes an unflushed buffer would publish a truncated
	# one -- the exact failure this class is built to make impossible.
	file.flush()
	file.close()
	return true


## Second half of a save: back up the live save, then publish the staged write over it by
## rename. Returns false (loudly) if there is nothing staged or the rename fails -- in
## which case the live save is still the last good one and the temp file is left alone for
## inspection rather than deleted.
static func commit(slot: int) -> bool:
	var temp := temp_path(slot)
	if not FileAccess.file_exists(temp):
		push_error("SaveIO.commit: nothing staged for slot %d ('%s' does not exist)" % [slot, temp])
		return false

	var live := slot_path(slot)
	if FileAccess.file_exists(live):
		# Best effort: a failed backup is worth a warning but is not a reason to refuse the
		# save. On POSIX the rename below is atomic on its own; the backup is what covers
		# Windows' remove-then-rename window (see the class comment).
		var copy_error := DirAccess.copy_absolute(live, backup_path(slot))
		if copy_error != OK:
			push_warning("SaveIO.commit: could not back up slot %d before overwriting it (%s)" % [
				slot, error_string(copy_error)])

	var rename_error := DirAccess.rename_absolute(temp, live)
	if rename_error != OK:
		push_error("SaveIO.commit: could not publish slot %d -- '%s' -> '%s' (%s). The previous save is untouched and the staged write is still at the temp path." % [
			slot, temp, live, error_string(rename_error)])
		return false
	return true


## Read `slot`. Returns the saved dictionary, or an EMPTY one for a slot that does not
## exist (silently -- that is a new game) or one that cannot be trusted (loudly). The file
## is never modified by a load, whatever state it is in.
static func load(slot: int) -> Dictionary:
	if slot < 0:
		push_error("SaveIO.load: slot %d is not a valid slot (slots start at 0)" % slot)
		return {}

	var path := slot_path(slot)
	if not FileAccess.file_exists(path):
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("SaveIO.load: '%s' exists but cannot be opened (%s)" % [
			path, error_string(FileAccess.get_open_error())])
		return {}
	var text := file.get_as_text()
	file.close()

	# JSON.new().parse() rather than the static JSON.parse_string(): the static one raises
	# an ENGINE error of its own on bad input, on top of the push_error below, which turns
	# "the loader handled a corrupt file exactly as designed" into a second, scarier-
	# looking error in the log (and into an unexpected-error test failure under GUT). The
	# instance form returns a code and hands over the line number and message, which is
	# also strictly better diagnostics for a player reporting a broken save.
	var json := JSON.new()
	var parse_error := json.parse(text)
	if parse_error != OK:
		push_error("SaveIO.load: '%s' is not a readable save file -- corrupt or truncated (%s at line %d). It has been left on disk exactly as it is." % [
			path, json.get_error_message(), json.get_error_line()])
		return {}
	if typeof(json.data) != TYPE_DICTIONARY:
		push_error("SaveIO.load: '%s' is valid JSON but not a save file -- the top level is %s, not an object. It has been left on disk exactly as it is." % [
			path, type_string(typeof(json.data))])
		return {}

	var loaded: Dictionary = json.data
	var raw_version: Variant = loaded.get(VERSION_KEY, null)
	if typeof(raw_version) != TYPE_INT and typeof(raw_version) != TYPE_FLOAT:
		push_error("SaveIO.load: '%s' carries no '%s' field, so it is not a save file this game wrote. Refusing to guess at what its fields mean." % [
			path, VERSION_KEY])
		return {}

	var version := int(raw_version)
	if not can_load_version(version):
		push_error("SaveIO.load: '%s' is version %d and this build reads up to version %d. Refusing to load it rather than misread it -- the file is untouched, so a build new enough to read it still can." % [
			path, version, FORMAT_VERSION])
		return {}

	if version < FORMAT_VERSION:
		loaded = migrate(loaded, version)
	loaded[VERSION_KEY] = FORMAT_VERSION
	return loaded


## Delete a slot and everything beside it. Returns true if the slot file is gone
## afterwards. Used by the tests and by a future "delete save" menu; nothing in the game
## calls it during play.
static func delete_slot(slot: int) -> bool:
	for path in [slot_path(slot), temp_path(slot), backup_path(slot)]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	return not FileAccess.file_exists(slot_path(slot))


## Bring a save written by an older build up to the current shape.
##
## The rule for what belongs here: only changes that cannot be expressed as a DEFAULT.
## A field that was added keeps working for free, because every from_dict() in this
## project fills a missing field from its default. A field that was RENAMED, split, or
## whose units or meaning changed is what needs a branch here.
##
## gems and inventory are the one exception worth writing down: GameState.from_dict()
## already defaults a missing "gems"/"inventory" to an empty pouch/inventory on its own,
## so this branch is not load-bearing for GameState. It exists so that migrate()'s
## output (what a version-1 file becomes once migrated, asserted directly by
## test_save_io.gd) states the version-2 shape explicitly, rather than leaving it to be
## inferred from a caller elsewhere in the project.
static func migrate(data: Dictionary, from_version: int) -> Dictionary:
	var out := data.duplicate(true)
	if from_version < 2:
		if not out.has("gems"):
			out["gems"] = {}
		if not out.has("inventory"):
			out["inventory"] = {}
	if from_version < 3:
		if not out.has("world_time"):
			out["world_time"] = 0.0
	if from_version < 4:
		if not out.has("compendium"):
			out["compendium"] = {}
		if not out.has("requests"):
			out["requests"] = []
	if from_version < 5:
		if not out.has("ledger"):
			out["ledger"] = {}
		if not out.has("player"):
			# PlayerLook.from_dict({}) is Twilight, the shipped look and a blank mark, which
			# is exactly what the design doc says a version 4 save should load as. Stated
			# here rather than left to that default so migrate()'s OUTPUT states the version
			# 5 shape, the way the version 2 branch does.
			out["player"] = {}
		if not out.has("casino"):
			# An empty dictionary is Casino.from_dict's own "no chips", which is what a save
			# from before the Palace opened should load as. Stated here rather than left to
			# that default so migrate()'s OUTPUT states the whole version 5 shape.
			out["casino"] = {}
	return out


## The first thing in `value` that JSON cannot represent, described for an error message,
## or "" if the whole structure is representable.
##
## JSON-safe here means: null, bool, int, float, String, Array of safe values, and
## Dictionary with STRING keys and safe values. Deliberately stricter than what
## JSON.stringify will silently accept:
##
##   * Objects become the literal `null` -- see stage() for why that is the dangerous one.
##   * StringName keys and values come back as plain Strings, so a round trip would
##     silently change a field's TYPE. Every to_dict() in this project already converts
##     its StringNames (game/systems/pony_instance.gd does it explicitly); refusing them
##     here is what keeps that from rotting.
##   * Non-string Dictionary keys become strings too: `{1: "pen"}` saves and reloads as
##     `{"1": "pen"}`, and a lookup by the int key then misses. Plot slots are keyed by
##     id for exactly this reason.
static func _first_unrepresentable(value: Variant, path: String) -> String:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return ""
		TYPE_ARRAY:
			var array: Array = value
			for i in array.size():
				var found := _first_unrepresentable(array[i], "%s[%d]" % [path, i])
				if found != "":
					return found
			return ""
		TYPE_DICTIONARY:
			var dict: Dictionary = value
			for key in dict:
				if typeof(key) != TYPE_STRING:
					return "the key %s in %s (%s -- JSON keys are strings, and a non-string key would silently come back as one)" % [
						str(key), path, type_string(typeof(key))]
				var found := _first_unrepresentable(dict[key], "%s.%s" % [path, key])
				if found != "":
					return found
			return ""
		_:
			return "%s (%s)" % [path, type_string(typeof(value))]
