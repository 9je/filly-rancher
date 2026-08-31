extends Node
## THE CREATION GATE. Proves the look, the mark and the letters round trip on the real
## ranch: the swatch rows against the real player palette and the real recolour pipeline,
## a mark drawn with the same widget the player draws with, and a save that brings all of
## it back pixel identical.
##
## WHY A GATE AND NOT ONLY game/test/test_creation_screen.gd, game/test/test_stock_tint.gd,
## game/test/test_mark_paint.gd, game/test/test_player_look.gd and game/test/test_letters.gd.
## Every one of those proves its own file's arithmetic in isolation; none of them can see
## the WIRE this file is about: whether cycling a swatch on the SCREEN really lands the SAME
## colour StockPalette itself would answer for that index, whether confirming really reaches
## GameState.player and the real player model rather than a copy of it, whether the mark that
## comes back off a save is the SAME BYTES rather than merely the same size.
##
## THE RANCH IS HOSTED HERE, not launched, the same way scenes/test/collection_test.gd's is;
## see that file's class comment for what _hosted changes and why this gate waits on
## gate_report_finished rather than polling for a symptom of it.
##
## A HEADLESS RUN NEVER OPENS THE CREATION SCREEN ON ITS OWN. ranch._maybe_open_creation()
## is gated on `_interactive`, which a hosted gate never is, precisely so no automated run
## ever waits on a button nobody is going to press. This gate opens the screen itself, and
## because ranch.gd never wires CreationScreen.confirmed to its own handler for a hosted
## ranch either (the same `_interactive` gate), this file reaches GameState.player and the
## player model directly rather than through _on_creation_confirmed() -- which also saves to
## the player's OWN slot, something a gate must never touch.
##
## Marker after verdict, exit code is the verdict. See docs/testing.md.

const GateWatchdogScript := preload("res://scripts/gate_watchdog.gd")
const PlayerLookScript := preload("res://systems/player_look.gd")
const StockPaletteScript := preload("res://systems/stock_palette.gd")
const StockTintScript := preload("res://systems/stock_tint.gd")
const CutieMarkScript := preload("res://systems/cutie_mark.gd")
const MarkPaintScript := preload("res://systems/mark_paint.gd")
const MarkStampsScript := preload("res://systems/mark_stamps.gd")
const LettersScript := preload("res://systems/letters.gd")
const LedgerScript := preload("res://systems/ledger.gd")
const SaveIOScript := preload("res://systems/save_io.gd")

## Scratch slots. Distinct from every other hosted gate's (collection_test.gd's 5,
## ledger_test.gd's 6, depot_test.gd's 7) and from ranch.gd's own boot-time probe
## (Ranch.GATE_SAVE_SLOT, 9) so none of them can ever race this one.
const SLOT := 8
const V4_SLOT := 10

var _checks: Dictionary = {}
var _duplicates: Array[String] = []


## Same duplicate-label guard as every other hosted gate's; see collection_test.gd's.
func _set_check(label: String, ok: bool) -> void:
	if _checks.has(label):
		_duplicates.append(label)
		var suffix := 2
		while _checks.has("%s [dup %d]" % [label, suffix]):
			suffix += 1
		_checks["%s [dup %d]" % [label, suffix]] = ok
		return
	_checks[label] = ok


