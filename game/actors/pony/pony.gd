class_name Pony
extends CharacterBody3D
## A wild pony: the thing that makes the world feel inhabited. Wanders, grazes, and
## reacts to the player according to its PonyData `personality`, and can be taken over
## by the magic beam (Task 8) via set_held().
##
## Interface other tasks depend on -- do not rename:
##   setup(data: PonyData)   -- build the body and adopt the record's stats/personality.
##   adopt(inst: PonyInstance) -- the same, for an INDIVIDUAL out of storage or a pen.
##   get_instance()          -- the individual she is, or null while she is still wild.
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
##   LEAVING  her spawn conditions stopped holding: she leaves at her flee speed, off
##            her leash, and frees herself once she is out of the detection area. See
##            leave() for why that is not a death.
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
##            easiest to HOLD   -- she freezes; MagicBeam grades her EASY, a 1.0 s window
##   CURIOUS  in between, and walks TOWARD you; graded MEDIUM, a 0.5 s window
##   BOLD     trivial to REACH  -- no reaction at all, walk right up to her
##            hardest to HOLD   -- graded HARD: a 0.35 s window, and she is the only grade
##            that can tear out of the beam BEFORE it secures her (see `beam_holds` below)
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

const BodySpaceScript := preload("res://systems/body_space.gd")
## Landing faster than this (m/s) bounces her hindquarters, as it does the player's.
const LAND_BOUNCE_FROM := 3.0
const PonyTraitsScript := preload("res://systems/pony_traits.gd")
const PonyLodScript := preload("res://actors/pony/pony_lod.gd")
const GaitScript := preload("res://systems/gait.gd")
const LayersScript := preload("res://world/collision_layers.gd")
const NeedsScript := preload("res://systems/needs.gd")
const PonyDataScript := preload("res://systems/pony_data.gd")
const PonyVisualsScript := preload("res://actors/pony/pony_visuals.gd")
const PlayerScript := preload("res://actors/player/player.gd")
const StockPaletteScript := preload("res://systems/stock_palette.gd")
const StockTintScript := preload("res://systems/stock_tint.gd")
const PonyLookScript := preload("res://systems/pony_look.gd")
const PonyPaintScript := preload("res://systems/pony_paint.gd")
const DonorTableScript := preload("res://systems/donor_table.gd")
const ToonStylerScript := preload("res://systems/toon_styler.gd")

## Emitted when a beam hold has become a capture -- i.e. when the beam calls
## notify_captured(), immediately before it stores her record and frees this node.
signal captured()
## Emitted when a held pony breaks free -- i.e. when the beam calls break_free() because
## she outlasted its struggle timer.
signal escaped()
## Emitted the FIRST time this pony can see the player and never again, however far he
## wanders off and comes back. "The player got a good look at her" is the compendium's
## SEEN, and SEEN only ever happens once per character (game/systems/compendium.gd), so a
## signal that re-fired every time she noticed him again would be a signal whose every
## emission after the first one is thrown away by its only listener. The flag behind it is
## never reset; see _noticed.
signal noticed_player()

enum State { IDLE, WANDER, GRAZE, FLEE, APPROACH, HELD, LEAVING }

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
## clamped by flee_speed_for()'s own FLEE_TOP_SPEED (4.29 m/s, pinned for capture balance,
## not for what the gallop clip can depict), so pushing difficulty through it would saturate
## there and leave a chase that closes at 0.91 m/s -- which is not "difficult", it is "long".
##
## PS9 (playtest 2026-11-05 item 69, "Catching is too easy"): 16.5 m in all (was 14). The
## plan said a quarter further, 17.5; it stops at 16.5 because the sneak must still beat
## the beam (half of 16.5 is 8.25, inside MagicBeam.REACH's 8.5; test_magic_beam). Only SHY
## reacts by running, so only she sees further; a CURIOUS pony still walks over from 12 m.
const SHY_NOTICE_BONUS := 4.5

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
## clamps to FLEE_TOP_SPEED (4.29 m/s), THIS FILE'S OWN CONSTANT, not Gait's. That clamp is
## what makes the player's 5.20 m/s run strictly faster than ANY wild pony can flee,
## whatever a roster edit puts in `base_speed`: a SHY Rainbow Dash (base_speed 6.5, which
## scales to 5.36 m/s) is pinned back to 4.29 and is therefore still catchable. Before the
## first playtest retune the player's gallop was 4.0 m/s and that same pony would have been
## 7% FASTER than the player and literally uncatchable in a straight line. She is BOLD on
## today's roster, so nobody ever hit it -- it was a landmine waiting for a personality
## edit, not a live bug.
const NOMINAL_FLEE_SPEED := GaitScript.GALLOP_CLIP_SPEED

## THE CEILING flee_speed_for() CLAMPS TO -- PINNED HERE, NOT READ OFF GAIT (final review
## F3, controller ruling). This used to be Gait.TOP_SKATE_FREE_SPEED directly, which slice
## R3's animation retune (GALLOP_MAX_PLAYBACK 1.3 -> 1.45) silently carried from 4.29 to
## 4.785: three roster ponies clamp here (soarin 6.0, spitfire 6.2, lightningdust 6.3) and
## would have started bolting 12% faster with no design decision behind it. CAPTURE BALANCE
## IS GAMEPLAY, NOT ANIMATION, so this does not track the clip's playback ceiling even
## though the two happened to be equal before this slice -- a future retune of how fast the
## legs are allowed to blur must not silently move how fast a pony can outrun the player.
const FLEE_TOP_SPEED := 4.29

## How close a CURIOUS pony comes before stopping to watch, in metres. Comfortably
## inside her own notice radius even when the player is sneaking (6.0 m -- she would
## otherwise walk out of her own eyesight mid-approach and forget what she was doing)
## and comfortably outside the two 0.42 m capsules, so she stops at conversational
## distance rather than shoving the player.
const APPROACH_STOP_DISTANCE := 2.0

## Metres from the wander target at which she counts as arrived.
const ARRIVAL_RADIUS := 0.35

## Seconds spent in each routine state. Ranges, drawn from this pony's own RNG.
## A HERD MOSTLY GRAZES. At 0.5-1.5 s idles, 1.5-3.5 s grazes and a 65% wander chance she was
## on the move about half the time, a field of ponies that never settled; now it is about a
## quarter, which reads as a herd at pasture (and halves what a crowd costs a physics tick:
## the 60-pony check's over-budget frames were its walkers, scenes/test/perf.gd exp=freeze).
const IDLE_SECONDS := Vector2(1.0, 2.5)
const GRAZE_SECONDS := Vector2(4.0, 9.0)
## Safety valve on WANDER: if the target somehow cannot be reached (a rock in the way,
## a leash that keeps steering her off it) she gives up and re-picks rather than
## grinding into an obstacle forever.
const WANDER_TIMEOUT_SECONDS := 6.0

## Chance the next routine state is WANDER rather than GRAZE.
const WANDER_CHANCE := 0.5

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

## How far from the player a LEAVING pony has to get before she may free herself, in
## metres. DELIBERATELY EQUAL TO DETECTION_AREA_RADIUS, which is DETECTION_RADIUS plus
## SHY_NOTICE_BONUS and therefore the widest anybody on the roster can see: at exactly
## this distance the DetectionArea drops the player, _leave_distance() starts answering
## INF, and she goes. One number, one meaning, and it is the game's own definition of out
## of sight rather than a second opinion about it.
##
## AN EARLIER 16.0 WAS UNREACHABLE and is the reason this is written down. It sat 2 m
## outside the area that reports the player at all, so the distance test could never see a
## value between 14 and 16: the player vanished from her at 14 m and the INF branch fired
## anyway. It was a promise the code could not keep, which is worse than a smaller promise
## it can.
const LEAVE_DISTANCE := DETECTION_AREA_RADIUS

## Safety ceiling on a departure, in seconds. NOT the ordinary way a departure ends: at
## flee speed she clears LEAVE_DISTANCE in a few seconds from anywhere on the map, so this
## only fires for a pony who cannot get away at all (wedged against a fence, walled into a
## pen's corner by terrain). Forty five seconds is long enough that it never pre-empts a
## real walk and short enough that a stuck pony is not standing there for the rest of the
## session.
const LEAVE_SECONDS := 45.0

## How near a delivered pony has to get to the crate before the walk is over. Wider than a
## pony is long, so an arrival is not a race between her steering and the frame rate.
const LEAVE_ARRIVAL_RADIUS := 1.2

## Width of the band, in metres, over which the leash takes hold -- see _leash(), which
## is where the reasoning lives. Derived from `roam_radius` rather than fixed, because a
## penned pony's territory is about 2 m across and a wild one's is 8 m, and a band sized
## for one is either useless or most of the other. Clamped at both ends: the floor keeps
## it wide enough to be a ramp rather than a step for the smallest territory anyone might
## author, and the ceiling stops a big territory from spending metres of itself braking.
const LEASH_BAND_FRACTION := 0.15
const LEASH_BAND_MIN := 0.25
const LEASH_BAND_MAX := 0.80

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

