extends GutTest
## THE BIG WHEEL, as arithmetic. Forty five segments painted 1x, 3x, 5x, 10x and 20x; a bet on
## a tier pays that many to one when the pointer stops on it. The claims worth testing are the
## counts (they ARE the odds), the payout convention (n to 1, the stake back on top), and that
## the edge the sign prints is the worst tier's, worked out from the wheel and not typed in.

const WheelScript := preload("res://systems/wheel.gd")

const SAMPLE_SPINS := 30000


func _bet(tier: int, stake: int) -> Array[int]:
	var bets: Array[int] = WheelScript.empty_bets()
	bets[tier] = stake
	return bets


func _first_segment(tier: int) -> int:
	return WheelScript.LAYOUT.find(tier)


func test_the_wheel_has_forty_five_segments_in_the_published_counts() -> void:
	assert_eq(WheelScript.LAYOUT.size(), WheelScript.SEGMENTS)
	assert_eq(WheelScript.SEGMENTS, 45)
	var expected: Array[int] = [21, 11, 7, 4, 2]
	for tier: int in WheelScript.TIERS:
		assert_eq(WheelScript.segment_count(tier), expected[tier],
			"%s owns %d segments" % [WheelScript.TIER_LABELS[tier], expected[tier]])
	assert_eq(WheelScript.MULTIPLIERS, [1, 3, 5, 10, 20] as Array[int])


func test_no_two_neighbouring_segments_carry_the_same_tier() -> void:
	for i: int in WheelScript.SEGMENTS:
		assert_ne(WheelScript.tier_of(i), WheelScript.tier_of((i + 1) % WheelScript.SEGMENTS),
			"segments %d and %d are alike" % [i, (i + 1) % WheelScript.SEGMENTS])


func test_the_two_twenty_segments_sit_across_the_wheel_from_each_other() -> void:
	var at: Array[int] = []
	for i: int in WheelScript.SEGMENTS:
		if WheelScript.tier_of(i) == WheelScript.Tier.TWENTY:
			at.append(i)
	assert_eq(at.size(), 2)
	var apart: int = absi(at[1] - at[0])
	assert_between(mini(apart, WheelScript.SEGMENTS - apart), 21, 22,
		"the jackpots are half a wheel apart")


func test_a_tier_pays_n_to_one_and_hands_the_stake_back_on_top() -> void:
	for tier: int in WheelScript.TIERS:
		var segment: int = _first_segment(tier)
		assert_eq(WheelScript.payout(_bet(tier, 10), segment),
			(WheelScript.MULTIPLIERS[tier] + 1) * 10,
			"%s on 10 chips returns %d" % [WheelScript.TIER_LABELS[tier],
				(WheelScript.MULTIPLIERS[tier] + 1) * 10])
	assert_eq(WheelScript.payout(_bet(WheelScript.Tier.THREE, 10),
		_first_segment(WheelScript.Tier.THREE)), 40, "10 on 3x comes back as 40")


func test_only_the_tier_under_the_pointer_is_paid_and_every_other_bet_is_lost() -> void:
	var bets: Array[int] = [10, 20, 30, 40, 50]
	var segment: int = _first_segment(WheelScript.Tier.FIVE)
	assert_eq(WheelScript.payout(bets, segment), 6 * 30, "only the 5x bet comes back")
	assert_eq(WheelScript.total_staked(bets), 150)
	assert_eq(WheelScript.payout(_bet(WheelScript.Tier.ONE, 10),
		_first_segment(WheelScript.Tier.TWENTY)), 0, "a 1x bet loses on a 20x segment")


func test_a_bad_segment_or_an_empty_or_negative_bet_pays_nothing() -> void:
	assert_eq(WheelScript.payout(_bet(0, 10), -1), 0)
	assert_eq(WheelScript.payout(_bet(0, 10), WheelScript.SEGMENTS), 0)
	assert_eq(WheelScript.payout(WheelScript.empty_bets(), 2), 0)
	assert_eq(WheelScript.payout(_bet(0, -50), 2), 0)
	assert_eq(WheelScript.payout([] as Array[int], 2), 0)
	assert_eq(WheelScript.total_staked([5, -9, 5] as Array[int]), 10,
		"a negative entry is not a credit")


## THE ARITHMETIC IN THE CLASS COMMENT, exactly, as fractions of 45.
func test_every_tier_returns_its_exact_fraction_of_forty_five() -> void:
	var numerators: Array[int] = [42, 44, 42, 44, 42]
	for tier: int in WheelScript.TIERS:
		assert_almost_eq(WheelScript.tier_return(tier), float(numerators[tier]) / 45.0, 1e-12,
			WheelScript.TIER_LABELS[tier])


func test_the_sign_prints_the_worst_tier_and_it_is_a_modest_edge() -> void:
	assert_almost_eq(WheelScript.house_edge(), 3.0 / 45.0, 1e-12, "6.67 per cent at worst")
	assert_almost_eq(WheelScript.best_edge(), 1.0 / 45.0, 1e-12, "2.22 per cent at best")
	assert_eq("%.1f" % (WheelScript.house_edge() * 100.0), "6.7")
	for tier: int in WheelScript.TIERS:
		assert_between(WheelScript.tier_edge(tier), 0.02, 0.07,
			"no tier is a giveaway and none is a trap")


func test_a_spin_never_leaves_the_wheel_and_a_seed_repeats_it() -> void:
	var a := RandomNumberGenerator.new()
	a.seed = 42
	var b := RandomNumberGenerator.new()
	b.seed = 42
	for i in 500:
		var segment: int = WheelScript.spin(a)
		assert_between(segment, 0, WheelScript.SEGMENTS - 1)
		assert_eq(segment, WheelScript.spin(b))


## Every tier, backed at once, over a long seeded run, lands inside a couple of points of what
## the counts say. Not a proof (the fractions above are) but a check that spin() is uniform.
func test_a_long_seeded_run_converges_on_the_counted_returns() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261105
	var returned: Array[int] = [0, 0, 0, 0, 0]
	for i in SAMPLE_SPINS:
		var segment: int = WheelScript.spin(rng)
		for tier: int in WheelScript.TIERS:
			returned[tier] += WheelScript.payout(_bet(tier, 1), segment)
	for tier: int in WheelScript.TIERS:
		var measured: float = float(returned[tier]) / float(SAMPLE_SPINS)
		var tolerance: float = 0.05 if tier < WheelScript.Tier.TEN else 0.12
		assert_almost_eq(measured, WheelScript.tier_return(tier), tolerance,
			"%s measured %.3f" % [WheelScript.TIER_LABELS[tier], measured])


func test_the_rules_card_carries_no_dashes_and_prices_every_tier() -> void:
	var lines: Array[String] = WheelScript.rules_lines()
	assert_eq(lines.size(), WheelScript.TIERS + 2)
	for line in lines:
		assert_false(line.contains("--") or line.contains("—") or line.contains(" - "),
			line)
	for tier: int in WheelScript.TIERS:
		assert_true(lines[tier + 1].begins_with(WheelScript.TIER_LABELS[tier] + " pays %d to 1"
			% WheelScript.MULTIPLIERS[tier]), lines[tier + 1])