func _ready() -> void:
	GateWatchdogScript.arm(self, "CREATION", 180.0)
	var ranch := $Ranch as Ranch

	var ranch_ok: bool = await ranch.gate_report_finished
	_set_check("the ranch is hosted", ranch.is_hosted())
	_set_check("the ranch's own report passed", ranch_ok)

	var state = get_node("/root/GameState")
	var screen := ranch.creation_screen as CreationScreen
	_set_check("the ranch built a creation screen", screen != null)
	if screen == null:
		_finish()
		return
	_set_check("a hosted ranch never opened it on its own", not screen.is_open())

	# --- the screen opens on GameState.player ----------------------------------------------
	screen.open(state.player)
	_set_check("the screen opens", screen.is_open())
	_set_check("it opens on GameState.player, not a copy of it", screen.look() == state.player)
	var model: Node3D = screen.model()
	_set_check("the turntable holds a model", model != null)

	# --- every palette choice round trips ---------------------------------------------------
	var palette: StockPalette = StockPaletteScript.load_player()
	if model == null:
		_set_check("no converted assets on this machine to check the swatches against", true)
	else:
		_check_row_round_trips(model, palette.coats.size(), "coat",
			func(step: int) -> void: screen.cycle_coat(step),
			func() -> int: return screen.look().coat,
			[&"body"], func(i: int) -> Color: return palette.coat_at(i))
		_check_row_round_trips(model, palette.manes.size(), "mane",
			func(step: int) -> void: screen.cycle_mane(step),
			func() -> int: return screen.look().mane,
			[&"hair", &"tail"], func(i: int) -> Color: return palette.mane_at(i))
		_check_row_round_trips(model, palette.eyes.size(), "eyes",
			func(step: int) -> void: screen.cycle_eyes(step),
			func() -> int: return screen.look().eyes,
			[&"eyeball_l"], func(i: int) -> Color: return palette.eye_at(i))

	# --- a mark the player draws: a stamp plus two strokes ----------------------------------
	var canvas: MarkCanvas = screen.canvas()
	_set_check("the screen carries a canvas", canvas != null)
	if canvas == null:
		_finish()
		return
	canvas.set_colour(Color(0.2, 0.6, 0.9))
	canvas.stamp(MarkStampsScript.Stamp.STAR)
	canvas.set_colour(Color(0.9, 0.3, 0.1))
	canvas.paint_at(Vector2(8, 8))
	canvas.drag_to(Vector2(20, 18))
	canvas.end_stroke()
	canvas.paint_at(Vector2(44, 46))
	canvas.drag_to(Vector2(56, 34))
	canvas.end_stroke()
	var drawn: Image = canvas.image()
	_set_check("a stamp plus two strokes leaves a mark that is not blank",
		not MarkPaintScript.is_blank(drawn))

	# --- confirm() puts it on GameState.player ----------------------------------------------
	_set_check("confirm succeeds", screen.confirm())
	_set_check("...and closes the screen", not screen.is_open())
	# ranch.gd wires CreationScreen.confirmed to _on_creation_confirmed() only for an
	# interactive session (see the class comment); this gate does the two things that
	# handler does that are about the SAVE FILE'S OWN LOOK rather than about the player's
	# own slot, which this gate must never touch.
	state.player = screen.look()
	ranch.call("_apply_player_look")
	_set_check("her drawn mark reached GameState.player pixel for pixel",
		MarkPaintScript.equal(state.player.mark(), drawn))

	if model != null:
		var body: Node3D = ranch.player.visuals.get_child(0) if ranch.player.visuals.get_child_count() > 0 else null
		_set_check("the player's body exists to carry the mark", body != null)
		if body != null:
			var decals: Array[Decal] = CutieMarkScript.decals_of(body)
			_set_check("two cutie mark decals exist on the player's body", decals.size() == 2)
			if decals.size() == 2:
				var local_a: Vector3 = body.global_transform.affine_inverse() * decals[0].global_position
				var local_b: Vector3 = body.global_transform.affine_inverse() * decals[1].global_position
				print("CREATION decals local_a=%s local_b=%s" % [local_a, local_b])
				_set_check("their world positions sit on opposite sides of her barrel",
					sign(local_a.x) != sign(local_b.x)
						and absf(local_a.x) > 0.05 and absf(local_b.x) > 0.05)

	# --- the save round trips the name, the three indices and the mark pixel identical -----
	var name_before: String = state.player.player_name
	var coat_before: int = state.player.coat
	var mane_before: int = state.player.mane
	var eyes_before: int = state.player.eyes
	var mark_before: Image = state.player.mark()
	_set_check("the save lands", state.save_to_slot(SLOT))
	state.reset()
	_set_check("a reset gives a fresh default look",
		state.player.player_name == PlayerLookScript.DEFAULT_NAME)
	ranch.rebind_economy()
	_set_check("the slot loads back", state.load_from_slot(SLOT))
	ranch.rebind_economy()
	_set_check("the name comes back", state.player.player_name == name_before)
	_set_check("the three indices come back", state.player.coat == coat_before
		and state.player.mane == mane_before and state.player.eyes == eyes_before)
	_set_check("the mark round trips pixel identical",
		MarkPaintScript.equal(state.player.mark(), mark_before))
	var slot_path: String = ProjectSettings.globalize_path(SaveIOScript.slot_path(SLOT))
	if FileAccess.file_exists(slot_path):
		DirAccess.remove_absolute(slot_path)
	var backup_path: String = ProjectSettings.globalize_path(SaveIOScript.backup_path(SLOT))
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_path)

	# --- every Letters template renders at the longest name, inside the line width, no dash -
	var long_name: String = "A".repeat(PlayerLookScript.MAX_NAME_LENGTH)
	_set_check("PlayerLook.MAX_NAME_LENGTH mirrors Letters.MAX_NAME_LENGTH",
		PlayerLookScript.MAX_NAME_LENGTH == LettersScript.MAX_NAME_LENGTH)
	var params := {"name": long_name, "count": 12, "credit": 4000, "pony": "A Very Long Name",
		"quota": 2, "balance": 99999, "upkeep": 2600, "punishment": "a suspended horn licence"}
	for id: int in LettersScript.ids():
		var letter: Dictionary = LettersScript.render(id, params)
		var lines: Array = [String(letter.get("title", ""))]
		for line in letter.get("body", []):
			lines.append(String(line))
		var over_width := false
		var dashed := false
		for line: String in lines:
			if line.length() > LettersScript.LINE_WIDTH:
				over_width = true
			if line.contains("--") or line.contains(char(0x2014)):
				dashed = true
		_set_check("letter %d renders at the longest name inside the line width" % id,
			not over_width)
		_set_check("letter %d carries no dash" % id, not dashed)

	# --- a hand written version 4 save loads in this build ----------------------------------
	var v4_path: String = SaveIOScript.slot_path(V4_SLOT)
	DirAccess.make_dir_recursive_absolute(v4_path.get_base_dir())
	var f := FileAccess.open(v4_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 4, "bits": 77, "compendium": {}, "requests": []},
		"  ", true))
	f.close()
	state.reset()
	ranch.rebind_economy()
	_set_check("the v4 file loads in this build", state.load_from_slot(V4_SLOT))
	_set_check("the name is Twilight", state.player.player_name == PlayerLookScript.DEFAULT_NAME)
	_set_check("the shipped look", state.player.coat == PlayerLookScript.DEFAULT_COAT
		and state.player.mane == PlayerLookScript.DEFAULT_MANE
		and state.player.eyes == PlayerLookScript.DEFAULT_EYES)
	_set_check("a blank mark", not state.player.has_mark())
	_set_check("a ledger at the sponsorship balance",
		state.ledger.balance == LedgerScript.STARTING_BALANCE)
	ranch.rebind_economy()

	var v4_full_path: String = ProjectSettings.globalize_path(v4_path)
	if FileAccess.file_exists(v4_full_path):
		DirAccess.remove_absolute(v4_full_path)
	var v4_backup: String = ProjectSettings.globalize_path(SaveIOScript.backup_path(V4_SLOT))
	if FileAccess.file_exists(v4_backup):
		DirAccess.remove_absolute(v4_backup)

	_finish()


