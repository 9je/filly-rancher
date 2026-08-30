class_name Ledger
extends RefCounted
## THE COMPANY'S HOLD ON THE PLAYER, AS ARITHMETIC. A sponsorship balance that the ranch
## was bought with, a collection day every three cycles that adds upkeep and a service
## charge to it, a quota of ponies that has to be delivered between one collection day and
## the next, and a four rung ladder of collectors for the periods where neither happens.
## No scene, no clock, no RNG: the cycle number comes in as an argument, the same
## discipline game/systems/production.gd and game/systems/economy.gd are built under, so
## the whole of it is GUT testable in milliseconds (game/test/test_ledger.gd).
##
## --- THE PROMISE THIS CLASS EXISTS TO KEEP -------------------------------------------
##
## A player who never delivers a pony cannot pay the balance off. That is the premise of
## the whole phase: the ranch is not a business, it is a debt with a supply contract
## attached, and the only thing that actually moves the principal is stock.
##
## THE MECHANISM IS A FLOOR, NOT MERELY INTEREST, and it is worth writing down why. The
## design doc attributes the promise to the service charge alone. The service charge cannot
## carry it: three legendary ponies in a pen produce a gem each every twenty seconds at a
## hundred bits a gem (game/systems/production.gd, game/systems/economy.gd), which is
## 54,000 bits in one collection day against a 25,000 balance, and no small percentage of a
## FALLING balance outruns that. So the rule is stated outright instead, and the Depot says
## it in as many words: bits settle the service charges, stock settles the principal.
## pay() will never take the balance below PRINCIPAL_FLOOR; credit_delivery() is the only
## thing that reaches under it. The service charge and the upkeep are still exactly what
## the player feels week to week; the floor is what makes the promise true.
## test_gems_alone_never_clear_the_balance asserts the two of them together.
##
## --- NOTHING IS EVER DELETED ----------------------------------------------------------
##
## A collector revokes a permit, padlocks a pen or recalls the beam. Every one of those is
## a note in this object that relieve() takes back the moment the balance is under the
## ceiling; the permit is still bought, the pen is still built, the ponies inside it are
## still hers, and NO PONY IS EVER TAKEN. (The one place after the fork where a collector
## reaches into a pen is the Resistance route, which is a later slice and is not here.)

enum Punishment { NONE, FEE, PERMIT_REVOKED, PEN_PADLOCKED, BEAM_RECALLED }

## The collector ladder, in the order the design doc names it. Index by `tier`, clamped at
## the end: the fourth failure and the fortieth both recall the beam.
const LADDER: Array[int] = [Punishment.FEE, Punishment.PERMIT_REVOKED,
	Punishment.PEN_PADLOCKED, Punishment.BEAM_RECALLED]

## What the ranch, the beam and the first pen cost, in bits, at a price the player never
## agreed to. Shown from minute one and never hidden.
const STARTING_BALANCE := 25000

## Cycles between collection days. Three at WorldState.CYCLE_SECONDS (1200 s) is one real
## hour, which is where the design doc puts the first one.
const PERIOD_CYCLES := 3

## Ponies that must be delivered between one collection day and the next. Grows with rank
## in a later slice; this is where it starts.
const STARTING_QUOTA := 2

## Over this, a collector calls whether or not the quota was met, and every punishment
## stands until the balance is back under it.
const CEILING := 40000

## The balance bits will not go below. See the class comment.
const PRINCIPAL_FLOOR := 5000

## Upkeep: a base, plus a charge per built plot and per open permit, times the rank
## multiplier. UPKEEP_BASE is 1800 for a pacing reason with a test on it: a fresh ranch is
## one free Paddock holding three ponies, three ponies at the best production rate earn
## 2700 bits in one collection period, and the first collection day has to charge more than
## that so the balance goes UP in the player's first hour even if she sells everything.
const UPKEEP_BASE := 1800
const UPKEEP_PER_PLOT := 350
const UPKEEP_PER_PERMIT := 450

## The service charge, as a fraction of the balance, with a floor so a nearly settled
## balance still visibly costs something to carry.
const INTEREST_RATE := 0.04
const MIN_SERVICE_CHARGE := 25

## Credit for delivering one pony of the crowd, and the multiplier a NAMED pony's gem value
## is scaled by (game/systems/economy.gd GEM_VALUE_BY_RARITY times this), so a legendary
## clears 4,000. A named delivery is the best money in the game by a wide margin. That is
## deliberate, and it is the whole hinge of the story.
const DELIVERY_CREDIT_STOCK := 300
const DELIVERY_NAMED_MULTIPLIER := 40

## What the first rung of the ladder costs in bits.
const COLLECTOR_FEE := 500

## How long the beam is "recalled" for, in cycles.
const BEAM_RECALL_CYCLES := 1

## Emitted whenever `balance` actually moves. Carries the new total so a HUD can bind to it
## without a second read, matching Economy.bits_changed's rule.
signal changed(balance: int)

