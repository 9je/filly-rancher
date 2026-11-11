class_name RaceCard
extends RefCounted
## THE SIX LANE RACE, as arithmetic: who is in it, what she is worth, what the odds are, and
## what happens when they go. The track behind the Spectra Palace (game/world/race_track.gd)
## plays out what this file decides and adds nothing of its own.
##
## THE RATING, AND WHERE ITS NUMBERS COME FROM.
##
##     rating = (0.5 * base_speed + 0.3 * base_stamina + 0.2 * base_spirit)
##              * (0.8 + 0.4 * happiness)
##
## Those three fields have existed on PonyData since Phase 1 and nothing used them until
## now. Measured across game/data/ponies/, base_speed runs 3.0 to 6.5, base_stamina 3.5 to
## 7.5 and base_spirit 4.0 to 8.5, so the weighted part runs 3.35 (the slowest pony on the
## roster) to 6.35 (the fastest), and the three hidden stock records at 4.0 / 1.0 / 1.0
## weight to 2.50. A stock pony is deliberately the slowest thing on the card: unregistered
## stock is the crowd, and entering a named pony you actually went and caught is what the
## race is for. Happiness then swings her form by a fifth either way, which is the spec's
## "a pony who races comes home happy" pointing back at itself: feed her and she runs.
##
## WHY THE SHOWN ODDS AND THE SIMULATION CANNOT DISAGREE. run() draws each lane a score of
## ln(rating) plus a standard Gumbel deviate and the highest score wins. That is the Gumbel
## max trick, and it has an exact identity behind it: the chance that lane i holds the
## highest score is exactly rating_i over the sum of the ratings. So win_chances() is not a
## model OF the race, it IS the race with the randomness taken out, and decimal_odds() can
## be (1 - TAKEOUT) / p with no fudge factor anywhere. Every lane on the card is then worth
## exactly 1 - TAKEOUT per chip staked, which is why the lobby sign can publish one number
## for racing and have it be true of every bet on it.
##
## WHAT THE TRACK GETS. run() also hands back a finishing time per lane, squashed out of the
## same score by a strictly increasing curve into [SLOWEST_SPEED, FASTEST_SPEED] and turned
## into TRACK_LENGTH over that speed. Strictly increasing means the times order the lanes
## exactly the way the scores do, so the race the player watches finishes in the order the
## arithmetic decided; a final pass pushes any tied time out by MIN_FINISH_GAP so a float
## coincidence cannot make the playback contradict the result. The speed band sits inside
## Gait's skate free gallop band, so her hooves match the ground she covers.
##
## NO PONY IS TOUCHED BY ANY OF THIS. entrant_from() READS a PonyInstance and copies what it
## needs; nothing here holds one, moves one, or frees one. She stays in her pen for the whole
## race and apply_race_effects() is the only thing that writes to her, and all it writes is
## hunger and happiness.
##
## Static only. Preload by path.

const PonyInstanceScript := preload("res://systems/pony_instance.gd")
const PonyDataScript := preload("res://systems/pony_data.gd")
const CompanyRunnersScript := preload("res://systems/company_runners.gd")

## Six lanes: yours and the Company's five.
const LANES := 6

## The lane the player's entrant always runs in. Fixed rather than drawn, so she is never
## hunting the card for her own pony; it is the one thing about the race that is not a draw,
## and the Palace says so on the race panel.
const PLAYER_LANE := 0

## The house's share of every chip staked on this card, and the number the lobby sign
## publishes for racing. The ONLY place the house takes anything on a race.
const TAKEOUT := 0.06

const SPEED_WEIGHT := 0.5
const STAMINA_WEIGHT := 0.3
const SPIRIT_WEIGHT := 0.2

## Mood multiplier at happiness 0 and the span up to happiness 1.
const HAPPINESS_FLOOR := 0.8
const HAPPINESS_SPAN := 0.4

## No rating may reach zero: decimal_odds() divides by a win chance.
const MIN_RATING := 0.05

## The Company keeps its runners at exactly this morale. It is in the staff handbook.
## P9 (playtest 2026-11-10 item 48): at 0.7 the Company field out-rated every pony on the
## roster but Rainbow Dash, so a player's pony was the slowest on the card nearly every race
## and finished last a quarter of the time. At an even 0.5 a well-fed favourite can be the
## pick of the field. The odds still follow the ratings exactly (see the class comment).
const COMPANY_HAPPINESS := 0.5

