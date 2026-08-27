class_name Pony
extends CharacterBody3D
## A wild pony: the thing that makes the world feel inhabited. Wanders, grazes, and
## reacts to the player according to its PonyData `personality`, and can be taken over
## by the magic beam (Task 8) via set_held().
##
## Interface other tasks depend on -- do not rename:
##   setup(data: PonyData)   -- build the body and adopt the record's stats/personality.
##   state: int              -- current State enum value (read it; do not assign it).
##   captured() / escaped()  -- emitted around a beam hold, see SIGNALS below.
##   set_held(is_held: bool) -- the beam takes / releases physics control.
##   get_held_seconds()      -- how long the current hold has lasted.
##   notify_captured() / break_free() -- the beam telling her how the hold ended.
##
## NOTHING IN HERE KNOWS A CHARACTER'S NAME. Every behavioural difference between one
## pony and another comes out of the PonyData record handed to setup(): `personality`
## chooses the reaction to the player, `base_speed` scales how fast she moves. Adding a
## pony stays what docs/design says it is -- authoring a .tres, never editing code.
##
## STATES. An explicit `match state` in _physics_process, one small function per state.
## Three of them are the idle routine and three are situational:
##
##   IDLE     pause for a beat, then pick the next routine state (WANDER or GRAZE).
##   WANDER   walk to a random point near home, playing `walk`. -> IDLE on arrival.
##   GRAZE    stand still playing `idle` for a few seconds. -> IDLE.
##   FLEE     SHY only: run directly away from the player, at a gallop. -> IDLE when
##            she can no longer see him (see _sees_player -- which is a live distance
##            test against her notice radius, not an area enter/exit event).
##   APPROACH CURIOUS only: walk toward the player and stop APPROACH_STOP_DISTANCE
##            short, watching her. -> IDLE when she can no longer see him.
##   HELD     the beam owns the transform: no gravity, no move_and_slide, no steering.
##
## The routine states are interruptible and the situational ones are not: every frame a
## pony in IDLE/WANDER/GRAZE that can see the player switches to her reaction state, and
## a pony in FLEE/APPROACH stays there until the player is out of range. BOLD ponies have
## no reaction state (reaction_state() returns NO_REACTION) so they simply never leave
## the routine -- which is the whole of "BOLD ignores the player", with no per-state
## special-casing anywhere below.
##
## HOW HARD SHE IS TO REACH, AND HOW HARD SHE IS TO HOLD, RUN IN OPPOSITE DIRECTIONS.
## That is a design decision the owner made in the second playtest ("it makes sense
## Fluttershy runs but freezes"), and it is split across two files, so it is written down
## in both:
##
##   SHY      hardest to REACH  -- notices from 14 m and bolts on sight (this file)
##            easiest to HOLD   -- she freezes; 4.6 s of struggle (magic_beam.gd)
##   CURIOUS  in between, and walks TOWARD you
##   BOLD     trivial to REACH  -- no reaction at all, walk right up to her
##            hardest to HOLD   -- she is not scared, she is just not having it: 2.3 s
##
## Before it, both dials pointed the same way: SHY was the hardest to catch AND the
## easiest to reach, and BOLD -- who is the RARE pony -- was a free catch. The rarest pony
## in a collection game was the least work to collect. Now reaching and holding are two
## different skills and rarity lines up with difficulty. Assertions in
## game/test/test_magic_beam.gd pin the ORDERING, in both directions, so an accidental
## re-inversion goes red rather than shipping.
##
## SPEEDS COME FROM Gait, SCALED BY base_speed. game/systems/gait.gd owns which clip
## honestly depicts a given ground speed and at what playback rate; this file must not
## re-derive any of that (docs/pipeline.md section 6 -- there were five hand-copied
## derivations of it before Gait existed). What this file adds is the one gameplay
## decision Gait cannot make: how fast a *particular* pony ambles or bolts.
##
## `base_speed` is used as a RELATIVE stat, not as metres per second. player.gd explains
## at length why it must not be read as m/s (it is a Phase 3 race-balance number; taking
## it literally would make Rainbow Dash's 6.5 into 6.5 m/s), and this file agrees with
## that reading: base_speed is divided by REFERENCE_BASE_SPEED to get a multiplier, and
## the result is clamped into the band of the clip that is supposed to be playing. So
## Fluttershy (3.0) ambles slower than Rainbow Dash (6.5) and bolts slower too, but no
## roster edit and no Phase 3 rebalance can push a wild pony outside what an authored
## clip can depict -- the worst a wild `base_speed` can do is saturate a clamp.
##
## SIGNALS, AND WHO DECIDES A CAPTURE. `captured()` fires when a beam hold has become a
## capture; `escaped()` fires when a held pony has broken free of one. Both are still
## declared and emitted HERE -- they are statements about this pony, and a listener that
## wants to react to one of them (an effect, a HUD, a later quest system) connects to the
## pony, not to whatever grabbed her.
##
## What this file deliberately does NOT own is the DECISION. It used to: it ran its own
## beam-hold timer against an exported `capture_seconds` and fired `captured()` itself
## once the hold outlasted it. That was a second capture state machine sitting underneath
## Task 8's, with a landmine default (`capture_seconds = 0` fired a capture on the first
## held frame), and the two would have fought over what a hold means the first time the
## beam wanted to tune it. It is gone. This file now only REPORTS -- that she is HELD,
## and for how long (get_held_seconds()) -- and the magic beam
## (game/actors/player/magic_beam.gd) decides when that hold becomes a capture or a
## break-free, then says so through notify_captured() / break_free(). Note that
## set_held(false) on its own is therefore silent: "the beam let go" is not by itself
## either outcome, and the beam calls the matching method for the outcome it chose.
##
## COLLISION CAPSULE. Identical to the player's -- radius 0.42 m, height 1.30 m, centred
## at y=0.65 so the bottom sits on the hoof plane -- for the reasons written out in
## player.gd: sized to the 1.163 m withers and the 0.839 m shoulder width, deliberately
## excluding the 2.09 m horn. All ponies use the same model scale, so they get the same
## capsule; if a future pony is a different size this is where a per-PonyData capsule
## would go.
##
## Preloads by path rather than by `class_name`, per the convention at the top of
## game/scripts/pony_rig.gd: the global class cache lives in the gitignored game/.godot/
## and a fresh clone has not built it yet.

