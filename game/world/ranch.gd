class_name Ranch
extends Node3D
## THE MAP. The first actual place in this game -- everything before it was a test
## scene on a grey plane -- and, as of Phase 1A Task 7, the project's main scene.
##
## WHAT IT IS. Terrain (game/world/terrain.gd) with a sun and a sky, a homestead of
## Kenney props at the validated 1.5x scale (game/world/props.gd), the player
## standing in the yard, five ZoneMarkers spread over the map, and a Spawner
## (game/world/spawner.gd) that fills them with wild ponies drawn from the registry.
##
## WHERE THE ZONES ARE, AND WHY THERE ARE FIVE OF THEM NOW. The first playtest's report
## was "ponies were only around the perimeter", and it was right: the three original
## markers sat at (2, -42), (40, 8) and (-30, 38), all of them 40 m or more from the
## player's spawn and none of them anywhere a player crossing the middle of the map would
## meet one. Eight ponies on a 140 x 140 m map is not many to begin with, and putting all
## eight around the rim meant the entire middle of the ranch -- the part you actually walk
## through -- was empty.
##
## The three original markers are kept (they are on real relief, which the raycast
## placement check below depends on) at two ponies each, and two more are added where the
## map was bare: HomePasture, a small herd in the open ground north-east of the pen plots,
## about 10 m from where the player spawns, so the FIRST thing a new session contains is
## a pony; and WestHollow, out west between the tree line and the map edge, which was the
## largest continuously empty quarter of the map. Ten ponies over five places rather than
## eight over three.
##
## Sizing all five is bounded by things this file's own checks care about: no disc may
## overlap the pen-plot clearing (game/world/props.gd's PEN_PLOTS_*), no disc may sit on
## a prop's footprint, and no two markers may be close enough that a pony spawned in one
## ends up nearer another -- "every pony was spawned inside her zone" is checked against
## her NEAREST marker, so overlapping discs would fail it. HomePasture's 6.5 m radius is
## the one that is tight rather than chosen: it is the largest circle at (7, 19) that
## clears the pen plots to the west and the oak at (14, 27) to the north-east.
##
## THIS FILE IS ALSO THE GATE. `RANCH_OK ponies=<n> props=<n> assets=<state>`, exit
## 0, printed only when every check below actually held. The checks are chosen the
## way the rest of this project chooses them -- each one has a specific way it can
## go red:
##
##   * "the player is standing on the ground" fails if the terrain collider is not
##     built, if the raycast/trimesh is wrong, or if the player's mask stops
##     matching the terrain's layer. It is the check that catches a main scene that
##     boots into a void, which is the worst possible regression for a MAIN SCENE.
##   * "every prop has collision" fails for a prop whose .glb carries no mesh, or if
##     the trimesh generation is dropped -- the difference between a barn and a
##     hologram, and nothing else here would notice.
##   * "the camera pulls in against a building" is the one that would have caught
##     the latent bug this task was told to fix. Before this map, EVERY collision
##     object in the project sat on the untouched default layer 1, and the camera's
##     spring arm probed with the untouched default mask 1, so it worked by
##     coincidence. Give the world real layers and leave that mask alone and the
##     camera sails through the barn -- with no error, no warning, and no numeric
##     assertion anywhere in this project able to see it. So the mask is asserted
##     structurally AND the pull-in is measured against an actual building.
##   * "no pony was placed by fallback" fails if the spawner's ground raycast is
##     finding nothing -- which is what happens if populate() is called before the
##     physics server has stepped, and would otherwise show up only as a herd
##     hovering at marker height in a screenshot nobody took.
##   * "the zones sit on sloped ground" fails if someone flattens the terrain. That
##     is not an aesthetic assertion: on flat ground the spawner's raycast placement
##     is indistinguishable from `y = 0`, so this check is what keeps the check
##     above from going hollow.
##   * "the pen-plot clearing is clear" fails if a prop or a pony ends up in the
##     ground reserved for Phase 1B's plots.
##   * "a save round-trips through the user:// filesystem" fails if a save cannot be
##     written or cannot be read back with every field intact. It is here rather than only
##     in the unit suite because this gate is the thing CI runs on real Windows and
##     tools/run_windows_build.sh runs under Proton, and `user://` resolves to a completely
##     different place on Windows (docs/windows-testing.md) through a differently
##     implemented rename. The gate also PRINTS where the file landed, which is how that
##     question gets an empirical answer on a machine nobody here can log into.
##   * "no pony is standing inside a prop" fails if a pony's own collision capsule
##     overlaps any prop's collider RIGHT NOW, checked by shape query rather than by
##     distance to a marker or a reroll history. The spawner's own prop-rejection
##     reroll (spawner.gd) only fires when the ground raycast that placed her hits a
##     PROPS-layer collider -- and on this exact layout no prop's footprint overlaps
##     any zone disc, so that reroll never fires here. This check exists so a pony
##     ending up inside the barn is caught independently of whether the reroll that
##     was supposed to prevent it was ever reachable.
##
## ASSETLESS CHECKOUTS ARE A DECLARED STATE, NOT A SILENT PASS. game/assets/converted/
## is gitignored, so CI and a fresh clone have no ponies and no props (docs/ci.md
## section 4). The ranch degrades to bare terrain -- that is option (a) of the three
## that doc lists, chosen because it is also what a new machine needs before the
## pipeline has been run on it -- and prints `assets=absent` so the zero counts read
## as "there was nothing to load here", not as "loading worked and found nothing".
## When assets ARE present, the counts are checked against what the layout and the
## markers say they should be, so the strict version of the gate is the one that
## runs on the machine that can actually run it.
##
## OFFSCREEN RENDERING. `xvfb-run tools/bin/godot --path game --audio-driver Dummy
## world/ranch.tscn -- --screenshot-dir=<path>` (NOT --headless) runs the same checks
## and then saves a dozen PNGs: the establishing shot, the view from the player's own
## eyes at spawn, a spawn zone with ponies in it, the camera pressed against a
## building, an eye-level look at the barn for scale, and -- added by the playtest pass,
## see _capture_the_mechanic() -- THE CORE LOOP ITSELF through the player's own camera
## with the real HUD over it: a shy pony bolting from beyond beam range, the beam and its
## landing ring at range, and a capture mid-struggle. Every check in this file is a
## number; whether the place READS as a place, and whether the mechanic READS at all, are
## not things a number can answer -- and the second of those had never been photographed
## in the real scene at all before the first playtest went and found five problems with
## it by hand.
## `--audio-driver Dummy` is required explicitly here (not implied, since this run is
## NOT --headless) -- this is the main scene, a captured pony here can fire the same
## first-capture voice line scenes/test/capture_test.gd's header describes, and
## game/systems/audio_safety.gd's Master-bus mute is a backstop, not a reason to skip
## the flag.

const LayersScript := preload("res://world/collision_layers.gd")
const PropsScript := preload("res://world/props.gd")
const GateWatchdogScript := preload("res://scripts/gate_watchdog.gd")
const GameStateScript := preload("res://systems/game_state.gd")
const SaveIOScript := preload("res://systems/save_io.gd")
const PonyInstanceScript := preload("res://systems/pony_instance.gd")
const PlotSlotScript := preload("res://world/plot_slot.gd")
const PlotRegistryScript := preload("res://systems/plot_registry.gd")
const PenScript := preload("res://world/pen.gd")
const EconomyScript := preload("res://systems/economy.gd")
const ZoneMarkerScript := preload("res://world/zone_marker.gd")
const PonyScript := preload("res://actors/pony/pony.gd")
const PonyDataScript := preload("res://systems/pony_data.gd")

## Headless watchdog ceiling. A normal run (assets present) finishes in under 2s on
## this machine; 30s leaves a wide margin for a slower box while still failing in
## seconds rather than in whatever an external timeout happens to be set to -- see
## GateWatchdog's own doc comment for why this exists at all.
const WATCHDOG_TIMEOUT_SEC := 30.0

## Physics frames awaited before the spawner's raycasts run. The terrain and prop
## colliders are created during _ready(); the physics server has not stepped since,
## so a space-state query made now sees an empty world. Two rather than one is
## belt-and-braces and costs 33 ms.
const PHYSICS_WARMUP_FRAMES := 2

## Frames the world is stepped before anything is measured, so the player and the
## herd have settled onto the ground under gravity instead of being sampled in
## mid-drop.
const SETTLE_FRAMES := 40

## Frames allowed for SpringArm3D's collision probe to settle after the player and
## the rig are moved for the camera-vs-building check (the arm casts once per
## physics frame).
const CAMERA_SETTLE_FRAMES := 8

## How far off the terrain surface a body may sit and still count as "on the
## ground", in metres. The player's and a pony's origin are both at the bottom of
## their capsule, so this is slack for the floor snap, not for a body's height.
const GROUND_TOLERANCE := 0.20

## Minimum pull-in the spring arm must show when the player has a building at her
## back: half a metre less than its commanded rest length. A wall the arm ignores
## returns exactly spring_length, so any real margin proves contact -- 0.5 m makes
## it impossible to satisfy by floating-point noise.
const MIN_CAMERA_PULL_IN := 0.5

## How far a prop's visible base may sit from where props.gd seated it, in metres.
## Tight on purpose: the seating is arithmetic, so anything but rounding here means
## a prop moved after it was placed or the AABB it was seated by is not the AABB it
## renders with.
const SEATING_TOLERANCE := 0.02

## Metres of relief the zone markers' ground must actually have, so that placing a
## pony by raycast is measurably different from placing her at y=0.
const MIN_ZONE_RELIEF := 0.25

## The save slot the GATE writes its round-trip probe into -- never the slot the game
## plays in (GameState.DEFAULT_SLOT, 0), so running the gate can never touch a real ranch.
##
## The probe file is deliberately LEFT ON DISK afterwards rather than cleaned up. It is the
## artefact that answers "where did `user://` actually resolve on this machine?", which is
## the single highest-value cross-platform question in this phase: on Windows `user://`
## lands in `%APPDATA%\Godot\app_userdata\Filly Rancher\`, a completely different place
## from Linux's `~/.local/share/godot/app_userdata/Filly Rancher/`
## (docs/windows-testing.md). The gate prints the globalized path of this file, so a
## Proton or CI log says exactly where the engine put it, and the file itself can then be
## found and read on the host filesystem.
const GATE_SAVE_SLOT := 9

## How close to the farmhouse door the player has to walk for the ranch to save, in
## metres, and how far she has to walk back off before it will save again. The gap between
## them is hysteresis: without it, standing in the doorway would save on every physics
## frame -- 60 file writes a second, each one copying the previous save to a backup.
##
## 6 m is a little wider than the farmhouse's own footprint (6.6 x 5.6 m), so "go home" is
## satisfied by walking up to the building rather than by finding an exact spot.
const HOUSE_SAVE_RADIUS := 6.0
const HOUSE_SAVE_REARM := 9.0

## Plot slots the map must carry -- the plan asks for four to six, and the reserved
## clearing (PropsScript.PEN_PLOTS_*) is an 18 m square, which fits four 7.8 m pens on a
## 9 m grid with room to walk between them. A range rather than an exact number so a later
## task can add a fifth without this becoming a two-file change, and a FLOOR because
## "somebody deleted the Plots node" must fail rather than pass with zero slots.
const MIN_PLOT_SLOTS := 4
const MAX_PLOT_SLOTS := 6

## Metres of height variation allowed across the reserved clearing.
##
## THIS IS THE ASSUMPTION game/world/pen.gd's CARPENTRY RESTS ON. A pen's fence is built
## flat in pen-local space and the pen is seated at its slot's ground height; that is only
## honest while the clearing is flat, which it is today (measured spread: 0.071 m end to
## end, because the whole clearing sits inside game/world/terrain.gd's homestead apron).
## The day a terrain retune pushes the apron in or moves the clearing out, this check goes
## red -- rather than a fence quietly floating at one corner in a screenshot nobody takes.
const PEN_GROUND_FLATNESS := 0.25

