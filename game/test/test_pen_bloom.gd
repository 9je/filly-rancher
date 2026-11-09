extends GutTest
## The Bloom in a pen (game/world/pen.gd + game/systems/bloom.gd): a well-kept Drifter
## finds her mark, gets a name and a talent, says so; a Calm Lamp or a canon record never
## Blooms; and a Bloomed pony survives a save as herself.

const PenScript := preload("res://world/pen.gd")
const PonyInstanceScript := preload("res://systems/pony_instance.gd")
const PlotDataScript := preload("res://systems/plot_data.gd")
const GeneratorScript := preload("res://systems/pony_generator.gd")
const PonyLookScript := preload("res://systems/pony_look.gd")
const PenReadoutScript := preload("res://world/pen_readout.gd")


func _pen() -> Pen:
	var pen: Pen = PenScript.new()
	var plot: PlotData = PlotDataScript.new()
	plot.id = &"pen"
	plot.capacity = 3
	pen.configure(plot, &"slot_bloom")
	autofree(pen)
	return pen


func _drifter(seed_value: int) -> PonyInstance:
	var inst := PonyInstanceScript.create(&"stock_curious")
	inst.stock = GeneratorScript.generate(seed_value).to_dict()
	inst.happiness = 1.0
	inst.hunger = 0.0
	return inst


func test_a_well_kept_drifter_blooms_with_a_name_and_a_talent() -> void:
	var pen := _pen()
	var a := _drifter(11)
	var b := _drifter(12)
	pen.add_pony(a)
	pen.add_pony(b)
	watch_signals(pen)
	for i in range(400):
		a.happiness = 1.0
		a.hunger = 0.0
		a.favorite_glow = 100.0
		b.happiness = 1.0
		b.hunger = 0.0
		pen.tick(1.0)
	assert_true(a.is_marked(), "after 400 s of the best care she has her mark")
	assert_signal_emitted(pen, "bloomed")
	assert_ne(a.nickname, "", "and a name")
	var look := PonyLookScript.from_stock(a.stock)
	assert_true(MarkComposer.TALENTS.has(look.mark.get("talent", &"")))


func test_a_calm_lamp_stops_the_bloom() -> void:
	var pen := _pen()
	pen.calm_lamp = true
	var a := _drifter(21)
	pen.add_pony(a)
	for i in range(2000):
		a.happiness = 1.0
		a.hunger = 0.0
		a.favorite_glow = 100.0
		pen.tick(1.0)
	assert_false(a.is_marked())
	assert_eq(a.bloom, 0.0)


func test_a_bloomed_pony_round_trips_through_a_save() -> void:
	var pen := _pen()
	var a := _drifter(31)
	pen.add_pony(a)
	pen.bloom_now(a)
	var back := PonyInstanceScript.from_dict(JSON.parse_string(JSON.stringify(a.to_dict())))
	assert_true(back.is_marked())
	assert_eq(back.nickname, a.nickname)
	assert_eq(back.stock, a.stock)
	assert_eq(back.bloom, 1.0)


# --- P8: the readout's data (playtest 2026-11-08 items 2, 10) --------------------------------

func test_bloom_status_names_her_reason_and_her_favourite() -> void:
	var pen := _pen()
	var a := _drifter(41)
	pen.add_pony(a)
	var pantry := Inventory.new()
	pen.inventory_provider = func() -> Inventory: return pantry
	a.hunger = 0.9
	var s := pen.bloom_status(a)
	assert_true(bool(s["drifter"]), "a blank stock pony is a Drifter")
	assert_eq(s["reason"], &"hungry")
	assert_false(is_finite(float(s["seconds_left"])), "hungry: she is stopped, and it says so")
	assert_false(bool(s["favorite_stocked"]))
	pantry.add(PonyTraits.favorite_of(a), 2)
	a.hunger = 0.1
	s = pen.bloom_status(a)
	assert_true(bool(s["favorite_stocked"]), "her favourite in the pantry is shown")
	assert_ne(s["reason"], &"hungry")
	var words: String = PenReadoutScript.words_for(s)
	assert_true(words.begins_with("Drifter"), "the tag calls her a Drifter: %s" % words)
	assert_true(words.contains("Loves"), "and names her favourite")


func test_a_full_grand_pen_of_drifters_keeps_blooming() -> void:
	var pen: Pen = PenScript.new()
	var plot: PlotData = PlotDataScript.new()
	plot.capacity = 8
	pen.configure(plot, &"slot_grand")
	autofree(pen)
	var all: Array[PonyInstance] = []
	for i in 8:
		var d := _drifter(60 + i)
		all.append(d)
		pen.add_pony(d)
	for i in range(120):
		for d in all:
			d.happiness = 1.0
			d.hunger = 0.0
			d.favorite_glow = 100.0
		pen.tick(1.0)
	for d in all:
		assert_gt(d.bloom, 0.0, "eight in a Grand pen still make progress (CROWDED_AT froze them)")