const GaitScript := preload("res://systems/gait.gd")
const PonyDataScript := preload("res://systems/pony_data.gd")
const PonyVisualsScript := preload("res://actors/pony/pony_visuals.gd")
const PlayerScript := preload("res://actors/player/player.gd")

## Emitted when a beam hold has become a capture -- i.e. when the beam calls
## notify_captured(), immediately before it stores her record and frees this node.
signal captured()
## Emitted when a held pony breaks free -- i.e. when the beam calls break_free() because
## she outlasted its struggle timer.
signal escaped()

enum State { IDLE, WANDER, GRAZE, FLEE, APPROACH, HELD }

## reaction_state() returns this for a personality that has no reaction to the player
## (BOLD). Deliberately not one of the State values: "no reaction" is the absence of a
## state change, and giving it a State value would make `if reaction == State.IDLE` read
## as a real transition somewhere down the line.
const NO_REACTION := -1

## Base notice radius, in metres: how far off a RUNNING player has to be before a pony of
## ordinary nerve notices him. The floor across every personality (SHY adds to it, nobody
## subtracts), and therefore the number the beam's invariant is stated against.
##
## THIS NUMBER MUST COMFORTABLY EXCEED MagicBeam.REACH, AND IT IS THE WHOLE OF THE FIX
## FOR THE WORST BUG THE FIRST PLAYTEST FOUND. It was 5.0 while the beam reached 8.5 m,
## and the consequence was not subtle: a pony could not notice the player until he was
## 5 m away, but he could beam her from 8.5 m, so EVERY grab happened before she had
## reacted to anything. The owner's words were "I could just hold click and walk up and
## catch them". The flee behaviour below was not broken -- FLEE, the leash, the gallop
## clip, all of it worked -- it was simply unreachable in play, because the beam always
## got there first. A whole personality's worth of behaviour existed and no player could
## ever see it.
##
## 12.0 m is 3.5 m of clear warning past MagicBeam.REACH. Sized against the chase that
## has to follow: the player closes that gap at (RUN_SPEED - her flee speed), which
## for the slowest bolt on the roster (Fluttershy, 2.48 m/s) is 2.7 m/s -- about two
## seconds of committed running, long enough that the chase is a thing that happened
## and short enough that it is not a commute. Widening it further is not free: a CURIOUS
## pony starts walking over from here too, and a SHY one this far out spends the whole
## approach fleeing rather than grazing, so the world stops looking inhabited and starts
## looking alarmed.
##
## The invariant (notice radius > reach, with margin, for EVERY personality, against a
## RUNNING player) is asserted in game/test/test_magic_beam.gd and again as a live check
## in scenes/test/capture_test.gd, because it is a relationship between constants in two
## files and nothing but an assertion can stop it silently inverting again.
const DETECTION_RADIUS := 12.0

