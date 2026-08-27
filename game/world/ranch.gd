class_name Ranch
extends Node3D
## THE MAP. The first actual place in this game -- everything before it was a test
## scene on a grey plane -- and, as of Phase 1A Task 7, the project's main scene.
##
## WHAT IT IS. Terrain (game/world/terrain.gd) with a sun and a sky, a homestead of
## Kenney props at the validated 1.5x scale (game/world/props.gd), the player
## standing in the yard, three ZoneMarkers out in open country, and a Spawner
## (game/world/spawner.gd) that fills them with wild ponies drawn from the registry.
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
## and then saves five PNGs: the establishing shot, the view from the player's own
## eyes at spawn, a spawn zone with ponies in it, the camera pressed against a
## building, and an eye-level look at the barn for scale. Every check in this file is
## a number; whether the place READS as a place is not something a number can answer.
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

@onready var terrain: StaticBody3D = $Terrain
@onready var props: Node3D = $Props
@onready var buildings: Node3D = $Buildings
@onready var spawner: Node3D = $Spawner
@onready var player: CharacterBody3D = $Player
@onready var player_spawn: Marker3D = $PlayerSpawn
@onready var capture_camera: Camera3D = $CaptureCamera

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

	for i in range(SETTLE_FRAMES):
		await get_tree().physics_frame

	# After the beam exists and the world has settled: put the ponies the player owned when
	# she quit back into her saddlebag.
	_restored_ponies = _restore_owned_ponies()

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


## Put the owned ponies back in the player's saddlebag after a load.
##
## Storage is fixed-capacity, so a save holding more ponies than the bag can carry cannot
## be fully restored into it -- and that is exactly why _sync_game_state() below merges
## rather than overwrites: a pony who did not fit must not be dropped from the save the
## next time it is written. (Task 3's pens are where the ones that do not fit will
## actually live; until there is somewhere else to put her, she stays in the file.)
func _restore_owned_ponies() -> int:
	if _game_state == null:
		return 0
	var beam: Node3D = player.get_magic_beam()
	if beam == null:
		return 0
	var storage: Storage = beam.get_storage()
	var restored := 0
	for instance: PonyInstance in _game_state.get_ponies():
		if not storage.store(instance):
			break
		restored += 1
	return restored


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
	for instance: PonyInstance in _game_state.get_ponies():
		if not seen.has(instance.uid):
			owned.append(instance)
	_game_state.set_ponies(owned)
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
	if not _interactive or _game_state == null:
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
		# (see CameraRig.probe_margin) and because a fade of 0.00 at 0.73 m is the whole
		# of the fix for the camera-inside-the-pony close-up -- worth a printed number
		# rather than only a screenshot.
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
	_rig.get_node("SpringArm3D/Camera3D").make_current()
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
		_rig.get_node("SpringArm3D/Camera3D").make_current()
		await _capture("04a_camera_pressed_to_wall")

		# ...and again from 1.2 m further out. Both shots are worth keeping: 04a is
		# the strict pose the check measures -- the arm at 0.6 m, well inside the pony
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


func _capture(shot_name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var path: String = _screenshot_dir.path_join("%s.png" % shot_name)
	image.save_png(path)
	print("SCREENSHOT_SAVED %s" % path)
