extends Node3D
## Task 8 verification scene for the magic beam and capture storage
## (game/actors/player/magic_beam.gd, game/systems/storage.gd).
##
## A ground plane, a real Player (real camera rig, real horn marker, real beam), one
## pony at a time at a KNOWN spot, and a crate. Five phases, each of which is a separate
## claim about the mechanic and each of which is failed by a different bug:
##
##   GRAB     aim the rig at the pony through the same get_aim_ray() the beam uses, switch
##            the beam on, and check she enters HELD and is REELED IN -- her distance to
##            the hold point must collapse, not merely be small at the end (a beam that
##            teleported her would pass a "she is near the hold point" check on its own).
##   CAPTURE  let go: her record must be in Storage (count 1) and her NODE must be gone.
##            Checked through a WeakRef, not through is_instance_valid on a variable we
##            are still holding -- the second would keep the reference alive.
##   ESCAPE   hold a SHY pony past her struggle time: escaped() must fire, she must be
##            out of HELD, and she must still be ALIVE and in the world. The elapsed time
##            is checked against MagicBeam.STRUGGLE_SHY with a window narrow enough that
##            handing a SHY pony BOLD's 4.0 s instead would fail it -- otherwise the
##            per-personality tuning would be a number no gate reads.
##   FULL     fill the bag, then hold and release another pony: store() must refuse, the
##            count must NOT grow, and she must still be in the world. NO PONY EVER DIES
##            is a project-wide rule and this is the branch where a careless
##            implementation drops one.
##   PROP     a loose RigidBody3D must be draggable too, and must get its physics back
##            (freeze cleared) when it is let go.
##
## WHY THIS GATE CAN FAIL -- the part worth writing down, because this project has
## repeatedly shipped gates that passed while measuring nothing (a harness that passed
## with zero tests; a hair metric reading a search-window boundary; a probe inert to the
## parameter it swept; a "seeded" spawn that differed between processes):
##
##   * The aim is not faked. The camera is driven by add_look_delta() until
##     get_aim_ray() points at the pony, and the ANGLE is asserted before the grab -- so
##     "the beam found her" cannot be true because the gate handed the beam a target.
##     If get_aim_ray() regressed, the aim check goes red before any capture is attempted.
##   * Reeling in is checked as a RATIO (final gap < a quarter of the gap at acquisition)
##     as well as an absolute, so a beam that dropped the lerp and simply snapped her
##     into place, or one that never moved her at all, both fail.
##   * The capture check is "the node is gone AND the record is in the bag". Freeing her
##     without storing her, or storing her without freeing her, each fail one half.
##   * The full-bag check asserts a NON-event (the count did not grow) plus a live pony
##     afterwards; a store() that returned false after already appending fails the first,
##     and a beam that deleted the refused pony fails the second.
##   * The escape window is narrow enough to fail on the wrong personality's number.
##   * Every phase re-checks that the pony it just finished with is still a valid
##     instance, except the captured one, which is asserted to be gone.
##
## Verified against a deliberately broken build before it was trusted -- see the failure
## proof in the task report.
##
## OFFSCREEN RENDERING (`xvfb-run -a tools/bin/godot --path game --audio-driver Dummy
## scenes/test/capture_test.tscn -- --screenshot-dir=<path>`, NOT `--headless`): runs the
## same five phases and additionally saves PNGs THROUGH THE PLAYER'S OWN CAMERA, which is
## the only way to answer the questions no number here can: is the beam legible, and does
## a held pony sit at a sensible distance in front of the camera rather than clipping into
## it? Structural gates in this project have been green through an invisible character
## before (docs/pipeline.md section 7).
##
## `--audio-driver Dummy` is REQUIRED here, explicitly, and not merely implied by
## `--headless` the way it is on every other gate: this scene is windowed/offscreen, not
## headless (headless renders nothing to screenshot), so Godot's own
## `--headless`->dummy-audio-driver mapping does not apply, and without this flag a run
## opens a real audio device. This is the exact scene whose CAPTURE phase fires
## game/actors/player/magic_beam.gd's first-capture voice line
## (assets/audio/voice/twilight/greeting_01.wav) -- an automated Proton verification run
## of this same mechanic once played that line out loud through real speakers/
## headphones before this flag existed. game/systems/audio_safety.gd (an autoload) mutes
## the Master bus on its own as a backstop whenever it sees a `--screenshot...` arg, in
## case a future invocation forgets this flag.

