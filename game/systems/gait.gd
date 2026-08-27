class_name Gait
extends RefCounted
## The one runtime home for "how fast does the `walk` clip actually think the pony is
## moving, and how do I keep her hooves on the ground when she moves at some other
## speed". Static-only helper, never instantiated -- preload it by path rather than
## relying on the `class_name` global, following the same convention as PonyRig and
## PonyVisuals (the global class cache lives in the gitignored game/.godot/ and a
## fresh clone has not built it yet).
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
## prints a `WALK_IMPLIED_SPEED <n> m/s` line on every run; if WALK_CLIP_SPEED below
## disagrees with it, THIS FILE is the one that is wrong, and the only visible symptom
## is foot skate (every structural gate still passes). Compare them if you ever retune
## STRIDE, the cycle length, the stance fraction, or the source .blend's frame rate.
##
## Existing duplicates of the same derivation that a later task should migrate onto
## this file: game/scenes/test/walk_test.gd (WALK_SPEED) and
## game/scenes/test/hair_lag_test.gd (TRAVEL_SPEED). Both were deliberately left
## untouched by Task 4 -- hair work was under adjudication in those files at the time.

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
## This is a SLOW AMBLE and it is a known limitation of the authored gait, not a
## number to design around -- the rig's front leg chain sits at 98.8% extension at
## rest, so the stride physically cannot lengthen without re-authoring the cycle.
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

## Fastest ground speed the clip can honestly depict, i.e. with the hooves exactly
## planted (1.98 m/s). Move faster than this and the hooves skate; skate_ratio()
## quantifies by how much.
const SKATE_FREE_TOP_SPEED := MAX_PLAYBACK * WALK_CLIP_SPEED


## AnimationPlayer.speed_scale to use for `walk` at the given ground speed, so the
## gait matches the ground instead of skating across it.
static func playback_scale_for_speed(speed: float) -> float:
	return clampf(absf(speed) / WALK_CLIP_SPEED, MIN_PLAYBACK, MAX_PLAYBACK)


## How badly the hooves skate at `speed`: the ratio of actual ground speed to the
## ground speed the clip depicts at the playback rate we would choose for it.
##   1.0        -- hooves exactly planted, no skate at all
##   up to ~1.25 -- not perceptible in motion
##   up to ~1.5 -- visible if you look for it
##   2.0+       -- unmistakable moonwalking
## Returns 1.0 for a stationary character (nothing to skate).
static func skate_ratio(speed: float) -> float:
	var s := absf(speed)
	if s <= 0.0:
		return 1.0
	return s / (playback_scale_for_speed(s) * WALK_CLIP_SPEED)
