extends GutTest
## Tests for SpawnTable (game/systems/spawn_table.gd). Preloads by path rather
## than referencing the global class_name, matching the convention documented
## at the top of game/scripts/pony_rig.gd (the global class cache lives in the
## gitignored game/.godot/ and a fresh clone hasn't built it yet).

const SpawnTableScript := preload("res://systems/spawn_table.gd")
const PonyDataScript := preload("res://systems/pony_data.gd")


## Builds an inline PonyData with the given id/rarity -- inline is preferred
## over loading the real .tres fixtures here since these tests are about
## verifying weight distribution, and inline entries let each test control
## exactly which rarities are present without depending on how many real
## pony files happen to exist on disk.
func _make_pony(id: StringName, rarity: int) -> PonyData:
	var data: PonyData = PonyDataScript.new()
	data.id = id
	data.rarity = rarity
	return data


func test_draw_only_returns_supplied_entries() -> void:
	var a := _make_pony(&"a", PonyDataScript.Rarity.COMMON)
	var b := _make_pony(&"b", PonyDataScript.Rarity.RARE)
	var entries: Array[PonyData] = [a, b]
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var table := SpawnTableScript.new(entries, rng)

	var seen_ids := {}
	for i in range(200):
		var drawn: PonyData = table.draw()
		seen_ids[drawn.id] = true

	for id in seen_ids.keys():
		assert_true(id == &"a" or id == &"b", "draw() returned an id not in the supplied entries: %s" % id)


