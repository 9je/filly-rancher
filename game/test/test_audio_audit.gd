extends GutTest
## THE MEASUREMENT GATE. tools/audio_audit.py decodes every audio file under game/ with
## ffmpeg and fails on true clipping, a peak over -1 dBFS, a one shot whose broadband noise
## floor sits above -60 dBFS, a limiter crushed transient, or a loudness far over the mix
## target. This runs it, so a noisy or clipped file cannot be committed and forgotten. See
## AUDIO_AUDIT.md for the last full run, file by file.
##
## Needs python3 (with numpy) and ffmpeg, the same two tools/fetch_sounds.sh needs; a machine
## without them is a machine that could not have made the files either, and the test says so
## rather than passing.


func test_every_audio_file_in_the_game_passes_the_audit() -> void:
	var repo := ProjectSettings.globalize_path("res://").path_join("..").simplify_path()
	var script := repo.path_join("tools/audio_audit.py")
	assert_true(FileAccess.file_exists(script), "no audit script at %s" % script)
	var out: Array = []
	var rc := OS.execute("python3", PackedStringArray(["-I", script]), out, true)
	var text: String = "\n".join(PackedStringArray(out))
	var failures: PackedStringArray = []
	var summary := ""
	for line in text.split("\n"):
		if line.begins_with("FAIL"):
			failures.append(line.strip_edges())
		elif line.begins_with("AUDIO_AUDIT"):
			summary = line
	assert_ne(summary, "", "the audit did not run to its summary line:\n%s" % text)
	assert_eq(failures.size(), 0, "\n".join(failures))
	assert_eq(rc, 0, summary)