## Cycle `screen`'s row of `size` swatches all the way round (size + 1 steps, so it wraps
## back to the start too) and check that every one of `materials`' overrides matches
## `expected_of(index)` at every step: StockTint.override_of() against StockPalette's own
## answer, which is what "round trips" means here.
func _check_row_round_trips(model: Node3D,
		size: int, row_name: String, cycle: Callable, current_index: Callable,
		materials: Array, expected_of: Callable) -> void:
	for step in range(maxi(1, size) + 1):
		cycle.call(1)
		var index: int = current_index.call()
		var want: Color = expected_of.call(index)
		var all_match := true
		for material_name: StringName in materials:
			var override: StandardMaterial3D = StockTintScript.override_of(model, material_name)
			if override == null or not override.albedo_color.is_equal_approx(want):
				all_match = false
		_set_check("%s row step %d/%d round trips on %s" % [row_name, step, size, materials],
			all_match)


func _finish() -> void:
	var all_ok := _duplicates.is_empty()
	for label in _checks:
		if not _checks[label]:
			push_error("creation_test: FAILED check: %s" % label)
			all_ok = false
	for label in _duplicates:
		push_error("creation_test: DUPLICATE CHECK LABEL: %s" % label)
	print(("CREATION_OK " if all_ok else "CREATION_FAILED ") + "checks=%d" % _checks.size())
	get_tree().quit(0 if all_ok else 1)