func test_distribution_matches_configured_weights_within_tolerance() -> void:
	# One entry per rarity so the observed per-rarity draw fraction directly
	# reflects SpawnTable.WEIGHTS.
	var entries: Array[PonyData] = [
		_make_pony(&"common", PonyDataScript.Rarity.COMMON),
		_make_pony(&"uncommon", PonyDataScript.Rarity.UNCOMMON),
		_make_pony(&"rare", PonyDataScript.Rarity.RARE),
		_make_pony(&"legendary", PonyDataScript.Rarity.LEGENDARY),
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var table := SpawnTableScript.new(entries, rng)

	var counts := {
		PonyDataScript.Rarity.COMMON: 0,
		PonyDataScript.Rarity.UNCOMMON: 0,
		PonyDataScript.Rarity.RARE: 0,
		PonyDataScript.Rarity.LEGENDARY: 0,
	}
	const DRAWS := 10000
	for i in range(DRAWS):
		var drawn: PonyData = table.draw()
		counts[drawn.rarity] += 1

	var total_weight := 0.0
	for w in SpawnTableScript.WEIGHTS.values():
		total_weight += w

	# Tolerance note: this is NOT a true statistical confidence bound (we'd
	# need to derive it from the binomial variance at a chosen confidence
	# level, e.g. via a normal approximation with a z-score). It is instead a
	# tolerance picked to comfortably fit the actual result produced by this
	# fixed seed (12345) at 10,000 draws, while still being tight enough to
	# catch a real implementation bug (e.g. swapped weights, off-by-one
	# bucket boundaries, or uniform-instead-of-weighted selection). A
	# genuinely flaky statistical test would need to either fix the seed
	# (which we do) or compute a proper confidence interval per rarity
	# bucket; since the seed is fixed, every run of this test is
	# deterministic, so "3 percentage points" is a comfortable, honest
	# margin around the expected percentage for this one seed -- not a
	# probabilistic guarantee that would hold for an arbitrary seed.
	# Observed with seed 12345, DRAWS=10000: COMMON 60.56% (expected 60%),
	# UNCOMMON 24.54% (25%), RARE 11.97% (12%), LEGENDARY 2.93% (3%) -- all
	# within ~1 point of expected, comfortably inside the 3pp margin.
	const TOLERANCE_PCT := 3.0

	for rarity in SpawnTableScript.WEIGHTS.keys():
		var expected_pct: float = (SpawnTableScript.WEIGHTS[rarity] / total_weight) * 100.0
		var observed_pct: float = (float(counts[rarity]) / float(DRAWS)) * 100.0
		assert_almost_eq(
			observed_pct,
			expected_pct,
			TOLERANCE_PCT,
			"rarity %s: observed %.2f%%, expected %.2f%% (+/- %.1f)" % [
				rarity, observed_pct, expected_pct, TOLERANCE_PCT
			]
		)


func test_tier_weight_is_split_evenly_across_entries_sharing_a_rarity() -> void:
	# Three RARE entries + one UNCOMMON entry. Per-TIER semantics: RARE (the
	# tier) gets its fixed WEIGHTS share (12) regardless of how many entries
	# occupy it, split evenly three ways; UNCOMMON gets its fixed share (25).
	# A *per-entry* implementation would instead give RARE 3x its per-entry
	# weight (36) against UNCOMMON's 25 -- inverting which tier draws more
	# often. This fixture is deliberately NOT one-entry-per-rarity (unlike
	# test_distribution_matches_configured_weights_within_tolerance above) --
	# with exactly one entry per tier, per-entry and per-tier weighting are
	# mathematically identical, so that test cannot distinguish the two
	# semantics. This one can and does.
	var rare_a := _make_pony(&"rare_a", PonyDataScript.Rarity.RARE)
	var rare_b := _make_pony(&"rare_b", PonyDataScript.Rarity.RARE)
	var rare_c := _make_pony(&"rare_c", PonyDataScript.Rarity.RARE)
	var uncommon := _make_pony(&"uncommon", PonyDataScript.Rarity.UNCOMMON)
	var entries: Array[PonyData] = [rare_a, rare_b, rare_c, uncommon]
	var rng := RandomNumberGenerator.new()
	rng.seed = 555
	var table := SpawnTableScript.new(entries, rng)

	var per_entry_counts := {
		&"rare_a": 0, &"rare_b": 0, &"rare_c": 0, &"uncommon": 0,
	}
	const DRAWS := 10000
	for i in range(DRAWS):
		var drawn: PonyData = table.draw()
		per_entry_counts[drawn.id] += 1

	var rare_total: int = per_entry_counts[&"rare_a"] + per_entry_counts[&"rare_b"] + per_entry_counts[&"rare_c"]
	var uncommon_total: int = per_entry_counts[&"uncommon"]

	# Expected tier shares under per-tier weighting: RARE 12/(25+12) =
	# 32.43%, UNCOMMON 25/37 = 67.57%. Same tolerance-honesty note as the
	# other distribution test: this is a seed-fit margin (verified against
	# seed 555 at 10,000 draws below), not a derived confidence interval --
	# but it is comfortably wide of the ~27-point gap between the per-tier
	# and per-entry predictions (32% vs 59% for RARE), so it can't pass
	# under the old per-entry semantics by accident. Observed with seed 555,
	# DRAWS=10000, current (per-tier) implementation: RARE 3298/10000 =
	# 32.98% (expected 32.43%, delta 0.55), UNCOMMON 6702/10000 = 67.02%
	# (expected 67.57%, delta 0.55) -- both well inside the 4pp margin.
	# Re-run against the OLD per-entry implementation (git show
	# HEAD:game/systems/spawn_table.gd from the Task 6A commit) before this
	# fix: RARE 5871/10000 = 58.71% -- fails hard, off by 26+ points, proving
	# this test has teeth.
	var rare_tier_weight: float = SpawnTableScript.WEIGHTS[PonyDataScript.Rarity.RARE]
	var uncommon_tier_weight: float = SpawnTableScript.WEIGHTS[PonyDataScript.Rarity.UNCOMMON]
	var tier_total_weight := rare_tier_weight + uncommon_tier_weight
	var expected_rare_pct: float = (rare_tier_weight / tier_total_weight) * 100.0
	var expected_uncommon_pct: float = (uncommon_tier_weight / tier_total_weight) * 100.0
	const TIER_TOLERANCE_PCT := 4.0

	assert_almost_eq(
		(float(rare_total) / float(DRAWS)) * 100.0,
		expected_rare_pct,
		TIER_TOLERANCE_PCT,
		"RARE tier aggregate share should match its WEIGHTS entry (12), not 3x it"
	)
	assert_almost_eq(
		(float(uncommon_total) / float(DRAWS)) * 100.0,
		expected_uncommon_pct,
		TIER_TOLERANCE_PCT,
		"UNCOMMON tier aggregate share should match its WEIGHTS entry (25)"
	)

	# Within the RARE tier, the three entries should split that tier's draws
	# roughly evenly (each ~1/3). Generous relative tolerance (25%) since
	# this is a three-way split of a smaller sub-sample, not the full 10,000.
	# Observed (seed 555): rare_a=1074, rare_b=1143, rare_c=1081 against an
	# expected ~1099.3 each -- all within the 25% band.
	var expected_per_rare_entry := float(rare_total) / 3.0
	for entry_id in [&"rare_a", &"rare_b", &"rare_c"]:
		assert_almost_eq(
			float(per_entry_counts[entry_id]),
			expected_per_rare_entry,
			expected_per_rare_entry * 0.25,
			"entry %s should get roughly 1/3 of the RARE tier's draws" % entry_id
		)


func test_empty_table_returns_null_not_a_crash() -> void:
	var entries: Array[PonyData] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var table := SpawnTableScript.new(entries, rng)
	assert_null(table.draw())


func test_single_entry_table_always_returns_it() -> void:
	var only := _make_pony(&"only", PonyDataScript.Rarity.LEGENDARY)
	var entries: Array[PonyData] = [only]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var table := SpawnTableScript.new(entries, rng)

	for i in range(50):
		var drawn: PonyData = table.draw()
		assert_eq(drawn, only, "single-entry table must always return that entry")
