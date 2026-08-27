extends SceneTree
## PROOF THAT AN INTERRUPTED SAVE CANNOT DESTROY THE PREVIOUS ONE. Driven by
## `bash tools/prove_atomic_save.sh`; not part of the game and never loaded by it.
##
## WHY THIS EXISTS AT ALL. game/systems/save_io.gd claims that a write killed halfway
## through leaves the last good save intact, because the new state is written to a temp
## file and published by rename. That claim is about what happens when the PROCESS DIES,
## and a unit test cannot die: it can only decline to call commit(), which proves the shape
## of the code rather than the behaviour of the filesystem. So this script kills itself for
## real -- `OS.kill(OS.get_process_id())`, SIGKILL, no cleanup, no destructors, no buffer
## flush -- at exactly the moment a crash would be worst, and a separate process afterwards
## checks what survived. That is the difference between a design and a demonstration, and
## this project has shipped enough gates that measured nothing to insist on the difference.
##
## THE PHASES (each one its own process, so the kill is real):
##
##   --phase=seed         write the OLD save and leave it there.
##   --phase=kill         stage() a NEW save, then SIGKILL before commit(). This is the
##                        atomic path being interrupted.
##   --phase=kill-unsafe  THE NEGATIVE CONTROL: do what a naive save system does -- open
##                        the live save for writing (which truncates it on the spot),
##                        write half the new state, then SIGKILL. No temp file, no rename.
##   --phase=verify       load the slot and report which save came back.
##
## After `kill`, verify must find the OLD save, complete and loadable. After `kill-unsafe`,
## verify must find a corrupt file and fail -- which is what proves the verification step
## can tell the two apart instead of passing on anything.
##
## Everything is written to its own scratch directory under user:// (PROOF_DIR), never to
## the slot the game plays in.
##
## MARKERS GO IN FILES, NOT ONLY IN STDOUT. SIGKILL does not flush a buffered stdout, and
## Godot's stdout is fully buffered when its output is piped -- so a print() immediately
## before the kill may never arrive. Each phase drops a marker FILE, and the shell driver
## reads those.

const SaveIOScript := preload("res://systems/save_io.gd")

const PROOF_DIR := "user://atomic_write_proof"
const SLOT := 0

## The save that must survive, and the one whose write gets interrupted. `marker` is what
## the verify phase reads: it says WHICH of the two is on disk, which "is the file valid"
## alone could not.
const OLD_SAVE := {
	"marker": "OLD_SAVE",
	"bits": 1111,
	"ponies": [{"uid": "twilight#000001", "data_id": "twilight",
		"nickname": "Sparkle", "happiness": 0.625, "hunger": 0.375, "caught_at_ms": 1772150400000}],
	"plots": {"0": "pen"},
	"unlocks": ["barn"],
	"world_seed": 20260839,
}
const NEW_SAVE := {
	"marker": "NEW_SAVE",
	"bits": 2222,
	"ponies": [],
	"plots": {},
	"unlocks": [],
	"world_seed": 20260839,
}

## Marker file the kill phases write just before they die, so the driver can tell "the
## process reached the kill" from "the process fell over earlier".
const REACHED_KILL := "reached_kill"


func _init() -> void:
	SaveIOScript.save_dir = PROOF_DIR

	var phase := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--phase="):
			phase = arg.split("=")[1]

	match phase:
		"seed":
			_seed()
		"kill":
			_kill()
		"kill-unsafe":
			_kill_unsafe()
		"verify":
			_verify()
		_:
			printerr("prove_atomic_save: unknown phase '%s' (expected seed|kill|kill-unsafe|verify)"
				% phase)
			quit(2)


## A clean slate plus the save that has to survive everything after it.
func _seed() -> void:
	DirAccess.make_dir_recursive_absolute(PROOF_DIR)
	for path in [SaveIOScript.slot_path(SLOT), SaveIOScript.temp_path(SLOT),
			SaveIOScript.backup_path(SLOT), PROOF_DIR.path_join(REACHED_KILL)]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)

	var ok := SaveIOScript.save(SLOT, OLD_SAVE)
	print("PROOF seed wrote=%s file=%s" % [
		ok, ProjectSettings.globalize_path(SaveIOScript.slot_path(SLOT))])
	quit(0 if ok else 1)


## The real thing: interrupt an atomic write between its two halves.
func _kill() -> void:
	var staged := SaveIOScript.stage(SLOT, NEW_SAVE)
	_mark("staged=%s temp=%s" % [staged, FileAccess.file_exists(SaveIOScript.temp_path(SLOT))])
	print("PROOF kill staged=%s -- SIGKILLing this process before commit()" % staged)
	OS.kill(OS.get_process_id())
	# Unreachable if the kill worked. Reaching it is itself a failure: the proof would
	# otherwise silently degrade into "we chose not to commit", which is the unit test.
	printerr("PROOF kill: still alive after OS.kill -- this proof measured nothing")
	quit(3)


## The negative control: what the same interruption does to a save system that writes
## straight over the live file. Nothing here calls SaveIO's write path on purpose.
func _kill_unsafe() -> void:
	var path := SaveIOScript.slot_path(SLOT)
	var text := JSON.stringify(NEW_SAVE, "  ", true, true)
	# Opening for WRITE truncates immediately -- the old save is already gone at this line,
	# before a single byte of the new one has been written. That is the whole failure mode.
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text.substr(0, 24))
	file.flush()
	_mark("unsafe half-write done")
	print("PROOF kill-unsafe wrote half of the new save directly over the live file")
	OS.kill(OS.get_process_id())
	printerr("PROOF kill-unsafe: still alive after OS.kill")
	quit(3)


## What is on disk now?
func _verify() -> void:
	var loaded := SaveIOScript.load(SLOT)
	var marker := str(loaded.get("marker", ""))
	var ponies: Array = loaded.get("ponies", [])
	var intact := marker == "OLD_SAVE" \
		and int(loaded.get("bits", 0)) == 1111 \
		and ponies.size() == 1 \
		and str(ponies[0].get("uid", "")) == "twilight#000001" \
		and absf(float(ponies[0].get("happiness", 0.0)) - 0.625) < 0.0001
	print("PROOF verify marker='%s' loaded_keys=%d intact=%s temp_left=%s backup_left=%s" % [
		marker, loaded.size(), intact,
		FileAccess.file_exists(SaveIOScript.temp_path(SLOT)),
		FileAccess.file_exists(SaveIOScript.backup_path(SLOT))])
	quit(0 if intact else 1)


func _mark(text: String) -> void:
	var file := FileAccess.open(PROOF_DIR.path_join(REACHED_KILL), FileAccess.WRITE)
	if file != null:
		file.store_string(text)
		file.flush()
		file.close()
