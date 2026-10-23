class_name PonyGenerator
extends RefCounted
## MAKES A PONY FROM A SEED. Every pony in the game comes from here: the same seed always
## gives the same pony, so a Drifter respawned from a save, or a story character from her
## fixed seed, is herself every time.
##
## Harmony, not dice: the coat is drawn from the curated swatches, and the mane is chosen
## among swatches that relate to it the way the show's palettes do (analogous, a hue step
## or two away, or complementary across the wheel), more saturated and a step darker. The
## second mane tone is a lighter or shifted take on the first. Eyes sit near the mane hue
## or across from the coat.

const ParamsScript := preload("res://systems/pony_gen_params.gd")
const DonorTableScript := preload("res://systems/donor_table.gd")
const MarkComposerScript := preload("res://systems/mark_composer.gd")

const PARAMS_PATH := "res://data/pony_gen.tres"
const RACES: Array[StringName] = [&"earth", &"pegasus", &"unicorn"]
const VARIANTS: Array[StringName] = [&"pearl", &"starry", &"ember"]

## Coat and mane pairs a player would read as a canon character at a glance (the main six
## and the wall-eyed mailmare). A draw within CANON_TOLERANCE of one on both coat and mane
## re-draws its mane; the brief bans canon characters, and color alone can name one.
const CANON_SIGNATURES: Array = [
	[Color(0.78, 0.79, 0.84), Color(0.98, 0.93, 0.62)],
	[Color(0.80, 0.66, 0.90), Color(0.17, 0.20, 0.45)],
	[Color(0.97, 0.97, 0.98), Color(0.42, 0.30, 0.66)],
	[Color(1.00, 0.95, 0.62), Color(0.95, 0.68, 0.80)],
	[Color(0.97, 0.72, 0.86), Color(0.93, 0.27, 0.56)],
	[Color(0.98, 0.76, 0.42), Color(0.98, 0.93, 0.62)],
	[Color(0.62, 0.84, 0.98), Color(0.90, 0.25, 0.25)],
]
const CANON_TOLERANCE := 0.16

static var _params: PonyGenParams


static func params() -> PonyGenParams:
	if _params == null:
		var res: Resource = load(PARAMS_PATH)
		_params = res as PonyGenParams if res is PonyGenParams else ParamsScript.new()
	return _params


## A complete look from `pony_seed`. `opts` may pin: race (StringName), foal (bool),
## variant (StringName), marked (bool: give her a mark now), talent (StringName).
static func generate(pony_seed: int, opts: Dictionary = {}) -> PonyLook:
	var p := params()
	var rng := RandomNumberGenerator.new()
	rng.seed = pony_seed
	var look := PonyLook.new()
	look.rng_seed = pony_seed
	look.foal = bool(opts.get("foal", false))
	look.race = StringName(opts.get("race", _pick_race(rng, p)))
	var table := DonorTableScript.load_table()
	var pool: Array[StringName] = table.for_race(look.race, look.foal)
	if pool.is_empty():
		pool = table.for_race(&"earth", look.foal)
	if pool.is_empty():
		pool = table.ids()
	if not pool.is_empty():
		look.donor = pool[rng.randi_range(0, pool.size() - 1)]
	look.variant = StringName(opts.get("variant", &""))
	_colors(look, rng, p)
	if look.variant != &"":
		_apply_variant(look, rng)
	if bool(opts.get("marked", false)):
		bloom(look, rng, StringName(opts.get("talent", &"")))
	return look


## Give `look` a mark (the Bloom). Uses `rng`, or a generator seeded from the look's own
## seed so the same pony always Blooms into the same talent.
static func bloom(look: PonyLook, rng: RandomNumberGenerator = null, talent: StringName = &"") -> void:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.seed = look.rng_seed ^ 0x5eed
	var talents: Array[StringName] = MarkComposerScript.talent_ids()
	if talent == &"" or not MarkComposerScript.TALENTS.has(talent):
		talent = talents[rng.randi_range(0, talents.size() - 1)]
	var a := _vivid(look.mane.lerp(look.eyes, rng.randf_range(0.0, 0.5)))
	var b := _vivid(look.mane2 if rng.randf() < 0.5 else look.eyes.lightened(0.3))
	look.mark = {"talent": talent, "motif": rng.randi_range(0, 2), "a": a, "b": b}


## A two-word name from `pony_seed`.
static func make_name(pony_seed: int) -> String:
	var p := params()
	var rng := RandomNumberGenerator.new()
	rng.seed = pony_seed ^ 0x7a3e
	if p.name_first.is_empty() or p.name_second.is_empty():
		return "Pony"
	var first := p.name_first[rng.randi_range(0, p.name_first.size() - 1)]
	var second := p.name_second[rng.randi_range(0, p.name_second.size() - 1)]
	if first == second:
		second = p.name_second[(p.name_second.find(second) + 1) % p.name_second.size()]
	return "%s %s" % [first, second]