## Physics frames the pen-containment probe runs for: SETTLE_FRAMES to land and adopt their
## bodies, then PEN_PROBE_FLEE_FRAMES of the worst case.
##
## THE SECOND HALF IS THE WHOLE TEST, AND IT IS SET UP RATHER THAN WAITED FOR. Three ponies
## pottering about a paddock never go anywhere near the fence, so a probe that only watched
## them wander would pass with the leash set to anything at all -- measured: with BOTH the
## leash and the fence colliders deliberately removed, 90 frames of ordinary wandering still
## reported every pony safely inside. Waiting longer is not the fix either; it took 300
## frames (5 seconds of every boot) before a wander happened to carry one out.
##
## So the probe PUTS them in the worst case instead: each body is teleported hard against
## the fence, facing out, at PEN_PROBE_EDGE_GAP from the rails -- outside her leash, which
## is where a pony who has just overshot a flee actually is -- and the player is set down in
## the middle so the shy one bolts. From there, a leash that does not pull her back or a
## fence that does not stop her shows up within a few frames rather than eventually. 60
## frames is one second, which is what this costs a real boot.
const PEN_PROBE_FRAMES := 40
const PEN_PROBE_FLEE_FRAMES := 60

## How far inside the fence line the probe's ponies are placed, in metres. Their capsules
## are PONY_BODY_RADIUS wide, so this leaves them just touching the rails.
const PEN_PROBE_EDGE_GAP := 0.45

## Metres a probe pony must move during the flee phase for the run to count as a stress
## test. THE ANTI-VACUITY GUARD: "everybody is still inside the fence" is trivially true of
## ponies who never moved, so a physics step that stopped stepping, a state machine that
## stopped ticking, or bodies that failed to adopt would all sail through the containment
## check while measuring nothing.
const PEN_PROBE_MIN_TRAVEL := 0.30

## Ponies the containment probe puts in its pen. Three, so they crowd each other and shove
## -- one pony alone in a paddock never goes anywhere near the fence, and a containment
## check she cannot fail is not a check.
const PEN_PROBE_PONIES := 3

@onready var terrain: StaticBody3D = $Terrain
@onready var props: Node3D = $Props
@onready var buildings: Node3D = $Buildings
@onready var spawner: Node3D = $Spawner
@onready var player: CharacterBody3D = $Player
@onready var player_spawn: Marker3D = $PlayerSpawn
@onready var capture_camera: Camera3D = $CaptureCamera
@onready var plots_root: Node3D = $Plots
@onready var build_menu: CanvasLayer = $BuildMenu

var _screenshot_dir := ""
var _rig: Node3D
var _spring_arm: SpringArm3D

## The GameState autoload (game/systems/game_state.gd), or null if it is not registered --
## which is a failed check below, not something to crash on.
var _game_state: Node

## Whether a person is playing, as opposed to a gate/CI/screenshot run. Autosave and the
## save-at-the-house trigger are enabled ONLY for this case: every automated run boots this
## same main scene with the same autoloads, and a save on quit that did not ask this
## question would end `bash tools/run_tests.sh` by overwriting the developer's ranch.
var _interactive := false

## Whether a save was found and loaded at boot. Printed, so a log says which world this is.
var _save_loaded := false

## How many owned ponies were put back into the saddlebag at boot. Printed rather than
## only counted: "the save loaded" and "the ponies in it reached the bag" are two different
## claims, and a restore that silently dropped them would satisfy the first one.
var _restored_ponies := 0

## False while the player is standing at the house, so the autosave fires once per visit
## instead of once per physics frame. Re-armed when she walks HOUSE_SAVE_REARM away.
var _house_armed := true

## Labels that were assigned to `checks` more than once. A Dictionary silently
## overwrites on a repeated key -- that is exactly the bug a reviewer proved live in
## `game/scenes/test/capture_test.gd` (two checks shared a label, one silently
## overwrote the other, and a whole requirement went ungated while the gate still
## printed green). `_set_check()` below is the only place `checks` may be written, and
## it records a collision here instead of only push_error'ing it, so a duplicate label
## fails the gate itself rather than merely logging a warning nobody reads.
var _duplicate_check_labels: Array[String] = []

## The buildable catalogue (game/systems/plot_registry.gd), loaded once at boot.
var _plot_registry: PlotRegistry = null

## The wallet, seeded from the loaded save and written straight back into GameState.bits
## on every change. Task 6 gives this prices and a shop; here it is what the build menu
## charges against, so that "you cannot build what you cannot afford" is enforced by the
## same object that will enforce it later rather than by an int compared in the UI.
var _economy: Economy = null

## The plot slot the player is standing in right now, or null. Tracked so the build prompt
## fires once on entry rather than every physics frame.
var _prompt_slot: PlotSlot = null

## How many plots a loaded save put back, and how many ponies went into pens rather than
## into the saddlebag. Printed by the gate.
var _restored_plots := 0
var _penned_ponies := 0

## Results of the boot-time pen-containment probe -- see _probe_pen_containment().
var _pen_probe: Dictionary = {}


func _ready() -> void:
	# Armed FIRST, before anything below has a chance to raise mid-function -- see
	# GateWatchdogScript's doc comment for the exact hang this guards against.
	GateWatchdogScript.arm(self, "RANCH", WATCHDOG_TIMEOUT_SEC)

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot-dir="):
			_screenshot_dir = arg.split("=")[1]

	_interactive = DisplayServer.get_name() != "headless" and _screenshot_dir == ""

	_rig = player.get_camera_pivot().get_node("CameraRig")
	_spring_arm = _rig.get_node("SpringArm3D")

	player.global_position = player_spawn.global_position

	# BEFORE the spawner runs: a loaded save carries the seed the wild world was generated
	# from, and applying it afterwards would mean the herd you come back to is not the herd
	# you left.
	_bind_game_state()

	# The hand-built barn and farmhouse first: they are the map's only real buildings
	# (game/world/building.gd says why), they exist on every checkout including CI,
	# and they are seated by exactly the rule props.gd seats the Kenney props with.
	for node: Node3D in buildings.get_children():
		node.build()
		PropsScript.seat(node, terrain.height_at(node.global_position.x, node.global_position.z))

	var prop_count: int = props.build() + buildings.get_child_count()

	for i in range(PHYSICS_WARMUP_FRAMES):
		await get_tree().physics_frame

	var pony_count: int = spawner.populate()

	# The plot slots are seated on the terrain before anything is built on them, so a pen
	# inherits a slot that is already standing on the ground rather than having to find it
	# for itself.
	_seat_plot_slots()

	for i in range(SETTLE_FRAMES):
		await get_tree().physics_frame

	# BEFORE the save's own plots are restored, while every slot is guaranteed empty: put a
	# pen up, drop ponies in it, watch whether they stay, and take it down again. See
	# _probe_pen_containment() for why this happens at boot in every mode rather than only
	# in a gate run.
	_pen_probe = await _probe_pen_containment()

	# Now the player's actual ranch: what she built, then who lives in it.
	_restored_plots = _restore_plots()

	# After the beam exists and the world has settled: put the ponies the player owned when
	# she quit back where they live -- pens first, saddlebag for everyone else.
	_restored_ponies = _restore_owned_ponies()

	_bind_build_menu()

	await _report(pony_count, prop_count)


# --- saving and loading ----------------------------------------------------------------

## Find the GameState autoload, load the play slot if there is one, and decide whether this
## run is allowed to write anything.
##
## THE SEED IS PUSHED BOTH WAYS. A loaded save hands its `world_seed` to the spawner, so
## coming back gives you the ranch you left. A run with NO save takes the spawner's own
## exported default INTO the state, so the very first save records the seed the world was
## actually generated with rather than a default that a later edit to spawner.tscn could
## silently change out from under it.
func _bind_game_state() -> void:
	_game_state = get_node_or_null(^"/root/GameState")
	if _game_state == null:
		# Not fatal here -- it is a FAILED check in _report(), which is a better place for
		# it than a crash during boot.
		push_error("ranch: the GameState autoload is not registered; this session cannot save.")
		return

	_save_loaded = _game_state.load_from_slot()
	if _save_loaded:
		spawner.spawn_seed = _game_state.world_seed
	else:
		_game_state.world_seed = spawner.spawn_seed

	# Every write -- the one at the house AND the one on quit -- pulls the live world in
	# through this first. Without it, quitting would save whatever the state last happened
	# to hold, which for a session that never walked home is an empty saddlebag.
	_game_state.world_sync = Callable(self, "_sync_game_state")

	# Only a person playing may write. See _interactive's comment.
	_game_state.autosave_enabled = _interactive


## Put the owned ponies back where they live after a load.
##
## PENS FIRST, SADDLEBAG SECOND. Every pony carries the slot she lives on in her own record
## (PonyInstance.home_slot -- see game/world/pen.gd on why her address is in there rather
## than in a second list), so a load is: for each pony, find her pen, put her in it;
## everyone else goes in the bag. This is the arrangement Task 2's version of this function
## said was a stopgap -- "Task 3's pens are where the ones that do not fit will actually
## live" -- and it is retired here.
##
## A PONY WHOSE PEN IS GONE goes in the bag AND HAS HER ADDRESS CLEARED. Her pen may have
## been demolished, or her save may name a plot type this build no longer carries, or the
## pen may be full because its capacity was retuned downward. Leaving her address pointing
## at a pen that has no record of her would mean she is filed in two places at once: in the
## bag, and (as far as the save is concerned) in a pen. One of those has to win, and it has
## to be the one that is actually holding her.
##
## Storage is still fixed-capacity, so a save holding more ponies than pens-plus-bag can
## carry cannot be fully restored -- which is why _sync_game_state() below still MERGES
## rather than overwrites. A pony who did not fit anywhere stays in the file.
func _restore_owned_ponies() -> int:
	if _game_state == null:
		return 0
	var beam: Node3D = player.get_magic_beam()
	if beam == null:
		return 0
	var storage: Storage = beam.get_storage()

	var pens := {}
	for slot in _plot_slots():
		var pen := slot.get_built() as Pen
		if pen != null:
			pens[String(slot.slot_id)] = pen

	var restored := 0
	var to_the_bag: Array[PonyInstance] = []
	for instance: PonyInstance in _game_state.get_ponies():
		var pen: Pen = pens.get(String(instance.home_slot), null)
		if pen != null and pen.add_pony(instance):
			restored += 1
			_penned_ponies += 1
		else:
			instance.home_slot = &""
			to_the_bag.append(instance)

	for instance in to_the_bag:
		if not storage.store(instance):
			break
		restored += 1
	return restored


# --- plots ---------------------------------------------------------------------------

## Every PlotSlot on the map, in scene order. Filtered by type rather than by node name so
## a slot renamed in ranch.tscn does not silently disappear from the ranch's own idea of
## how many slots it has (which is what MIN_PLOT_SLOTS then measures).
func _plot_slots() -> Array[PlotSlot]:
	var found: Array[PlotSlot] = []
	if plots_root == null:
		return found
	for child in plots_root.get_children():
		if child is PlotSlotScript:
			found.append(child)
	return found


## Stand every slot on the ground and wire its `built` signal. The same seating rule
## props.gd uses -- one rule for the whole map.
func _seat_plot_slots() -> void:
	for slot in _plot_slots():
		slot.global_position.y = terrain.height_at(slot.global_position.x,
			slot.global_position.z)
		if not slot.built.is_connected(_on_plot_built):
			slot.built.connect(_on_plot_built)


## The catalogue, loaded once.
func _plots_catalogue() -> PlotRegistry:
	if _plot_registry == null:
		_plot_registry = PlotRegistryScript.new()
		_plot_registry.load_all(PlotRegistryScript.PLOT_DIR)
	return _plot_registry


## Replay `GameState.plots` onto the slots. Returns how many went back up.
##
## A SAVED PLOT TYPE THIS BUILD DOES NOT CARRY leaves the slot EMPTY AND BUILDABLE, loudly.
## The alternative -- substituting some other plot -- would silently change what the player
## built, and refusing to load would cost her the whole ranch over one renamed .tres.
func _restore_plots() -> int:
	if _game_state == null:
		return 0
	var built := 0
	for slot in _plot_slots():
		var plot_id := str(_game_state.plots.get(String(slot.slot_id), ""))
		if plot_id.is_empty():
			continue
		var plot: PlotData = _plots_catalogue().by_id(StringName(plot_id))
		if plot == null:
			push_error(("ranch: the save says slot '%s' holds a '%s', which is not a plot " +
				"type this build carries. The slot has been left empty and buildable.")
				% [String(slot.slot_id), plot_id])
			continue
		if slot.build(plot):
			built += 1
	return built