## Extra metres a SHY pony notices from, on top of DETECTION_RADIUS: 14.0 m in total.
##
## THE SECOND PLAYTEST INVERTED WHICH PERSONALITY IS HARD, AND THIS IS THE HALF OF THAT
## INVERSION THAT LIVES OUT IN THE WORLD. The owner's report was "Fluttershy always breaks
## out -- impossible to catch", followed by the design call that fixes it: "it makes sense
## Fluttershy runs but freezes". So SHY is now hard to REACH and easy to HOLD, and BOLD is
## the other way round (see MagicBeam.STRUGGLE_*). Reaching and holding became two
## different skills instead of one difficulty dial applied twice -- and the rarest pony on
## the roster stopped being the easiest one to collect, which was a real design inversion
## the first playtest round flagged and did not fix.
##
## 2.0 m rather than more: it has to be enough that a SHY pony is measurably jumpier than
## the others (she starts running 2 m before anyone else would, which at her 2.48 m/s bolt
## is nearly a second of head start on top of the 3.5 m everyone gets), and small enough
## that the chase still closes. At RUN_SPEED she is caught after ~2 s of running, not ~1.3.
## The lever deliberately used here is her EYESIGHT rather than her flee SPEED: speed is
## clamped by what the gallop clip can depict (flee_speed_for), so pushing difficulty
## through it would saturate at 4.29 m/s and leave a chase that closes at 0.9 m/s -- which
## is not "difficult", it is "long".
const SHY_NOTICE_BONUS := 2.0

## What a pony's notice radius is MULTIPLIED BY while the player is sneaking (holding
## Player.SNEAK_ACTION). SHY 14.0 -> 7.0 m, everyone else 12.0 -> 6.0 m.
##
## THIS IS WHAT THE SLOW GAIT BUYS, and it is deliberately generous enough to matter: both
## of those are INSIDE MagicBeam.REACH (8.5 m), so a player willing to creep can get the
## crosshair on a pony who has not noticed him at all and take her without a chase. That
## inverts the invariant above ON PURPOSE and only for a sneaking player -- the invariant
## is a promise about the player who is RUNNING, which is the default and is what every
## player does by reflex. Halving it is not subtle enough to be missed and not so deep
## that ponies stop reacting to the game; the numbers are asserted, in both directions, in
## game/test/test_pony.gd and demonstrated behaviourally in scenes/test/capture_test.gd.
const SNEAK_NOTICE_FACTOR := 0.5

## Radius of the DetectionArea sphere, in metres. Applied to the shape in _ready() so this
## constant cannot drift from what pony.tscn ships.
##
## THE AREA IS ONLY THE BROAD PHASE NOW. It has to be as wide as the widest notice radius
## any personality can have, because a body it never reports cannot be noticed at all; the
## real, per-personality, per-gait test is notice_radius_for() applied in _sees_player().
## Doing it that way round rather than resizing the sphere per pony (and re-resizing it
## every time the player presses Shift) keeps one cheap physics query and puts the whole
## rule in one pure function that a unit test can read.
const DETECTION_AREA_RADIUS := DETECTION_RADIUS + SHY_NOTICE_BONUS

## `base_speed` value that maps to exactly the nominal speeds below. Sits in the middle
## of the current roster (3.0 / 3.4 / 6.5) so a typical pony moves at the nominal rate
## and the extremes land either side of it. See the class comment on why base_speed is
## a multiplier here rather than a speed.
const REFERENCE_BASE_SPEED := 4.0

## Ambling speed for a REFERENCE_BASE_SPEED pony: exactly the `walk` clip's own speed,
## so she plays it at 1.0x with her hooves planted. A wild pony pottering about should
## be slower than the player's brisk 1.32 m/s -- she is not going anywhere.
const NOMINAL_WANDER_SPEED := GaitScript.WALK_CLIP_SPEED

## Ceiling on an amble, as a playback rate of the `walk` clip: 2.0x, i.e. 1.32 m/s.
## Deliberately NOT Gait.SKATE_FREE_TOP_SPEED (3.0x, 1.98 m/s): that is the exact speed
## at which Gait hands over to the `gallop` clip, so clamping there would produce a
## "wandering" pony that Gait then asks to gallop. A pony pottering about her field
## should not be moving faster than the player SNEAKS (player.gd's SNEAK_SPEED, also
## 1.32 m/s) anyway; anything faster is a flee, and flee_speed_for() handles that. This
## used to be pinned to the player's walk speed exactly; it is a plain 2.0x now, because
## the two numbers answer different questions and tying them together meant every retune
## of how the PLAYER handles silently retuned how a grazing animal ambles. (They have
## since come back to the same value from opposite directions, which is a coincidence and
## must not become a dependency again.)
const MAX_WANDER_PLAYBACK := 2.0

