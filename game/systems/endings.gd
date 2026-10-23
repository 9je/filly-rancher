class_name Endings
extends RefCounted
## WHICH ENDING (STORY.md section 6). A pure function of the path and the tallies counted
## after the reveal, so the whole table is one unit test and the climax scripts never
## decide anything themselves.
##
## `s` is a Dictionary:
##   path       "factory" or "rescue" (anything else: no ending yet)
##   climax     true once the lever has been pulled (Jubilee or Lights Out)
##   placed     true when the Rescue path's Heat held at 100 through a collection day
##   rescued    ponies sent down the Lantern Line or Bloomed under Heat
##   delivered  ponies delivered AFTER the reveal
##   allies     how many of Pip, Bramble, Fennel joined (0..3)
##   clover     true if Clover was brought home

const BRIGHTEST_RAINBOW := &"brightest_rainbow"
const GRAY_GOLD := &"gray_gold"
const LIGHTS_OUT := &"lights_out"
const HALF_LIGHT := &"half_light"
const PLACEMENT := &"placement"
const NONE := &""

const ALL: Array[StringName] = [BRIGHTEST_RAINBOW, GRAY_GOLD, LIGHTS_OUT, HALF_LIGHT, PLACEMENT]

## Factory path: rescued at or above this is the mixed ending.
const GRAY_GOLD_RESCUES := 5
## Rescue path: this many (net of post-reveal deliveries) for the good ending.
const LIGHTS_OUT_RESCUES := 20

const TITLES := {
	BRIGHTEST_RAINBOW: "The Brightest Rainbow",
	GRAY_GOLD: "Gray Gold",
	LIGHTS_OUT: "Lights Out",
	HALF_LIGHT: "Half Light",
	PLACEMENT: "Placement",
}


static func select(s: Dictionary) -> StringName:
	var path := str(s.get("path", ""))
	if path == "rescue" and bool(s.get("placed", false)):
		return PLACEMENT
	if not bool(s.get("climax", false)):
		return NONE
	var rescued: int = int(s.get("rescued", 0))
	match path:
		"factory":
			return GRAY_GOLD if rescued >= GRAY_GOLD_RESCUES else BRIGHTEST_RAINBOW
		"rescue":
			# Each pony delivered after the reveal undoes one rescue in this count: the
			# player can always cave for money, and the game remembers (STORY.md section 6).
			var net := rescued - int(s.get("delivered", 0))
			if net >= LIGHTS_OUT_RESCUES and int(s.get("allies", 0)) >= 3 and bool(s.get("clover", false)):
				return LIGHTS_OUT
			return HALF_LIGHT
	return NONE


static func title(ending: StringName) -> String:
	return str(TITLES.get(ending, ""))


## The ending's music context (game/systems/music.gd) and its final grade: the rainbow
## endings stay in dread, the free ones get the real sunrise.
static func tone(ending: StringName) -> Dictionary:
	match ending:
		BRIGHTEST_RAINBOW:
			return {"music": &"ending_sad", "dread": 0.85, "free": false}
		GRAY_GOLD:
			return {"music": &"ending_sad", "dread": 0.65, "free": false}
		LIGHTS_OUT:
			return {"music": &"ending_hope", "dread": 0.0, "free": true}
		HALF_LIGHT:
			return {"music": &"ending_hope", "dread": 0.25, "free": true}
		PLACEMENT:
			return {"music": &"ending_sad", "dread": 1.0, "free": false}
	return {"music": &"day", "dread": 0.0, "free": false}