## Emitted by run_collection_day() with the summary it returns, so a HUD, a toast and a
## letter can all hang off one event.
signal collection_day(summary: Dictionary)

var balance := STARTING_BALANCE
var quota := STARTING_QUOTA
var delivered_this_period := 0
var periods_run := 0

## Every pony this ranch has ever shipped, across every period. Counted here rather than in
## the ranch because a delivered pony leaves no trace anywhere else by design, and the
## receipt letter counts her shipments back to her ("your 12th delivery!"). Saved, so a
## reload does not start the count over and hand her a first receipt on her twentieth pony.
var shipments := 0

## How far up LADDER the next failure will reach. Raised by a failed collection day,
## lowered by one (not reset) by a good one, so recovering from a bad run takes as many
## good periods as the bad run took.
var tier := 0

## The punishment the collector will serve at the NEXT DAWN, taken exactly once by
## take_pending_punishment(). Separated from the collection day itself because the design
## doc puts the visit at dawn and the arithmetic at the cycle boundary.
var pending_punishment: int = Punishment.NONE

## Permit unlock ids currently revoked, and plot slot ids currently padlocked. Plain
## Strings, and untyped Arrays, for GameState.unlocks' reason: these are assigned
## dynamically from the ranch and from tests, and a typed array would refuse an untyped
## literal at runtime rather than at parse time.
var revoked_permits: Array = []
var padlocked_slots: Array = []

## Cycle index the beam comes back at, or -1 when it was never recalled.
var beam_recalled_until := -1


## Which collection period `cycle` falls in.
static func period_of(cycle: int) -> int:
	return int(floor(float(maxi(0, cycle)) / float(PERIOD_CYCLES)))


## Is `cycle` a collection day? Cycle zero is not: the day the player starts is the day she
## is handed the ranch, and billing her for it before she has walked out of the house would
## be a joke with no setup.
static func is_collection_cycle(cycle: int) -> bool:
	return cycle > 0 and cycle % PERIOD_CYCLES == 0


## Bits credited for delivering one pony. Stock is a flat rate; a named pony is her gem
## value times the multiplier.
static func delivery_credit(rarity: int, is_stock: bool) -> int:
	if is_stock:
		return DELIVERY_CREDIT_STOCK
	var unit: int = int(Economy.GEM_VALUE_BY_RARITY.get(rarity, 0))
	return unit * DELIVERY_NAMED_MULTIPLIER


func upkeep_for(built_plots: int, open_permits: int, rank_multiplier: float = 1.0) -> int:
	var raw: int = UPKEEP_BASE + maxi(0, built_plots) * UPKEEP_PER_PLOT \
		+ maxi(0, open_permits) * UPKEEP_PER_PERMIT
	return int(round(float(raw) * maxf(0.0, rank_multiplier)))


func service_charge() -> int:
	if balance <= 0:
		return 0
	return maxi(MIN_SERVICE_CHARGE, int(round(float(balance) * INTEREST_RATE)))


## The most bits pay() will accept right now. Never negative.
func payable() -> int:
	return maxi(0, balance - PRINCIPAL_FLOOR)


## THE COLLECTION DAY. Adds the upkeep and the service charge, judges the period, arms the
## next collector, and starts the count again. Returns everything the ranch, the statement
## and the tests need, in one dictionary, so nothing has to ask this object a second
## question about a moment that has already passed.
func run_collection_day(cycle: int, built_plots: int, open_permits: int,
		rank_multiplier: float = 1.0) -> Dictionary:
	var upkeep: int = upkeep_for(built_plots, open_permits, rank_multiplier)
	var charge: int = service_charge()
	balance += upkeep + charge

	var delivered: int = delivered_this_period
	var quota_met: bool = delivered >= quota
	var over_ceiling: bool = balance > CEILING
	var punishment: int = Punishment.NONE
	if quota_met and not over_ceiling:
		tier = maxi(0, tier - 1)
	else:
		punishment = LADDER[clampi(tier, 0, LADDER.size() - 1)]
		tier = mini(tier + 1, LADDER.size())
	pending_punishment = punishment

	delivered_this_period = 0
	periods_run += 1

	var summary := {
		"period": period_of(cycle),
		"upkeep": upkeep,
		"service_charge": charge,
		"delivered": delivered,
		"quota": quota,
		"quota_met": quota_met,
		"over_ceiling": over_ceiling,
		"punishment": punishment,
		"balance": balance,
	}
	changed.emit(balance)
	collection_day.emit(summary)
	return summary


## One pony delivered. Returns the credit applied, counts her toward the quota, and MAY
## take the balance below the floor and into credit: stock settles the principal.
func credit_delivery(rarity: int, is_stock: bool) -> int:
	var credit: int = delivery_credit(rarity, is_stock)
	if credit <= 0:
		return 0
	balance -= credit
	delivered_this_period += 1
	shipments += 1
	changed.emit(balance)
	return credit