## Bolting speed for a REFERENCE_BASE_SPEED pony: exactly the `gallop` clip's own speed,
## 3.30 m/s, played at 1.0x. Faster than the player's sneak (1.32 m/s) and slower than her
## run (5.20 m/s), so a spooked pony outruns anyone creeping and is caught by anyone who
## commits to the chase.
##
## The CEILING is the interesting number, and it is not set here -- flee_speed_for()
## clamps to Gait.TOP_SKATE_FREE_SPEED (4.29 m/s), the fastest any authored clip can
## honestly depict. That clamp is what makes the player's 5.20 m/s run strictly faster
## than ANY wild pony can flee, whatever a roster edit puts in `base_speed`: a SHY Rainbow
## Dash (base_speed 6.5, which scales to 5.36 m/s) is pinned back to 4.29 and is therefore
## still catchable. Before the first playtest retune the player's gallop was 4.0 m/s and
## that same pony would have been 7% FASTER than the player and literally uncatchable in a
## straight line. She is BOLD on today's roster, so nobody ever hit it -- it was a
## landmine waiting for a personality edit, not a live bug.
const NOMINAL_FLEE_SPEED := GaitScript.GALLOP_CLIP_SPEED

## How close a CURIOUS pony comes before stopping to watch, in metres. Comfortably
## inside her own notice radius even when the player is sneaking (6.0 m -- she would
## otherwise walk out of her own eyesight mid-approach and forget what she was doing)
## and comfortably outside the two 0.42 m capsules, so she stops at conversational
## distance rather than shoving the player.
const APPROACH_STOP_DISTANCE := 2.0

## Metres from the wander target at which she counts as arrived.
const ARRIVAL_RADIUS := 0.35

## Seconds spent in each routine state. Ranges, drawn from this pony's own RNG.
const IDLE_SECONDS := Vector2(0.5, 1.5)
const GRAZE_SECONDS := Vector2(1.5, 3.5)
## Safety valve on WANDER: if the target somehow cannot be reached (a rock in the way,
## a leash that keeps steering her off it) she gives up and re-picks rather than
## grinding into an obstacle forever.
const WANDER_TIMEOUT_SECONDS := 6.0

## Chance the next routine state is WANDER rather than GRAZE.
const WANDER_CHANCE := 0.65

## How many times _pick_wander_target() will re-roll to avoid handing back a point she
## is already standing on. A pony near the edge of a small roam circle draws such a
## point often; without the re-roll she would "arrive" the frame she set off and spend
## the whole scene twitching on the spot.
const WANDER_TARGET_ATTEMPTS := 4

## Metres per second per second. Gentler than the player's 12/18 -- nothing about a
## grazing animal should snap to speed the way a controller under a thumb does.
const ACCELERATION := 8.0
const DECELERATION := 12.0

## Exponential turn rate for the visual yaw, 1/seconds. Same treatment as the player's,
## slightly lazier.
const TURN_RESPONSE := 9.0

## Crossfade seconds between locomotion clips, matching player.gd.
const ANIM_BLEND := 0.2

## Downward speed cap, so a long fall cannot accumulate absurd velocity.
const TERMINAL_VELOCITY := 25.0

## Nodes in a group with this name count as "the player" to DetectionArea, in addition
## to anything running player.gd. The group exists so a test scene (or a Phase 2 decoy)
## can stand in for the player without dragging the whole player.tscn -- camera rig and
## all -- into a scene that only needs something for ponies to react to.
const PLAYER_GROUP := &"player"

@export_group("Roaming")
## Metres from her spawn point she is willing to stray. Wander targets are clamped into
## this circle and a flee direction that would leave it is steered along its edge
## instead (see _leash), so a herd stays where the map put it and no pony walks off the
## edge of the world while running away.
@export var roam_radius := 8.0

## Current State. READ ONLY from outside -- transitions go through _transition_to(),
## which resets the state timer and runs the on-enter work for the new state. Assigning
## to it directly would skip both.
var state: int = State.IDLE

@onready var visuals: Node3D = $Visuals
@onready var detection_area: Area3D = $DetectionArea

var _data: PonyData
var _anim: AnimationPlayer
var _rng := RandomNumberGenerator.new()

var _wander_speed := NOMINAL_WANDER_SPEED
var _flee_speed := NOMINAL_FLEE_SPEED

var _home := Vector3.ZERO
var _wander_target := Vector3.ZERO
var _state_timer := 0.0
var _visual_yaw := 0.0
var _held_seconds := 0.0
var _has_wandered := false

## The player-ish body currently inside DetectionArea, or null. Maintained by the area's
## enter/exit signals; every read goes through _sees_player() so a freed node cannot be
## mistaken for a visible one.
var _player: Node3D


func _ready() -> void:
	_visual_yaw = visuals.rotation.y
	_home = global_position

	# One source of truth for the detection radius: the constant this file's logic
	# reasons about, pushed into the shape pony.tscn ships. A scene edit that changed
	# the radius without changing the constant would otherwise be invisible.
	var shape: CollisionShape3D = detection_area.get_node("CollisionShape3D")
	if shape.shape is SphereShape3D:
		# Shapes are shared resources between instances of the same scene; make this
		# one local before writing to it or every pony in the herd shares one radius.
		shape.shape = shape.shape.duplicate()
		(shape.shape as SphereShape3D).radius = DETECTION_AREA_RADIUS

	detection_area.body_entered.connect(_on_detection_body_entered)
	detection_area.body_exited.connect(_on_detection_body_exited)

	if _data != null:
		_apply_data()