## What is standing on the slots right now, as the {slot id -> plot id} dictionary of
## Strings GameState.plots wants (JSON has no integer keys -- see game_state.gd). Slots
## with nothing on them are OMITTED rather than stored as "": an empty entry and a missing
## one mean the same thing, and only one of them costs bytes in a file a human reads.
func _live_plots() -> Dictionary:
	var live := {}
	for slot in _plot_slots():
		if not slot.is_empty():
			live[String(slot.slot_id)] = slot.saved_plot_id()
	return live


## Hand a freshly built pen the terrain sampler, so the residents it sets down stand on the
## ground rather than at the slot's exact height. (The fence itself is built flat in
## pen-local space; PEN_GROUND_FLATNESS above is the check that keeps that honest.)
func _on_plot_built(_plot: PlotData, node: Node) -> void:
	var pen := node as Pen
	if pen != null:
		pen.ground_sampler = Callable(terrain, "height_at")


## Wire the build menu to the wallet and to the thing that actually builds.
##
## THE TRANSACTION LIVES HERE, NOT IN THE MENU. The menu emits "she picked this"; this is
## what checks the wallet, calls PlotSlot.build(), and only then spends. Charging BEFORE
## the build would need a refund path for a build that failed, and a refund path is a place
## for bits to be created out of nothing.
func _bind_build_menu() -> void:
	if build_menu == null or not build_menu.has_method("open"):
		return
	_economy = EconomyScript.new(_game_state.bits if _game_state != null else 0)
	_economy.bits_changed.connect(_on_bits_changed)
	# set()/connect()-by-name rather than direct property access and `.plot_chosen.connect`,
	# because `build_menu` is typed as the CanvasLayer that ranch.tscn declares. A build menu
	# whose SCRIPT failed to parse is still exactly that -- a CanvasLayer with no script --
	# and reaching straight into a property it then does not have raises a runtime error that
	# aborts this function. The whole point of the has_method() guard above is that a broken
	# menu is a FAILED check in _report(), not a boot that dies before it gets there.
	build_menu.set("bits_provider", Callable(self, "_current_bits"))
	if not build_menu.is_connected("plot_chosen", _on_plot_chosen):
		build_menu.connect("plot_chosen", _on_plot_chosen)
	if not build_menu.is_connected("opened", _on_menu_opened):
		build_menu.connect("opened", _on_menu_opened)
	if not build_menu.is_connected("closed", _on_menu_closed):
		build_menu.connect("closed", _on_menu_closed)


## THE WORLD STOPS WHILE THE MENU IS UP. See game/ui/build_menu.gd's class comment for why
## this lives here rather than in the menu: the player reads WASD with
## Input.is_action_pressed() in _physics_process, which no amount of consuming events in a
## UI script will stop, and `ui_down` shares the down arrow with `move_back`.
##
## The cursor is released with it, because game/actors/player/camera_rig.gd only turns the
## camera while the mouse is CAPTURED -- so letting it go also stops mouse-look, and a menu
## you cannot get the pointer back from is a menu players close with Alt-F4.
func _on_menu_opened(_slot: PlotSlot) -> void:
	get_tree().paused = true
	if _interactive:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_menu_closed() -> void:
	get_tree().paused = false
	# Only re-grab the pointer for somebody actually playing. A headless or screenshot run
	# has no window worth capturing it into, and grabbing it during an automated capture is
	# exactly the kind of thing that makes people stop running captures.
	if _interactive:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _current_bits() -> int:
	return _economy.bits if _economy != null else 0


func _on_bits_changed(new_total: int) -> void:
	if _game_state != null:
		_game_state.bits = new_total


func _on_plot_chosen(plot: PlotData, slot: PlotSlot) -> void:
	if plot == null or slot == null:
		return
	if _economy != null and not _economy.can_afford(plot.cost):
		_toast("You cannot afford a %s yet." % plot.display_name)
		return
	if not slot.build(plot):
		_toast("Nothing can go up on that plot.")
		return
	if _economy != null:
		_economy.spend(plot.cost)
	_toast("%s built." % plot.display_name)


## Move the pony at the top of the saddlebag into the pen the player is standing at.
##
## THIS IS `Storage.release()`'s PRODUCTION CALLER on the pen side -- the finding Phase 1A's
## review raised ("release() exists with zero callers") and that Phase 1B's plan named as a
## carried fact. MagicBeam.release_stored() is the other one; this is the one that makes a
## pen a place ponies live rather than a decoration.
##
## THE ORDER IS CHECK, THEN RELEASE, THEN ADD, THEN PUT HER BACK IF THE ADD SOMEHOW FAILED.
## A pony taken out of the bag and refused by the pen with nowhere to go is a pony deleted
## by a bookkeeping mistake, and NO PONY EVER DIES covers that as much as it covers
## anything else.
func _move_pony_into_pen(slot: PlotSlot) -> bool:
	var pen := slot.get_built() as Pen if slot != null else null
	if pen == null:
		return false
	var beam: Node3D = player.get_magic_beam()
	if beam == null:
		return false
	var storage: Storage = beam.get_storage()
	var next: PonyInstance = storage.peek()
	if next == null:
		_toast("Your saddlebag is empty.")
		return false
	if pen.is_full():
		_toast("That pen is full.")
		return false

	var instance: PonyInstance = storage.release()
	if not pen.add_pony(instance):
		# Belt and braces: the checks above should make this unreachable. If it ever is
		# reached, she goes straight back in the bag rather than being dropped on the floor.
		storage.store(instance)
		_toast("She would not go in.")
		return false
	_toast("%s moved into the pen." % instance.display_name())
	return true


func _toast(text: String) -> void:
	var hud := get_node_or_null(^"HUD")
	if hud != null and hud.has_method("toast"):
		hud.toast(text)


## Copy the live world back into the savable state, immediately before a write.
##
## MERGES rather than replaces the owned list: what is in the saddlebag right now, plus any
## pony the state already knew about who is not in it (see _restore_owned_ponies). Replacing
## outright would mean a save silently deleting every pony the bag could not hold.
func _sync_game_state() -> void:
	if _game_state == null:
		return
	var owned: Array[PonyInstance] = []
	var seen := {}
	var beam: Node3D = player.get_magic_beam()
	if beam != null:
		for instance: PonyInstance in beam.get_storage().contents():
			owned.append(instance)
			seen[instance.uid] = true
	# Everyone living in a pen. Their addresses ride in their own records, so writing them
	# into the roster is the whole of "the pens survive quitting" -- there is no second
	# structure to keep in step.
	for slot in _plot_slots():
		var pen := slot.get_built() as Pen
		if pen == null:
			continue
		for instance: PonyInstance in pen.ponies():
			if not seen.has(instance.uid):
				owned.append(instance)
				seen[instance.uid] = true
	for instance: PonyInstance in _game_state.get_ponies():
		if not seen.has(instance.uid):
			owned.append(instance)
	_game_state.set_ponies(owned)
	_game_state.plots = _live_plots()
	_game_state.world_seed = spawner.spawn_seed


## Save the ranch. Returns whether it landed. The live world is copied in by
## GameState.save_to_slot() itself, through the `world_sync` Callable registered above --
## deliberately not called here, so that this path and the save-on-quit path cannot drift
## apart into "one of them syncs and the other does not".
func save_game() -> bool:
	if _game_state == null:
		return false
	return _game_state.save_to_slot()


## Save when the player comes home, and on nothing else.
##
## THE HOUSE IS THE SAVE POINT because it is the one place on this map that already means
## "you". Hysteresis (HOUSE_SAVE_RADIUS vs HOUSE_SAVE_REARM) is what makes it one save per
## visit instead of one per frame -- standing in the doorway at 60 fps would otherwise
## rewrite the file, and its backup, sixty times a second.
##
## Gated on `_interactive` twice over (here and in GameState.autosave_enabled): a gate run
## teleports the player around the map to probe the camera, and one of those poses is a
## metre from a building. An autosave that fired on that would be a gate overwriting a real
## save.
func _physics_process(_delta: float) -> void:
	if not _interactive:
		return
	_update_plot_interaction()
	if _game_state == null:
		return
	var house := get_node_or_null(^"Buildings/Farmhouse") as Node3D
	if house == null:
		return
	var gap := Vector2(player.global_position.x - house.global_position.x,
		player.global_position.z - house.global_position.z).length()
	if gap > HOUSE_SAVE_REARM:
		_house_armed = true
		return
	if gap > HOUSE_SAVE_RADIUS or not _house_armed:
		return
	_house_armed = false
	var ok := save_game()
	var hud := get_node_or_null(^"HUD")
	if hud != null and hud.has_method("toast"):
		hud.toast("Ranch saved" if ok else "SAVE FAILED -- see the log")


## THE ONE INTERACT BUTTON, and what it means depends on where you are standing.
##
##   an EMPTY slot -> open the build menu.
##   a slot with a PEN on it -> move the pony at the top of your saddlebag into it.
##
## One verb rather than two buttons, for the reason project.godot's `interact` block gives:
## a player who has to remember which of two keys applies to which square of ground is a
## player who presses neither. The prompt is shown once on entering a slot rather than
## every frame -- a toast that reprints at 60 Hz never fades and never stops covering the
## middle of the screen.
##
## Which slot she is in is asked of the Area3D rather than computed from distances: the
## trigger volume is the authority on "am I on this plot", it is what a future prompt
## billboard would hang off, and an Area3D with no shape (a real and completely invisible
## failure -- see PlotSlot._ensure_shape) then shows up as a prompt that never appears
## rather than as a distance check that quietly still works.
func _update_plot_interaction() -> void:
	if build_menu != null and build_menu.has_method("is_open") and build_menu.is_open():
		return

	var here: PlotSlot = null
	for slot in _plot_slots():
		if player in slot.get_overlapping_bodies():
			here = slot
			break

	if here != _prompt_slot:
		_prompt_slot = here
		if here != null:
			if here.is_empty():
				_toast("Press E / X to build here.")
			else:
				_toast("Press E / X to move a pony in.")

	if here == null or not Input.is_action_just_pressed(&"interact"):
		return
	if here.is_empty():
		if build_menu != null and build_menu.has_method("open"):
			build_menu.open(here)
	else:
		_move_pony_into_pen(here)


# --- the gate -----------------------------------------------------------------------

## The only place `checks` may be written. Guards against the exact bug a reviewer
## found live in `game/scenes/test/capture_test.gd`: a label reused for a second check
## silently discards the first one, and the gate keeps printing green with a whole
## requirement no longer gated. A Dictionary itself will not tell you that happened --
## `checks[label] = x` just overwrites -- so the guard has to live here, not in the
## Dictionary.
func _set_check(checks: Dictionary, label: String, ok: bool) -> void:
	if checks.has(label):
		push_error(("ranch: DUPLICATE CHECK LABEL -- '%s' was assigned twice; the first " +
			"assignment was silently discarded and its requirement went ungated.") % label)
		if not label in _duplicate_check_labels:
			_duplicate_check_labels.append(label)
	checks[label] = ok


