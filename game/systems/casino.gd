class_name Casino
extends RefCounted
## THE CHIP PURSE, and nothing else. How many chips the player is holding at the Spectra
## Palace, what may be added, what may be taken away, and how that survives quitting.
##
## IT NEVER SEES THE WALLET. Chips are bought and cashed out at the cage by game/world/
## ranch.gd, which is the only file in the project holding an Economy and a Casino at the
## same time; this class cannot spend a bit or grant one, so no bug in here can reach the
## player's money. That is the same split game/ui/depot_menu.gd has from the Ledger, for
## the same reason.
##
## ONE FOR ONE, BOTH WAYS. A bit buys exactly one chip and a chip cashes out for exactly
## one bit; CHIP_RATE exists so that number has a name rather than being an unwritten
## assumption spread over two call sites. The house makes its money at the tables, and the
## edge is printed on the lobby sign (game/systems/casino_sign.gd). The cage takes nothing.
##
## THE CONTRACT IS ECONOMY'S, DELIBERATELY. add_chips() refuses zero or less the way
## Economy.grant() does, remove_chips() refuses what is not there the way Economy.spend()
## does, a refusal changes nothing at all rather than partially, and chips_changed fires
## only when the number actually moved. A reviewer who knows game/systems/economy.gd knows
## this file already.
##
## Preloaded by path everywhere, never by the class_name: the class cache lives in the
## gitignored game/.godot/ and a fresh clone has not built it yet.

## Bits per chip, in both directions.
const CHIP_RATE := 1

## The key inside the save's `casino` dictionary. Named so the writer and the reader cannot
## disagree by a typo.
const KEY_CHIPS := "chips"

## Emitted when `chips` actually changes. Never for a refusal, and never for a move of
## exactly zero: a signal that fires when nothing moved is as useless as one that never
## fires. Carries the NEW total so a menu can bind to it without a second read.
signal chips_changed(new_total: int)

## How many chips the player is holding. Never negative; see _init() and remove_chips().
var chips: int = 0


func _init(starting_chips: int = 0) -> void:
	chips = maxi(0, starting_chips)


## Buy in, or take a win. Refuses zero or less: a buy in of nothing is a caller that thinks
## it paid something and did not, and a negative one is a cash out wearing a buy in's coat.
func add_chips(count: int) -> bool:
	if count <= 0:
		return false
	chips += count
	chips_changed.emit(chips)
	return true


## Cash out, or stake a bet. Returns false HAVING CHANGED NOTHING when the purse cannot
## cover it, so every caller may treat a false as proof the count did not move. A removal
## of exactly zero succeeds and announces nothing, because nothing happened.
func remove_chips(count: int) -> bool:
	if count < 0 or count > chips:
		return false
	if count == 0:
		return true
	chips -= count
	chips_changed.emit(chips)
	return true


## Whether `amount` is a legal stake right now. A bet must be a positive number of chips
## the player actually holds; this is the one question every game asks before it deals.
func can_stake(amount: int) -> bool:
	return amount > 0 and amount <= chips


func to_dict() -> Dictionary:
	return {KEY_CHIPS: chips}


## Rebuild a purse from a to_dict() dictionary, or from what JSON.parse_string hands back,
## which is the same thing with every number as a float.
##
## NOTHING HERE CAN MINT A CHIP. Only an int or a float is read at all; a string, an array,
## a dictionary or a missing key all load as an empty purse, and a negative count clamps to
## zero. A save file is a text file on the player's disk, and the cage is the one place in
## the game where a number typed into it would turn straight into money.
static func from_dict(d: Dictionary) -> Casino:
	var raw: Variant = d.get(KEY_CHIPS, 0)
	var count := 0
	if typeof(raw) == TYPE_INT or typeof(raw) == TYPE_FLOAT:
		count = int(raw)
	return Casino.new(count)


func _to_string() -> String:
	return "Casino(chips=%d)" % chips
