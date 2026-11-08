class_name RareGate
extends RefCounted
## WHO SHOWS UP, AND WHEN (P8; playtest 2026-11-08 items 6, 12; idea C1). The owner had every
## legendary and the debt paid inside one in-game day, an hour in. Rares are now gated three
## ways, and this is the one place the rule lives (the spawner and Tumble's sightings both ask):
##   the hour and the weather   PonyData.phases / weathers (Rainbow Dash after the rain,
##                              Twilight at dusk and night, Rarity on a clear day)
##   what the ranch has built   PonyData.needs_decor (Fluttershy once the flower bushes are
##                              planted, Pinkie for the tetherball, Applejack the apple tree)
##   one new legendary a day    a legendary not yet caught is not drawn on a day (cycle) that
##                              already brought one in (story var LEGEND_DAY)
## The sightings are paced here too: at most SIGHTINGS_PER_DAY a day, SIGHTING_GAP apart.

const LEGEND_DAY := "legend_day"
const SIGHTINGS_PER_DAY := 2
## Play seconds between two sightings, and before the first.
const SIGHTING_FIRST := 13.0 * 60.0
const SIGHTING_GAP := 6.0 * 60.0


## Whether `data` may be drawn now. `decor` is the decoration ids built; `legend_day` the
## cycle a new legendary was last caught on (-1 for never); `cycle` today's; `caught` whether
## the player has caught this character before (a known face is not "new").
static func allowed(data: PonyData, decor: Array, legend_day: int, cycle: int,
		caught: bool = false) -> bool:
	if data == null:
		return false
	if data.needs_decor != &"" and not (data.needs_decor in decor or String(data.needs_decor) in decor):
		return false
	if data.rarity == PonyData.Rarity.LEGENDARY and not caught and legend_day == cycle:
		return false
	return true


## Whether a sighting may fire now: `today` is how many fired this cycle, `last_at` the play
## seconds of the last one (-INF for never), `t` the play seconds now.
static func sighting_due(today: int, last_at: float, t: float) -> bool:
	if t < SIGHTING_FIRST or today >= SIGHTINGS_PER_DAY:
		return false
	return t - last_at >= SIGHTING_GAP