func _report(pony_count: int, prop_count: int) -> void:
	var checks := {}

	var props_present: bool = PropsScript.has_assets()
	var expected_props: int = PropsScript.expected_count() + buildings.get_child_count()
	var expected_ponies := 0
	for marker in spawner.get_markers():
		expected_ponies += marker.spawn_count
	# "Some pony in the roster has a model on this machine". Asked of the spawner's
	# own roster rather than by re-scanning the directory here: one scan, one answer,
	# and it cannot disagree with what the spawner actually drew from.
	var roster_size: int = spawner.get_roster_size()
	var ponies_present: bool = roster_size > 0 \
		and spawner.get_unspawnable().size() < roster_size
	if not ponies_present:
		expected_ponies = 0
	# A roster that failed to LOAD is not an assetless checkout, it is a broken game:
	# game/data/ponies/*.tres is committed, so it is present on every machine and in
	# every export. (It read as empty in the first exported build of this scene --
	# see PonyRegistry._resource_path for why.)
	_set_check(checks, "the pony roster loaded at all", roster_size > 0)

	var assets_state := "present"
	if not props_present and not ponies_present:
		assets_state = "absent"
	elif not props_present or not ponies_present:
		assets_state = "partial"
	if assets_state != "present":
		# Said once, plainly, at the top of the report -- a log that is going to
		# contain "0 ponies" should say why before it says the number.
		print(("RANCH NOTE assets=%s: game/assets/converted/ is gitignored, so this " +
			"checkout has no pony models and/or no props (docs/ci.md section 4). " +
			"The ranch is running on terrain and its hand-built buildings only; " +
			"the pony and prop counts below are expected to be zero.") % assets_state)

	# --- terrain ---------------------------------------------------------------
	var terrain_shape := terrain.get_node_or_null("CollisionShape3D") as CollisionShape3D
	_set_check(checks, "the terrain has a collider",
		terrain_shape != null and terrain_shape.shape != null)
	_set_check(checks, "the terrain is on the TERRAIN layer",
		terrain.collision_layer == LayersScript.TERRAIN)

	# --- the player is somewhere real ------------------------------------------
	var p := player.global_position
	var ground_y: float = terrain.height_at(p.x, p.z)
	var player_offset: float = absf(p.y - ground_y)
	print("RANCH player pos=(%.2f, %.3f, %.2f) ground=%.3f offset=%.3f on_floor=%s"
		% [p.x, p.y, p.z, ground_y, player_offset, player.is_on_floor()])
	_set_check(checks, "the player is standing on the ground", player_offset <= GROUND_TOLERANCE)
	_set_check(checks, "the player reports a floor under her", player.is_on_floor())
	_set_check(checks, "the player's mask includes the terrain",
		player.collision_mask & LayersScript.TERRAIN != 0)
	_set_check(checks, "the player's mask includes the props",
		player.collision_mask & LayersScript.PROPS != 0)
	_set_check(checks, "the player is on the PLAYER layer",
		player.collision_layer == LayersScript.PLAYER)

	# --- props ------------------------------------------------------------------
	var all_props := _all_props()
	var total_shapes := 0
	var uncollided: Array[String] = []
	var prop_layers_ok := true
	var props_seated := true
	var pen_intrusions: Array[String] = []
	for prop: Node3D in all_props:
		var box: AABB = PropsScript.world_aabb(prop)
		# Measured off the live scene tree rather than from a counter kept during
		# construction: a counter can only tell you what the builder THOUGHT it made.
		var shapes: int = prop.find_children("*", "CollisionShape3D", true, false).size()
		total_shapes += shapes
		if shapes == 0:
			uncollided.append(prop.name)
		for body: StaticBody3D in _bodies_of(prop):
			if body.collision_layer != LayersScript.PROPS:
				prop_layers_ok = false
		if PropsScript.is_in_pen_plots(prop.global_position.x, prop.global_position.z):
			pen_intrusions.append(prop.name)
		# How far the bottom of the visible model sits from where props.gd seated it.
		# Zero means the prop is standing ON the ground, not floating over it and not
		# buried in it -- the assertion the eye would otherwise have to make.
		var sunk: float = box.position.y - (terrain.height_at(
			prop.global_position.x, prop.global_position.z) - PropsScript.SINK_BIAS)
		if absf(sunk) > SEATING_TOLERANCE:
			props_seated = false
		print("RANCH prop %-34s pos=(%6.1f, %5.2f, %6.1f) height=%.2f seat_error=%+.3f"
			% [prop.name, prop.global_position.x, prop.global_position.y,
				prop.global_position.z, box.size.y, sunk])
	print("RANCH props placed=%d expected=%d shapes=%d missing=%s"
		% [prop_count, expected_props, total_shapes,
			", ".join(props.get_missing()) if not props.get_missing().is_empty() else "-"])
	_set_check(checks, "every layout entry with an asset was placed", prop_count == expected_props)
	_set_check(checks, "every prop got at least one collision shape", uncollided.is_empty())
	if not uncollided.is_empty():
		push_error("ranch: props with NO collision shape: %s" % ", ".join(uncollided))
	_set_check(checks, "every prop collider is on the PROPS layer", prop_layers_ok)
	_set_check(checks, "every prop is seated on the ground (none floats or sinks)", props_seated)

	# --- ponies -----------------------------------------------------------------
	var ponies: Array[CharacterBody3D] = spawner.get_spawned()
	var on_ground := true
	var in_zone := true
	var max_relief := 0.0
	var prop_overlaps: Array[String] = []
	var space := get_world_3d().direct_space_state
	for pony in ponies:
		var pos: Vector3 = pony.global_position
		var home: Vector3 = pony.get_home()
		var g: float = terrain.height_at(pos.x, pos.z)
		var offset: float = absf(pos.y - g)
		var marker := _nearest_marker(home)
		var from_marker := INF
		if marker != null:
			from_marker = Vector2(home.x - marker.global_position.x,
				home.z - marker.global_position.z).length()
			if from_marker > marker.spawn_radius + 0.01:
				in_zone = false
		if offset > GROUND_TOLERANCE:
			on_ground = false
		max_relief = maxf(max_relief, absf(terrain.height_at(home.x, home.z)))
		if PropsScript.is_in_pen_plots(home.x, home.z):
			pen_intrusions.append(pony.name)
		# The spawner's own reroll (game/world/spawner.gd, "inside a building or a tree
		# canopy, try somewhere else") only fires when the RAYCAST that first found her
		# ground point hits a PROPS-layer collider. Measured against this exact map, no
		# prop's footprint overlaps any zone disc (nearest is ~13.5 m outside
		# EastField), so that branch never fires here and a pony standing inside the
		# barn at ground level -- the raycast finding the barn's own floor, not
		# rejecting it -- would pass every check above. This is an independent,
		# after-the-fact geometric check: does the pony's ACTUAL capsule overlap ANY
		# prop's collider, right now, regardless of how she got there.
		if _pony_overlaps_prop(pony, space):
			prop_overlaps.append(pony.name)
		print("RANCH pony %-22s home=(%6.1f, %5.2f, %6.1f) now=(%6.1f, %5.2f, %6.1f) ground_offset=%.3f zone=%s r=%.1f state=%s"
			% [pony.name, home.x, home.y, home.z, pos.x, pos.y, pos.z, offset,
				marker.zone_id if marker != null else "<none>", from_marker,
				pony.state_name(pony.state)])
	_set_check(checks, "every pony spawned", ponies.size() == expected_ponies)
	_set_check(checks, "every pony is standing on the ground", on_ground)
	_set_check(checks, "every pony was spawned inside her zone", in_zone)
	_set_check(checks, "no pony needed a fallback placement",
		spawner.get_fallback_placements() == 0)
	_set_check(checks, "no zone came back with an empty roster",
		spawner.get_empty_zones().is_empty())
	# See the class comment: this is what stops the raycast check above going hollow.
	_set_check(checks, "the spawn zones sit on sloped ground",
		max_relief >= MIN_ZONE_RELIEF if ponies.size() > 0 else true)
	_set_check(checks, "no pony is standing inside a prop", prop_overlaps.is_empty())
	if not prop_overlaps.is_empty():
		push_error("ranch: pony overlapping a prop's collider: %s" % ", ".join(prop_overlaps))

	_set_check(checks, "the pen-plot clearing is clear", pen_intrusions.is_empty())
	# The PenPlots marker in ranch.tscn is what a human sees when they open the
	# scene; PropsScript.PEN_PLOTS_CENTRE is what the layout and these checks
	# actually use. Assert they agree, or the visible marker becomes a lie the first
	# time one of them is nudged.
	var pen_marker := $PenPlots as Marker3D
	_set_check(checks, "the PenPlots marker agrees with the reserved area",
		Vector2(pen_marker.global_position.x, pen_marker.global_position.z)
			.distance_to(PropsScript.PEN_PLOTS_CENTRE) < 0.01)
	if not pen_intrusions.is_empty():
		push_error("ranch: pen-plot clearing intruded on by: %s" % ", ".join(pen_intrusions))

	# --- plots and pens ------------------------------------------------------------------
	var slots := _plot_slots()
	var slots_seated := true
	var slots_in_clearing := true
	var slots_triggered := true
	var slot_ids := {}
	var slot_ids_unique := true
	for slot in slots:
		var at: Vector3 = slot.global_position
		var slot_ground: float = terrain.height_at(at.x, at.z)
		if absf(at.y - slot_ground) > SEATING_TOLERANCE:
			slots_seated = false
		# The whole TRIGGER, not just the centre: a slot whose middle is inside the reserved
		# clearing but whose corners hang over a tree is still a slot with a tree in it.
		for corner in [Vector2(-1.0, -1.0), Vector2(1.0, -1.0), Vector2(-1.0, 1.0),
				Vector2(1.0, 1.0)]:
			var probe := Vector2(at.x + corner.x * PlotSlotScript.TRIGGER_HALF,
				at.z + corner.y * PlotSlotScript.TRIGGER_HALF)
			if not PropsScript.is_in_pen_plots(probe.x, probe.y):
				slots_in_clearing = false
		# See PlotSlot._ensure_shape(): an Area3D with no shape never fires body_entered,
		# and the only symptom is a build prompt that silently never appears.
		var trigger_shapes: Array = slot.find_children("*", "CollisionShape3D", false, false)
		if trigger_shapes.size() != 1 or (trigger_shapes[0] as CollisionShape3D).shape == null:
			slots_triggered = false
		if slot_ids.has(String(slot.slot_id)) or String(slot.slot_id).is_empty():
			slot_ids_unique = false
		slot_ids[String(slot.slot_id)] = true
		print("RANCH plot %-8s pos=(%6.1f, %5.2f, %6.1f) seat_error=%+.3f built=%s"
			% [String(slot.slot_id), at.x, at.y, at.z, at.y - slot_ground,
				slot.saved_plot_id() if not slot.is_empty() else "-"])

	# Every pair, both ways round the grid. Two slots whose triggers overlap make "which
	# plot am I standing on" a question with two answers, and the interact button would
	# then act on whichever one happened to be first in the scene.
	var slots_disjoint := true
	for i in range(slots.size()):
		for j in range(i + 1, slots.size()):
			var gap := Vector2(slots[i].global_position.x - slots[j].global_position.x,
				slots[i].global_position.z - slots[j].global_position.z).abs()
			if gap.x < PlotSlotScript.TRIGGER_HALF * 2.0 \
					and gap.y < PlotSlotScript.TRIGGER_HALF * 2.0:
				slots_disjoint = false

	_set_check(checks, "the ranch has between four and six plot slots",
		slots.size() >= MIN_PLOT_SLOTS and slots.size() <= MAX_PLOT_SLOTS)
	_set_check(checks, "every plot slot has a unique, non-empty id", slot_ids_unique)
	_set_check(checks, "every plot slot is seated on the ground", slots_seated)
	_set_check(checks, "every plot slot lies inside the reserved clearing", slots_in_clearing)
	_set_check(checks, "no two plot slots overlap", slots_disjoint)
	_set_check(checks, "every plot slot has a trigger shape", slots_triggered)

	# THE ASSUMPTION pen.gd's FLAT CARPENTRY RESTS ON -- see PEN_GROUND_FLATNESS.
	var clearing_low := INF
	var clearing_high := -INF
	for i in range(13):
		for j in range(13):
			var cx: float = PropsScript.PEN_PLOTS_CENTRE.x - PropsScript.PEN_PLOTS_HALF_EXTENT \
				+ 2.0 * PropsScript.PEN_PLOTS_HALF_EXTENT * float(i) / 12.0
			var cz: float = PropsScript.PEN_PLOTS_CENTRE.y - PropsScript.PEN_PLOTS_HALF_EXTENT \
				+ 2.0 * PropsScript.PEN_PLOTS_HALF_EXTENT * float(j) / 12.0
			var h: float = terrain.height_at(cx, cz)
			clearing_low = minf(clearing_low, h)
			clearing_high = maxf(clearing_high, h)
	var clearing_spread: float = clearing_high - clearing_low
	_set_check(checks, "the reserved clearing is flat enough to stand a fence on",
		clearing_spread <= PEN_GROUND_FLATNESS)

	# THE MEASUREMENT THAT MATTERS, asserted on the map rather than only in a unit test: a
	# pony is 2.138 m to her horn tip, not 1.163 m at the withers (docs/pipeline.md
	# section 3). Same argument game/world/building.gd's MIN_DOOR_CLEARANCE makes for a
	# doorway.
	_set_check(checks, "a pen's fence clears a pony's horn tip",
		PenScript.FENCE_HEIGHT >= 2.138 and PenScript.GATE_CLEARANCE >= 2.138)
	# roam_radius IS SOFT: fleeing momentum overshoots it by ~1.15 m, so a leash set at the
	# fence line is a pony clipped through her own paddock.
	_set_check(checks, "a penned pony's leash stops short of the fence by more than her flee overshoot",
		PenScript.roam_radius_for(PenScript.HALF_EXTENT) + ZoneMarkerScript.ROAM_OVERSHOOT
			+ PenScript.PONY_BODY_RADIUS <= PenScript.HALF_EXTENT)

	var catalogue: Array[PlotData] = _plots_catalogue().all()
	_set_check(checks, "the plot catalogue loaded at all", catalogue.size() > 0)
	var free_plots := 0
	for plot in catalogue:
		if plot.cost == 0:
			free_plots += 1
	# Bits come from selling gems, gems come from penned ponies, ponies need a pen. If every
	# plot cost something, a brand new save could never build anything.
	_set_check(checks, "at least one plot is buildable with zero bits", free_plots > 0)

	print("RANCH plots slots=%d catalogue=%d restored=%d penned=%d clearing_spread=%.3f bits=%d"
		% [slots.size(), catalogue.size(), _restored_plots, _penned_ponies, clearing_spread,
			_current_bits()])

	# THE PEN PROBE. See _probe_pen_containment() for why this runs at boot in every mode
	# and why an empty result is a failure rather than a skip -- the four slots are in
	# ranch.tscn on every checkout, assetless or not, so a probe that did not run means a
	# slot that could not be built on.
	print(("RANCH pen probe ran=%s ponies=%d inside=%s no_clip=%s solid=%s travelled=%.2f " +
		"worst=(%.2f, %.2f) half=%.2f leash=%.2f")
		% [_pen_probe.get("ran", false), _pen_probe.get("ponies", 0),
			_pen_probe.get("inside", false), _pen_probe.get("no_clip", false),
			_pen_probe.get("solid", false), _pen_probe.get("travelled", 0.0),
			_pen_probe.get("worst_x", 0.0), _pen_probe.get("worst_z", 0.0),
			_pen_probe.get("half", 0.0), _pen_probe.get("roam", 0.0)])
	_set_check(checks, "a pen could be built on a slot and stocked with ponies",
		bool(_pen_probe.get("ran", false)) and int(_pen_probe.get("ponies", 0)) == PEN_PROBE_PONIES)
	# THE ANTI-VACUITY GUARD, checked BEFORE the containment result it guards: "everybody is
	# inside the fence" is trivially true of ponies who never moved at all.
	_set_check(checks, "the pen probe actually moved its ponies",
		bool(_pen_probe.get("stressed", false)))
	_set_check(checks, "every penned pony is still inside her fence after being driven at it",
		bool(_pen_probe.get("inside", false)))
	_set_check(checks, "no penned pony is standing inside the fence itself",
		bool(_pen_probe.get("no_clip", false)))
	# See _fence_is_solid(): without this one, deleting the pen's colliders outright still
	# printed RANCH_OK, because the leash alone kept the ponies in.
	_set_check(checks, "a pen's fence is solid all the way round at pony height",
		bool(_pen_probe.get("solid", false)))
	_set_check(checks, "the probe pen was taken back down",
		bool(_pen_probe.get("torn_down", false)))

	# --- the build menu ------------------------------------------------------------------
	# Same argument as the HUD block below: a build menu that failed to load its script is
	# still a CanvasLayer in the tree, drawn perfectly, doing nothing. `has_method` rather
	# than a bare call, for the same reason -- a call straight into an unscripted node
	# raises mid-report and the gate DISAPPEARS instead of failing.
	var menu = build_menu
	var menu_scripted: bool = menu != null and menu.has_method("entries")
	_set_check(checks, "the build menu is mounted and its script loaded", menu_scripted)
	if menu_scripted:
		_set_check(checks, "the build menu lists the whole plot catalogue",
			menu.entries().size() == catalogue.size() and catalogue.size() > 0)
		var provider: Variant = menu.get("bits_provider")
		_set_check(checks, "the build menu is wired to a wallet",
			provider is Callable and (provider as Callable).is_valid())

		# IT MUST REFUSE TO OPEN ON AN OCCUPIED SLOT, or the player builds a second pen on
		# top of her first one and the slot's whole build-once rule is bypassed by the only
		# thing that ever calls it.
		#
		# Measured against a THROWAWAY slot built here, not against whatever happens to be
		# on the map: the map's slots are empty in a fresh gate run, so asking the question
		# of them would be asking it of a case that cannot answer -- a check that passes
		# because there was nothing to refuse. This project has shipped that shape of gate
		# more than once; see the camera block below.
		var scratch: PlotSlot = PlotSlotScript.new()
		scratch.slot_id = &"slot_gate_probe"
		var refused_on_occupied := false
		var opened_on_empty: bool = menu.open(scratch)
		if opened_on_empty:
			menu.close()
		if catalogue.size() > 0 and scratch.build(catalogue[0]):
			refused_on_occupied = not menu.open(scratch)
			if not refused_on_occupied:
				menu.close()
		scratch.free()
		# Both halves, so "refuses everything" cannot pass as "refuses the right thing".
		_set_check(checks, "the build menu opens on an empty slot", opened_on_empty)
		_set_check(checks, "the build menu refuses to open on an occupied slot",
			refused_on_occupied)

	# --- the HUD ---------------------------------------------------------------------
	# A HUD that failed to find the beam looks EXACTLY like a HUD with an empty bag:
	# "0 / 12" and a row of empty pips, drawn perfectly, meaning nothing. game/ui/hud.gd
	# binds itself lazily (its own comment says why sibling ready order must not be
	# depended on), so "did the binding actually take" is a real thing to assert rather
	# than a formality -- and it is exactly the kind of failure a screenshot cannot show.
	# `has_method` rather than a bare call: a hud.gd that failed to PARSE still leaves a
	# CanvasLayer node in the tree with no script attached, and calling straight into it
	# raises a runtime error that aborts this whole report mid-way -- so the gate hangs
	# instead of printing RANCH_FAILED. (Which is exactly what a missing type hint in
	# hud.gd did the first time this check ran.) A gate must fail, not disappear.
	var hud := $HUD
	var hud_scripted: bool = hud != null and hud.has_method("get_beam")
	_set_check(checks, "the HUD is mounted and its script loaded", hud_scripted)
	if hud_scripted:
		# `player.get_magic_beam()` fetched ONCE and null-checked before anything chains
		# off it. The unguarded version of this (calling `.get_magic_beam()` twice more
		# and dereferencing straight into `.get_storage().capacity`) is the exact line a
		# reviewer proved turns "the beam failed to wire up" into a silent 240s hang
		# instead of a failed check: a null beam raises a GDScript runtime error mid-
		# function, which aborts this whole report -- including its own `quit()` -- with
		# nothing printed. GateWatchdogScript.arm() above is the backstop for THAT
		# failure mode generally; this null check is the actual fix for THIS call.
		var beam: Node3D = player.get_magic_beam()
		_set_check(checks, "the HUD found the magic beam", hud.get_beam() == beam)
		_set_check(checks, "the HUD is showing the beam's real capacity",
			beam != null and hud.get_capacity() == beam.get_storage().capacity
				and hud.get_capacity() > 0)

	# --- saving --------------------------------------------------------------------
	# THE CHECK THAT EARNS ITS PLACE IN THIS GATE. `user://` resolves somewhere completely
	# different on Windows than on Linux (docs/windows-testing.md), the directory does not
	# pre-exist, and the rename that publishes a save is implemented differently on the two
	# platforms. None of that is visible in a unit test on the developer's machine -- but
	# this gate is ALSO run by CI on real Windows and by tools/run_windows_build.sh under
	# Proton, and this check is what makes those runs answer "can this build actually write
	# and re-read a save on that platform, in that filesystem" rather than only "does the
	# scene graph build".
	_set_check(checks, "the GameState autoload is mounted", _game_state != null)
	var save_probe := _probe_save_round_trip()
	print("RANCH save user_dir=%s file=%s wrote=%s reloaded=%s loaded_at_boot=%s owned=%d restored=%d"
		% [OS.get_user_data_dir(), save_probe["path"], save_probe["wrote"],
			save_probe["reloaded"], _save_loaded,
			_game_state.pony_count() if _game_state != null else -1, _restored_ponies])
	_set_check(checks, "a save round-trips through the user:// filesystem", save_probe["ok"])

	# --- the camera ---------------------------------------------------------------
	_set_check(checks, "the camera probes the world, not just layer 1",
		_spring_arm.collision_mask == LayersScript.WORLD)
	var pull_in: Dictionary = await _probe_camera_against_building()
	if pull_in.get("ran", false):
		# `hit` is the spring arm's own bookkeeping; `actual` is where the lens really
		# ended up, measured off its transform, and `fade` is what CameraRig does about
		# it. All three, because the first two have already disagreed once on this rig
		# (see CameraRig's note on SpringArm3D.margin) and because a fade of 0.00 at
		# 0.55 m is the whole of the fix for the camera-inside-the-pony close-up --
		# worth a printed number rather than only a screenshot.
		#
		# `actual` is now the LENS -- shoulder offset and all -- while the fade is driven
		# by where the ARM left the mount (CameraRig.get_arm_distance()), so at a normal
		# distance the two are allowed to differ by the offset. At this pose they agree,
		# because the ramp has eased the offset to nothing by the time the arm is this
		# short.
		print("RANCH camera building=%s rest=%.2f hit=%.2f actual=%.2f pull_in=%.2f subject_opacity=%.2f"
			% [pull_in["building"], pull_in["rest"], pull_in["hit"], pull_in["actual"],
				pull_in["pull_in"], pull_in["opacity"]])
		_set_check(checks, "the player's body is faded out when the camera is inside her",
			pull_in["opacity"] <= 0.01)
		_set_check(checks, "the camera pulls in against a building",
			pull_in["pull_in"] >= MIN_CAMERA_PULL_IN)
	else:
		# The barn and farmhouse are hand-built in building.gd and exist on EVERY
		# checkout, assetless or not -- they are not gated on assets_state. So a probe
		# that comes back empty means _find_wall_stand_point()'s raycast found no wall
		# on a map that unquestionably has one: a real regression (wrong layer, wrong
		# mask, a building that failed to build, or -- the case a reviewer actually
		# caught -- a building's collider disabled outright), not an assetless
		# checkout with nothing to probe.
		#
		# This USED to branch on assets_state: a FAILED check when assets=present, but
		# only a `print` -- no _set_check() call at all, so the label never entered
		# `checks` -- when assets was absent or partial. That branch was reasoned to be
		# unreachable; it is not. It is exactly the path CI runs (assets are always
		# absent in CI -- see docs/ci.md section 4), so a reviewer disabling both
		# buildings' colliders sailed straight through: this whole check silently did
		# not exist for that run, `RANCH_OK ponies=0 props=2 assets=absent` printed,
		# exit 0. A missing dictionary entry is not visible in the "every check held"
		# loop below the way `false` is -- so a silent SKIP here is worse than a wrong
		# answer, it's a gate CI runs that cannot fail this way at all.
		#
		# An empty probe is now an unconditional FAILED check, in every assets_state,
		# with no SKIP path left to fall into.
		print("RANCH camera check FAILED -- no building found to probe (assets=%s)"
			% assets_state)
		_set_check(checks, "the camera pulls in against a building", false)

	# --- verdict -------------------------------------------------------------------
	# A duplicate label is not a check that failed -- it is a check that never ran. It
	# fails the gate here, unconditionally, rather than only being logged by
	# _set_check() above, so it cannot start being broken without anyone noticing.
	if not _duplicate_check_labels.is_empty():
		push_error("ranch: %d check label(s) were assigned more than once: %s"
			% [_duplicate_check_labels.size(), ", ".join(_duplicate_check_labels)])

	var all_ok := _duplicate_check_labels.is_empty()
	for label in checks:
		if not checks[label]:
			push_error("ranch: FAILED check -- %s" % label)
			all_ok = false

	var summary := "ponies=%d props=%d assets=%s" % [ponies.size(), prop_count, assets_state]
	print(("RANCH_OK " if all_ok else "RANCH_FAILED ") + summary)

	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if all_ok else 1)
		return

	if _screenshot_dir != "":
		await _capture_all()
		get_tree().quit(0 if all_ok else 1)
		return

	# Windowed, no screenshot directory: this is somebody playing the game. Leave it
	# running. (An exported build launched by CI passes --headless and quits above;
	# --quit-after bounds it either way.)