## Pay bits against the balance. Returns what was actually taken, which is zero for a
## non positive amount and is capped at payable(). A caller must debit the wallet by the
## RETURN VALUE, never by what it asked for.
func pay(bits: int) -> int:
	if bits <= 0:
		return 0
	var taken: int = mini(bits, payable())
	if taken <= 0:
		return 0
	balance -= taken
	changed.emit(balance)
	return taken


## The punishment a collector should serve at this dawn, taken exactly once. A second call
## before the next collection day answers NONE, so a dawn that fires twice (a mid session
## load, a pinned clock) cannot serve one collector twice.
func take_pending_punishment() -> int:
	var punishment: int = pending_punishment
	pending_punishment = Punishment.NONE
	return punishment


## GIVE EVERYTHING BACK, once the balance is under the ceiling. Returns what was cleared,
## `{"permits": Array, "slots": Array, "beam": bool}`, so the caller can re-open the fences,
## unpadlock the pens and hand the horn back; or an EMPTY dictionary when there was nothing
## to give back or she is still over the ceiling, which is the caller's cue to do nothing
## and say nothing.
func relieve() -> Dictionary:
	if balance > CEILING:
		return {}
	if revoked_permits.is_empty() and padlocked_slots.is_empty() and beam_recalled_until < 0:
		return {}
	var given := {
		"permits": revoked_permits.duplicate(),
		"slots": padlocked_slots.duplicate(),
		"beam": beam_recalled_until >= 0,
	}
	revoked_permits = []
	padlocked_slots = []
	beam_recalled_until = -1
	return given


func beam_is_recalled(cycle: int) -> bool:
	return beam_recalled_until >= 0 and cycle < beam_recalled_until


## The Depot's statement, as lines. Made out to the player by name, because the Company
## knowing your name is part of the register.
func statement_lines(player_name: String, built_plots: int, open_permits: int,
		cycle: int) -> Array[String]:
	var next_cycle: int = (period_of(cycle) + 1) * PERIOD_CYCLES
	var lines: Array[String] = []
	lines.append("Cloudsdale Weather Corporation, Sponsorship Services")
	lines.append("Account: %s" % player_name)
	lines.append("Sponsorship balance: %d bits" % balance)
	lines.append("Upkeep next collection: %d bits" % upkeep_for(built_plots, open_permits))
	lines.append("  base %d, plots %d at %d, permits %d at %d" % [
		UPKEEP_BASE, built_plots, UPKEEP_PER_PLOT, open_permits, UPKEEP_PER_PERMIT])
	lines.append("Service charge next collection: %d bits" % service_charge())
	lines.append("Next collection day: cycle %d (you are on cycle %d)" % [next_cycle, cycle])
	lines.append("Quota this period: %d of %d delivered" % [delivered_this_period, quota])
	lines.append("Collections passed: %d" % periods_run)
	lines.append("Bits settle the service charges. The principal is settled in stock.")
	lines.append("You may pay down to %d bits here; thank you for choosing Cloudsdale!"
		% PRINCIPAL_FLOOR)
	return lines


func to_dict() -> Dictionary:
	return {
		"balance": balance,
		"quota": quota,
		"delivered_this_period": delivered_this_period,
		"periods_run": periods_run,
		"shipments": shipments,
		"tier": tier,
		"pending_punishment": pending_punishment,
		"revoked_permits": revoked_permits.duplicate(),
		"padlocked_slots": padlocked_slots.duplicate(),
		"beam_recalled_until": beam_recalled_until,
	}


## Rebuild from a to_dict() dictionary, or from one JSON.parse_string handed back, which is
## the same thing with every number as a float. Every field is optional and falls back to a
## brand new ledger's value, which is what makes an older save load without a migration
## step; and every field is CLAMPED rather than trusted, so a hand edited file cannot
## produce a negative quota or a rung the ladder does not have.
static func from_dict(d: Dictionary) -> Ledger:
	var out := Ledger.new()
	out.balance = int(d.get("balance", STARTING_BALANCE))
	out.quota = maxi(0, int(d.get("quota", STARTING_QUOTA)))
	out.delivered_this_period = maxi(0, int(d.get("delivered_this_period", 0)))
	out.periods_run = maxi(0, int(d.get("periods_run", 0)))
	out.shipments = maxi(0, int(d.get("shipments", 0)))
	out.tier = clampi(int(d.get("tier", 0)), 0, LADDER.size())
	out.pending_punishment = clampi(int(d.get("pending_punishment", Punishment.NONE)),
		Punishment.NONE, Punishment.BEAM_RECALLED)
	out.revoked_permits = _string_list(d.get("revoked_permits", []))
	out.padlocked_slots = _string_list(d.get("padlocked_slots", []))
	out.beam_recalled_until = int(d.get("beam_recalled_until", -1))
	return out


static func _string_list(value: Variant) -> Array:
	var out: Array = []
	if typeof(value) != TYPE_ARRAY:
		return out
	for entry in (value as Array):
		out.append(str(entry))
	return out
