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

## Preloaded by path rather than referenced through the global class_name, per the
## convention at the top of game/scripts/pony_rig.gd.
const EconomyScript := preload("res://systems/economy.gd")

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

## Credit for delivering one pony of the crowd, and the multiplier a NAMED pony's unit value
## is scaled by (DELIVERY_UNIT_BY_RARITY times this), so a legendary clears 4,000. The units
## are the gem values from before PS9 trimmed gem sales, kept here so a delivery is not cut
## twice (the repeat falloff is its trim). A named delivery is the best money in the game by a wide margin. That is
## deliberate, and it is the whole hinge of the story.
const DELIVERY_CREDIT_STOCK := 300
const DELIVERY_NAMED_MULTIPLIER := 40
const DELIVERY_UNIT_BY_RARITY := {
	PonyData.Rarity.COMMON: 5,
	PonyData.Rarity.UNCOMMON: 12,
	PonyData.Rarity.RARE: 30,
	PonyData.Rarity.LEGENDARY: 100,
}

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

## The punishment the collector will serve, taken exactly once by
## take_pending_punishment(). Separated from the collection day itself because the design
## doc puts the visit at dawn and the arithmetic at the cycle boundary.
var pending_punishment: int = Punishment.NONE

## THE CYCLE THE PENDING PUNISHMENT WAS ARMED ON, or -1 when nothing is armed. This is what
## makes "the letter arrives before the knock" true rather than a phrase in a doc comment.
##
## A COLLECTION DAY ALWAYS LANDS ON A DAWN: is_collection_cycle() only answers true at a
## cycle boundary and a cycle's first phase is DAWN by construction. So a caller that
## served the pending punishment at "the next DAWN" served it in the same breath as the
## bill: the letter and the knock in one frame, which is not the beat the spec describes.
## game/world/ranch.gd's _maybe_serve_collector() therefore requires the current cycle to be
## STRICTLY GREATER than this one, which puts the visit on the first dawn of a LATER cycle:
## the player reads the notice, has a cycle to ship or to pay, and then somebody calls.
##
## SAVED, like pending_punishment itself, so a session that quits between the notice and the
## visit comes back owing the same visit on the same dawn rather than one dawn early.
var pending_punishment_cycle := -1

## Permit unlock ids currently revoked, and plot slot ids currently padlocked. Plain
## Strings, and untyped Arrays, for GameState.unlocks' reason: these are assigned
## dynamically from the ranch and from tests, and a typed array would refuse an untyped
## literal at runtime rather than at parse time.
var revoked_permits: Array = []
var padlocked_slots: Array = []

## Cycle index the beam comes back at, or -1 when it was never recalled.
var beam_recalled_until := -1

## A REPEAT PAYS LESS (PS9, playtest 2026-11-05 item 69: the owner's money came from sending
## up every pony who was not one of a kind). Within one cycle the same kind is credited full,
## then 70%, 50%, and 35% from the fourth on; every Drifter is one kind (DRIFTER_KIND); a new
## cycle starts the count again. `repeats` is {kind: deliveries this cycle} for repeats_cycle.
const REPEAT_FALLOFF := [1.0, 0.7, 0.5, 0.35]
const DRIFTER_KIND := &"drifter"
var repeats := {}
var repeats_cycle := -1


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
## A DELIVERY PAYS HER TOO (PT9; playtest 2026-11-05: "i thought i was gonna get paid but it
## went to debt"). The full credit comes off the balance, as it always has (the story's pace of
## paying the debt is unchanged), and HANDLER_SHARE of it goes into her purse on top.
const HANDLER_SHARE := 0.25


static func handler_share(credit: int) -> int:
	return int(round(float(maxi(0, credit)) * HANDLER_SHARE))


static func delivery_credit(rarity: int, is_stock: bool) -> int:
	if is_stock:
		return DELIVERY_CREDIT_STOCK
	var unit: int = int(DELIVERY_UNIT_BY_RARITY.get(rarity, 0))
	return unit * DELIVERY_NAMED_MULTIPLIER


## What delivering her would credit now, counting the repeats so far this cycle. Spends nothing.
func quote_delivery(rarity: int, is_stock: bool, kind: StringName = &"", cycle: int = -1) -> int:
	var base: int = delivery_credit(rarity, is_stock)
	if kind == &"" or cycle != repeats_cycle:
		return base
	var n: int = int(repeats.get(String(kind), 0))
	return int(round(float(base) * float(REPEAT_FALLOFF[mini(n, REPEAT_FALLOFF.size() - 1)])))


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