const PonyScene := preload("res://actors/pony/pony.tscn")
const PonyScript := preload("res://actors/pony/pony.gd")
const PonyDataScript := preload("res://systems/pony_data.gd")
const PonyInstanceScript := preload("res://systems/pony_instance.gd")
const PonyRegistryScript := preload("res://systems/pony_registry.gd")
const MagicBeamScript := preload("res://actors/player/magic_beam.gd")
const GateWatchdogScript := preload("res://scripts/gate_watchdog.gd")

## Physics frames to let the player settle onto the ground and the spring arm's collision
## probe run before anything is aimed or grabbed.
const SETTLE_FRAMES := 12

## How many correction steps the aim loop takes. The camera hangs off a SPRING ARM, so
## changing the pitch MOVES the eye point the ray starts from -- one analytic step would
## overshoot. Twelve is far more than the three or four it actually converges in.
const AIM_ITERATIONS := 12

## Maximum angle, in degrees, between the aim ray and the line to the pony's chest that
## still counts as "aimed at her". Tight: the point of the check is that the beam is
## following the crosshair, not that it eventually found something.
const AIM_TOLERANCE_DEG := 1.0

## Frames to let the pull-in finish. PULL_RESPONSE reels 90% of the gap in ~0.29 s, so 40
## frames (0.67 s) is well past settled -- and still under every struggle time, so this
## wait cannot itself cause an escape.
const PULL_FRAMES := 40

## Metres from the hold point at which a held body counts as arrived.
const ARRIVE_TOLERANCE := 0.25

## The gap at the end must be no more than this fraction of the gap at acquisition. This
## is the check that the pony was actually TRANSPORTED rather than grabbed where she
## already stood.
const ARRIVE_RATIO := 0.25

## Minimum metres between the camera and a held body. The eyeball question ("does she
## clip into the camera?") gets a number as well as a screenshot.
const MIN_CAMERA_CLEARANCE := 2.5

## Where each phase's pony is placed, relative to the player at the origin. 6.2 m out:
## comfortably inside MagicBeam.REACH and comfortably outside Pony.DETECTION_RADIUS, so
## she is not already reacting to the player when the beam reaches her.
const PONY_SPOT := Vector3(1.5, 0.0, -6.0)

## Where a finished pony is parked. Scene housekeeping, not a gameplay path: a released
## pony wanders (or flees), and one drifting through the next phase's line of fire would
## make this gate flaky for a reason that has nothing to do with the beam. She is moved,
## never freed -- the phase that cares has already asserted she is alive.
const PARK_SPOT := Vector3(0.0, 0.0, -40.0)

## Longest a struggle phase will wait before giving up, in seconds.
const STRUGGLE_TIMEOUT := 3.5

## Acceptance window around MagicBeam.STRUGGLE_SHY for the escape, in seconds. Wide enough
## for frame quantisation and the screenshot pauses, narrow enough that CURIOUS's 2.5 s or
## BOLD's 4.0 s would fail it.
const STRUGGLE_WINDOW := 0.4

@onready var player: Node3D = $Player
@onready var crate: RigidBody3D = $Crate

var _rig: Node3D
var _beam: Node3D
var _storage: Storage
var _roster: Dictionary = {}
var _screenshot_dir := ""
var _checks: Dictionary = {}
## Labels recorded more than once. Any entry here fails the whole gate -- see _record().
var _duplicate_labels: Array[String] = []
var _shot_index := 0


