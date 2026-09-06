class_name Gait
extends RefCounted
## The one runtime home for "how fast does a locomotion clip actually think the pony is
## moving, which clip should be playing at this ground speed, and how do I keep her
## hooves on the ground when she moves at some other speed". Static-only helper, never
## instantiated -- preload it by path rather than relying on the `class_name` global,
## following the same convention as PonyRig and PonyVisuals (the global class cache
## lives in the gitignored game/.godot/ and a fresh clone has not built it yet).
##
## THE SPEED LADDER, at a glance. Two authored locomotion clips, each played through a
## bounded playback window, arranged so the windows meet EXACTLY rather than overlap or
## leave a gap -- so every speed from a standstill to 4.79 m/s has one clip that can
## depict it honestly, and clip_for_speed() is the only thing that has to choose:
##
##   0.00 - 0.33 m/s   `idle`    (1.0x; she is not really going anywhere)
##   0.33 - 1.98 m/s   `walk`    (0.5x - 3.0x of a 0.66 m/s clip)
##   1.98 - 4.79 m/s   `gallop`  (0.6x - 1.45x of a 3.30 m/s clip)
##
## The handover at 1.98 is exact, not approximate: MAX_PLAYBACK * WALK_CLIP_SPEED and
## GALLOP_MIN_PLAYBACK * GALLOP_CLIP_SPEED are the same number, so the character never
## passes through a speed neither clip can depict. Everything in that whole range has
## skate_ratio() == 1.0. Only above 4.79 m/s does anything skate. (The ceiling was 4.29 m/s
## -- 1.3x -- until slice R3 retuned GALLOP_MAX_PLAYBACK; see that constant's own comment.)
##
## WHY THIS FILE EXISTS. The clip's implied ground speed is derived from four
## authoring constants that live in tools/author_anims.py and were, until now,
## re-derived by hand in every consumer scene. docs/pipeline.md section 6 calls this
## out explicitly ("FOUR values are duplicated, not one") and names the frame rate as
## the sneaky one, because author_anims.py reads it from the source .blend's
## `bpy.context.scene.render.fps` while every GDScript copy hardcodes 24. Task 4 needs
## the same number, and Task 6's wild ponies will need it again, so it gets a single
## named home here instead of a fifth hand-copied derivation.
##
## KEEPING IT HONEST. These constants are still not automatically synchronised with
## tools/author_anims.py -- nothing in the engine can read a Python module. The export
## prints `WALK_IMPLIED_SPEED <n> m/s` and `GALLOP_IMPLIED_SPEED <n> m/s` lines on
## every run; if WALK_CLIP_SPEED or GALLOP_CLIP_SPEED below disagrees with them, THIS
## FILE is the one that is wrong, and the only visible symptom is foot skate (every
## structural gate still passes). Compare them if you ever retune a stride, a cycle
## length, a stance fraction, or the source .blend's frame rate. game/test/test_gait.gd
## pins both numbers to what the exporter printed, which is the closest thing to an
## automatic check that is available across the language boundary.
##
## Remaining duplicate of the same derivation, deliberately left alone: TRAVEL_SPEED in
## game/scenes/test/hair_lag_test.gd. (walk_test.gd's own copy was migrated onto this
## file by the gallop task; hair_lag_test.gd is off-limits to it.)

## Metres of ground a hoof travels backwards, relative to the body, over one stance.
## Mirrors STRIDE in tools/author_anims.py. Metric since Phase 1A task 1.
const WALK_STRIDE := 0.275

## Length of the authored walk cycle. WALK_FPS must match the source .blend's
## scene.render.fps -- see the class comment.
const WALK_FRAMES := 20.0
const WALK_FPS := 24.0
const WALK_CYCLE_SECONDS := WALK_FRAMES / WALK_FPS

## A hoof is planted for half of the cycle and covers WALK_STRIDE during that stance,
## so the body has to cover WALK_STRIDE in HALF a cycle, not a whole one. Dividing by
## the full cycle understates the clip's speed by exactly 2x -- the mistake that
## produced the original "mincing shuffle" tuning.
const STANCE_FRACTION := 0.5

## Ground speed the `walk` clip depicts, at playback speed 1.0: 0.66 m/s.
## This is a SLOW AMBLE, and it is a property of the authored cycle rather than of the
## stride: the rig's front leg chain sits at 98.8% extension at rest, so the stride
## physically cannot lengthen. Re-authoring the CYCLE is the way out, and `gallop`
## below is exactly that -- same 0.275 m stride, one sixth of the stance.
const WALK_CLIP_SPEED := WALK_STRIDE / (WALK_CYCLE_SECONDS * STANCE_FRACTION)