## Adopt `data`: build her body through the canonical PonyVisuals path and derive her
## speeds from `base_speed`. Safe to call either before or after this node enters the
## tree -- called early, it records the data and the build happens in _ready().
##
## PLACE HER BEFORE add_child(). _ready() records wherever she is standing at that
## moment as her roaming anchor (see get_home()); a pony added at the origin and moved
## afterwards will spend the rest of her life being leashed back to the origin.
func setup(data: PonyData) -> void:
	_data = data
	if is_node_ready():
		_apply_data()


## Give this pony a seeded RNG so a scene's whole herd is reproducible. Call before the
## pony enters the tree (or at least before its first physics frame); without it she
## gets her own entropy-seeded generator and behaves differently every run.
func set_rng(rng: RandomNumberGenerator) -> void:
	_rng = rng


## The PonyData this pony was set up from, or null if setup() has not been called.
func get_data() -> PonyData:
	return _data


## Her AnimationPlayer, or null if the visuals failed to build. Exposed so scenes and
## tests can assert which clip is playing without re-deriving the node path.
func get_animation_player() -> AnimationPlayer:
	return _anim


## Ground speed right now, in m/s, ignoring vertical motion.
func get_ground_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


## Where she was spawned. Wander targets are drawn around this point, not around
## wherever she has drifted to, so a herd cannot random-walk across the map.
func get_home() -> Vector3:
	return _home


## Human-readable name of a State value, for gate output and error messages.
static func state_name(value: int) -> String:
	return State.keys()[value] if value >= 0 and value < State.size() else "INVALID(%d)" % value


## The state a pony with this `personality` enters when she notices the player, or
## NO_REACTION if she does not react at all. Pure and static: this is the entire rule
## that separates the three personalities, so it is testable on its own without a scene
## tree (game/test/test_pony.gd).
static func reaction_state(personality: int) -> int:
	match personality:
		PonyDataScript.Personality.SHY:
			return State.FLEE
		PonyDataScript.Personality.CURIOUS:
			return State.APPROACH
		_:
			# BOLD, and anything a future roster adds without a reaction of its own.
			return NO_REACTION


## How far away this `personality` notices a player who is (or is not) sneaking, in metres.
## Pure and static, like reaction_state() above and for the same reason: this and that
## function are between them the WHOLE of what a personality means out in the world, so
## they are checkable without a scene tree (game/test/test_pony.gd).
##
## The two axes are deliberately independent. Personality says how jumpy she is; the
## player's gait says how much of a target he is making of himself. Multiplying rather
## than subtracting means the sneak is worth the same FRACTION to everyone -- a flat
## "-6 m" would make the jumpiest pony the one it helped least, which is backwards.
static func notice_radius_for(personality: int, sneaking: bool) -> float:
	var radius := DETECTION_RADIUS
	if personality == PonyDataScript.Personality.SHY:
		radius += SHY_NOTICE_BONUS
	return radius * (SNEAK_NOTICE_FACTOR if sneaking else 1.0)


## Ambling speed for a pony with this `base_speed`, in m/s. Clamped so it always sits
## strictly INSIDE the `walk` clip's band, at both ends: the floor is nudged just above
## Gait.IDLE_SPEED so a very slow pony still reads as walking rather than sliding along
## while the `idle` clip plays, and the ceiling is MAX_WANDER_PLAYBACK rather than the
## top of the band, because the top of the band is exactly where Gait hands over to
## `gallop`. Both boundaries are inclusive on the wrong side otherwise -- clamping to
## Gait.SKATE_FREE_TOP_SPEED made clip_for_speed() answer `gallop` for a wandering pony.
static func wander_speed_for(base_speed: float) -> float:
	var scaled := NOMINAL_WANDER_SPEED * (base_speed / REFERENCE_BASE_SPEED)
	return clampf(scaled, GaitScript.IDLE_SPEED * 1.05,
		MAX_WANDER_PLAYBACK * GaitScript.WALK_CLIP_SPEED)


## Bolting speed for a pony with this `base_speed`, in m/s. Clamped into the `gallop`
## clip's band: the floor is Gait.GALLOP_HANDOVER_SPEED, so fleeing ALWAYS looks like a
## gallop no matter how timid the record says she is, and the ceiling is
## Gait.TOP_SKATE_FREE_SPEED, so it never costs foot skate no matter how fast.
static func flee_speed_for(base_speed: float) -> float:
	var scaled := NOMINAL_FLEE_SPEED * (base_speed / REFERENCE_BASE_SPEED)
	return clampf(scaled, GaitScript.GALLOP_HANDOVER_SPEED, GaitScript.TOP_SKATE_FREE_SPEED)