## HOW MANY TIMES THE BEAM HAS HAD HOLD OF HER, counted for her whole life as a node.
##
## Owned here rather than in a dictionary inside the beam for one blunt reason: it dies
## when she does. A per-pony counter kept on the grabber would have to be swept for freed
## nodes, and the sweep is the bug. It is a plain public var rather than a setter pair
## because it carries no rule of its own -- the rule that reads it is
## MagicBeam.wrench_chance_for(), which is where "one place decides what a hold means"
## still lives.
##
## WHAT IT IS FOR: a HARD pony (a BOLD one -- see the grading note above) has a chance to
## tear out of the beam before it can secure her, and that chance falls off with every
## previous grab until it reaches zero. She tires. This is the count that makes "she will
## eventually let you catch her" a guarantee instead of a hope, so a gate that needs a hold
## which CANNOT wrench sets this past MagicBeam.WRENCH_GRACE_HOLDS rather than reaching for
## a test-only bypass.
##
## Deliberately NOT part of PonyInstance and NOT saved: it is fatigue inside one encounter,
## not a fact about who she is. A pony let out of the bag comes back as a fresh node and
## fights the beam like she did the first time.
var beam_holds := 0

@onready var visuals: Node3D = $Visuals
@onready var detection_area: Area3D = $DetectionArea

var _data: PonyData
## Her palette triple if she is one of the crowd, or {} if she is a named character.
## `{"coat": int, "mane": int, "eyes": int}`, indices into game/data/stock_palette.tres.
##
## ON THE BODY AS WELL AS ON THE RECORD. A WILD stock pony has no PonyInstance at all (an
## individual identity is a thing a pony acquires by being caught), so the only place her
## look can live before she is caught is here; MagicBeam copies it onto the instance it
## mints (see _settle_pony). A penned pony comes the other way, through adopt().
var _stock: Dictionary = {}
## Set only for a pony who has been OWNED -- see adopt() / get_instance(). Null for a wild
## pony the spawner put on the map, which is every pony until the beam catches one.
var _instance: PonyInstance
var _anim: AnimationPlayer
var _rng := RandomNumberGenerator.new()

## Seconds spent in LEAVING so far, and the direction chosen when she set off. Both are
## only ever read or written while `state == State.LEAVING` (see _state_leaving), so a
## capture that lands mid departure cannot leave a half finished walk running underneath
## the beam.
var _leave_elapsed := 0.0
var _leave_direction := Vector3.ZERO

## Where she is walking TO, and whether there is anywhere in particular. An ordinary
## departure has no target: she walks away from the player and is discarded once she is out
## of his sight (see _state_leaving). A DELIVERY has one: the Depot crate. Same state, same
## walk, same single place in this project where a pony is ever freed. The Depot does not
## get a second way to remove a pony, because there must not be one.
var _leave_target := Vector3.ZERO
var _has_leave_target := false

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

## Whether noticed_player has already been emitted for this body. NEVER RESET, not when he
## leaves her detection area and not when she is beamed and set back down: this is a latch,
## and the thing it latches (the player has laid eyes on this character) does not become
## untrue later.
var _noticed := false

# --- detail tiers (performance) -----------------------------------------------------
## How much of her runs, from how far the camera is. FULL near the camera (everything,
## every tick); MID past DETAIL_MID_AT (moves on every second tick, no mane or tail spring,
## the small parts cast no shadow); FAR past DETAIL_FAR_AT or off screen past
## DETAIL_OFFSCREEN_AT (every fourth tick, no shadow). Past FULL her animation is advanced
## by hand on the ticks she runs. A held
## pony is always FULL. Headless runs never leave FULL, so no test or gate sees a tier.
enum Detail { FULL, MID, FAR }
const DETAIL_MID_AT := 12.0
const DETAIL_FAR_AT := 40.0
const DETAIL_OFFSCREEN_AT := 12.0
const DETAIL_CHECK_SECONDS := 0.3
## A FAR pony nobody can see thinks and moves on every 24th tick (2.5 times a second): how
## often an unseen pony takes her steps cannot be seen, and most of a herd is behind the
## camera at any moment. The 60-pony check's ticks were the frames over budget, and her
## share of them is a quarter of what it was. She is checked every DETAIL_CHECK_SECONDS
## like anypony, so turning to look at her gives her back her steps within a third of a second.
const OFFSCREEN_STRIDE := 24
var _offscreen := false
## Meshes too small to see a shadow from (by name): never cast one.
const NO_SHADOW_PARTS: Array[String] = ["tongue", "eyebrow", "hooves", "teeth"]
var detail: int = Detail.FULL
var _detail_timer := 0.0
var _tick_count := 0
## How long she has been wandering into a wall. See _physics_process.
var _wall_time := 0.0
const WALL_GIVE_UP_SECONDS := 0.75
var _tick_accum := 0.0
var _stood_still := false
static var _headless := -1
## The ground's height at (x, z), set by the ranch (Terrain.height_at): FAR ponies walk on it
## without a collision solve.
static var ground_height: Callable


func _enter_tree() -> void:
	BodySpaceScript.join(self)


func _exit_tree() -> void:
	BodySpaceScript.leave(self)


## Her footprint for BodySpace: none while the beam holds her or she is out of sight.
func body_footprint() -> Dictionary:
	if state == State.HELD or collision_layer == 0:
		return {}
	return BodySpaceScript.default_footprint(self, 1.0)


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


## Give her a stock pony's look. Call BEFORE add_child, the same rule setup() states, or
## call it afterwards and the tint is applied to the body she already has.
func set_stock(triple: Dictionary) -> void:
	_stock = triple.duplicate()
	if is_node_ready():
		_apply_stock_tint()
		_apply_traits()


func get_stock() -> Dictionary:
	return _stock.duplicate()


func is_stock() -> bool:
	return not _stock.is_empty()


## Recolour the built body from _stock. A no op for a named character and for a body that
## failed to build, both of which are ordinary states rather than errors.
func _apply_stock_tint() -> void:
	if visuals.get_child_count() == 0:
		return
	var body: Node3D = visuals.get_child(0)
	if _stock.is_empty():
		# A named record (the legacy roster, the hidden records with no look): still the
		# show's shading, just her own colors.
		ToonStylerScript.style(body, &"pony", {})
		ToonStylerScript.cross_eyes(body, _data.id if _data != null else &"")
		return
	var look := look()
	PonyPaintScript.apply(body, look)
	visuals.scale = Vector3.ONE * PonyPaintScript.body_scale(look)


## Her look as a PonyLook (a v2 record, or a legacy palette triple converted).
func look() -> PonyLook:
	return PonyLookScript.from_stock(_stock)


## Which donor body her look is built on, or "" for a named record (her own model).
## READ BEFORE THE BODY IS BUILT, which is why set_stock() must be called before add_child.
func _base_model_path() -> String:
	if _stock.is_empty():
		return ""
	return DonorTableScript.model_path(look().donor)


func adopt(instance: PonyInstance) -> void:
	_instance = instance
	if instance == null:
		return
	# Her look comes back with her record, so a pony stood up out of a pen after a reload is
	# the same pony the player put in it rather than a stranger with the same uid.
	if not instance.stock.is_empty():
		_stock = instance.stock.duplicate()
	setup(instance.data())