## Playback-rate window we are willing to drive the single `walk` clip through.
##
## Below MIN_PLAYBACK the leg cycle is so slow it reads as a stall, and the character
## is barely moving anyway -- so IDLE_SPEED (the speed at which MIN_PLAYBACK would be
## requested) is also exactly where callers should switch to the `idle` clip. That
## makes the walk band continuous: the clip is never played slower than 0.5x, and
## never faster than MAX_PLAYBACK.
##
## Above MAX_PLAYBACK the 0.833 s cycle drops under ~0.28 s and the legs stop reading
## as a gait and start reading as a vibration. 3.0x is the empirical ceiling chosen in
## Task 4; anything faster than SKATE_FREE_TOP_SPEED is bought with foot skate.
const MIN_PLAYBACK := 0.5
const MAX_PLAYBACK := 3.0

## Speed below which callers should play `idle` instead of `walk` (0.33 m/s).
const IDLE_SPEED := MIN_PLAYBACK * WALK_CLIP_SPEED

## Fastest ground speed the WALK clip can honestly depict, i.e. with the hooves exactly
## planted (1.98 m/s). This is also exactly where `gallop` takes over, so it is not a
## ceiling on honest movement any more -- see GALLOP_HANDOVER_SPEED, which is defined
## to equal it, and TOP_SKATE_FREE_SPEED, which is the real ceiling.
const SKATE_FREE_TOP_SPEED := MAX_PLAYBACK * WALK_CLIP_SPEED

# --- `gallop` -----------------------------------------------------------------------
# Authored by build_gallop() in tools/author_anims.py as a transverse gallop on the left
# lead: four separate beats (right-hind, left-hind, right-fore, left-fore) and two
# airborne phases, i.e. a genuinely different gait, not the walk played fast. Which
# matters here because the numbers below are NOT the walk's numbers scaled -- the stride
# is identical and the STANCE is what changed.

## Metres a hind or fore hoof travels backwards, relative to the body, over one stance.
## Mirrors GALLOP_STRIDE in tools/author_anims.py -- and deliberately equal to
## WALK_STRIDE: the rig's front leg chain has no room for a longer reach, so the gallop
## buys its speed entirely from the cycle. See that file's GALLOP_* comment block.
const GALLOP_STRIDE := 0.275

## Length of the authored gallop cycle: 12 frames at 24 fps = 0.5 s, a 2 Hz stride rate.
## GALLOP_FPS must match the source .blend's scene.render.fps, same trap as WALK_FPS.
const GALLOP_FRAMES := 12.0
const GALLOP_FPS := 24.0
const GALLOP_CYCLE_SECONDS := GALLOP_FRAMES / GALLOP_FPS

## Each hoof is planted for two of the twelve frames. That is the whole trick: one sixth
## of a cycle rather than the walk's one half, over the same ground, is 5x the speed.
const GALLOP_STANCE_FRACTION := 1.0 / 6.0

## Ground speed the `gallop` clip depicts, at playback speed 1.0: 3.30 m/s.
## Exactly 5x WALK_CLIP_SPEED, for the reason above.
const GALLOP_CLIP_SPEED := GALLOP_STRIDE / (GALLOP_CYCLE_SECONDS * GALLOP_STANCE_FRACTION)

## Playback window for `gallop`, much narrower than the walk's on purpose.
##
## The floor is set BY the walk band rather than chosen: 0.6 x 3.30 == 1.98 m/s ==
## SKATE_FREE_TOP_SPEED, so the two bands meet exactly and nothing has to skate through
## a gap between them. (0.6x of a 0.5 s cycle is a 0.83 s cycle, which reads as an easy
## canter -- a plausible thing for the clip to become at the bottom of its range.)
##
## The ceiling was 1.3x because a 0.5 s gallop cycle driven past ~2.6 Hz stops reading as
## hooves and starts reading as a blur, the same failure MAX_PLAYBACK guards for the walk.
##
## RETUNED TO 1.45 IN SLICE R3, AND THE TRADE IS WRITTEN DOWN RATHER THAN HIDDEN. Running
## became the DEFAULT travel speed in Phase 3, so the 21% of foot skate RUN_SPEED (5.2 m/s)
## was buying against a 4.29 m/s ceiling stopped being something the player saw while a
## button was held and became what she sees all the time -- and slice R3's hoofstep rework
## put a sound on every cycle of the clip, which is exactly what makes a foot/ground
## mismatch audible rather than merely visible. 1.45 lifts the ceiling to 4.79 m/s and the
## skate at RUN_SPEED from 1.21 to 1.087, comfortably inside Gait.skate_ratio()'s "not
## perceptible in motion" band instead of at the top of it, at the cost of a 2.9 Hz stride
## rate against the ~2.6 Hz caution above. Deliberately NOT taken all the way to the 1.576
## that would zero the skate: that is 3.15 Hz, a fifth past the blur threshold, and buying
## the last 9% of skate with it is a bad trade. The honest fix for the whole band remains a
## faster authored gallop cycle (tools/author_anims.py), which is an animation task.
const GALLOP_MIN_PLAYBACK := 0.6
const GALLOP_MAX_PLAYBACK := 1.45