## PUT A PEN UP, PUT PONIES IN IT, AND WATCH WHETHER THEY STAY.
##
## THE CHECK THIS WHOLE TASK EXISTS TO PASS, and the one thing here no unit test can
## answer. game/test/test_pen.gd can prove the arithmetic -- that the leash stops short of
## the fence by more than a fleeing pony's measured 1.15 m of overshoot, that the fence
## clears her 2.138 m horn tip. It cannot prove that a real CharacterBody3D, on a real
## collision layer, running the real wander/flee state machine on real terrain, is still
## inside the paddock a second later. Every part of that sentence has been wrong in this
## project at least once: a layer mask that stopped matching, a leash measured from the
## wrong origin, a collider that was never generated.
##
## SO IT IS MEASURED TWICE, TWO DIFFERENT WAYS. Where she is (her capsule's footprint
## against the fence line) AND whether her body actually intersects the pen's colliders
## from the outside. The first catches a pony who walked out; the second catches a pony who
## is standing exactly in the fence, which reads as "inside" to a coordinate comparison and
## is a pony clipped through a rail.
##
## WHY IT RUNS AT BOOT IN EVERY MODE, INCLUDING A REAL PLAY SESSION. The alternative is
## running it only in gate runs, which means the check does not exist for the run the
## player actually makes -- and this codebase has already shipped a gate whose most
## important check silently did not run on the path CI takes (see the camera block below).
## It runs on slot 0 BEFORE _restore_plots(), so the slot is guaranteed empty whatever the
## save says, and it takes its pen down again afterwards. `_report()` is awaited inside
## `_ready()`, so this all happens before the player has had a frame in which to act.
##
## Returns {ran, inside, no_clip, worst_x, worst_z, half, roam, ponies}.
func _probe_pen_containment() -> Dictionary:
	var result := {"ran": false, "inside": false, "no_clip": false, "torn_down": false,
		"solid": false, "stressed": false, "travelled": 0.0,
		"worst_x": 0.0, "worst_z": 0.0, "half": PenScript.HALF_EXTENT,
		"roam": PenScript.roam_radius_for(PenScript.HALF_EXTENT), "ponies": 0}

	var slots := _plot_slots()
	if slots.is_empty():
		return result
	var slot: PlotSlot = slots[0]
	if not slot.is_empty():
		return result

	# The cheapest pen in the catalogue, so this probe is not silently gated on a plot type
	# somebody later prices out of reach.
	var plot: PlotData = null
	for candidate in _plots_catalogue().all():
		if candidate.capacity >= PEN_PROBE_PONIES:
			plot = candidate
			break
	if plot == null or not slot.build(plot):
		return result

	var pen := slot.get_built() as Pen
	if pen == null:
		return result

	# Real characters off the real roster, so the bodies that spawn are the bodies the game
	# spawns -- a probe pony built from a made-up data_id resolves to no PonyData, gets no
	# model, and would be contained by nothing.
	var registry: PonyRegistry = _game_state.get_registry() if _game_state != null else null
	var roster: Array[PonyData] = registry.by_zone(&"ranch") if registry != null \
		else [] as Array[PonyData]

	var probes: Array[PonyInstance] = []
	for i in range(PEN_PROBE_PONIES):
		var character: StringName = roster[i % roster.size()].id if not roster.is_empty() \
			else &"twilight"
		var inst: PonyInstance = PonyInstanceScript.create(character)
		if pen.add_pony(inst):
			probes.append(inst)

	result["ponies"] = probes.size()

	for i in range(PEN_PROBE_FRAMES):
		await get_tree().physics_frame

	# THE WORST CASE, SET UP RATHER THAN WAITED FOR -- see PEN_PROBE_FLEE_FRAMES. Each body
	# goes hard against the fence, spread around it, outside her own leash; then the player
	# is put down in the middle so the shy one bolts. Her position is restored below;
	# _report() has not yet run the camera probe, which moves her the same way for the same
	# kind of reason.
	var edge: float = PenScript.HALF_EXTENT - PenScript.PONY_BODY_RADIUS - PEN_PROBE_EDGE_GAP
	var started: Dictionary = {}
	for i in range(probes.size()):
		var body := pen.body_for(probes[i].uid) as CharacterBody3D
		if body == null:
			continue
		var angle: float = TAU * float(i) / float(maxi(1, probes.size()))
		var spot := Vector3(cos(angle) * edge, 0.35, sin(angle) * edge)
		body.global_position = pen.to_global(spot)
		started[probes[i].uid] = body.global_position

	var player_home: Vector3 = player.global_position
	player.global_position = pen.to_global(Vector3(0.0, 0.4, 0.0))
	for i in range(PEN_PROBE_FLEE_FRAMES):
		await get_tree().physics_frame

	var inside := probes.size() > 0
	var travelled := 0.0
	var no_clip := true
	var worst_x := 0.0
	var worst_z := 0.0
	var space := get_world_3d().direct_space_state
	for inst in probes:
		var body := pen.body_for(inst.uid) as CharacterBody3D
		if body == null:
			inside = false
			continue
		# In the PEN's own frame, because the two back-row slots are rotated 180 degrees in
		# ranch.tscn (so their gates face open ground rather than the gap behind their
		# neighbour) and a world-space comparison would silently be measuring the wrong
		# axis for them.
		var local: Vector3 = pen.to_local(body.global_position)
		var edge_x: float = absf(local.x) + PenScript.PONY_BODY_RADIUS
		var edge_z: float = absf(local.z) + PenScript.PONY_BODY_RADIUS
		worst_x = maxf(worst_x, edge_x)
		worst_z = maxf(worst_z, edge_z)
		if edge_x > PenScript.HALF_EXTENT or edge_z > PenScript.HALF_EXTENT:
			inside = false
		if _body_overlaps(body, pen, space):
			no_clip = false
		if started.has(inst.uid):
			travelled = maxf(travelled,
				(body.global_position - (started[inst.uid] as Vector3)).length())
		print("RANCH pen probe %-22s local=(%6.2f, %6.2f) edge=(%.2f, %.2f) state=%s"
			% [body.name, local.x, local.z, edge_x, edge_z, body.state_name(body.state)])

	player.global_position = player_home
	result["solid"] = _fence_is_solid(pen, space)
	result["travelled"] = travelled
	result["stressed"] = travelled >= PEN_PROBE_MIN_TRAVEL

	result["ran"] = true
	result["inside"] = inside
	result["no_clip"] = no_clip
	result["worst_x"] = worst_x
	result["worst_z"] = worst_z

	# Take it back down. remove_pony() frees each body and clears her production ledger
	# entry; freeing the pen returns the slot to the empty, buildable state the real save is
	# about to be restored onto.
	for inst in probes:
		pen.remove_pony(inst.uid)
	slot.demolish()
	# Reported rather than assumed. If the teardown ever stopped working, the very next
	# thing that happens is _restore_plots() trying to build the player's real pen onto a
	# slot that is still holding the probe's -- which the slot would correctly refuse, and
	# the player would come back to a ranch with a pen missing and nothing said about it.
	result["torn_down"] = slot.is_empty()
	return result


