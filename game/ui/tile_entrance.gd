extends RefCounted
## THE TILES DEAL THEMSELVES IN (PS10, G6; FS6.1: "tiles stagger in 30 ms apart"). A tile menu
## opening used to fade its whole panel as one sheet; now tile i starts its own scale-and-fade
## STAGGER * i seconds after the first, so the grid arrives one card after another, the way
## a dealer lays a hand.
##
## A CLOCK, NOT A TWEEN PER TILE. The menus rebuild every tile on each cursor move (see
## market_menu.gd's refresh()), so a tween would die with the tile it was animating; the clock
## outlives them, and apply() puts any freshly built tile exactly where the schedule says it
## should be. A cursor move after the deal is over finds the clock finished and every tile in.
## advance() is also how the suite steps it, deterministically. Preload by path.

const STAGGER := 0.03
const SECONDS := 0.16
const FROM_SCALE := 0.86

var _clock := INF


## Deal again from the top: on opening, and on a new tab.
func restart() -> void:
	_clock = 0.0


func running(count: int) -> bool:
	return _clock < delay(maxi(0, count - 1)) + SECONDS


## When tile `index` starts, in seconds after the first.
static func delay(index: int) -> float:
	return STAGGER * index


## How far tile `index` is in, 0 to 1.
func amount(index: int) -> float:
	return clampf((_clock - delay(index)) / SECONDS, 0.0, 1.0)


## Step the clock and put every tile where it should be. Returns whether it is still dealing.
func advance(dt: float, tiles: Array) -> bool:
	_clock += dt
	apply(tiles)
	return running(tiles.size())


func apply(tiles: Array) -> void:
	for i in tiles.size():
		var tile := tiles[i] as Control
		if tile == null:
			continue
		var f := amount(i)
		tile.pivot_offset = tile.size * 0.5
		tile.modulate.a = ease(f, 0.6)
		# A touch past full size and back, so each card lands rather than appears.
		var s := lerpf(FROM_SCALE, 1.0, f) + sin(f * PI) * 0.04
		tile.scale = Vector2.ONE * (1.0 if f >= 1.0 else s)