## A shade name for a coat ("Peach Sunrise No. 4"), for the Rainbow Dye labels.
static func shade_name(c: Color, number: int) -> String:
	var hue_words := ["Rose", "Coral", "Peach", "Apricot", "Butter", "Lemon", "Pistachio",
		"Meadow", "Mint", "Seafoam", "Lagoon", "Sky", "Cornflower", "Periwinkle", "Lilac",
		"Orchid", "Berry", "Blush"]
	var light_words := ["Dusk", "Hearth", "Sunrise", "Morning", "Cloud"]
	var word: String
	if c.s < 0.12:
		word = "Moonbeam" if c.v > 0.8 else "Pewter"
	else:
		word = hue_words[clampi(int(c.h * hue_words.size()), 0, hue_words.size() - 1)]
	var tail: String = light_words[clampi(int(c.v * light_words.size()), 0, light_words.size() - 1)]
	return "%s %s No. %d" % [word, tail, number]


static func _pick_race(rng: RandomNumberGenerator, p: PonyGenParams) -> StringName:
	var w := p.race_weights
	var total := 0.0
	for x in w:
		total += x
	var roll := rng.randf() * maxf(total, 0.0001)
	for i in range(mini(w.size(), RACES.size())):
		roll -= w[i]
		if roll <= 0.0:
			return RACES[i]
	return &"earth"


static func _colors(look: PonyLook, rng: RandomNumberGenerator, p: PonyGenParams) -> void:
	if p.coats.is_empty() or p.manes.is_empty() or p.eyes.is_empty():
		return
	look.coat = p.coats[rng.randi_range(0, p.coats.size() - 1)]
	# Score every mane swatch against the coat; draw among the best few.
	var scored: Array = []
	for m: Color in p.manes:
		scored.append([_harmony(look.coat, m) + rng.randf() * 0.35, m])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var top: int = mini(5, scored.size())
	look.mane = scored[rng.randi_range(0, top - 1)][1]
	for attempt in range(6):
		if not reads_as_canon(look.coat, look.mane):
			break
		look.mane = scored[rng.randi_range(0, scored.size() - 1)][1]
	if rng.randf() < 0.55:
		# A lighter streak of the same hue.
		look.mane2 = look.mane.lerp(Color.WHITE, rng.randf_range(0.3, 0.5))
	else:
		# A neighboring hue, the show's two-tone manes.
		var h := fposmod(look.mane.h + rng.randf_range(-0.12, 0.12), 1.0)
		look.mane2 = Color.from_hsv(h, clampf(look.mane.s * 0.9, 0.0, 1.0), clampf(look.mane.v * 1.08, 0.0, 1.0))
	look.tail = look.mane if rng.randf() < 0.75 else look.mane2
	var best_eye: Color = p.eyes[0]
	var best := -INF
	for e: Color in p.eyes:
		var near_mane := 1.0 - _hue_gap(e, look.mane) * 2.0
		var across_coat := _hue_gap(e, look.coat) * 2.0
		var s := maxf(near_mane, across_coat * 0.8) + rng.randf() * 0.6
		if s > best:
			best = s
			best_eye = e
	look.eyes = best_eye


## True when coat `c` with mane `m` is one of CANON_SIGNATURES.
static func reads_as_canon(c: Color, m: Color) -> bool:
	for sig: Array in CANON_SIGNATURES:
		if _near(c, sig[0]) and _near(m, sig[1]):
			return true
	return false


static func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < CANON_TOLERANCE and absf(a.g - b.g) < CANON_TOLERANCE \
		and absf(a.b - b.b) < CANON_TOLERANCE


## How well mane `m` sits on coat `c`. Higher is better.
static func _harmony(c: Color, m: Color) -> float:
	var gap := _hue_gap(c, m)
	var analog := 1.0 - absf(gap - 0.12) / 0.12
	var comp := 1.0 - absf(gap - 0.5) / 0.15
	var hue := maxf(maxf(analog, comp), 0.0)
	if c.s < 0.12:
		hue = 0.8 # Whites and greys wear anything.
	var sat := clampf((m.s - c.s) * 1.6, 0.0, 1.0)
	var contrast := clampf((c.v - m.v) * 2.5 + 0.3, 0.0, 1.0)
	return hue * 1.2 + sat * 0.8 + contrast * 0.6


static func _hue_gap(a: Color, b: Color) -> float:
	var d := absf(a.h - b.h)
	return minf(d, 1.0 - d)


static func _vivid(c: Color) -> Color:
	return Color.from_hsv(c.h, clampf(maxf(c.s, 0.55), 0.0, 1.0), clampf(maxf(c.v, 0.6), 0.0, 1.0))


static func _apply_variant(look: PonyLook, rng: RandomNumberGenerator) -> void:
	match look.variant:
		&"pearl":
			look.coat = Color(0.99, 0.97, 1.0)
			look.mane = Color.from_hsv(rng.randf(), 0.35, 1.0)
			look.mane2 = Color.from_hsv(fposmod(look.mane.h + 0.33, 1.0), 0.35, 1.0)
			look.tail = look.mane2
			look.eyes = Color(0.62, 0.45, 0.95)
		&"starry":
			look.coat = Color(0.16, 0.18, 0.38)
			look.mane = Color(0.36, 0.42, 0.95)
			look.mane2 = Color(0.85, 0.9, 1.0)
			look.tail = look.mane
			look.eyes = Color(0.95, 0.85, 0.35)
		&"ember":
			look.coat = Color(0.35, 0.22, 0.2)
			look.mane = Color(0.98, 0.42, 0.14)
			look.mane2 = Color(1.0, 0.82, 0.3)
			look.tail = look.mane
			look.eyes = Color(0.98, 0.7, 0.2)