func _ready() -> void:
	GateWatchdogScript.arm(self, "CAPTURE", 60.0)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot-dir="):
			_screenshot_dir = arg.split("=")[1]

	_roster = PonyRegistryScript.new().load_all("res://data/ponies")

	_rig = player.get_camera_pivot().get_node("CameraRig")
	_beam = player.get_magic_beam()
	_storage = _beam.get_storage()

	for i in range(SETTLE_FRAMES):
		await get_tree().physics_frame

	_record("the beam is mounted on the player", _beam != null)
	_record("the beam owns a storage", _storage != null and _storage.capacity > 0)
	_record("the beam starts switched off and empty", not _beam.is_active()
		and not _beam.is_holding() and _storage.count() == 0)
	# Not a triviality: MagicBeam resolves this through Player.get_beam_origin(), which is
	# an @onready var the Player has not assigned yet while its children are readying. The
	# first version asked for it too early, got null, and quietly drew the beam out of the
	# player's HOOVES -- green everywhere, wrong in every frame.
	print("CAPTURE anchor=%s at=(%.2f, %.2f, %.2f)" % [
		_beam.get_beam_anchor().name, _beam.get_beam_anchor().global_position.x,
		_beam.get_beam_anchor().global_position.y, _beam.get_beam_anchor().global_position.z])
	_record("the beam is drawn from the player's horn, not from her origin",
		_beam.get_beam_anchor() == player.get_beam_origin()
		and _beam.get_beam_anchor().global_position.y > 1.5)
	# The personality rule, asserted here as well as in game/test/test_magic_beam.gd, so a
	# reader of this gate's output can see the numbers the ESCAPE phase is checked against.
	_record("a shy pony struggles sooner than a bold one",
		MagicBeamScript.struggle_seconds_for(PonyDataScript.Personality.SHY)
		< MagicBeamScript.struggle_seconds_for(PonyDataScript.Personality.BOLD))

	await _phase_grab_and_capture()
	await _phase_distinct_and_release()
	await _phase_escape()
	await _phase_full_storage()
	await _phase_prop()
	await _phase_teardown()

	_finish()


# --- phases ---------------------------------------------------------------------------

## GRAB + CAPTURE. A BOLD pony (rainbowdash: 4.0 s struggle, no reaction to the player, so
## nothing in this phase is racing her state machine) is aimed at, grabbed, reeled in,
## then released into an empty bag.
func _phase_grab_and_capture() -> void:
	var pony := _spawn_pony(&"rainbowdash", PONY_SPOT)
	var spawn_position: Vector3 = pony.global_position
	print("CAPTURE spawn id=rainbowdash at=(%.2f, %.2f, %.2f) personality=%s struggle=%.2fs" % [
		spawn_position.x, spawn_position.y, spawn_position.z,
		PonyDataScript.Personality.keys()[pony.get_data().personality],
		MagicBeamScript.struggle_seconds_for(pony.get_data().personality)])

	await _aim_at_pony(pony, "grab")

	_beam.grab()
	var acquired := await _wait_until_holding()
	_record("the beam picks up the pony the crosshair is on", acquired)
	_record("a grabbed pony is in HELD", pony.state == PonyScript.State.HELD)

	var gap_at_grab: float = _chest(pony).distance_to(_beam.get_hold_point())
	await _frames(4)
	await _shot("01_beam_reaching")

	await _frames(PULL_FRAMES)
	var gap_now: float = _chest(pony).distance_to(_beam.get_hold_point())
	var camera_gap: float = pony.global_position.distance_to(_camera().global_position)
	print("CAPTURE pull gap_at_grab=%.3f gap_now=%.3f moved=%.3f camera_clearance=%.3f hold_point=(%.2f, %.2f, %.2f)" % [
		gap_at_grab, gap_now, pony.global_position.distance_to(spawn_position), camera_gap,
		_beam.get_hold_point().x, _beam.get_hold_point().y, _beam.get_hold_point().z])

	_record("the held pony is reeled toward the hold point", gap_now < gap_at_grab * ARRIVE_RATIO)
	_record("...and arrives at it", gap_now < ARRIVE_TOLERANCE)
	_record("...having actually travelled from where she was standing",
		pony.global_position.distance_to(spawn_position) > 1.0)
	_record("...and does not clip into the camera", camera_gap > MIN_CAMERA_CLEARANCE)
	_record("she is still in HELD while the button is down",
		pony.state == PonyScript.State.HELD and _beam.is_holding())

	await _shot("02_held_at_hold_point")

	# The capture itself. WeakRef, so this variable cannot be what keeps her alive.
	var ghost: WeakRef = weakref(pony)
	var captured_instances: Array = []
	_beam.captured.connect(func(inst: PonyInstance) -> void: captured_instances.append(inst))

	_beam.release()
	_record("releasing over an empty bag stores her", _storage.count() == 1)
	_record("...and reports it", captured_instances.size() == 1
		and captured_instances[0] != null and captured_instances[0].data_id == &"rainbowdash")
	# Phase 1B Task 1: what goes in the bag is an INDIVIDUAL, not the shared character
	# record. The DISTINCT phase below is what proves two of them stay apart; this is the
	# narrower claim that one of them has an identity at all.
	_record("...as an individual with her own uid, not as the shared character record",
		captured_instances.size() == 1 and captured_instances[0] != null
		and PonyInstanceScript.serial_of(captured_instances[0].uid) > 0)
	_record("...and the beam is empty afterwards", not _beam.is_holding())

	await _frames(3)
	_record("the captured pony's node is gone from the world", ghost.get_ref() == null)
	print("CAPTURE stored count=%d/%d node_freed=%s" % [
		_storage.count(), _storage.capacity, ghost.get_ref() == null])

	await _shot("03_release_captured")