## The individual this pony IS, or null if she is an unowned wild pony who has never been
## caught. Wild ponies deliberately have no instance until the beam mints one for them:
## an individual identity is a thing you acquire by being caught, and minting one for every
## pony the spawner drops on the map would burn uids on ponies nobody will ever own.
func get_instance() -> PonyInstance:
	return _instance


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
## clip's band: the floor makes fleeing ALWAYS look like a gallop no matter how timid the
## record says she is, and the ceiling is this file's own FLEE_TOP_SPEED (4.29 m/s), so it
## never costs foot skate no matter how fast.
##
## The floor is Gait.GALLOP_HANDOVER_SPEED PLUS FIVE PER CENT, for exactly the reason
## wander_speed_for() above sits five per cent over Gait.IDLE_SPEED: the boundary is
## inclusive on the wrong side. clip_for_speed() answers `walk` for anything strictly
## below the handover, so a floor set AT the handover asks the most timid pony on the
## roster to flee at precisely the speed where the walk band ends, and any frame whose
## realized speed lands a hair short of that request reads as `walk`. Five per cent of
## headroom puts the request inside the gallop band instead of balanced on its edge.
##
## THAT INCLUSIVE BOUNDARY IS THE WHOLE OF WHAT THIS FLOOR FIXES, and it is worth being
## exact about the case it does NOT fix, because the two look alike from the outside. This
## clamp is applied to the REQUEST; _state_flee() then multiplies the result by _leash(),
## so damping happens downstream of the clamp and no floor here can raise a pony the leash
## has slowed. A pony asking for 2.72 m/s and running at 1.98 because she was spooked at
## the edge of a two metre territory is that case, and the fix for it is to give her a
## territory big enough to run in, not a bigger number here: see ROAM_RADIUS in
## game/scenes/test/wild_ponies.gd. The floor below only binds at all under base_speed
## 2.52, which no character on the current roster has.
static func flee_speed_for(base_speed: float) -> float:
	var scaled := NOMINAL_FLEE_SPEED * (base_speed / REFERENCE_BASE_SPEED)
	return clampf(scaled, GaitScript.GALLOP_HANDOVER_SPEED * 1.05, FLEE_TOP_SPEED)


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
		# Lifted, she neither leans nor carries her last stride into the drop (FS4.2 review).
		_gait_blend.reset()
		visuals.rotation.z = 0.0
		_transition_to(State.HELD)
		return

	if state != State.HELD:
		return
	# The beam wrote her transform without move_and_slide, so is_on_floor() still reads the
	# ground she was lifted off. Left alone, the resting shortcut in _physics_process takes
	# that stale floor at its word and she hangs in the air where the beam let go (owner
	# playtest 2026-10-25, "i beamed this pony and they just flew"). Not resting, and already
	# falling, the next tick's move_and_slide finds the real floor.
	_stood_still = false
	velocity = Vector3(0.0, -1.0, 0.0)
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


## Her spawn conditions stopped holding, so she walks off the map. Returns whether she is
## now leaving: false only if the beam has hold of her.
##
## NO PONY EVER DIES. This is the one place a pony's body is discarded outside the capture
## path, and it is discarded, never killed: the thing that goes away is a WILD, UNOWNED
## CharacterBody3D that the spawner drew a moment ago out of a data record which is still
## sitting on disk. Nothing owned is reachable from here. An owned pony is a PonyInstance
## in GameState.ponies, in a pen's resident list or in the bag, and none of those three is
## touched by anything in this file. She has gone home for the night, and the spawner will
## draw her again at an hour she keeps.
##
## AND SHE IS NEVER FREED IN FRONT OF THE PLAYER UNLESS SHE CANNOT GET AWAY AT ALL. The
## free happens in _state_leaving(), and only once she is further away than the widest
## notice radius on the roster (see LEAVE_DISTANCE). LEAVE_SECONDS is the other way out of
## that state and the reason for the "unless": a pony walled in, or followed step for step,
## would otherwise walk forever, so the timer frees her where she stands. Everything the
## player can do about it is on the player's side of the bargain.
##
## REFUSED WHILE HELD, because the beam is writing her transform and owns what happens to
## her next; a hold that turns into a capture must be allowed to finish as a capture. The
## other half of that race is handled by _state_leaving() reading the timer only while she
## is still in LEAVING: the beam's set_held(true) takes her out of LEAVING, so the walk
## stops the moment she is grabbed, and set_held(false) drops her back into IDLE rather
## than back into the departure.
func leave() -> bool:
	if state == State.HELD:
		return false
	if state == State.LEAVING:
		return true
	_has_leave_target = false
	_leave_elapsed = 0.0
	_leave_direction = _away_from_player()
	_transition_to(State.LEAVING)
	return true


## THE DELIVERY WALK. She sets off for `point` and frees herself when she gets there,
## through exactly the same LEAVING state a runaway uses, so there is still only one way a
## pony leaves the world.
##
## REFUSED WHILE HELD, like leave(), and for the same reason: capture wins. THE RETURN
## VALUE IS LOAD BEARING, and game/world/ranch.gd's deliver_pony() is why: the Depot pays
## for a pony only after this answers true, so a refusal here costs the player nothing and
## leaves her record, her pen and her credit exactly where they were.
##
## AND FROM HERE ON THE BEAM WILL NOT TAKE HER: is_being_delivered() answers true for the
## whole of this walk and game/actors/player/magic_beam.gd's _is_grabbable() declines a pony
## it answers true for. That is a REFUSAL TO GRAB, not a pony removed. She keeps walking,
## nothing frees her but her own arrival, and it is the one place capture does not win,
## because she has already been paid for: a beam that could take her back off the walk would
## hand the player the credit AND the pony.
##
## Re-targeting a pony who is ALREADY leaving is allowed and restarts her timer, so a crate
## that moves (it does not, today) or a second delivery order cannot strand her.
func leave_toward(point: Vector3) -> bool:
	if state == State.HELD:
		return false
	_leave_target = point
	_has_leave_target = true
	_leave_elapsed = 0.0
	_leave_direction = _toward_target()
	if state != State.LEAVING:
		_transition_to(State.LEAVING)
	return true


## Whether she is on her way off the map. False for every pony the player can still catch
## in the ordinary way, which is every pony whose conditions still hold.
func is_leaving() -> bool:
	return state == State.LEAVING


## IS SHE ON A WALK SOMEBODY SENT HER ON, rather than one she chose? True only while she is
## LEAVING toward a point handed to her by leave_toward(), which today means exactly one
## thing: she has been delivered and is walking to the Depot crate.
##
## THE BEAM ASKS THIS BEFORE IT GRABS (magic_beam.gd, _is_grabbable). An ordinary departure
## answers false and stays catchable to the last step, which is the rule everywhere else in
## the game; a delivered pony answers true and is declined, because the Company has already
## paid for her. Nothing here removes anybody: a declined grab is a beam that does not
## start.
func is_being_delivered() -> bool:
	return state == State.LEAVING and _has_leave_target


var _rescue_check := 0.5