## Metres from the gate to the wire. Matches RaceTrack's own LENGTH; the track reads this
## one rather than declaring a second.
const TRACK_LENGTH := 40.0

## The band a runner's speed is squashed into, in metres per second. Inside Gait's skate free
## gallop band (GALLOP_HANDOVER_SPEED 1.98 to TOP_SKATE_FREE_SPEED 4.785) so every lane reads
## as a gallop and none of them slides.
## 3.1, not 2.6 (P9 item 48): the last pony home came in six seconds behind the winner, "far
## behind" to the owner; the order is unchanged, the gaps are closer.
const SLOWEST_SPEED := 3.1
const FASTEST_SPEED := 4.2

## Centre and width of the squash, in score units. A typical field scores around 2.3, so a
## midpoint of 1.7 puts the average runner comfortably in the top half of the band and leaves
## the bottom of it for a bad draw.
const SPEED_MID := 1.7
const SPEED_SCALE := 0.55

## Seconds forced between two consecutive finishers whose times came out equal.
const MIN_FINISH_GAP := 0.05

## What a race costs and pays a racer, on her own record. Tired and pleased with herself.
const RACE_HUNGER := 0.20
const RACE_HAPPINESS := 0.12


## Her form, from her stats and her mood. See the class comment for where the weights and
## the ranges come from.
static func rating(speed: float, stamina: float, spirit: float, happiness: float) -> float:
	var form: float = SPEED_WEIGHT * speed + STAMINA_WEIGHT * stamina + SPIRIT_WEIGHT * spirit
	var mood: float = HAPPINESS_FLOOR + HAPPINESS_SPAN * clampf(happiness, 0.0, 1.0)
	return maxf(MIN_RATING, form * mood)


## Copy what the race needs out of one of the player's ponies. READ ONLY; she is not moved,
## not held and not changed.
##
## A pony whose character this build does not carry resolves to null and runs on the stock
## record's own numbers rather than being refused: she is still a pony in a pen and the
## player should still be able to enter her.
static func entrant_from(inst: PonyInstance) -> Dictionary:
	if inst == null:
		return {}
	var data: PonyData = inst.data()
	return {
		"name": inst.display_name(),
		"uid": inst.uid,
		"data_id": inst.data_id,
		"speed": data.base_speed if data != null else 4.0,
		"stamina": data.base_stamina if data != null else 1.0,
		"spirit": data.base_spirit if data != null else 1.0,
		"happiness": inst.happiness,
		"stock": inst.stock.duplicate(),
	}


## The six lanes: the entrant on the rail, then the Company's five in card order. Every entry
## carries everything the odds, the panel and the track need, so nothing downstream has to go
## back to a PonyInstance or to the runners resource.
static func build_field(entrant: Dictionary, runners: CompanyRunners) -> Array[Dictionary]:
	var field: Array[Dictionary] = []
	field.append({
		"lane": PLAYER_LANE,
		"name": String(entrant.get("name", "Your pony")),
		"player": true,
		"uid": entrant.get("uid", &""),
		"data_id": entrant.get("data_id", &""),
		"speed": float(entrant.get("speed", 4.0)),
		"stamina": float(entrant.get("stamina", 1.0)),
		"spirit": float(entrant.get("spirit", 1.0)),
		"happiness": float(entrant.get("happiness", 0.5)),
		"stock": (entrant.get("stock", {}) as Dictionary).duplicate(),
		"rating": rating(float(entrant.get("speed", 4.0)), float(entrant.get("stamina", 1.0)),
			float(entrant.get("spirit", 1.0)), float(entrant.get("happiness", 0.5))),
	})
	if runners == null or not runners.is_valid():
		return field
	for i in mini(runners.count(), LANES - 1):
		var runner: Dictionary = runners.entry(i)
		field.append({
			"lane": i + 1,
			"name": String(runner["name"]),
			"player": false,
			"uid": &"",
			"data_id": runner["base_id"],
			"speed": float(runner["speed"]),
			"stamina": float(runner["stamina"]),
			"spirit": float(runner["spirit"]),
			"happiness": COMPANY_HAPPINESS,
			"stock": (runner["stock"] as Dictionary).duplicate(),
			"rating": rating(float(runner["speed"]), float(runner["stamina"]),
				float(runner["spirit"]), COMPANY_HAPPINESS),
		})
	return field