## The magic beam taking or releasing physics control of this pony. While held she runs
## no steering, no gravity and no move_and_slide -- the beam writes her transform
## directly. Releasing drops her back into her routine (where she will immediately react
## to a player still standing in her detection area).
##
## SILENT ON PURPOSE, in both directions. "The beam let go" is not by itself a capture or
## an escape -- the beam knows which of those just happened and says so with
## notify_captured() / break_free(). See the SIGNALS section of the class comment.
func set_held(is_held: bool) -> void:
	if is_held:
		if state == State.HELD:
			return
		velocity = Vector3.ZERO
		_held_seconds = 0.0
		_transition_to(State.HELD)
		return

	if state != State.HELD:
		return
	_transition_to(State.IDLE)


## How long the current (or most recent) beam hold has lasted, in seconds. Reset to zero
## at the start of each hold. This is the whole of what this pony reports about a hold --
## the beam reads it to run its struggle timer, and what counts as "too long" is the
## beam's number, not hers, because it is a tuning knob for how the beam feels.
func get_held_seconds() -> float:
	return _held_seconds


## The beam telling her the hold ended in a capture. Emits `captured()`; the beam then
## stores her PonyData and frees this node, so this signal is a pony's last word.
## Deliberately does NOT itself release the hold or free anything -- what a capture DOES
## is the beam's business (see magic_beam.gd), this only reports that it happened.
func notify_captured() -> void:
	captured.emit()


## The beam telling her she outlasted its struggle timer: she wins, physics control comes
## back to her, and `escaped()` fires. A no-op if she is not currently held, so a beam
## that has already let go for another reason cannot double-report an escape.
func break_free() -> void:
	if state != State.HELD:
		return
	set_held(false)
	escaped.emit()