func _physics_process(delta: float) -> void:
	if state == State.HELD:
		# Everything below -- gravity, steering, move_and_slide -- is exactly what the
		# beam must not have fighting it, so HELD returns before any of it.
		if detail != Detail.FULL:
			_set_detail(Detail.FULL)
		_state_held(delta)
		return
	# Never trapped in a building (PT2): checked twice a second, see Building.rescue_body.
	_rescue_check -= delta
	if _rescue_check <= 0.0:
		_rescue_check = 0.5
		Building.rescue_body(self)

	# DETAIL TIERS (see _update_detail): a pony far from the camera thinks, moves and
	# animates on every third or sixth tick, carrying the skipped time with her.
	_detail_timer -= delta
	if _detail_timer <= 0.0:
		# The GLOBAL generator, never hers: her own (_rng) is seeded by the spawner and the tests
		# for a reproducible wander, and a draw here would shift every target after it.
		_detail_timer = DETAIL_CHECK_SECONDS + randf() * 0.1
		_update_detail()
		_update_mood()
		if detail == Detail.FULL:
			_update_gaze_target()
	var stride := 1
	if detail != Detail.FULL:
		stride = 3 if detail == Detail.MID else (OFFSCREEN_STRIDE if _offscreen else 6)
		# Standing grazing or idle out there, all she does is breathe and crop the grass: the
		# slow idle reads the same at 10 steps a second, and most of a settled herd is standing.
		if stride == 3 and _stood_still and (state == State.IDLE or state == State.GRAZE):
			stride = 6
		_tick_accum += delta
		_tick_count += 1
		if _tick_count < stride:
			return
		_tick_count = 0
		delta = _tick_accum
		_tick_accum = 0.0
		if _anim != null:
			_anim.advance(delta)

	_state_timer -= delta
	calm = maxf(0.0, calm - delta)
	_wary = maxf(0.0, _wary - delta)
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
		State.LEAVING:
			desired = _state_leaving(delta)
			# _state_leaving() is the one state function that can end this pony, and
			# everything below (gravity, move_and_slide, the animation blend) would be
			# work done on a node already queued for deletion.
			if is_queued_for_deletion():
				return
		_:
			push_error("Pony '%s': invalid state %d" % [_id(), state])
			_transition_to(State.IDLE)

	if not is_on_floor():
		velocity += get_gravity() * delta
		velocity.y = maxf(velocity.y, -TERMINAL_VELOCITY)

	# NOT INTO ANOTHER BODY (PT4): the part of where she wants to go that points into a pony
	# she already touches is dropped, so she slides along her or stops rather than walking
	# through her faster than the two can ease apart.
	# And not up to one she is about to touch (PS1 item 17b): the step toward a body within
	# BodySpace.CLEARANCE is dropped too, so a walker turns aside rather than nosing in.
	var touching := BodySpaceScript.push_on(self) + BodySpaceScript.aside_on(self)
	if touching != Vector3.ZERO and desired != Vector3.ZERO:
		var out_of := touching.normalized()
		var into := desired.dot(-out_of)
		if into > 0.0:
			desired += out_of * into
	# Held from turning (_update_facing), she does not walk off backwards or sideways: she
	# waits for the room to turn, which the push gives her.
	if _turn_held and desired != Vector3.ZERO:
		var facing := -visuals.global_transform.basis.z
		facing.y = 0.0
		if facing.normalized().dot(desired.normalized()) < 0.0:
			desired = Vector3.ZERO
	var rate := ACCELERATION if desired.length_squared() > 0.0 else DECELERATION
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(desired, rate * delta)
	# The speed she already carries is trimmed the same way: easing toward a trimmed wish
	# still walked her in at her old speed for half a second.
	if touching != Vector3.ZERO:
		var out_of := touching.normalized()
		var carried := horizontal.dot(-out_of)
		if carried > 0.0:
			horizontal += out_of * carried
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	# STANDING STILL ON THE GROUND COSTS NOTHING. move_and_slide is most of a pony's tick
	# (about 47 of 67 us measured, game/scenes/test/perf.gd), and a grazing herd is mostly
	# standing: with no wish to move, no speed and a floor already under her, there is
	# nothing for it to resolve.
	# ROOM FOR HER BODY (PT4): her collider is a post under a long body, so her nose and rump
	# would pass through other ponies; overlapping footprints slide apart (systems/body_space.gd).
	var room := BodySpaceScript.push_on(self)
	var resting := desired == Vector3.ZERO and velocity.length_squared() < 0.0001 \
		and is_on_floor() and _stood_still and room == Vector3.ZERO
	velocity += room
	# DROPPED FROM A HEIGHT, SHE BOUNCES (PT11; playtest 2026-11-05: "i was dropping twilight from
	# the beam i thought it would do it from that height"): the player's own landing rule
	# (Player.LAND_BOUNCE_FROM), on her.
	var was_airborne := not is_on_floor()
	var fall_speed := -velocity.y
	if not resting:
		# (A collision-free glide for FAR ponies was tried and dropped: it walked them through
		# trunks and standing stones, which the ranch's own gate rightly refuses.)
		if stride > 1:
			# move_and_slide steps by the physics tick, not by `delta`: scale her velocity
			# for the ticks she skipped, then hand back the velocity she would have had.
			velocity *= float(stride)
			move_and_slide()
			velocity /= float(stride)
		else:
			move_and_slide()
	velocity -= room
	if was_airborne and is_on_floor() and fall_speed > LAND_BOUNCE_FROM:
		RumpBounce.kick_on(visuals, clampf(fall_speed / 7.0, 0.3, 1.2))
	_stood_still = desired == Vector3.ZERO and velocity.length_squared() < 0.0001 and is_on_floor()
	# A WANDERER WHO WALKS INTO A WALL STOPS WALKING INTO IT. She has nowhere to be, and a pony
	# pressed against a coop or a barn grinds move_and_slide through its full recovery every
	# tick: one such pony cost the 60-pony check as much as twenty grazing ones (900 us a
	# slide against the coop, scenes/test/perf.gd exp=timing). She stands, then picks again.
	if state == State.WANDER and is_on_wall():
		_wall_time += delta
		if _wall_time > WALL_GIVE_UP_SECONDS:
			_transition_to(State.IDLE)
	else:
		_wall_time = 0.0
	# Fleeing and getting nowhere (her leash or a wall has her): see _settle_wary.
	if state == State.FLEE:
		_fled += delta
	if state == State.FLEE and get_ground_speed() < _flee_speed * 0.35:
		_pinned += delta
		if _pinned > PINNED_SECONDS and _fled > WARY_MIN_FLEE:
			_settle_wary()
	else:
		_pinned = 0.0

	_update_facing(_facing_direction(desired), delta)
	_update_animation(get_ground_speed(), delta)


func _update_detail() -> void:
	if _headless < 0:
		_headless = 1 if DisplayServer.get_name() == "headless" else 0
	var want: int = Detail.FULL
	var cam := get_viewport().get_camera_3d() if _headless == 0 and is_inside_tree() else null
	if cam != null:
		var d := cam.global_position.distance_to(global_position)
		# Two metres of hysteresis either side of each line, so a pony standing on one does not
		# flicker between tiers as the camera breathes.
		var slack := 2.0 if detail == Detail.FULL else -2.0
		var slack_far := 2.0 if detail != Detail.FAR else -2.0
		var seen := cam.is_position_in_frustum(global_position)
		_offscreen = not seen and d > DETAIL_OFFSCREEN_AT
		if d > DETAIL_FAR_AT + slack_far or _offscreen:
			want = Detail.FAR
		elif d > DETAIL_MID_AT + slack:
			want = Detail.MID
	if want != detail:
		_set_detail(want)


func _set_detail(want: int) -> void:
	detail = want
	# A RANDOM PHASE IN HER STRIDE, so a crowd that changes tier together (the camera turned)
	# does not then think, move and animate all on the same tick: the 60-pony check showed a
	# spike every sixth tick until this was staggered.
	_tick_count = randi() % OFFSCREEN_STRIDE
	_tick_accum = 0.0
	if visuals == null:
		return
	var meshes := _detail_meshes()
	for m in _springs_cache:
		if is_instance_valid(m):
			m.active = detail == Detail.FULL
			if m is PonyFace and detail != Detail.FULL:
				(m as PonyFace).settle()
	for mi: MeshInstance3D in meshes:
		if not is_instance_valid(mi):
			continue
		var small := false
		for part in NO_SHADOW_PARTS:
			if part in String(mi.name).to_lower():
				small = true
		var cast := detail == Detail.FULL and not small
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_outline(detail == Detail.FULL)
	# Far off, nopony needs to notice the player: her 14 m detection sphere stops being
	# re-queried against the broadphase every time she takes a step.
	if detection_area != null:
		detection_area.set_deferred("monitoring", detail != Detail.FAR)
	if _anim != null:
		# Past FULL her skeleton moves only on the ticks she thinks on (30 or 15 a second):
		# every pose costs a skin update on each of her meshes.
		_anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL \
			if detail != Detail.FULL else AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE


## Past FULL the toon outline (a second pass per surface, a thread at that size) goes off.
## The pass is DROPPED, not just collapsed: each surface wears a copy of its material without
## the next_pass, because a collapsed pass still costs its draw call, and a herd of 60 spent
## 22 to 38 draws a pony on lines nobody could see (scenes/test/perf.gd exp=parts). Her
## teeth and tongue, shut inside her mouth, are not drawn at all out there.
## `outline_on` is still set, for a material somebody hands her while she is far; and a
## surface whose material was changed by somebody else meanwhile keeps theirs on the way back.
func _outline(on: bool) -> void:
	for mi: MeshInstance3D in _detail_meshes():
		if not is_instance_valid(mi):
			continue
		mi.set_instance_shader_parameter(&"outline_on", 1.0 if on else 0.0)
		var lower := String(mi.name).to_lower()
		if "tongue" in lower or "teeth" in lower:
			mi.visible = on
	ToonStylerScript.wear_outline(_detail_meshes(), on, _worn_bare)


## Surfaces wearing an outline-free twin now (ToonStyler.wear_outline keeps it).
var _worn_bare: Dictionary = {}


var _meshes_cache: Array[MeshInstance3D] = []
var _springs_cache: Array[SkeletonModifier3D] = []


func _detail_meshes() -> Array[MeshInstance3D]:
	if _meshes_cache.is_empty() and visuals != null:
		for m in visuals.find_children("*", "MeshInstance3D", true, false):
			_meshes_cache.append(m as MeshInstance3D)
		# Hair springs, her face and her hoof planter all rest when she is far (FS3.1).
		for m in visuals.find_children("*", "SkeletonModifier3D", true, false):
			_springs_cache.append(m as SkeletonModifier3D)
	return _meshes_cache


## HER FACE FOLLOWS HER STATE (FS3.1): scared when she runs or is held in the beam, content
## otherwise. The face is PonyVisuals' "Face" modifier on her skeleton.
var _face_node: PonyFace


func _face_ref() -> PonyFace:
	if (_face_node == null or not is_instance_valid(_face_node)) and visuals != null:
		var found := visuals.find_children("Face", "", true, false)
		_face_node = found[0] as PonyFace if not found.is_empty() else null
	return _face_node


## Her eyes on the player when he is close and she is calm (FS3.2); on nobody otherwise.
const GAZE_RADIUS := 6.0


func _update_gaze_target() -> void:
	var face := _face_ref()
	if face == null:
		return
	var calm := state == State.IDLE or state == State.GRAZE or state == State.WANDER or state == State.APPROACH
	if calm and _player != null and is_instance_valid(_player) \
			and (is_coy() or _player.global_position.distance_to(global_position) < GAZE_RADIUS):
		face.gaze_at = _player.global_position + Vector3(0, 1.2, 0)
	else:
		face.gaze_at = Vector3.INF