## DISTINCT + RELEASE. Phase 1B Task 1's whole reason for existing, driven end to end
## through the real beam rather than asserted about a container in isolation.
##
## Two catches of the SAME CHARACTER used to put two pointers to one shared PonyData in the
## bag -- a reviewer inspected it and saw `contents=[twilight, twilight]`. So: catch a
## second rainbowdash on top of the first and check the bag holds two INDIVIDUALS with
## different uids and independently movable state.
##
## Then let one back out. `Storage.release()` shipped with ZERO CALLERS -- the bag was a
## one-way trip -- and MagicBeam.release_stored() is the caller that retires that finding.
## The claim with teeth is not "a pony appeared" but "the pony who appeared is the SAME
## individual, with the state she went in with", so her happiness and nickname are set to
## values nothing else in this scene uses and read back off the live node. And then she is
## caught AGAIN, which must reuse her existing instance rather than mint a fresh one: a
## recapture that quietly reset her would be exactly the amnesia PonyInstance exists to
## prevent, and it is invisible to every other check here.
func _phase_distinct_and_release() -> void:
	var pony := _spawn_pony(&"rainbowdash", PONY_SPOT)
	await _aim_at_pony(pony, "second catch")
	_beam.grab()
	_record("a second pony of the same character can be caught too",
		await _wait_until_holding())
	await _frames(PULL_FRAMES)
	_beam.release()

	var bag: Array = _storage.contents()
	var uid_a := String(bag[0].uid) if bag.size() > 1 else ""
	var uid_b := String(bag[1].uid) if bag.size() > 1 else ""
	print("CAPTURE distinct count=%d uids=[%s, %s] data_ids=[%s, %s]" % [
		_storage.count(), uid_a, uid_b,
		String(bag[0].data_id) if bag.size() > 1 else "-",
		String(bag[1].data_id) if bag.size() > 1 else "-"])

	_record("two catches of one character are two records, not one", _storage.count() == 2)
	_record("...of the same character", bag.size() == 2
		and bag[0].data_id == &"rainbowdash" and bag[1].data_id == &"rainbowdash")
	# Compared as String, never as StringName: Godot orders StringName by interned POINTER,
	# a footgun this project has already shipped once (game/world/spawner.gd's DETERMINISM
	# note). Equality is safe either way; doing it one way everywhere is what stops the next
	# reader reaching for sort() on a pile of uids.
	_record("...telling the two individuals apart by uid",
		bag.size() == 2 and not uid_a.is_empty() and uid_a != uid_b)

	# The state that had nowhere to live before this task.
	bag[0].happiness = 0.9
	bag[1].happiness = 0.1
	_record("...with state that moves independently",
		absf(_storage.contents()[0].happiness - 0.9) < 0.0001
		and absf(_storage.contents()[1].happiness - 0.1) < 0.0001)

	# --- and back out again ---------------------------------------------------------
	var stored: PonyInstance = _storage.peek()
	stored.happiness = 0.42
	stored.nickname = "Dashie"
	var stored_uid := String(stored.uid)

	var back: Node3D = _beam.release_stored()
	var alive: bool = back != null and is_instance_valid(back) and back.is_inside_tree()
	_record("a stored pony can be let back out into the world", alive)
	_record("...and is gone from the bag when she is", _storage.count() == 1)

	var out: PonyInstance = back.get_instance() if alive else null
	print("CAPTURE release uid=%s happiness=%s nickname=%s at=(%.2f, %.2f, %.2f)" % [
		String(out.uid) if out != null else "-",
		("%.3f" % out.happiness) if out != null else "-",
		out.nickname if out != null else "-",
		back.global_position.x if alive else 0.0,
		back.global_position.y if alive else 0.0,
		back.global_position.z if alive else 0.0])

	_record("...as the very same individual she went in as",
		out != null and String(out.uid) == stored_uid)
	_record("...carrying the state she went in with",
		out != null and absf(out.happiness - 0.42) < 0.0001 and out.nickname == "Dashie")
	# The mane/tail spring simulation is the whole reason PonyVisuals.build() is the only
	# sanctioned spawn path (docs/notes-hair-sim.md). A release that loaded the .glb some
	# other way would still produce a pony-shaped thing, and this is what tells them apart.
	_record("...rebuilt through the sanctioned visuals path, not a bare model load",
		alive and back.get_animation_player() != null)

	# She was set down slightly above the ground and has her own gravity back, so she comes
	# down and stands on it -- the same "not stranded mid-air" claim the teardown phase makes.
	await _frames(60)
	alive = back != null and is_instance_valid(back) and back.is_inside_tree()
	_record("...standing on the ground on her own hooves afterwards",
		alive and absf(back.global_position.y) < 0.05)

	await _shot("08_released_from_storage")

	# --- caught again: the same pony, not a fresh copy of her character ---------------
	if alive:
		back.global_position = PONY_SPOT
		await _aim_at_pony(back, "recapture")
		_beam.grab()
		_record("a released pony can be caught again", await _wait_until_holding())
		await _frames(PULL_FRAMES)
		_beam.release()
		var again: PonyInstance = _storage.peek()
		print("CAPTURE recapture uid=%s happiness=%s count=%d" % [
			String(again.uid) if again != null else "-",
			("%.3f" % again.happiness) if again != null else "-", _storage.count()])
		_record("...and re-catching her reuses her identity rather than minting a new one",
			again != null and String(again.uid) == stored_uid)
		_record("...so her state survives the round trip out and back",
			again != null and absf(again.happiness - 0.42) < 0.0001)