## IS THERE ACTUALLY A FENCE THERE, or only a leash?
##
## THIS CHECK EXISTS BECAUSE THE OTHER TWO PASSED WITHOUT IT. Deleting the pen's collider
## generation outright -- leaving four sides of decorative rails with nothing solid behind
## them -- left `inside` and `no_clip` both true and printed RANCH_OK: the leash alone kept
## the ponies in, and "no pony is standing inside the fence" is trivially satisfied by a
## fence that is not there. That is the vacuous-check shape this codebase has shipped
## before, caught here by trying it.
##
## So this asks the fence directly. From just inside each of the four sides, at three
## positions along it and at three heights spanning a pony capsule, fire a short ray
## outward: every one of them has to hit THIS PEN. A missing barrier, a barrier that does
## not reach the ground, a gap at a corner or a gateway with nothing across it all come back
## as a ray that went straight out into the field.
##
## The heights stop below GATE_LEAF_HEIGHT deliberately. The gateway is open ABOVE the gate
## leaf and is meant to be -- that is the 2.25 m of framed clear air a pony will walk
## through when gates open. What must be solid is the band a pony capsule occupies, and that
## is what is measured.
func _fence_is_solid(pen: Pen, space: PhysicsDirectSpaceState3D) -> bool:
	var half: float = PenScript.HALF_EXTENT
	var solid := true
	for side in range(4):
		var outward := Vector3(cos(float(side) * PI * 0.5), 0.0, sin(float(side) * PI * 0.5))
		var along := Vector3(-outward.z, 0.0, outward.x)
		for offset in [-0.55, 0.0, 0.55]:
			for height in [0.25, 0.75, 1.25]:
				var from_local: Vector3 = along * (offset * half) \
					+ outward * (half - 1.0) + Vector3.UP * height
				var to_local: Vector3 = from_local + outward * 2.0
				var query := PhysicsRayQueryParameters3D.create(
					pen.to_global(from_local), pen.to_global(to_local),
					LayersScript.PROPS)
				var hit := space.intersect_ray(query)
				if hit.is_empty() or hit.get("collider") != pen:
					solid = false
					print(("RANCH pen fence GAP side=%d along=%+.2f height=%.2f -- a ray " +
						"fired outward from inside the pen did not hit its own fence")
						% [side, offset * half, height])
	return solid


## Whether `body`'s capsule is intersecting any of `owner_node`'s collision shapes right
## now. The independent, after-the-fact half of the containment probe -- see its comment.
## Built the same way _pony_overlaps_prop() below is, and deliberately not merged with it:
## that one asks about the PROPS layer generally, this one asks about ONE specific body's
## shapes, and a shared version would have to take so many parameters that neither call
## site would read.
func _body_overlaps(body: CharacterBody3D, owner_node: CollisionObject3D,
		space: PhysicsDirectSpaceState3D) -> bool:
	var shape := body.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape == null or shape.shape == null:
		return false
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape.shape
	query.transform = shape.global_transform
	query.collision_mask = LayersScript.PROPS
	query.exclude = [body.get_rid()]
	query.margin = 0.0
	for hit in space.intersect_shape(query, 8):
		if hit.get("collider") == owner_node:
			return true
	return false


## Write a save into the gate's own scratch slot, read it back with a SECOND, independent
## GameState, and report whether every field came back.
##
## {ok, wrote, reloaded, path}. Never touches the slot the game plays in.
##
## A SEPARATE GameState ON EACH SIDE, not the autoload: reading back into the live state
## would overwrite whatever the player just loaded, and reading back into the SAME object
## that wrote it would pass even if the file on disk were empty -- the values would still
## be sitting in memory. Two objects and one file is what makes this measure the
## filesystem instead of measuring a dictionary.
##
## The probe pony is a real PonyInstance round-tripped through PonyInstance.to_dict(), so
## this exercises the actual serialisation path the player's ponies use, not a toy payload.
func _probe_save_round_trip() -> Dictionary:
	var path: String = ProjectSettings.globalize_path(SaveIOScript.slot_path(GATE_SAVE_SLOT))
	var result := {"ok": false, "wrote": false, "reloaded": false, "path": path}

	var writer: Node = GameStateScript.new()
	writer.bits = 1234
	writer.world_seed = spawner.spawn_seed
	writer.plots = {"0": "gate_probe"}
	writer.unlocks = ["gate_probe"]
	writer.add_pony(PonyInstanceScript.from_dict({
		"uid": "gate_probe#000001", "data_id": "twilight",
		"nickname": "Probe", "happiness": 0.625, "hunger": 0.375, "caught_at_ms": 1772150400000,
	}))
	result["wrote"] = writer.save_to_slot(GATE_SAVE_SLOT)
	writer.free()

	var reader: Node = GameStateScript.new()
	result["reloaded"] = reader.load_from_slot(GATE_SAVE_SLOT)
	if result["reloaded"]:
		var ponies: Array = reader.get_ponies()
		result["ok"] = bool(result["wrote"]) \
			and reader.bits == 1234 \
			and reader.world_seed == spawner.spawn_seed \
			and String(reader.plots.get("0", "")) == "gate_probe" \
			and ponies.size() == 1 \
			and String(ponies[0].uid) == "gate_probe#000001" \
			and ponies[0].nickname == "Probe" \
			and absf(ponies[0].happiness - 0.625) < 0.0001 \
			and ponies[0].caught_at_ms == 1772150400000
	reader.free()
	return result