## Speed at or above which callers should play `gallop` instead of `walk` (1.98 m/s).
## Named separately from SKATE_FREE_TOP_SPEED even though they are equal, because they
## are different facts that happen to coincide by construction -- one is "the walk clip
## runs out of honesty here", the other is "hand over to the gallop here" -- and a
## future retune of either band must break the equality loudly rather than silently
## re-point the handover. test_gait.gd asserts they are still the same number.
const GALLOP_HANDOVER_SPEED := GALLOP_MIN_PLAYBACK * GALLOP_CLIP_SPEED

## Fastest ground speed ANY authored clip can depict with the hooves exactly planted:
## 4.79 m/s (4.29 until slice R3's retune, see GALLOP_MAX_PLAYBACK above). This is the
## number a map or a chase should be designed against. Beyond it the gallop clip
## saturates and skate_ratio() starts climbing again.
const TOP_SKATE_FREE_SPEED := GALLOP_MAX_PLAYBACK * GALLOP_CLIP_SPEED


## Which locomotion clip honestly depicts `speed`. The single place the ladder at the
## top of this file is encoded -- callers must not re-derive it from the constants, or
## the next clip added here will need finding in every one of them.
static func clip_for_speed(speed: float) -> StringName:
	var s := absf(speed)
	if s < IDLE_SPEED:
		return &"idle"
	if s < GALLOP_HANDOVER_SPEED:
		return &"walk"
	return &"gallop"


## Ground speed the named clip depicts at playback 1.0. Zero for `idle`, which depicts
## a pony standing still and so cannot be scaled to a ground speed at all.
static func clip_speed(clip: StringName) -> float:
	match clip:
		&"walk":
			return WALK_CLIP_SPEED
		&"gallop":
			return GALLOP_CLIP_SPEED
		_:
			return 0.0


## AnimationPlayer.speed_scale to use for `walk` at the given ground speed, so the
## gait matches the ground instead of skating across it.
static func playback_scale_for_speed(speed: float) -> float:
	return clampf(absf(speed) / WALK_CLIP_SPEED, MIN_PLAYBACK, MAX_PLAYBACK)


## AnimationPlayer.speed_scale to use for `gallop` at the given ground speed.
static func gallop_playback_scale_for_speed(speed: float) -> float:
	return clampf(absf(speed) / GALLOP_CLIP_SPEED, GALLOP_MIN_PLAYBACK, GALLOP_MAX_PLAYBACK)


## AnimationPlayer.speed_scale for whichever clip is playing. `idle` depicts no ground
## motion, so it always plays at its authored rate.
static func playback_scale_for_clip(clip: StringName, speed: float) -> float:
	match clip:
		&"walk":
			return playback_scale_for_speed(speed)
		&"gallop":
			return gallop_playback_scale_for_speed(speed)
		_:
			return 1.0


## How badly the hooves skate at `speed`: the ratio of actual ground speed to the
## ground speed the chosen clip depicts at the playback rate we would choose for it.
##   1.0        -- hooves exactly planted, no skate at all
##   up to ~1.25 -- not perceptible in motion
##   up to ~1.5 -- visible if you look for it
##   2.0+       -- unmistakable moonwalking
## Returns 1.0 for a stationary character (nothing to skate). Below IDLE_SPEED this
## still reports against the walk clip -- that band is where `idle` plays, so there are
## no planted hooves travelling anywhere and the number is informational only.
static func skate_ratio(speed: float) -> float:
	var s := absf(speed)
	if s <= 0.0:
		return 1.0
	if s >= GALLOP_HANDOVER_SPEED:
		return s / (gallop_playback_scale_for_speed(s) * GALLOP_CLIP_SPEED)
	return s / (playback_scale_for_speed(s) * WALK_CLIP_SPEED)