func _physics_process(delta: float) -> void:
	if state == State.HELD:
		# Everything below -- gravity, steering, move_and_slide -- is exactly what the
		# beam must not have fighting it, so HELD returns before any of it.
		_state_held(delta)
		return

	_state_timer -= delta
	_react_to_player()

	var desired := Vector3.ZERO
	match state:
		State.IDLE:
			desired = _state_idle()
		State.WANDER:
			desired = _state_wander()
		State.GRAZE:
			desired = _state_graze()
		State.FLEE:
			desired = _state_flee()
		State.APPROACH:
			desired = _state_approach()
		_:
			push_error("Pony '%s': invalid state %d" % [_id(), state])
			_transition_to(State.IDLE)

	if not is_on_floor():
		velocity += get_gravity() * delta
		velocity.y = maxf(velocity.y, -TERMINAL_VELOCITY)

	var rate := ACCELERATION if desired.length_squared() > 0.0 else DECELERATION
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(desired, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	move_and_slide()

	_update_facing(_facing_direction(desired), delta)
	_update_animation(get_ground_speed())


# --- states -----------------------------------------------------------------------
# Each returns the velocity it wants on the ground plane (zero to stand still); the
# common code above handles acceleration, gravity, collision, facing and animation, so
# none of these has to.

## Pause for a beat, then pick the next routine state.
func _state_idle() -> Vector3:
	if _state_timer <= 0.0:
		_transition_to(_pick_routine())
	return Vector3.ZERO


## Walk to the current wander target. Arriving -- or running out of patience -- ends the
## state; the leash keeps the heading inside `roam_radius` on the way.
func _state_wander() -> Vector3:
	var to_target := _wander_target - global_position
	to_target.y = 0.0
	if to_target.length() < ARRIVAL_RADIUS or _state_timer <= 0.0:
		_transition_to(State.IDLE)
		return Vector3.ZERO
	return _leash(to_target.normalized()) * _wander_speed


## Head down, standing still, playing `idle` (which _update_animation picks for her,
## because her ground speed is zero).
func _state_graze() -> Vector3:
	if _state_timer <= 0.0:
		_transition_to(State.IDLE)
	return Vector3.ZERO


## Run directly away from the player for as long as she can see one. Ends the moment the
## player leaves DetectionArea -- which normally happens because she has outrun them.
func _state_flee() -> Vector3:
	if not _sees_player():
		_transition_to(State.IDLE)
		return Vector3.ZERO
	var away := global_position - _player.global_position
	away.y = 0.0
	if away.length_squared() < 0.0001:
		# Standing exactly on the player: any direction is "away", so pick her facing
		# rather than dividing by zero.
		away = -visuals.global_transform.basis.z
		away.y = 0.0
	return _leash(away.normalized()) * _flee_speed


## Walk toward the player and stop APPROACH_STOP_DISTANCE short, watching them. Ends
## when the player leaves DetectionArea.
func _state_approach() -> Vector3:
	if not _sees_player():
		_transition_to(State.IDLE)
		return Vector3.ZERO
	var toward := _player.global_position - global_position
	toward.y = 0.0
	if toward.length() <= APPROACH_STOP_DISTANCE:
		return Vector3.ZERO
	return _leash(toward.normalized()) * _wander_speed


## The beam owns her transform. All this does is count how long the hold has lasted, for
## get_held_seconds() to report. No threshold, no signal, no second capture rule: the one
## that decides what a hold of this length means lives in the beam.
func _state_held(delta: float) -> void:
	_held_seconds += delta


# --- transitions ------------------------------------------------------------------

## A pony in a routine state who can see the player switches to her personality's
## reaction; a pony already reacting stays put until the player is gone (handled by the
## reaction states themselves). BOLD has no reaction state, so this is a no-op for her
## -- there is no `if personality == BOLD` anywhere in this file.
func _react_to_player() -> void:
	if not _is_routine_state(state):
		return
	if not _sees_player():
		return
	var reaction := reaction_state(_personality())
	if reaction != NO_REACTION:
		_transition_to(reaction)


func _transition_to(next: int) -> void:
	state = next
	match state:
		State.IDLE:
			_state_timer = _rng.randf_range(IDLE_SECONDS.x, IDLE_SECONDS.y)
		State.WANDER:
			_state_timer = WANDER_TIMEOUT_SECONDS
			_wander_target = _pick_wander_target()
			_has_wandered = true
		State.GRAZE:
			_state_timer = _rng.randf_range(GRAZE_SECONDS.x, GRAZE_SECONDS.y)
		_:
			# FLEE, APPROACH and HELD end on a condition, not on a clock.
			_state_timer = 0.0


## WANDER or GRAZE. The first routine choice a freshly spawned pony makes is always
## WANDER: a herd dropped onto its spawn markers should walk off them and spread out,
## rather than a third of it standing rooted on the marker for the first few seconds.
func _pick_routine() -> int:
	if not _has_wandered:
		return State.WANDER
	return State.WANDER if _rng.randf() < WANDER_CHANCE else State.GRAZE


## A random point inside her roam circle, drawn around HOME rather than around wherever
## she currently stands -- a step-from-here walk would random-walk the herd across the
## map, and the leash would then be doing all the work of holding it together.
## sqrt() on the radius makes the draw uniform over the disc's AREA; without it every
## target crowds toward the centre and she paces the same short line all day.
func _pick_wander_target() -> Vector3:
	var target := _home
	for attempt in WANDER_TARGET_ATTEMPTS:
		var angle := _rng.randf() * TAU
		var radius := sqrt(_rng.randf()) * roam_radius
		target = _home + Vector3(cos(angle), 0.0, sin(angle)) * radius
		target.y = _home.y
		if Vector2(target.x - global_position.x, target.z - global_position.z).length() > ARRIVAL_RADIUS * 3.0:
			break
	return target


## Keep `direction` from taking her further outside her roam circle. Inside the circle
## it is returned untouched. Outside it, the outward component is removed, so she runs
## along the boundary instead of over it -- and if the direction was straight out, with
## nothing tangential left, she turns straight back toward home. This is what stops a
## fleeing pony from running off the edge of the map: the leash bends her escape into an
## arc around her territory rather than a straight line out of it.
func _leash(direction: Vector3) -> Vector3:
	var from_home := global_position - _home
	from_home.y = 0.0
	var distance := from_home.length()
	if distance <= roam_radius or distance < 0.0001:
		return direction

	var outward := from_home / distance
	var outward_amount := direction.dot(outward)
	if outward_amount <= 0.0:
		return direction

	var tangential := direction - outward * outward_amount
	if tangential.length_squared() < 0.0001:
		return -outward
	return tangential.normalized()


# --- detection --------------------------------------------------------------------

## Anything running player.gd (or a script extending it), or anything in the `player`
## group. Deliberately not a node-name check against a specific scene -- see
## PLAYER_GROUP. `is` rather than `get_script() ==` so that a future subclass of Player
## still registers as one; an identity comparison would silently stop seeing her.
func _is_player(body: Node) -> bool:
	return body.is_in_group(PLAYER_GROUP) or body is PlayerScript


func _on_detection_body_entered(body: Node3D) -> void:
	if _is_player(body):
		_player = body


func _on_detection_body_exited(body: Node3D) -> void:
	if body == _player:
		_player = null


## Whether she can see a player right now. Re-checks validity every call, so a player
## freed while inside the area cannot leave a dangling reference that the flee/approach
## states would then dereference.
##
## TWO STAGES, AND THE SECOND ONE IS THE GAMEPLAY. DetectionArea answers "is there a player
## within DETECTION_AREA_RADIUS", which is the widest anyone can see and is therefore only
## a broad phase; the real question is whether he is inside THIS pony's notice radius, which
## depends on her personality and on whether he is sneaking, and both of those can change
## between one frame and the next. So the distance is measured here rather than inferred
## from an area enter/exit event.
##
## Everything downstream gets the new behaviour for free, because everything downstream
## already went through this function: _react_to_player() only spooks her if she can see
## him, and FLEE/APPROACH both END the moment she cannot -- so a player who drops to a
## sneak inside a fleeing pony's old radius watches her calm down and go back to grazing,
## which is exactly what the sneak is supposed to feel like.
func _sees_player() -> bool:
	if _player == null or not is_instance_valid(_player):
		_player = null
		return false
	var radius := notice_radius_for(_personality(), _player_is_sneaking())
	return global_position.distance_to(_player.global_position) <= radius


## Whether the body in her detection area is moving quietly. Asked of the body through
## has_method() rather than by type: PLAYER_GROUP exists precisely so a test stand-in (or
## a Phase 2 decoy) can be a player to a pony without being a Player, and such a thing has
## no gait to report. Anything that cannot answer counts as NOT sneaking, which is the
## conservative reading -- the fallback is the shorter-sighted pony, never the blinder one.
func _player_is_sneaking() -> bool:
	return _player.has_method("is_sneaking") and _player.is_sneaking()


static func _is_routine_state(value: int) -> bool:
	return value == State.IDLE or value == State.WANDER or value == State.GRAZE


# --- presentation -----------------------------------------------------------------

## Which way to point the model. Normally her direction of travel; a CURIOUS pony who
## has stopped short faces the player instead, which is the whole point of her stopping.
func _facing_direction(desired: Vector3) -> Vector3:
	if desired.length_squared() > 0.0:
		return desired
	if state == State.APPROACH and _sees_player():
		var toward := _player.global_position - global_position
		toward.y = 0.0
		return toward
	return Vector3.ZERO


## Yaw the model toward `direction`, keeping her last heading when there is none. Only
## the `Visuals` child turns, never the body: the capsule is rotationally symmetric
## about Y so rotating the body would change nothing about collision, and DetectionArea
## is a sphere for the same reason -- exactly the split player.gd documents.
func _update_facing(direction: Vector3, delta: float) -> void:
	if direction.length_squared() > 0.0:
		# The asset's forward is -Z (baked in by export_blend.py --rotate-z 180), same
		# convention player.gd relies on.
		_visual_yaw = atan2(-direction.x, -direction.z)
	var weight := 1.0 - exp(-TURN_RESPONSE * delta)
	visuals.rotation.y = lerp_angle(visuals.rotation.y, _visual_yaw, weight)


## Pick `idle`/`walk`/`gallop` and scale playback to her ground speed. Both decisions
## belong to Gait; this must not grow an if-ladder over speed constants of its own.
func _update_animation(speed: float) -> void:
	if _anim == null:
		return
	var clip := GaitScript.clip_for_speed(speed)
	_play(clip)
	_anim.speed_scale = GaitScript.playback_scale_for_clip(clip, speed)


## play() only when the clip actually changes -- calling it every frame would restart
## the crossfade continuously and the blend would never finish.
func _play(clip: StringName) -> void:
	if _anim == null or _anim.current_animation == clip:
		return
	if not _anim.has_animation(clip):
		push_error("Pony '%s' has no '%s' animation" % [_id(), clip])
		return
	_anim.play(clip, ANIM_BLEND)


# --- setup ------------------------------------------------------------------------

## Build her body and derive her speeds. A build failure is loud but not fatal: an
## invisible pony that still wanders is a better headless-test and debugging experience
## than a crash, and PonyVisuals already push_errors the specific reason.
func _apply_data() -> void:
	_wander_speed = wander_speed_for(_data.base_speed)
	_flee_speed = flee_speed_for(_data.base_speed)

	var body: Node3D = PonyVisualsScript.build(_data)
	if body == null:
		push_error("Pony: PonyVisuals.build failed for '%s'" % _id())
		return

	visuals.add_child(body)
	_anim = body.get_node_or_null(PonyVisualsScript.ANIMATION_PLAYER_PATH)
	if _anim == null:
		# build() refuses to return an instance without one, so this is unreachable
		# unless that contract changes -- assert it rather than assume it.
		push_error("Pony: no AnimationPlayer at %s" % PonyVisualsScript.ANIMATION_PLAYER_PATH)
		return
	_play(&"idle")


func _personality() -> int:
	return _data.personality if _data != null else PonyDataScript.Personality.BOLD


func _id() -> String:
	return String(_data.id) if _data != null else "<no data>"