## ESCAPE. A SHY pony held past her struggle time wins and is handed back, alive.
func _phase_escape() -> void:
	var pony := _spawn_pony(&"fluttershy", PONY_SPOT)
	var expected: float = MagicBeamScript.struggle_seconds_for(pony.get_data().personality)
	var escaped_reported := [false]
	pony.escaped.connect(func() -> void: escaped_reported[0] = true)

	await _aim_at_pony(pony, "escape")
	_beam.grab()
	var acquired := await _wait_until_holding()
	_record("a shy pony can be picked up at all", acquired)

	var start := Time.get_ticks_msec()
	var held_for := 0.0
	for i in range(int(STRUGGLE_TIMEOUT * 60.0)):
		await get_tree().physics_frame
		if not _beam.is_holding():
			held_for = float(Time.get_ticks_msec() - start) / 1000.0
			break

	var count_before: int = _storage.count()
	print("CAPTURE struggle personality=SHY expected=%.2fs actual=%.2fs escaped_signal=%s state=%s" % [
		expected, held_for, escaped_reported[0], PonyScript.state_name(pony.state)])

	_record("a held pony eventually wins her struggle", held_for > 0.0)
	_record("...on her own personality's clock, not another's",
		absf(held_for - expected) <= STRUGGLE_WINDOW)
	_record("...and reports it as escaped()", escaped_reported[0])
	_record("...and gets her physics back", pony.state != PonyScript.State.HELD)
	_record("...and is still alive in the world (no pony ever dies)",
		is_instance_valid(pony) and pony.is_inside_tree())
	_record("an escaped pony is not in the bag", _storage.count() == count_before)

	await _shot("04_struggle_escape")

	# The beam refuses to re-acquire for ESCAPE_COOLDOWN, so an escape means something.
	_record("the beam does not instantly re-grab an escapee", not _beam.is_holding())
	_beam.release()
	_park(pony)

	# ...and that refusal is deliberately NOT cleared by letting go of the button, or
	# tapping it again would undo every escape. So the next phase has to wait it out --
	# it does not, and the FULL phase's grab silently failed the first time this gate ran.
	await _frames(int(MagicBeamScript.ESCAPE_COOLDOWN * 60.0) + 6)