## Within this many metres a calm pony who has noticed the player gives her the coy look.
const COY_RADIUS := 16.0


func _update_mood() -> void:
	_show_hunger(looks_hungry())
	var face := _face_ref()
	if face == null:
		return
	var was := face.mood
	match state:
		State.FLEE, State.HELD:
			face.mood = PonyFace.Mood.SCARED
		State.GRAZE, State.IDLE, State.APPROACH:
			face.mood = PonyFace.Mood.HAPPY if is_in_group(&"penned") else PonyFace.Mood.NEUTRAL
			if _coy_at_player():
				face.mood = PonyFace.Mood.COY
		_:
			face.mood = PonyFace.Mood.NEUTRAL
	# Hungry in her pen, she looks it (PS9 item 64; FS3.1's missing part). Not over a fright.
	if state != State.FLEE and state != State.HELD and looks_hungry():
		face.mood = PonyFace.Mood.SAD
	# A resting face (Detail past FULL) is told once, rather than left where it stopped.
	if face.mood != was and not face.active:
		face.settle()


## THE HUNGER BUBBLE (PS9 item 64): her face alone said too little from across a pen (renders,
## 2026-11-07), so a hungry resident wears a cream bubble with a hay bale in it, the same
## shape as a townspony's news bubble, gone the moment she is fed.
static var _hunger_tex: ImageTexture
var _hunger_bubble: Node3D


func _show_hunger(on: bool) -> void:
	if not on:
		if _hunger_bubble != null:
			_hunger_bubble.visible = false
		return
	if _hunger_bubble == null:
		_hunger_bubble = _make_hunger_bubble()
		add_child(_hunger_bubble)
	_hunger_bubble.position = Vector3(0.0, 2.45 * absf(visuals.scale.y), 0.0)
	_hunger_bubble.visible = true


func hunger_bubble_shown() -> bool:
	return _hunger_bubble != null and _hunger_bubble.visible


static func _make_hunger_bubble() -> Node3D:
	if _hunger_tex == null:
		var n := 96
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		var cream := Color(1.0, 0.96, 0.86)
		var rim := Color(0.45, 0.25, 0.55)
		var straw := Color(0.96, 0.78, 0.32)
		var band := Color(0.7, 0.5, 0.18)
		var c := Vector2(48, 42)
		for y in n:
			for x in n:
				var p := Vector2(x + 0.5, y + 0.5)
				var d := p.distance_to(c)
				var tail := y > 70 and y < 92 and absf(x - 48.0) < (92.0 - y) * 0.45
				if d < 38.0 or tail:
					img.set_pixel(x, y, cream)
				if (d >= 38.0 and d < 42.0 and y < 74) or (tail and absf(x - 48.0) >= (92.0 - y) * 0.45 - 2.5):
					img.set_pixel(x, y, rim)
				# A hay bale: a straw block with two bands.
				if x >= 26 and x < 70 and y >= 28 and y < 58:
					var edge := x < 28 or x >= 68 or y < 30 or y >= 56
					img.set_pixel(x, y, band if edge or absf(x - 40.0) < 1.5 or absf(x - 56.0) < 1.5 else straw)
		img.generate_mipmaps()
		_hunger_tex = ImageTexture.create_from_image(img)
	var q := MeshInstance3D.new()
	q.name = "HungerBubble"
	var quad := QuadMesh.new()
	quad.size = Vector2(0.6, 0.6)
	q.mesh = quad
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = _hunger_tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	q.material_override = m
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return q


## A resident past Needs.HUNGRY_THRESHOLD: the pantry has nothing for her, or she is about to eat.
func looks_hungry() -> bool:
	if not is_in_group(&"penned"):
		return false
	var inst = get_instance() if has_method("get_instance") else null
	return inst != null and inst.hunger >= NeedsScript.HUNGRY_THRESHOLD


## THE LOOK, ON PURPOSE (PS1, playtest 2026-11-05 item 67: the half-lidded look "switch[ed]
## off as you get close (backwards)"; the owner liked it: "keep them, make them deliberate and
## shared by more ponies"). Any calm pony the player comes within COY_RADIUS of, close up
## included, Drifters and shy ones too, gives her the look for COY_HOLD seconds with her eyes
## on her, then looks away and rests COY_REST seconds before she can give it again: a moment,
## not a face she wears.
const COY_HOLD := 4.0
const COY_REST := Vector2(20.0, 40.0)


static func coy_near(d: float, calm: bool) -> bool:
	return calm and d < COY_RADIUS


## Every pony has it: a Drifter (no PonyData) and a shy one (a shy glance) as well.
static func coy_allowed(_data: PonyData) -> bool:
	return true


## One step of the look for state `st` ({until, rest} in ms): true while she gives it. `roll`
## (0..1) picks the rest that follows.
static func coy_next(st: Dictionary, near: bool, now: int, roll: float) -> bool:
	var until := int(st.get("until", -1))
	if now < until:
		if near:
			return true
		st["until"] = -1
		return false
	if now < int(st.get("rest", -1)):
		return false
	if not near:
		return false
	st["until"] = now + int(COY_HOLD * 1000.0)
	st["rest"] = int(st.until) + int(lerpf(COY_REST.x, COY_REST.y, roll) * 1000.0)
	return true


var _coy := {}


func _coy_at_player() -> bool:
	if _player == null or not is_instance_valid(_player) or not coy_allowed(_data):
		return false
	var calm := state == State.IDLE or state == State.GRAZE or state == State.APPROACH
	return coy_next(_coy, coy_near(_player.global_position.distance_to(global_position), calm),
		Time.get_ticks_msec(), randf())  # the global generator: hers keeps the wander reproducible


## True while she is giving the look (her eyes stay on the player for it, past GAZE_RADIUS).
func is_coy() -> bool:
	return Time.get_ticks_msec() < int(_coy.get("until", -1))


# --- states -----------------------------------------------------------------------
# Each returns the velocity it wants on the ground plane (zero to stand still); the
# common code above handles acceleration, gravity, collision, facing and animation, so
# none of these has to.

## Pause for a beat, then pick the next routine state.
func _state_idle() -> Vector3:
	if _state_timer <= 0.0:
		# The global generator, not hers: her own keeps the wander reproducible.
		if _action == &"" and wants_joy_hop(is_in_group(&"penned"), looks_hungry(), randf()):
			play_action(&"hop")
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
	# NOT THROUGH A CONVERSATION (PS1, playtest 2026-11-05 item 10): with the player talking
	# to somepony across her way, she thinks better of it and stops to pick somewhere else.
	if BodySpaceScript.crosses_zone(global_position, _wander_target):
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
	if _fled > WARY_MIN_FLEE and away.length() > _notice_radius() + 1.0:
		_settle_wary()
		return Vector3.ZERO
	if away.length_squared() < 0.0001:
		# Standing exactly on the player: any direction is "away", so pick her facing
		# rather than dividing by zero.
		away = -visuals.global_transform.basis.z
		away.y = 0.0
	return _leash(_bend_round(away.normalized())) * _flee_speed


## SMARTER FLEEING (PS9, item 69). How far ahead a fleeing pony looks for a tree or a prop,
## the turns she tries to get round one (radians, nearest first), and how far either side
## of her middle she looks, so a trunk that would catch her shoulder counts.
const FLEE_LOOK_AHEAD := 2.5
const FLEE_BENDS := [0.5, 1.0, 1.5]
const FLEE_SHOULDER := 0.35

## Which way she last bent (+1 or -1), so she keeps to one side of an obstacle instead of
## dithering in front of it.
var _bend_side := 1.0


## `away` if the way ahead is clear, else the smallest turn off it that is, on the side she
## last chose first. Straight on when nothing is clear: the pinned rule (_settle_wary) has her.
func _bend_round(away: Vector3) -> Vector3:
	if not is_inside_tree() or not _flee_blocked(away):
		return away
	for turn: float in FLEE_BENDS:
		for side: float in [_bend_side, -_bend_side]:
			var heading := away.rotated(Vector3.UP, turn * side)
			if not _flee_blocked(heading):
				_bend_side = side
				return heading
	return away