## WHETHER A COLLECTION DAY IS OWED FOR `cycle`: true only when `cycle` really is a
## collection cycle AND the period it falls in has not already been billed. Reads only
## `periods_run`, which travels with the save (to_dict()/from_dict()), so a caller can ask
## this instead of keeping its own runtime counter of the last cycle it billed.
##
## THIS IS THE WHOLE FIX FOR A BUG A RUNTIME COUNTER CANNOT SEE. game/world/ranch.gd used
## to guard run_collection_day() with a plain `var _last_collection_cycle := -1` that reset
## to -1 on every fresh process; a save loaded mid cycle (or a fresh process booting
## straight into one) had no way to tell "never billed" from "billed by the session that
## wrote this save", and re-billed the same period's upkeep and service charge, escalated
## the tier a second time, and threw away delivered_this_period's count. periods_run is
## the one number that already survives that boundary honestly, because it is part of the
## save.
func is_collection_day_due(cycle: int) -> bool:
	return is_collection_cycle(cycle) and period_of(cycle) > periods_run


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
	pending_punishment_cycle = cycle if punishment != Punishment.NONE else -1

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
## `kind` and `cycle` price her as a repeat (REPEAT_FALLOFF); an empty kind is not counted.
func credit_delivery(rarity: int, is_stock: bool, kind: StringName = &"", cycle: int = -1) -> int:
	var credit: int = quote_delivery(rarity, is_stock, kind, cycle)
	if credit <= 0:
		return 0
	if kind != &"":
		if cycle != repeats_cycle:
			repeats = {}
			repeats_cycle = cycle
		repeats[String(kind)] = int(repeats.get(String(kind), 0)) + 1
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
##
## WHEN it may be taken is the caller's question, not this one's: see
## pending_punishment_cycle and game/world/ranch.gd's _maybe_serve_collector().
func take_pending_punishment() -> int:
	var punishment: int = pending_punishment
	pending_punishment = Punishment.NONE
	pending_punishment_cycle = -1
	return punishment


## GIVE EVERYTHING BACK, once the balance is under the ceiling. Returns what was cleared,
## `{"permits": Array, "slots": Array, "beam": bool}`, so the caller can re-open the fences,
## unpadlock the pens and hand the horn back; or an EMPTY dictionary when there was nothing
## to give back or she is still over the ceiling, which is the caller's cue to do nothing
## and say nothing.
## THE RECALL IS CLEARED WHETHER OR NOT IT WAS STILL RUNNING, but it is only REPORTED when
## it was. beam_recalled_until is a cycle number that goes stale on its own clock: one cycle
## after the visit the horn is already back, and a note left sitting in this field would
## make the next relieve() announce it was handing back something the player has been using
## for the last twenty minutes. `cycle` is the world's current cycle; pass -1 (the default)
## from a caller that has no clock, which reads every recall as still running and is the
## safe way round, because it hands the horn back rather than forgetting to.
func relieve(cycle: int = -1) -> Dictionary:
	if balance > CEILING:
		return {}
	var recalled: bool = beam_is_recalled(cycle) if cycle >= 0 else beam_recalled_until >= 0
	if revoked_permits.is_empty() and padlocked_slots.is_empty() and beam_recalled_until < 0:
		return {}
	var given := {
		"permits": revoked_permits.duplicate(),
		"slots": padlocked_slots.duplicate(),
		"beam": recalled,
	}
	revoked_permits = []
	padlocked_slots = []
	beam_recalled_until = -1
	if given["permits"].is_empty() and given["slots"].is_empty() and not recalled:
		# Nothing was actually owed back: the only note on file was a recall that had
		# already expired, and it has now been tidied away. An empty answer is the caller's
		# cue to say nothing, which is right, because there is nothing to tell her.
		return {}
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
	var days := next_cycle - cycle
	# "Collections passed: 0" read as a counter that never moved (item 62): before the
	# first one, the statement says when it comes instead.
	lines.append("%s collection: %s" % ["First" if periods_run == 0 else "Next",
		"tomorrow" if days <= 1 else "in %d days" % days])
	# "31 of 2" read as a broken counter (playtest 2026-11-05 item 62): say met or short.
	if delivered_this_period >= quota:
		lines.append("Quota met: %d delivered, %d needed" % [delivered_this_period, quota])
	else:
		lines.append("Quota: %d more to deliver (%d of %d)" % [quota - delivered_this_period,
			delivered_this_period, quota])
	if periods_run > 0:
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
		"pending_punishment_cycle": pending_punishment_cycle,
		"revoked_permits": revoked_permits.duplicate(),
		"padlocked_slots": padlocked_slots.duplicate(),
		"beam_recalled_until": beam_recalled_until,
		"repeats": repeats.duplicate(),
		"repeats_cycle": repeats_cycle,
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
	# A save written before this field existed carries no arming cycle. -1 is the honest
	# answer for it and it is also the permissive one: any cycle is later than -1, so an
	# older save's armed collector calls at the very next dawn rather than never.
	out.pending_punishment_cycle = int(d.get("pending_punishment_cycle", -1))
	out.revoked_permits = _string_list(d.get("revoked_permits", []))
	out.padlocked_slots = _string_list(d.get("padlocked_slots", []))
	out.beam_recalled_until = int(d.get("beam_recalled_until", -1))
	out.repeats_cycle = int(d.get("repeats_cycle", -1))
	var reps: Variant = d.get("repeats", {})
	if typeof(reps) == TYPE_DICTIONARY:
		for k in (reps as Dictionary):
			out.repeats[str(k)] = maxi(0, int(reps[k]))
	return out


static func _string_list(value: Variant) -> Array:
	var out: Array = []
	if typeof(value) != TYPE_ARRAY:
		return out
	for entry in (value as Array):
		out.append(str(entry))
	return out
