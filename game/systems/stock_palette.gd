class_name StockPalette
extends Resource
## THE SWATCH ROWS EVERY RECOLOUR IN THE GAME PICKS FROM. One resource class, two
## authored files: game/data/stock_palette.tres is the crowd's palette and
## game/data/player_palette.tres is the wider one the creation screen offers. The
## machinery is identical, which is the point: the player's pony and an unregistered
## stock pony are tinted by exactly the same code (game/systems/stock_tint.gd).
##
## A TRIPLE OF INDICES, NOT THREE COLOURS. What a stock pony carries in her save record
## (PonyInstance.stock) and what the player's look carries (game/systems/player_look.gd)
## are indices into these rows. A colour written into a save would freeze today's palette
## into every old file; an index lets a later authoring pass restyle the whole crowd by
## editing one .tres. The cost is that reordering a row restyles existing ponies, which is
## a trade this project takes knowingly: nothing about a pony's identity lives in her coat.
##
## EVERY LOOKUP WRAPS. coat_at()/mane_at()/eye_at() take posmod of the index, so a hand
## edited save, a shortened row, or an off by one in a menu produces a pony in the wrong
## colour rather than an out of range read. An EMPTY row answers Color.WHITE, so a resource
## that failed to load leaves a white pony standing in the field: visibly wrong, and still
## a pony.

## Where the two shipped palettes live. Committed, unlike game/assets/converted/, so they
## are present on every machine and in every export (docs/ci.md section 4).
const STOCK_PATH := "res://data/stock_palette.tres"
const PLAYER_PATH := "res://data/player_palette.tres"

## The three hidden PonyData records every stock pony is built from, one per personality.
## THREE RECORDS RATHER THAN ONE WITH A PERSONALITY FIELD ON THE INSTANCE, because
## personality is what the capture difficulty and the notice radius are keyed to
## (game/actors/pony/pony.gd, game/actors/player/magic_beam.gd) and both of those read it
## off PonyData. Splitting the record is three small .tres files; threading a per instance
## personality through the beam is a change to the capture code, which this slice has no
## business touching.
const IDS: Array[StringName] = [&"stock_shy", &"stock_bold", &"stock_curious"]

@export var coats: Array[Color] = []
@export var manes: Array[Color] = []
@export var eyes: Array[Color] = []


static func load_stock() -> StockPalette:
	return _load(STOCK_PATH)


static func load_player() -> StockPalette:
	return _load(PLAYER_PATH)


static func _load(path: String) -> StockPalette:
	var res: Resource = load(path)
	if res == null or not (res is StockPalette):
		push_error("StockPalette: '%s' did not load as a StockPalette resource" % path)
		return StockPalette.new()
	return res as StockPalette


## Is `id` one of the three hidden stock records? The one question every caller that has to
## tell a member of the crowd from a collectible asks, in one place.
static func is_stock_id(id: StringName) -> bool:
	return id in IDS


func is_valid() -> bool:
	return not coats.is_empty() and not manes.is_empty() and not eyes.is_empty()


func coat_at(index: int) -> Color:
	return _at(coats, index)


func mane_at(index: int) -> Color:
	return _at(manes, index)


func eye_at(index: int) -> Color:
	return _at(eyes, index)


static func _at(row: Array[Color], index: int) -> Color:
	if row.is_empty():
		return Color.WHITE
	return row[posmod(index, row.size())]


## One pony's whole look, drawn off `rng`. Three numbers pulled in a fixed order, so the
## same seed always produces the same pony and a gate can pin one.
func draw_triple(rng: RandomNumberGenerator) -> Dictionary:
	return {
		"coat": rng.randi_range(0, maxi(0, coats.size() - 1)),
		"mane": rng.randi_range(0, maxi(0, manes.size() - 1)),
		"eyes": rng.randi_range(0, maxi(0, eyes.size() - 1)),
	}