## Everything solid the layout put on the map: the Kenney props and the two
## hand-built buildings. One list, so no check can quietly cover only half of them.
func _all_props() -> Array[Node3D]:
	var result: Array[Node3D] = []
	result.append_array(props.get_placed())
	for node: Node3D in buildings.get_children():
		result.append(node)
	return result


## Every StaticBody3D belonging to `prop`, INCLUDING the node itself when it is one.
## The Kenney props carry their colliders on generated StaticBody3D children; a
## Building IS the static body. Missing that distinction would make the layer check
## pass vacuously on exactly the objects the camera has to stop against.
func _bodies_of(prop: Node3D) -> Array[StaticBody3D]:
	var result: Array[StaticBody3D] = []
	if prop is StaticBody3D:
		result.append(prop)
	for body: StaticBody3D in prop.find_children("*", "StaticBody3D", true, false):
		result.append(body)
	return result


## True if `pony`'s own collision capsule, at its CURRENT global transform, overlaps
## ANY prop's collider (buildings included -- see _all_props()/_bodies_of()).
##
## This is checked BY SHAPE QUERY, not by distance to a marker or a prop's centre,
## for the same reason the ground placement itself is a raycast (see spawner.gd's
## class comment): the pony's actual capsule is what a player would see standing
## inside a wall, and nothing about her `home`/`zone` bookkeeping can tell you that.
## See the class comment above and the call site in _report() for why this check
## exists independently of the spawner's own prop-rejection reroll.
func _pony_overlaps_prop(pony: CharacterBody3D, space: PhysicsDirectSpaceState3D) -> bool:
	var shape_node := pony.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node == null or shape_node.shape == null:
		# No shape to query with is itself a different, already-covered problem (a
		# pony whose body is malformed would fail other checks); do not fabricate an
		# overlap that was never measured.
		return false
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape_node.shape
	query.transform = shape_node.global_transform
	query.collision_mask = LayersScript.PROPS
	query.collide_with_bodies = true
	query.collide_with_areas = false
	return not space.intersect_shape(query, 1).is_empty()


func _nearest_marker(point: Vector3) -> ZoneMarker:
	var best: ZoneMarker = null
	var best_d := INF
	for marker: ZoneMarker in spawner.get_markers():
		var d := Vector2(point.x - marker.global_position.x,
			point.z - marker.global_position.z).length()
		if d < best_d:
			best_d = d
			best = marker
	return best


# --- camera-vs-building -------------------------------------------------------------

## Stand the player right up against the biggest building with the building at her
## back, and measure how far the spring arm has to pull the camera in.
##
## THE STAND POINT IS FOUND BY RAYCAST, not taken from the building's AABB. The
## first version of this check used `aabb.max.x + 0.75` and measured a pull-in of
## exactly zero -- correctly, because a Kenney windmill's bounding box is defined by
## its sails, which stick out several metres past the tower and past nothing at all
## at camera height. A "camera hits the building" check that quietly stands the
## player next to thin air is worse than no check. So: cast a horizontal ray INTO the
## building at the exact height the camera will sit, and stand 0.75 m off whatever
## surface it actually finds (0.75 m clears the player's 0.42 m capsule radius).
## Buildings are tried tallest-first until one presents a wall.
##
## The rig is then yawed to -90 degrees, which points the arm's +Z -- the direction
## it casts, and the direction the camera sits from the pivot -- along world -X,
## straight into that surface. Pitch is levelled to zero first, so the arm probes
## horizontally into the wall rather than diagonally over the roof.
func _probe_camera_against_building() -> Dictionary:
	var found := _find_wall_stand_point()
	if found.is_empty():
		return {"ran": false}
	var building: Node3D = found["building"]
	var stand: Vector3 = found["stand"]

	var saved_pos: Vector3 = player.global_position
	var saved_yaw: float = _rig.rotation.y
	var saved_pitch: float = _rig.get_look_pitch_degrees()

	player.global_position = stand
	player.velocity = Vector3.ZERO
	_rig.rotation.y = -PI * 0.5
	_rig.add_look_delta(0.0, deg_to_rad(saved_pitch))

	for i in range(CAMERA_SETTLE_FRAMES):
		await get_tree().physics_frame

	var rest: float = _spring_arm.spring_length
	var hit: float = _spring_arm.get_hit_length()

	var result := {
		"ran": true,
		"building": building.name,
		"rest": rest,
		"hit": hit,
		"actual": _rig.get_camera_distance(),
		"opacity": _rig.get_subject_opacity(),
		"pull_in": rest - hit,
		"stand": stand,
	}

	player.global_position = saved_pos
	player.velocity = Vector3.ZERO
	_rig.rotation.y = saved_yaw
	_rig.add_look_delta(0.0, deg_to_rad(_rig.get_look_pitch_degrees() - saved_pitch))
	for i in range(CAMERA_SETTLE_FRAMES):
		await get_tree().physics_frame
	return result


## Buildings (never trees -- a canopy is a bad camera obstacle to prove anything
## with; the arm could be stopping on a leaf a player would happily walk under),
## tallest first.
func _buildings_by_height() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for prop: Node3D in _all_props():
		if not prop.name.begins_with("kenney_tree"):
			result.append(prop)
	result.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return PropsScript.world_aabb(a).size.y > PropsScript.world_aabb(b).size.y)
	return result


## The tallest building, for framing shots. Not used for the collision probe -- see
## _find_wall_stand_point() for why an AABB is the wrong thing to stand against.
func _tallest_building() -> Node3D:
	var buildings := _buildings_by_height()
	return buildings[0] if not buildings.is_empty() else null


## {building, stand} for the first building that presents an actual wall to a
## horizontal ray at camera height, or {} if none does. See
## _probe_camera_against_building() for why this is a raycast and not arithmetic.
func _find_wall_stand_point() -> Dictionary:
	var space := get_world_3d().direct_space_state
	for building: Node3D in _buildings_by_height():
		var box: AABB = PropsScript.world_aabb(building)
		var centre := box.get_center()
		var y: float = terrain.height_at(centre.x, centre.z) + 1.45
		var query := PhysicsRayQueryParameters3D.create(
			Vector3(box.position.x + box.size.x + 8.0, y, centre.z),
			Vector3(centre.x, y, centre.z),
			LayersScript.PROPS)
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			continue
		var wall: Vector3 = hit["position"]
		var stand := Vector3(wall.x + 0.75, 0.0, wall.z)
		stand.y = terrain.height_at(stand.x, stand.z) + 0.15
		return {"building": building, "stand": stand}
	return {}


# --- offscreen capture ---------------------------------------------------------------

func _capture_all() -> void:
	# 01 -- does this read as a place at all?
	capture_camera.global_position = Vector3(33.0, 18.0, 36.0)
	capture_camera.look_at(Vector3(-1.0, 2.0, -7.0), Vector3.UP)
	capture_camera.make_current()
	await _capture("01_establishing")

	# 02 -- what the owner actually sees the instant the game boots.
	_rig.get_camera().make_current()
	await _capture("02_player_eye_at_spawn")

	# 03 -- a spawn zone with ponies in it, framed from the herd's own centre of mass
	# so the shot is about the ponies and not about wherever a fixed camera pointed.
	var ponies: Array[CharacterBody3D] = spawner.get_spawned()
	if not ponies.is_empty():
		var centre := Vector3.ZERO
		var markers: Array = spawner.get_markers()
		var zone: ZoneMarker = markers[0] if not markers.is_empty() else null
		var n := 0
		for pony in ponies:
			if zone == null or _nearest_marker(pony.get_home()) == zone:
				centre += pony.global_position
				n += 1
		if n > 0:
			centre /= float(n)
			capture_camera.global_position = centre + Vector3(7.0, 3.2, 9.0)
			capture_camera.look_at(centre + Vector3(0.0, 0.9, 0.0), Vector3.UP)
			capture_camera.make_current()
			await _capture("03_spawn_zone_ponies")

	# 04 -- the spring arm pressed against a real building.
	var pull_in: Dictionary = await _probe_camera_against_building()
	if pull_in.get("ran", false):
		# Re-enter the pose (the probe restores it), hold it for the shot.
		player.global_position = pull_in["stand"]
		_rig.rotation.y = -PI * 0.5
		_rig.add_look_delta(0.0, deg_to_rad(_rig.get_look_pitch_degrees()))
		for i in range(CAMERA_SETTLE_FRAMES):
			await get_tree().physics_frame
		_rig.get_camera().make_current()
		await _capture("04a_camera_pressed_to_wall")

		# ...and again from 1.2 m further out. Both shots are worth keeping: 04a is
		# the strict pose the check measures -- the arm at 0.55 m, well inside the pony
		# -- and it is now the picture of CameraRig's subject fade doing its job (she
		# is gone and the world is visible). Until Phase 1A Task 9 the same shot was an
		# unreadable macro close-up of her flank, which is what the fade was written to
		# fix; SpringArm3D's pull-in is NOT bounded by CameraRig.SPRING_MIN and will
		# happily put the camera inside her. 04b is the same wall from a playable
		# distance, where she is fully drawn and the arm is visibly shortened.
		var back_off: Vector3 = pull_in["stand"] + Vector3(1.2, 0.0, 0.0)
		back_off.y = terrain.height_at(back_off.x, back_off.z) + 0.15
		player.global_position = back_off
		for i in range(CAMERA_SETTLE_FRAMES):
			await get_tree().physics_frame
		print("RANCH camera(backed off 1.2 m) rest=%.2f hit=%.2f"
			% [_spring_arm.spring_length, _spring_arm.get_hit_length()])
		await _capture("04b_camera_near_wall")

		player.global_position = player_spawn.global_position
		_rig.rotation.y = 0.0

	await _capture_the_mechanic()

	# 05 -- eye level in the yard, for judging prop scale against a 1.16 m pony.
	var barn := _tallest_building()
	if barn != null:
		var box: AABB = PropsScript.world_aabb(barn)
		var target := box.get_center()
		var eye := target + Vector3(9.0, 0.0, 11.0)
		eye.y = terrain.height_at(eye.x, eye.z) + 1.45
		capture_camera.global_position = eye
		capture_camera.look_at(Vector3(target.x, box.position.y + box.size.y * 0.45, target.z),
			Vector3.UP)
		capture_camera.make_current()
		await _capture("05_scale_at_the_barn")

	await _capture_plots()