## FULL. With the bag full, a released pony is set down rather than stored -- or lost.
func _phase_full_storage() -> void:
	# BOUNDED, not `while not is_full()`. The unbounded version hung this gate for two
	# minutes when the failure proof broke is_full() into always returning false -- a gate
	# that hangs on a bug is a gate that reports nothing about it. The bound is capacity
	# plus a little, so a storage that refuses to fill runs out of attempts and the check
	# below goes red instead.
	var filler := 0
	for i in range(_storage.capacity + 4):
		if _storage.is_full():
			break
		if not _storage.store(PonyInstanceScript.create(StringName("filler%d" % filler))):
			break
		filler += 1
	_record("the bag can actually be filled", _storage.is_full())
	var count_before: int = _storage.count()

	var pony := _spawn_pony(&"twilight", PONY_SPOT)
	var refused := [false]
	_beam.capture_refused.connect(func(_body: Node3D) -> void: refused[0] = true)

	await _aim_at_pony(pony, "full")
	_beam.grab()
	var acquired := await _wait_until_holding()
	_record("a full bag does not stop the beam picking her up", acquired)
	await _frames(PULL_FRAMES)
	await _shot("05_full_storage_held")

	var ghost: WeakRef = weakref(pony)
	_beam.release()
	_record("a full bag refuses the store", _storage.count() == count_before)
	_record("...and reports it as capture_refused()", refused[0])
	await _frames(3)
	# `alive` is computed once and every later clause is guarded by it. On a build that
	# WRONGLY freed her -- the exact bug this phase exists to catch -- the unguarded
	# version crashed on the next line instead of reporting, so a broken build produced a
	# short, confusing check list rather than a clear red one.
	var alive: bool = ghost.get_ref() != null and is_instance_valid(pony) and pony.is_inside_tree()
	_record("...and the pony is still in the world", alive)
	_record("...and out of HELD, steering herself again",
		alive and pony.state != PonyScript.State.HELD)

	# She was floating when she was let go; gravity is hers again, so she comes down.
	await _frames(45)
	alive = ghost.get_ref() != null and is_instance_valid(pony) and pony.is_inside_tree()
	print("CAPTURE full_bag count=%d/%d refused=%s pony_alive=%s landed_y=%s" % [
		_storage.count(), _storage.capacity, refused[0], alive,
		("%.3f" % pony.global_position.y) if alive else "<freed>"])
	_record("...and lands on the ground unharmed",
		alive and absf(pony.global_position.y) < 0.05)

	await _shot("06_full_storage_dropped")
	if alive:
		_park(pony)


## PROP. The part of the mechanic people play with for its own sake.
func _phase_prop() -> void:
	var start: Vector3 = crate.global_position
	await _aim_at(crate.global_position, "prop")
	_beam.grab()
	var acquired := await _wait_until_holding()
	_record("a loose rigid body can be dragged too", acquired)
	_record("...and it is the crate that got picked up", _beam.get_held_body() == crate)

	await _frames(PULL_FRAMES)
	var gap: float = crate.global_position.distance_to(_beam.get_hold_point())
	print("CAPTURE prop moved=%.3f gap=%.3f frozen=%s" % [
		crate.global_position.distance_to(start), gap, crate.freeze])
	_record("the crate is reeled to the hold point too", gap < ARRIVE_TOLERANCE)

	await _shot("07_prop_held")

	_beam.release()
	await _frames(30)
	_record("a released prop gets its physics back", not crate.freeze)
	_record("...and is still in the world", is_instance_valid(crate) and crate.is_inside_tree())