func _flee_blocked(heading: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var side := heading.cross(Vector3.UP).normalized() * FLEE_SHOULDER
	for offset: Vector3 in [Vector3.ZERO, side, -side]:
		var from := global_position + Vector3(0.0, 0.6, 0.0) + offset
		var q := PhysicsRayQueryParameters3D.create(from, from + heading * FLEE_LOOK_AHEAD,
			LayersScript.PROPS)
		q.exclude = [get_rid()]
		if not space.intersect_ray(q).is_empty():
			return true
	return false


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
	# Kicking at the air in the Scoop. A body exported before v1 has no such clip and
	# keeps whatever she was playing when the beam took her.
	if _anim != null and _anim.has_animation(&"struggle"):
		_play(&"struggle")
		_anim.speed_scale = 1.0


## Walk away and, once nobody can see it happen, stop existing. See leave() for why this
## is not a death and for the two guards that keep it out of the capture path's way.
##
## THE TIMER IS INSIDE THIS FUNCTION, which _physics_process only reaches while `state ==
## State.LEAVING`, so a pony grabbed mid departure stops counting the moment the beam
## takes her rather than freeing herself out from under it.
##
## WHAT IS GUARANTEED, exactly: she is freed once she is outside her own DetectionArea
## (LEAVE_DISTANCE is that radius, so nobody can be looking at her from inside the notice
## range of any personality), or after LEAVE_SECONDS if she somehow cannot get away at
## all. Those are the only two ways this state ends on its own; the third way it ends is
## the beam taking her, which is a capture and not a departure.
##
## AT HER FLEE SPEED, not her wander speed. She is leaving, and a brisk exit reads as a
## pony with somewhere to be rather than a pony strolling out of existence. It also makes
## the guarantee above cheap: 3.3 m/s clears 14 m in about four seconds, so LEAVE_SECONDS
## is a ceiling nobody normally touches instead of the thing that actually ends most
## departures.
##
## NO LEASH. A leaving pony is the one pony in the game who is supposed to walk out of her
## own territory, so _leash() is deliberately not applied to this heading; the roam circle
## exists to hold a herd in place and she is no longer part of it.
func _state_leaving(delta: float) -> Vector3:
	_leave_elapsed += delta
	if _has_leave_target:
		var gap := Vector2(_leave_target.x - global_position.x,
			_leave_target.z - global_position.z).length()
		# The timer is still the ceiling: a pony who cannot reach the crate (a prop in the
		# way, a stuck step) is not left walking into a wall forever.
		if gap <= LEAVE_ARRIVAL_RADIUS or _leave_elapsed >= LEAVE_SECONDS:
			queue_free()
			return Vector3.ZERO
		_leave_direction = _toward_target()
		return _leave_direction * _flee_speed
	if _leave_distance() > LEAVE_DISTANCE or _leave_elapsed >= LEAVE_SECONDS:
		queue_free()
		return Vector3.ZERO
	if _leave_direction.length_squared() < 0.0001:
		_leave_direction = _away_from_player()
	return _leave_direction * _flee_speed


## The flat direction to her destination, or her current heading if she is standing on it.
func _toward_target() -> Vector3:
	var to := _leave_target - global_position
	to.y = 0.0
	if to.length_squared() < 0.0001:
		return _leave_direction if _leave_direction.length_squared() > 0.0001 else Vector3.FORWARD
	return to.normalized()


## How far the player is from her right now, or INF when she cannot see one at all.
##
## INF RATHER THAN ZERO, and it is the ORDINARY way a departure ends rather than an edge
## case: "no player in my detection area" means the nearest player is further off than
## DETECTION_AREA_RADIUS, which is exactly LEAVE_DISTANCE, so the moment she crosses that
## line the area drops him and this answers INF. Reading it as zero would strand every
## departure in a world with no player in it for the full LEAVE_SECONDS.
func _leave_distance() -> float:
	if _player == null or not is_instance_valid(_player):
		return INF
	return global_position.distance_to(_player.global_position)


## The direction she sets off in: straight away from the player if she can see one, else
## straight out from home, else whichever way she is already facing. Never zero length.
func _away_from_player() -> Vector3:
	var away := Vector3.ZERO
	if _player != null and is_instance_valid(_player):
		away = global_position - _player.global_position
	else:
		away = global_position - _home
	away.y = 0.0
	if away.length_squared() < 0.0001:
		away = -visuals.global_transform.basis.z
		away.y = 0.0
	if away.length_squared() < 0.0001:
		return Vector3.FORWARD
	return away.normalized()


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
	# SHE IS HOME. A resident does not bolt from her own farmer: her pen's leash is set for a
	# walk, not a gallop (Pen.roam_radius_for), and a shy pony running laps of a full paddock
	# was half of how eight of them ended up in one heap (playtest 2026-11-05 item 65).
	if reaction == State.FLEE and is_in_group(&"penned"):
		return
	# NOR DOES SHE WALK UP TO THE RAILS (PS1 item 65, [52]): every curious resident of a full
	# pen headed for the edge nearest the farmer and they stood in one heap there, pressed
	# past the leash into the fence. At home she turns where she stands to watch him.
	if reaction == State.APPROACH and is_in_group(&"penned"):
		if state != State.WANDER:
			var toward := _player.global_position - global_position
			_visual_yaw = atan2(-toward.x, -toward.z)
		return
	# Wary (see _settle_wary): she has already run, and she holds her ground watching unless
	# the player comes on at her.
	if reaction == State.FLEE and _wary > 0.0 \
			and global_position.distance_to(_player.global_position) > WARY_BOLT_DISTANCE:
		return
	if reaction != NO_REACTION:
		_transition_to(reaction)


## A SHY PONY WHO HAS GOT AWAY STOPS RUNNING. Flight used to end only when the player left
## her 14 m sphere, and her leash would not let her get that far: stand still near a shy herd
## and half of it ran in place against its boundaries for as long as you stood there (27 of
## 59 in the 60-pony check). Now, WARY_DISTANCE clear or pinned by her leash or a wall, she
## stops and watches you for WARY_SECONDS, and bolts again only if you close on her.
## "Clear" is past the distance she notices you from; and she always runs WARY_MIN_FLEE
## first, so a bolt is a bolt and not a flinch.
const WARY_MIN_FLEE := 1.0
const WARY_BOLT_DISTANCE := 5.0
const WARY_SECONDS := 5.0
const PINNED_SECONDS := 0.6
var _wary := 0.0
var _pinned := 0.0
var _fled := 0.0


func _settle_wary() -> void:
	_wary = WARY_SECONDS
	_pinned = 0.0
	_transition_to(State.IDLE)


func _transition_to(next: int) -> void:
	if next == State.FLEE and state != State.FLEE:
		_fled = 0.0
		_maybe_blink()
	state = next
	_update_mood()
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
			# FLEE, APPROACH, HELD and LEAVING all end on a condition, not on a clock.
			_state_timer = 0.0
	if state == State.IDLE or state == State.GRAZE:
		_face_out_of_the_pen()


## Walk to `point` now (a WANDER with that target): the ranch's pen probe drives residents
## at their fence with it, since a resident never flees in her own pen.
func wander_to(point: Vector3) -> void:
	_transition_to(State.WANDER)
	_wander_target = point


## A resident on the ring who stops turns to face out over the rails, as paddock horses do:
## ring neighbours then stand side by side with a metre of grass between them, not nose to
## rump in a chain round the middle (item 65's acceptance review). Turned smoothly by
## _update_facing; the one in the middle keeps her heading.
func _face_out_of_the_pen() -> void:
	if pen_patch == Vector3.INF:
		return
	var out := Vector3(pen_patch.x - _home.x, 0.0, pen_patch.z - _home.z)
	if out.length() < 0.5:
		return
	_visual_yaw = atan2(-out.x, -out.z)


## A startled unicorn blinks a few metres away (once in a while, never into a wall): she
## is suddenly not where the Scoop was pointing.
func _maybe_blink() -> void:
	if not PonyTraitsScript.blinks(race) or _player == null or not is_inside_tree():
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _blinked_at < 15.0:
		return
	var away := global_position - _player.global_position
	away.y = 0.0
	if away.length_squared() < 0.01:
		return
	var hop := away.normalized() * 4.5
	if test_move(global_transform, hop):
		return
	_blinked_at = now
	global_position += hop + Vector3(0, 0.3, 0)
	# Teleported, so is_on_floor() still reads the ground she left: off the resting shortcut
	# and already falling, or she hangs 0.3 m up where she lands (set_held(false) has the
	# same note).
	_stood_still = false
	velocity.y = -1.0
	if visuals != null:
		visuals.scale = Vector3.ONE * 0.2
		create_tween().tween_property(visuals, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	blinked.emit()


signal blinked


## A HOP FOR JOY (PS1, playtest 2026-11-05 items 19/23: "The rump bounce is barely seen: it
## only fires on a pen flop or a hard landing"). A happy, fed pony in her pen, finishing an
## idle beat, now and then hops instead (`roll` is a 0..1 draw); every hop bounces her rump as
## she lands (play_action). Wild ponies have better things to do; a hungry one does not hop.
const JOY_HOP_CHANCE := 0.05
## Where in the hop clip her hooves meet the ground again, as a fraction of its length.
const HOP_LAND_AT := 0.55


static func wants_joy_hop(penned: bool, hungry: bool, roll: float) -> bool:
	return penned and not hungry and roll < JOY_HOP_CHANCE


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
	if pen_patch != Vector3.INF:
		return _patch_spot()
	var target := _home
	# The last dry pick, kept for when every attempt lands short or wet; else where she stands.
	var dry := Vector3(global_position.x, _home.y, global_position.z)
	for attempt in WANDER_TARGET_ATTEMPTS:
		var angle := _rng.randf() * TAU
		var radius := sqrt(_rng.randf()) * roam_radius
		target = _home + Vector3(cos(angle), 0.0, sin(angle)) * radius
		target.y = _home.y
		# Not a spot in a lake (PS2 item 61): she would only walk to the shore ring and stand.
		if _in_lake(target):
			continue
		dry = target
		if Vector2(target.x - global_position.x, target.z - global_position.z).length() > ARRIVAL_RADIUS * 3.0:
			break
	return dry


## A RESIDENT WANDERS ROUND HER OWN PATCH (playtest item 65, and its acceptance review: "at
## 60 to 75 s the residents are still one clump in the pen's middle"). Every resident's leash
## is anchored at the pen's centre (Pen: the fence arithmetic), and drawing her spots from the
## whole leash circle sent the residents across the pen through each other, where PS1 item
## 17b's turn hold jammed them in one clump in the middle. Her spots are drawn round her patch
## (Pen.resident_spot, about 2 m from the next) inside her leash: of PATCH_CANDIDATES there,
## the one furthest from her penmates and where they are walking to, never one she stands on.
## `pen_patch` is INF for a pony who is not a resident.
var pen_patch := Vector3.INF
const PATCH_WANDER := 0.6
## The shortest walk within her patch (ARRIVAL_RADIUS * 3, the wild pony's, would not fit in it).
const PATCH_MIN_WALK := 0.4
const PATCH_CANDIDATES := 8


func _patch_spot() -> Vector3:
	var others: Array[Vector3] = []
	for n: Node in get_parent().get_children():
		if n != self and n is Pony and (n as Pony).pen_patch != Vector3.INF:
			others.append((n as Node3D).global_position)
			if (n as Pony).state == State.WANDER:
				others.append((n as Pony)._wander_target)
	var best := pen_patch
	var room := -1.0
	for attempt in PATCH_CANDIDATES:
		var angle := _rng.randf() * TAU
		var spot := pen_patch + Vector3(cos(angle), 0.0, sin(angle)) * sqrt(_rng.randf()) * PATCH_WANDER
		if Vector2(spot.x - _home.x, spot.z - _home.z).length() > roam_radius:
			continue
		if Vector2(spot.x - global_position.x, spot.z - global_position.z).length() <= PATCH_MIN_WALK:
			continue
		var nearest := INF
		for o in others:
			nearest = minf(nearest, Vector2(spot.x - o.x, spot.z - o.z).length())
		if nearest > room:
			room = nearest
			best = spot
	return Vector3(best.x, _home.y, best.z)


## Inside a lake's pony keep-out ring (Terrain.build_water: the "lake_water" group and its
## "pony_keep_out" radius; the spawner's own test, Spawner._dry_from).
func _in_lake(p: Vector3) -> bool:
	if not is_inside_tree():
		return false
	for water: Node in get_tree().get_nodes_in_group(&"lake_water"):
		var at := (water as Node3D).global_position
		if Vector2(p.x - at.x, p.z - at.z).length() < float(water.get_meta(&"pony_keep_out", 0.0)):
			return true
	return false


## Keep `direction` from taking her further outside her roam circle: the outward part of
## where she wants to go is faded out as she nears the edge of her territory, removed
## entirely at `roam_radius`, and reversed into a pull home once she is a band past it.
## Whatever was tangential survives untouched and at its own length, so a direction with
## any sideways component to it is bent into an arc around her territory rather than
## reversed out of it. This is what keeps a fleeing pony from running off the map, and
## what keeps a penned one inside her paddock.
##
## THE RETURNED VECTOR IS A STEERING VECTOR, NOT A HEADING: its length is between 0 and 1
## and the callers multiply it by her speed, so shortening it is how she slows down. A
## pony whose entire desire points straight out of her territory gets back a vector near
## zero and simply stops at her boundary.
##
## --- WHY THIS IS A RAMP AND NOT A TEST ------------------------------------------------
##
## This is the fix for the third playtest's "as i type this ponies are standing in place
## spazzing out", and the whole of the bug was that this function used to be
## DISCONTINUOUS -- twice.
##
## It used to do nothing at all inside `roam_radius` and, one centimetre outside it, turn
## a straight-out direction into `-outward`: a 180-degree reversal at full speed between
## one frame and the next. A CURIOUS pony walking toward a player standing outside her
## territory therefore drove at full speed into her own boundary, was flung back inside,
## walked out again, and never stopped. Measured, before the fix, with the player parked
## still: her velocity reversed 25 times in 240 physics frames while she covered a few
## centimetres of ground, and her model whipped back and forth through most of a half-turn
## about three times a second. That is precisely what "standing in place spazzing out"
## looks like. A SHY pony fleeing a player who stood on her home did the same in mirror
## image (30 reversals in 240 frames).
##
## It also used to NORMALIZE the leftover tangential component, which is the second
## discontinuity and the reason the judder was not confined to the exactly-radial case:
## a full-magnitude tangential push that flips sign as the wanted direction sweeps through
## the outward ray makes that ray an attractor she can only oscillate about. Keeping the
## component at its own length instead means the push fades smoothly to nothing as she
## lines up with it, and she settles on it.
##
## So the property to preserve here is CONTINUITY: no hair's-breadth change in where she
## stands, or in where she wants to go, may reverse where this sends her. A `distance >
## roam_radius` test cannot have that property no matter what it returns, which is why the
## radial term is a ramp across a band. game/test/test_pony_leash.gd measures both
## continuities directly and fails on a jump of more than 0.05.
##
## SHE IS ALLOWED TO STOP, and that is a deliberate behaviour choice rather than a
## side-effect. A pony whose only wish is to leave her territory now stands at the edge of
## it -- a curious one watching the player from as close as she is willing to come, a
## fleeing one cornered at the far side of her range -- instead of charging home and back
## forever. Anything with a sideways component to it still arcs, which is the case that
## reads as "she ran around rather than stopping" and is pinned by its own test.
func _leash(direction: Vector3) -> Vector3:
	var from_home := global_position - _home
	from_home.y = 0.0
	var distance := from_home.length()
	var band := _leash_band()
	if distance <= roam_radius - band or distance < 0.0001:
		return direction

	var outward := from_home / distance
	var outward_amount := direction.dot(outward)
	if outward_amount <= 0.0:
		# Already heading inward: the leash has no opinion about that, at any distance.
		return direction

	# 1.0 a full band inside the boundary (outward motion untouched), 0.0 at the boundary
	# (outward motion removed), -1.0 a full band outside it (outward motion reversed into
	# a pull home). Linear in between, so the field is continuous everywhere.
	var allowed := clampf((roam_radius - distance) / band, -1.0, 1.0)
	return direction - outward * (outward_amount * (1.0 - allowed))


## Width of the leash's ramp, in metres, for this pony's territory. See LEASH_BAND_*.
func _leash_band() -> float:
	return clampf(roam_radius * LEASH_BAND_FRACTION, LEASH_BAND_MIN, LEASH_BAND_MAX)


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
## How far off she notices the player as he moves now (her personality, his gait, her quirk).
func _notice_radius() -> float:
	return notice_radius_for(_personality(), _player_is_sneaking()) * PonyTraitsScript.notice_mult(quirk)


func _sees_player() -> bool:
	if _player == null or not is_instance_valid(_player):
		_player = null
		return false
	if calm > 0.0:
		return false
	var radius := _notice_radius()
	var seen := global_position.distance_to(_player.global_position) <= radius
	# ANNOUNCED FROM INSIDE THE PREDICATE, not from _react_to_player(). Every route that
	# asks whether she can see him already comes through here (the class comment on this
	# function says so), so putting the announcement anywhere else would mean one of those
	# routes silently not counting as having been noticed by.
	if seen and not _noticed:
		_noticed = true
		noticed_player.emit()
		_on_noticed_player()
	return seen


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
	if (state == State.APPROACH or (_wary > 0.0 and state == State.IDLE)) and _sees_player():
		# Curious, or wary: either way she keeps her eyes on you.
		var toward := _player.global_position - global_position
		toward.y = 0.0
		return toward
	return Vector3.ZERO


## Yaw the model toward `direction`, keeping her last heading when there is none. Only
## the `Visuals` child turns, never the body: the capsule is rotationally symmetric
## about Y so rotating the body would change nothing about collision, and DetectionArea
## is a sphere for the same reason -- exactly the split player.gd documents.
## Turn her to face `direction` (flat) at once, and keep facing it until she next moves.
func face(direction: Vector3) -> void:
	direction.y = 0.0
	if direction.length_squared() < 1e-6:
		return
	_visual_yaw = atan2(-direction.x, -direction.z)
	visuals.rotation.y = _visual_yaw


## Whether her last turn was held by BodySpace.turn_allowed (a neighbour in the way).
var _turn_held := false


func _update_facing(direction: Vector3, delta: float) -> void:
	if direction.length_squared() > 0.0:
		# The asset's forward is -Z (baked in by export_blend.py --rotate-z 180), same
		# convention player.gd relies on.
		_visual_yaw = atan2(-direction.x, -direction.z)
	var weight := 1.0 - exp(-TURN_RESPONSE * delta)
	var before := visuals.rotation.y
	# Only a pony who is turning has her room weighed (PS11 G11: it was every pony, every tick),
	# and only when somepony stands near enough for a turn to reach her (BodySpace.turn_is_free).
	# Nor for the last of a turn, too small to bring her nose a millimetre nearer anypony
	# (BodySpace.turn_too_small).
	var swing := absf(angle_difference(before, lerp_angle(before, _visual_yaw, weight)))
	var turning := swing > 1e-4 and not BodySpaceScript.turn_too_small(swing, absf(visuals.scale.x)) \
		and BodySpaceScript.has_near(self) and not BodySpaceScript.turn_is_free(self)
	var room_before := body_footprint() if turning else {}
	visuals.rotation.y = lerp_angle(visuals.rotation.y, _visual_yaw, weight)
	# Not into the pony beside her (BodySpace.turn_allowed): she holds her heading and finishes
	# the turn once she has room; her walking is not held, so she can always step away.
	# The short way round blocked, she turns the long way, away from her; held only when both are.
	_turn_held = false
	var step := angle_difference(before, visuals.rotation.y)
	if not room_before.is_empty() and absf(step) > 1e-4 \
			and not BodySpaceScript.turn_allowed(self, room_before, body_footprint()):
		visuals.rotation.y = before - step
		if not BodySpaceScript.turn_allowed(self, room_before, body_footprint()):
			visuals.rotation.y = before
			_turn_held = true
	# Into a sharp turn she banks (FS4.2, systems/gait_blend.gd).
	if delta > 0.0:
		visuals.rotation.z = _gait_blend.lean(angle_difference(before, visuals.rotation.y) / delta,
			get_ground_speed(), delta)


## Pick `idle`/`walk`/`gallop` and scale playback to her ground speed. Both decisions
## belong to Gait; this must not grow an if-ladder over speed constants of its own.
func _update_animation(speed: float, delta := 1.0 / 60.0) -> void:
	if _anim == null or _action != &"":
		return
	# Her legs show a speed that settles down through the trot and the walk when she stops
	# (FS4.2, systems/gait_blend.gd); Gait still names the clip for it.
	speed = _gait_blend.shown_speed(speed, delta)
	var clip := _gait_blend.clip(speed, _anim.has_animation(&"trot"))
	if clip == &"idle":
		clip = _standing_clip()
	_play(clip)
	_anim.speed_scale = GaitScript.playback_scale_for_clip(clip, speed)


const GaitBlendScript := preload("res://systems/gait_blend.gd")
var _gait_blend: GaitBlend = GaitBlendScript.new()


## She has just seen the player for the first time: a startle (FS4.3).
func _on_noticed_player() -> void:
	if state != State.HELD:
		play_action(&"startle")


## A one-shot she is acting out (a Bloom's rear, a startle): locomotion leaves her clip
## alone until it ends. Empty when none.
var _action: StringName = &""


## Play `clip` once over whatever she is doing; false if her body has no such clip.
func play_action(clip: StringName) -> bool:
	if _anim == null or not _anim.has_animation(clip):
		return false
	_action = clip
	_anim.play(clip, 0.15)
	_anim.speed_scale = 1.0
	# Every hop lands rump first (items 19/23): her spring takes the kick as her hooves land.
	if clip == &"hop" and is_inside_tree():
		var land := _anim.get_animation(clip).length * HOP_LAND_AT
		get_tree().create_timer(land, false, true).timeout.connect(func() -> void:
			if is_instance_valid(self) and visuals != null:
				RumpBounce.kick_on(visuals, 0.8))
	if not _anim.animation_finished.is_connected(_on_action_finished):
		_anim.animation_finished.connect(_on_action_finished)
	return true


func _on_action_finished(clip: StringName) -> void:
	if clip == _action:
		_action = &""


## What she does while standing still: grazes in GRAZE, otherwise idles. A body exported
## before the v1 clips (no `graze`) idles either way.
func _standing_clip() -> StringName:
	if state == State.GRAZE and _anim.has_animation(&"graze"):
		return &"graze"
	return &"idle"


## play() only when the clip actually changes -- calling it every frame would restart
## the crossfade continuously and the blend would never finish.
func _play(clip: StringName) -> void:
	if _anim == null or _anim.current_animation == clip:
		return
	if not _anim.has_animation(clip):
		push_error("Pony '%s' has no '%s' animation" % [_id(), clip])
		return
	# A clip played over a one-shot cuts it off, and Godot sends no animation_finished
	# for a cut clip: without this `_action` stays set and locomotion never runs again
	# (a startle cut off by the beam's struggle, review 2026-11-06).
	_action = &""
	_anim.play(clip, ANIM_BLEND)


# --- setup ------------------------------------------------------------------------

## Build her body and derive her speeds. A build failure is loud but not fatal: an
## invisible pony that still wanders is a better headless-test and debugging experience
## than a crash, and PonyVisuals already push_errors the specific reason.
func _apply_data() -> void:
	_wander_speed = wander_speed_for(_data.base_speed)
	_flee_speed = flee_speed_for(_data.base_speed)

	var body: Node3D = PonyVisualsScript.build(_data, _base_model_path())
	if body == null:
		push_error("Pony: PonyVisuals.build failed for '%s'" % _id())
		return

	visuals.add_child(body)
	# Mesh LODs, eyes excluded (actors/pony/pony_lod.gd): a far pony costs a fraction of a
	# near one on the GPU.
	PonyLodScript.apply(body)
	_anim = body.get_node_or_null(PonyVisualsScript.ANIMATION_PLAYER_PATH)
	if _anim == null:
		# build() refuses to return an instance without one, so this is unreachable
		# unless that contract changes -- assert it rather than assume it.
		push_error("Pony: no AnimationPlayer at %s" % PonyVisualsScript.ANIMATION_PLAYER_PATH)
		return
	_play(&"idle")
	_apply_stock_tint()
	_apply_traits()


# --- traits (game/systems/pony_traits.gd) ---------------------------------------------

var quirk: StringName = &""
var race: StringName = &"earth"
## Seconds left of the calm a treat gives (she ignores you and holds easy in the Scoop).
var calm := 0.0
var _blinked_at := -100.0


## What her quirk and race do to her out in the grass: a skittish pony spots you from
## further off, a pegasus flutters away faster than a pony can run.
func _apply_traits() -> void:
	quirk = PonyTraitsScript.quirk_for(_stock, _data.id if _data != null else &"")
	race = StringName(str(_stock.get("race", "earth"))) if not _stock.is_empty() \
		else PonyTraitsScript.canon_race(_data.id if _data != null else &"")
	if _data != null:
		_flee_speed = flee_speed_for(_data.base_speed) * PonyTraitsScript.flee_mult(race)
	if detection_area != null:
		var shape: CollisionShape3D = detection_area.get_node_or_null("CollisionShape3D")
		if shape != null and shape.shape is SphereShape3D:
			(shape.shape as SphereShape3D).radius = DETECTION_AREA_RADIUS * PonyTraitsScript.notice_mult(quirk)


## The personality the Scoop's struggle is rolled for: a skittish or a treat-calmed pony
## gives up like a shy one.
func hold_personality() -> int:
	if calm > 0.0 or PonyTraitsScript.easy_hold(quirk):
		return PonyDataScript.Personality.SHY
	return _personality()


## A treat landed by her: if it is her favorite she trots over and is calm for a while.
func offer_treat(at: Vector3, food: StringName) -> bool:
	if state == State.HELD or state == State.LEAVING:
		return false
	var fav := PonyTraitsScript.favorite_for(_stock, _data)
	if food != fav and _rng.randf() > 0.35:
		return false
	calm = 10.0 if food == fav else 6.0
	_transition_to(State.WANDER)
	# AFTER the transition: entering WANDER picks a random target of its own, which used to
	# overwrite the treat, so a tossed treat sent her strolling anywhere but to it.
	_wander_target = at
	return true


func _personality() -> int:
	return _data.personality if _data != null else PonyDataScript.Personality.BOLD


func _id() -> String:
	return String(_data.id) if _data != null else "<no data>"