## 06 to 09: the plot loop, photographed by DRIVING IT rather than by staging it.
##
## Every step below goes through the same call the player's button press goes through --
## BuildMenu.open(), BuildMenu.confirm(), and the saddlebag-to-pen move that
## _move_pony_into_pen() performs -- so what these four pictures show is the real path and
## not a pen assembled for the camera. If the build menu stops opening, or a pen stops
## being buildable, or Storage.release() stops handing a pony over, these shots come out
## wrong (or do not come out) rather than coming out fine because a fixture built the pen
## directly.
##
## Screenshot runs only, which is why it is safe for it to leave a pen standing: those runs
## have autosave off (see _interactive) and quit immediately afterwards.
func _capture_plots() -> void:
	var slots := _plot_slots()
	if slots.is_empty():
		print("RANCH capture: no plot slots to photograph")
		return
	var slot: PlotSlot = slots[0]
	var at: Vector3 = slot.global_position

	# 06 -- an empty plot: four corner stakes and nothing else. This is what the player is
	# looking at when the build prompt appears, and the thing this shot is asked to answer
	# is whether an empty plot reads as "something goes here" at all.
	capture_camera.global_position = at + Vector3(7.5, 4.6, 7.5)
	capture_camera.look_at(at + Vector3(0.0, 0.4, 0.0), Vector3.UP)
	capture_camera.make_current()
	await _capture("06_empty_plot_slot")

	var menu = build_menu
	if menu == null or not menu.has_method("open"):
		return

	# 07 -- the build menu over that same view.
	if menu.open(slot):
		await _capture("07_build_menu")
		# ...and the same button the player presses. pen_small costs nothing and sorts
		# first, so the default selection is affordable from a cold start.
		if not menu.confirm():
			print("RANCH capture: the build menu refused to build the default plot")
			menu.close()
	else:
		print("RANCH capture: the build menu would not open on an empty slot")

	# 08 -- the finished pen, empty. Rails, gate and posts against a 1.16 m-at-the-withers
	# world: this is the shot that answers "does the fence read at the right scale".
	for i in range(CAMERA_SETTLE_FRAMES):
		await get_tree().physics_frame
	capture_camera.global_position = at + Vector3(9.0, 5.4, 9.0)
	capture_camera.look_at(at + Vector3(0.0, 1.1, 0.0), Vector3.UP)
	capture_camera.make_current()
	await _capture("08_pen_built")

	# 09 -- the same pen with ponies in it, at a pony's own eye height. Ponies are put in
	# THROUGH THE SADDLEBAG, using _move_pony_into_pen(), which is Storage.release()'s
	# production caller on the pen side.
	var pen := slot.get_built() as Pen
	var beam: Node3D = player.get_magic_beam()
	if pen != null and beam != null:
		var registry: PonyRegistry = _game_state.get_registry() if _game_state != null \
			else null
		var roster: Array[PonyData] = registry.by_zone(&"ranch") if registry != null \
			else [] as Array[PonyData]
		var storage: Storage = beam.get_storage()
		var wanted: int = mini(pen.capacity, maxi(1, roster.size()))
		for i in range(wanted):
			var character: StringName = roster[i % roster.size()].id if not roster.is_empty() \
				else &"twilight"
			if storage.store(PonyInstanceScript.create(character)):
				_move_pony_into_pen(slot)
		for i in range(SETTLE_FRAMES):
			await get_tree().physics_frame
		print("RANCH capture: pen '%s' holds %d/%d"
			% [String(slot.slot_id), pen.count(), pen.capacity])

	capture_camera.global_position = at + Vector3(6.6, 1.75, 6.6)
	capture_camera.look_at(at + Vector3(0.0, 1.0, 0.0), Vector3.UP)
	capture_camera.make_current()
	await _capture("09_pen_with_ponies")

	# 09b -- straight down the fence line from outside, level with a pony. The scale shot:
	# a 1.163 m withers and a 2.138 m horn tip against a 2.25 m fence, in one frame.
	var side := at + Vector3(PenScript.HALF_EXTENT + 2.6, 0.0, 0.0)
	side.y = terrain.height_at(side.x, side.z) + 1.15
	capture_camera.global_position = side
	capture_camera.look_at(at + Vector3(0.0, 1.05, 0.0), Vector3.UP)
	capture_camera.make_current()
	await _capture("09b_pen_scale_at_the_fence")


## THE SHOTS THE PLAYTEST ASKED FOR: the core loop, through the player's own camera, with
## the real HUD over it. Everything above this point photographs the PLACE; nothing in the
## project photographed the MECHANIC in the place, and every one of the owner's five
## complaints was about how the mechanic feels rather than about how the ranch looks.
##
## Screenshot-pass only (this whole function is downstream of the headless quit), and
## deliberately so: it moves the player about and takes a pony out of the world, which is
## exactly what a gate must not do to the state its own checks were computed from. Every
## check in _report() has already run and printed by the time this is reached.
##
## Numbers are printed beside each shot for the same reason wild_ponies.gd prints them:
## a picture of a beam and a printed hold time that disagree is the paper-correct-but-
## visually-wrong bug the whole capture pass exists to catch.
func _capture_the_mechanic() -> void:
	var beam: Node3D = player.get_magic_beam()
	if beam == null:
		return

	# 06 -- a SHY pony noticing the player from beyond the beam's reach, and bolting. The
	# whole of the headline fix, in one frame: he is not close enough to take her, and she
	# is already leaving.
	var shy := _find_pony_by_personality(PonyDataScript.Personality.SHY)
	if shy != null:
		var reach: float = beam.REACH
		# Stood at the midpoint of the warning band -- outside REACH, inside detection.
		var stand_off: float = (reach + PonyScript.DETECTION_RADIUS) * 0.5
		await _stand_player_near(shy, stand_off)
		await _aim_rig_at(shy.global_position + Vector3(0.0, 0.65, 0.0))
		for i in range(18):
			await get_tree().physics_frame
		# Re-aimed after the wait: she has been running the whole time, and a shot of the
		# grass she left is not a shot of a pony fleeing.
		await _aim_rig_at(shy.global_position + Vector3(0.0, 0.65, 0.0))
		var gap: float = _ground_gap(player.global_position, shy.global_position)
		print("RANCH mechanic flee pony=%s state=%s gap=%.2f reach=%.2f detection=%.2f speed=%.2f"
			% [shy.name, PonyScript.state_name(shy.state), gap, reach,
				PonyScript.DETECTION_RADIUS, shy.get_ground_speed()])
		_rig.get_camera().make_current()
		await _capture("06_she_bolts_before_you_are_in_range")

	# The beam shots want a pony who holds still while she is photographed, which on this
	# roster means a BOLD one -- she has no reaction to the player at all, so the framing
	# is not racing her state machine. Falls back to whoever is left.
	var target := _find_pony_by_personality(PonyDataScript.Personality.BOLD)
	if target == null:
		var live: Array[CharacterBody3D] = spawner.get_spawned()
		target = live[0] if not live.is_empty() else null
	if target == null:
		return

	# 07 -- the beam sweeping empty ground at full stretch: the arc, and the ring lying on
	# the grass under where it runs out. This is the shot for "hard to gauge distance of
	# beam" -- the ring is on a surface the eye is already reading perspective off, and it
	# is drawn even when the beam has hit nothing, so sweeping for range is something the
	# player can DO rather than guess at. Aimed 15 degrees off the pony so nothing gets
	# grabbed and the beam stays empty.
	await _stand_player_near(target, beam.REACH - 0.6)
	var aside := (target.global_position - player.global_position).rotated(Vector3.UP, deg_to_rad(28.0))
	await _aim_rig_at(player.global_position + aside + Vector3(0.0, 0.4, 0.0))
	beam.grab()
	for i in range(8):
		await get_tree().physics_frame
	print("RANCH mechanic sweep holding=%s has_target=%s has_mark=%s mark=(%.1f, %.2f, %.1f) gap=%.2f"
		% [beam.is_holding(), beam.has_target(), beam.has_mark(),
			beam.get_mark_point().x, beam.get_mark_point().y, beam.get_mark_point().z,
			_ground_gap(player.global_position, beam.get_mark_point())])
	_rig.get_camera().make_current()
	await _capture("07a_beam_landing_ring_at_range")
	beam.release()
	for i in range(int(beam.ESCAPE_COOLDOWN * 60.0) + 4):
		await get_tree().physics_frame

	# 07b -- the same distance, aimed AT her, beam off: the reticle alone says she is in
	# range, before the button is pressed.
	await _aim_rig_at(target.global_position + Vector3(0.0, 0.65, 0.0))
	print("RANCH mechanic in_range pony=%s gap=%.2f has_target=%s (beam still OFF)"
		% [target.name, _ground_gap(player.global_position, target.global_position),
			beam.has_target()])
	_rig.get_camera().make_current()
	await _capture("07b_in_range_before_pressing")

	# 07c -- the fumbled catch, and the one state in which the LOCKED landing ring is
	# visible at all. Aiming the beam at a pony in range takes her on the same frame, so
	# "beam on, target in range, nothing held" only exists during the post-slip cooldown --
	# which is exactly the moment the player is re-lining up a catch they just dropped, and
	# so exactly the moment the ring is worth having. Also gets the toast that teaches the
	# mistake ("she slipped out") into a frame.
	beam.grab()
	for i in range(3):
		await get_tree().physics_frame
	beam.release()
	for i in range(10):
		await get_tree().physics_frame
	await _aim_rig_at(target.global_position + Vector3(0.0, 0.65, 0.0))
	beam.grab()
	for i in range(4):
		await get_tree().physics_frame
	print("RANCH mechanic cooling loss=%s holding=%s has_target=%s has_mark=%s"
		% [beam.get_last_loss(), beam.is_holding(), beam.has_target(), beam.has_mark()])
	await _capture("07c_locked_on_during_the_cooldown")
	beam.release()
	for i in range(int(beam.ESCAPE_COOLDOWN * 60.0) + 6):
		await get_tree().physics_frame
	await _aim_rig_at(target.global_position + Vector3(0.0, 0.65, 0.0))

	beam.grab()
	for i in range(6):
		await get_tree().physics_frame
	print("RANCH mechanic beam holding=%s secure_progress=%.2f mark=%s"
		% [beam.is_holding(), beam.get_secure_progress(), beam.has_mark()])
	await _capture("08_beam_reaching")

	# 09 -- mid-struggle: the outer ring part-drained, the inner secure arc part-filled.
	# Waited to a FRACTION of the secure time rather than a fixed frame count, so this
	# stays the mid-struggle shot whatever SECURE_SECONDS becomes.
	while beam.is_holding() and beam.get_secure_progress() < 0.55:
		await get_tree().physics_frame
	print("RANCH mechanic struggle hold=%.2fs secure=%.2fs struggle=%.2fs progress=%.2f secured=%s"
		% [beam.get_hold_seconds(), beam.get_secure_seconds(), beam.get_struggle_seconds(),
			beam.get_secure_progress(), beam.is_secured()])
	await _capture("09_struggle_ring_half_drained")

	# 10 -- secured: let go NOW.
	while beam.is_holding() and not beam.is_secured():
		await get_tree().physics_frame
	print("RANCH mechanic secured hold=%.2fs secured=%s" % [
		beam.get_hold_seconds(), beam.is_secured()])
	await _capture("10_secured_let_go_now")

	beam.release()
	for i in range(4):
		await get_tree().physics_frame
	await _capture("11_caught_her")

	player.global_position = player_spawn.global_position
	player.velocity = Vector3.ZERO

	# 12 -- the whole map from above, for the complaint a close-up cannot answer: "ponies
	# were only around the perimeter". A herd is a handful of pixels from up here, so the
	# picture is read alongside the per-pony `RANCH pony ... home=(x, y, z)` table printed
	# by _report() -- the shot is for judging whether the SPREAD looks like a place with
	# animals living all over it, and the table is for knowing exactly where they are.
	var wide := $CaptureCamera as Camera3D
	wide.global_position = Vector3(6.0, 64.0, 80.0)
	wide.look_at(Vector3(-2.0, 0.0, -8.0), Vector3.UP)
	wide.make_current()
	# The HUD is hidden for this one shot and put back afterwards. It is drawn for the
	# player, at the player's eye, and over a map shot the hints card covers a whole
	# quadrant of the thing the picture is of.
	var hud := $HUD as CanvasLayer
	var hud_was_visible: bool = hud.visible
	hud.visible = false
	await _capture("12_spawn_spread")
	hud.visible = hud_was_visible


## Stand the player `distance` metres from `pony` on the ground, on the side she is
## currently facing away from, and level the rig at her. Used only by the screenshot pass.
func _stand_player_near(pony: Node3D, distance: float) -> void:
	var away := player.global_position - pony.global_position
	away.y = 0.0
	if away.length_squared() < 0.01:
		away = Vector3.FORWARD
	var stand: Vector3 = pony.global_position + away.normalized() * distance
	stand.y = terrain.height_at(stand.x, stand.z) + 0.15
	player.global_position = stand
	player.velocity = Vector3.ZERO
	for i in range(CAMERA_SETTLE_FRAMES):
		await get_tree().physics_frame


## Drive the camera rig until get_aim_ray() points at `target`. The same iterative
## correction scenes/test/capture_test.gd uses, and iterative for the same reason: the
## camera hangs off a spring arm, so changing the pitch moves the eye the ray starts from.
func _aim_rig_at(target: Vector3) -> void:
	for i in range(12):
		var ray = _rig.get_aim_ray()
		var want: Vector3 = (target - ray.origin).normalized()
		var have: Vector3 = ray.direction
		var yaw_error := wrapf(atan2(-want.x, -want.z) - atan2(-have.x, -have.z), -PI, PI)
		var pitch_error := asin(clampf(want.y, -1.0, 1.0)) - asin(clampf(have.y, -1.0, 1.0))
		_rig.add_look_delta(-yaw_error, -pitch_error)
		await get_tree().physics_frame


func _find_pony_by_personality(personality: int) -> CharacterBody3D:
	for pony: CharacterBody3D in spawner.get_spawned():
		var data: PonyData = pony.get_data()
		if data != null and data.personality == personality:
			return pony
	return null


func _ground_gap(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _capture(shot_name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var path: String = _screenshot_dir.path_join("%s.png" % shot_name)
	image.save_png(path)
	print("SCREENSHOT_SAVED %s" % path)
