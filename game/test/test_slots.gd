extends GutTest
## THE SLOTS, as arithmetic. The interesting claim is that the published house edge is a
## fact about the strip and the paytable rather than a number typed onto a sign, so most of
## this file is about return_to_player() being enumerated and the seeded spin agreeing with
## it over a long run.

const SlotsScript := preload("res://systems/slots.gd")

## Enough spins for the measured return to sit inside a per cent of the exact one. The gate
## (game/scenes/test/casino_test.gd) runs a hundred thousand; the suite runs this many so it
## stays a suite rather than a coffee break.
const SAMPLE_SPINS := 20000


func test_the_strip_is_sixteen_positions_and_holds_every_symbol() -> void:
	var strip: Array[int] = SlotsScript.strip()
	assert_eq(strip.size(), SlotsScript.REEL_SIZE)
	var counts: Array[int] = [0, 0, 0, 0, 0, 0]
	for symbol in strip:
		counts[symbol] += 1
	assert_eq(counts, SlotsScript.STRIP_COUNTS, "the strip is exactly what STRIP_COUNTS says")


## EVERY REEL HOLDS THE SAME SIXTEEN SYMBOLS, so the odds are the old odds; only the order
## changed, and the order is what the window shows.
func test_every_real_reel_strip_holds_exactly_the_published_counts() -> void:
	assert_eq(SlotsScript.REEL_STRIPS.size(), SlotsScript.REELS)
	for reel: int in SlotsScript.REELS:
		var strip: Array[int] = SlotsScript.reel_strip(reel)
		assert_eq(strip.size(), SlotsScript.REEL_SIZE, "reel %d" % reel)
		var counts: Array[int] = [0, 0, 0, 0, 0, 0]
		for symbol in strip:
			counts[symbol] += 1
		assert_eq(counts, SlotsScript.STRIP_COUNTS, "reel %d holds the published counts" % reel)


## THE PLAYTEST BUG ("2 spins in a row where the first 2 reels had all 3 the same"): a window
## shows three adjacent positions, and on every reel every three adjacent positions, wrapping
## round, must be three different symbols.
func test_every_window_on_every_reel_shows_three_different_symbols() -> void:
	for reel: int in SlotsScript.REELS:
		var strip: Array[int] = SlotsScript.reel_strip(reel)
		for top: int in strip.size():
			var a: int = strip[top]
			var b: int = strip[(top + 1) % strip.size()]
			var c: int = strip[(top + 2) % strip.size()]
			assert_true(a != b and b != c and a != c,
				"reel %d positions %d to %d show %d %d %d" % [reel, top, top + 2, a, b, c])


func test_the_three_reels_do_not_share_one_order() -> void:
	assert_ne(SlotsScript.reel_strip(0), SlotsScript.reel_strip(1))
	assert_ne(SlotsScript.reel_strip(1), SlotsScript.reel_strip(2))
	assert_ne(SlotsScript.reel_strip(0), SlotsScript.reel_strip(2))


func test_three_of_a_kind_pays_the_paytable_and_a_losing_line_pays_nothing() -> void:
	assert_eq(SlotsScript.payout([SlotsScript.Symbol.APPLE, SlotsScript.Symbol.APPLE,
		SlotsScript.Symbol.APPLE], 10), 40)
	assert_eq(SlotsScript.payout([SlotsScript.Symbol.RAINBOW, SlotsScript.Symbol.RAINBOW,
		SlotsScript.Symbol.RAINBOW], 10), 4500)
	assert_eq(SlotsScript.payout([SlotsScript.Symbol.APPLE, SlotsScript.Symbol.CLOUD,
		SlotsScript.Symbol.GEM], 10), 0)


func test_rainbows_outside_a_triple_pay_a_consolation() -> void:
	assert_eq(SlotsScript.payout([SlotsScript.Symbol.RAINBOW, SlotsScript.Symbol.RAINBOW,
		SlotsScript.Symbol.APPLE], 10), 50, "two rainbows pay five")
	assert_eq(SlotsScript.payout([SlotsScript.Symbol.RAINBOW, SlotsScript.Symbol.APPLE,
		SlotsScript.Symbol.CLOUD], 10), 10, "one rainbow hands the stake back")


func test_a_zero_or_negative_stake_pays_nothing_at_all() -> void:
	var jackpot: Array[int] = [SlotsScript.Symbol.RAINBOW, SlotsScript.Symbol.RAINBOW,
		SlotsScript.Symbol.RAINBOW]
	assert_eq(SlotsScript.payout(jackpot, 0), 0)
	assert_eq(SlotsScript.payout(jackpot, -50), 0, "there is no such thing as a negative bet")


func test_the_return_to_player_is_the_enumerated_fraction_and_nothing_else() -> void:
	assert_almost_eq(SlotsScript.return_to_player(), 3809.0 / 4096.0, 1e-9,
		"3809 units returned over 4096 equally likely position triples")
	assert_almost_eq(SlotsScript.house_edge(), 287.0 / 4096.0, 1e-9)


func test_the_published_edge_reads_as_seven_per_cent() -> void:
	assert_eq("%.1f" % (SlotsScript.house_edge() * 100.0), "7.0")


func test_a_spin_is_three_symbols_and_never_leaves_the_alphabet() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in 500:
		var reels: Array[int] = SlotsScript.spin(rng)
		assert_eq(reels.size(), SlotsScript.REELS)
		for symbol in reels:
			assert_between(symbol, 0, SlotsScript.SYMBOL_NAMES.size() - 1)


func test_the_same_seed_spins_the_same_reels() -> void:
	var a := RandomNumberGenerator.new()
	a.seed = 4242
	var b := RandomNumberGenerator.new()
	b.seed = 4242
	for i in 50:
		assert_eq(SlotsScript.spin(a), SlotsScript.spin(b))


## THE SPIN IS UNIFORM OVER EACH REEL'S POSITIONS, which together with the exact enumeration
## above is the whole proof that the sign is honest. This used to measure the edge itself over
## twenty thousand spins from a seed picked by search, and that is not a test: three lines pay
## 55, 150 and 450 times the stake, so one standard error at that sample is five points, and
## the per reel strips (2026-11-05) moved the seed's luck. Symbol frequencies have no fat tail,
## so they are checked instead, per reel, against STRIP_COUNTS / 16.
func test_each_reel_lands_on_its_symbols_in_the_published_proportions() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261105
	var seen: Array = [[0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0]]
	for i in SAMPLE_SPINS:
		var line: Array[int] = SlotsScript.spin(rng)
		for reel: int in SlotsScript.REELS:
			seen[reel][line[reel]] += 1
	for reel: int in SlotsScript.REELS:
		for symbol: int in SlotsScript.STRIP_COUNTS.size():
			var measured: float = float(seen[reel][symbol]) / float(SAMPLE_SPINS)
			var expected: float = float(SlotsScript.STRIP_COUNTS[symbol]) \
				/ float(SlotsScript.REEL_SIZE)
			assert_almost_eq(measured, expected, 0.012,
				"reel %d symbol %d" % [reel, symbol])


func test_every_paytable_line_is_printable_and_carries_no_dashes() -> void:
	var lines: Array[String] = SlotsScript.paytable_lines()
	assert_gt(lines.size(), 0)
	for line in lines:
		assert_false(line.is_empty())
		assert_false(line.contains("--") or line.contains("—"),
			"player facing copy carries no double hyphen and no em dash: %s" % line)