## TEARDOWN. The one exit from a hold that no other phase reaches: the beam going away
## while it still has hold of somebody. A pony in HELD runs no gravity and no steering, so
## a beam freed mid-hold leaves her suspended in the air with nothing left to release her.
## Runs last, because it removes the beam from the tree.
func _phase_teardown() -> void:
	var pony := _spawn_pony(&"rainbowdash", PONY_SPOT)
	await _aim_at_pony(pony, "teardown")
	_beam.grab()
	var acquired := await _wait_until_holding()
	_record("the beam has hold of her before the tree comes apart", acquired)
	await _frames(PULL_FRAMES)
	var held_at: Vector3 = pony.global_position

	# The beam vanishes out from under the hold -- a scene change, a despawned player.
	var parent := _beam.get_parent()
	parent.remove_child(_beam)
	await _frames(3)

	var alive: bool = is_instance_valid(pony) and pony.is_inside_tree()
	_record("a beam removed mid-hold lets go of her", alive and pony.state != PonyScript.State.HELD)
	_record("...leaving her alive in the world", alive)

	# The check with the teeth: HELD is precisely the state in which she does not fall, so
	# "she came down" is the difference between released and stranded.
	await _frames(60)
	alive = is_instance_valid(pony) and pony.is_inside_tree()
	print("CAPTURE teardown held_at_y=%.3f state=%s alive=%s now_y=%s" % [
		held_at.y, PonyScript.state_name(pony.state) if alive else "-", alive,
		("%.3f" % pony.global_position.y) if alive else "<freed>"])
	_record("...and falling under her own gravity again, not stranded mid-air",
		alive and held_at.y > 0.5 and absf(pony.global_position.y) < 0.05)

	# Put it back so the scene is not left with an orphaned node at quit. Re-entering the
	# tree does not re-run _ready(), so the storage and its contents survive.
	parent.add_child(_beam)


# --- aiming ---------------------------------------------------------------------------

## Drive the camera rig until get_aim_ray() points at `target`, then assert that it does.
##
## Iterative rather than analytic because the camera hangs off a SPRING ARM: changing the
## pitch moves the eye point the ray starts from, so the correction has to be re-derived
## from the new eye point. It converges in three or four steps; AIM_ITERATIONS is twelve.
##
## THE ASSERTION IS THE POINT. Nothing here hands the beam a target -- the beam runs its
## own cast along the same get_aim_ray() the loop below is steering, so if the rig's ray
## ever stopped agreeing with where the camera actually looks, this check goes red before
## a single capture is attempted.
func _aim_at(target: Vector3, label: String) -> void:
	for i in range(AIM_ITERATIONS):
		var ray = _rig.get_aim_ray()
		var want: Vector3 = (target - ray.origin).normalized()
		var have: Vector3 = ray.direction
		# add_look_delta's signs: positive yaw turns the view RIGHT (rotation.y -= yaw),
		# positive pitch looks DOWN (_look_pitch -= pitch). Both corrections are therefore
		# the negation of the error measured in the "view" sense.
		var yaw_error := wrapf(atan2(-want.x, -want.z) - atan2(-have.x, -have.z), -PI, PI)
		var pitch_error := asin(clampf(want.y, -1.0, 1.0)) - asin(clampf(have.y, -1.0, 1.0))
		_rig.add_look_delta(-yaw_error, -pitch_error)
		await get_tree().physics_frame

	var ray = _rig.get_aim_ray()
	var want: Vector3 = (target - ray.origin).normalized()
	var error_deg := rad_to_deg(acos(clampf(want.dot(ray.direction), -1.0, 1.0)))
	print("CAPTURE aim(%s) error=%.4f deg origin=(%.2f, %.2f, %.2f) dir=(%.3f, %.3f, %.3f)" % [
		label, error_deg, ray.origin.x, ray.origin.y, ray.origin.z,
		ray.direction.x, ray.direction.y, ray.direction.z])
	_record("the crosshair really is on the %s target" % label, error_deg <= AIM_TOLERANCE_DEG)


func _aim_at_pony(pony: CharacterBody3D, label: String) -> void:
	await _aim_at(_chest(pony), label)


## The centre of a pony's collision capsule -- what the crosshair should rest on, and what
## the hold point lines up with (MagicBeam.PONY_HOLD_LIFT).
func _chest(pony: Node3D) -> Vector3:
	return pony.global_position + Vector3(0.0, MagicBeamScript.PONY_HOLD_LIFT, 0.0)


# --- helpers --------------------------------------------------------------------------