## Each lane's chance of winning. These are the REAL chances, not a display approximation:
## see the class comment on the Gumbel identity.
static func win_chances(field: Array[Dictionary]) -> Array[float]:
	var total := 0.0
	for entry in field:
		total += float(entry["rating"])
	var out: Array[float] = []
	if total <= 0.0:
		for entry in field:
			out.append(0.0)
		return out
	for entry in field:
		out.append(float(entry["rating"]) / total)
	return out


## Chips returned per chip staked on `lane` if she wins, stake included. (1 - TAKEOUT) over
## her chance, so the expected return on every lane is exactly 1 - TAKEOUT and the sign's
## number is true of every bet on the card.
static func decimal_odds(field: Array[Dictionary], lane: int) -> float:
	if lane < 0 or lane >= field.size():
		return 0.0
	var chance: float = win_chances(field)[lane]
	if chance <= 0.0:
		return 0.0
	return (1.0 - TAKEOUT) / chance


## Player facing, so no dashes.
static func odds_text(odds: float) -> String:
	return "%.2f for 1" % odds


## The squash from a score to a running speed. Strictly increasing everywhere, which is what
## makes the times agree with the order.
static func speed_for_score(score: float) -> float:
	var t: float = 1.0 / (1.0 + exp(-(score - SPEED_MID) / SPEED_SCALE))
	return SLOWEST_SPEED + (FASTEST_SPEED - SLOWEST_SPEED) * t


## RUN THE RACE. Returns {"order": Array[int], "times": Array[float], "winner": int,
## "scores": Array[float]}, where `order` is lane indices with the winner first and `times`
## is indexed BY LANE.
##
## A function of the field and the seed and of nothing else: no clock, no frame, no global
## generator. The same two arguments give the same race on any machine.
static func run(field: Array[Dictionary], seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var scores: Array[float] = []
	var times: Array[float] = []
	for entry in field:
		# A standard Gumbel deviate. randf() is [0, 1), so both logs are guarded: a u of
		# exactly 0 would be an infinite score and a u of exactly 1 a negative infinite one.
		var u: float = clampf(rng.randf(), 1e-9, 1.0 - 1e-9)
		var gumbel: float = -log(-log(u))
		scores.append(log(maxf(float(entry["rating"]), MIN_RATING)) + gumbel)
		times.append(0.0)

	var order: Array[int] = []
	for lane in field.size():
		order.append(lane)
	order.sort_custom(func(a: int, b: int) -> bool:
		if scores[a] == scores[b]:
			return a < b
		return scores[a] > scores[b])

	for lane in field.size():
		times[lane] = TRACK_LENGTH / speed_for_score(scores[lane])
	# The squash is strictly increasing, so this only ever fires on a float coincidence; it
	# is here so that "the race you watch finishes in the order the arithmetic decided" is a
	# property of the data rather than of the floating point unit.
	for k in range(1, order.size()):
		var ahead: float = times[order[k - 1]]
		if times[order[k]] <= ahead:
			times[order[k]] = ahead + MIN_FINISH_GAP

	return {"order": order, "times": times, "winner": order[0] if not order.is_empty() else -1,
		"scores": scores}


## Chips handed back for a bet on `lane`, THE STAKE INCLUDED; 0 for a loser. Same contract as
## every other game here. Rounded rather than floored: rounding down would quietly hand the
## house a little more than the takeout the sign published.
static func payout(field: Array[Dictionary], lane: int, stake: int, winner: int) -> int:
	if stake <= 0 or lane < 0 or lane >= field.size() or lane != winner:
		return 0
	return roundi(float(stake) * decimal_odds(field, lane))


## WHAT RUNNING DOES TO HER. Hungrier and happier, clamped, and nothing else: she is not
## moved, not evicted from her pen and not freed. This is the whole of racing's effect on a
## pony, and it is here rather than in the track so it can be tested without a scene.
static func apply_race_effects(inst: PonyInstance) -> void:
	if inst == null:
		return
	inst.hunger = clampf(inst.hunger + RACE_HUNGER, PonyInstanceScript.STATE_MIN,
		PonyInstanceScript.STATE_MAX)
	inst.happiness = clampf(inst.happiness + RACE_HAPPINESS, PonyInstanceScript.STATE_MIN,
		PonyInstanceScript.STATE_MAX)
