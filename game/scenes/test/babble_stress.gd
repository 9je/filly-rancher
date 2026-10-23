extends SceneTree
## THE BABBLE RACE, reproduced on purpose (docs: DECISIONS.md, the exit hang). A Babble is
## made, starts talking, and is freed a frame or two later, over and over. Each free drops the
## last reference to its AudioStreamGenerator while the audio thread may still be mixing the
## playback's fade out through the generator's raw pointer. Prints BABBLE_STRESS_OK when it
## gets through; a hang here is the bug.
##   tools/bin/godot --headless --audio-driver Dummy --path game -s res://scenes/test/babble_stress.gd -- --n=4000

const BabbleScript := preload("res://systems/babble.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var n := 4000
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--n="):
			n = int(a.substr(4))
	# --scribble: after each free, allocate same-sized generators with an absurd rate and
	# keep them, so a freed generator's memory is soon reused with a value the mixer cannot
	# survive (freed memory otherwise still reads 22050, and the bug stays invisible).
	var scribble := "--scribble" in OS.get_cmdline_user_args()
	var keep: Array = []
	for i in n:
		var b: Node = BabbleScript.new()
		root.add_child(b)
		b.call("say", "Hello there, friend!")
		for k in (i % 3):
			await process_frame
		b.free()
		if scribble:
			for k in 4:
				var g := AudioStreamGenerator.new()
				g.mix_rate = 1.0e30
				keep.append(g)
		if i % 500 == 0:
			print("BABBLE_STRESS %d" % i)
	print("BABBLE_STRESS_OK %d" % n)
	quit(0)