func _spawn_pony(id: StringName, at: Vector3) -> CharacterBody3D:
	var ponies: Dictionary = _roster
	if not ponies.has(id):
		push_error("capture_test: no PonyData with id '%s'" % id)
		return null
	var pony: CharacterBody3D = PonyScene.instantiate()
	pony.name = "Pony_%s" % id
	# Placed BEFORE add_child: _ready() records wherever she stands as her roam anchor.
	pony.position = at
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260827
	pony.set_rng(rng)
	add_child(pony)
	pony.setup(ponies[id])
	return pony


## Park a finished pony well out of the next phase's way. Scene housekeeping only -- see
## PARK_SPOT.
func _park(pony: Node3D) -> void:
	if pony != null and is_instance_valid(pony):
		pony.global_position = PARK_SPOT


## Wait for the beam to acquire something (acquisition runs in the physics step after
## grab(), by design -- see MagicBeam.grab()). Returns false if it never does.
func _wait_until_holding() -> bool:
	for i in range(45):
		await get_tree().physics_frame
		if _beam.is_holding():
			return true
	return false


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().physics_frame


func _camera() -> Camera3D:
	return _rig.get_node("SpringArm3D/Camera3D")


## Record one check's verdict under `label`.
##
## THE DUPLICATE GUARD IS NOT DEFENSIVE PROGRAMMING, IT IS A BUG FIX. `_checks` is keyed by
## label, so two checks sharing one meant the second silently OVERWROTE the first's verdict
## and the total count came out one short. It happened: the ESCAPE phase's "did escaped()
## fire?" and the FULL phase's "did capture_refused() fire?" were both labelled
## "...and says so", so deleting `escaped.emit()` from pony.gd outright left this gate
## printing CAPTURE_OK -- a green gate not measuring the thing it claimed to. Distinct
## labels fix that instance; this guard is what stops the next one, because the next
## "...and " continuation line is one copy-paste away and nothing else in the file would
## notice.
##
## A collision is recorded as a FAILURE in its own right (and the loser is kept under a
## suffixed key rather than dropped, so a run with a duplicate still reports both verdicts
## instead of hiding one).
func _record(label: String, passed: bool) -> void:
	if _checks.has(label):
		push_error("capture_test: DUPLICATE check label -- '%s'" % label)
		_duplicate_labels.append(label)
		var suffix := 2
		while _checks.has("%s [dup %d]" % [label, suffix]):
			suffix += 1
		_checks["%s [dup %d]" % [label, suffix]] = passed
		return
	_checks[label] = passed


## Save a PNG through the PLAYER'S OWN CAMERA -- the whole point is to see what the player
## would see. No-op headless, where there is nothing to render.
func _shot(shot_name: String) -> void:
	if _screenshot_dir == "" or DisplayServer.get_name() == "headless":
		return
	await get_tree().process_frame
	await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var path: String = _screenshot_dir.path_join("%s.png" % shot_name)
	image.save_png(path)
	_shot_index += 1
	var held: Node3D = _beam.get_held_body()
	print("SCREENSHOT_SAVED %s beam_active=%s holding=%s held=%s hold_point=(%.2f, %.2f, %.2f) storage=%d/%d" % [
		path, _beam.is_active(), _beam.is_holding(),
		held.name if held != null else "-",
		_beam.get_hold_point().x, _beam.get_hold_point().y, _beam.get_hold_point().z,
		_storage.count(), _storage.capacity])


func _finish() -> void:
	var all_ok := true
	for label in _checks:
		if not _checks[label]:
			push_error("capture_test: FAILED check -- %s" % label)
			all_ok = false

	# A duplicate label fails the gate outright, even if every verdict happened to be
	# true: a gate that cannot say how many checks it ran, or which result belongs to
	# which claim, is not reporting. See _record().
	if not _duplicate_labels.is_empty():
		push_error("capture_test: check labels must be unique -- duplicated: %s"
			% ", ".join(_duplicate_labels))
		all_ok = false

	print("CAPTURE checks=%d shots=%d duplicates=%d storage=%d/%d" % [
		_checks.size(), _shot_index, _duplicate_labels.size(), _storage.count(),
		_storage.capacity])
	print(("CAPTURE_OK " if all_ok else "CAPTURE_FAILED ") + "checks=%d" % _checks.size())
	get_tree().quit(0 if all_ok else 1)
