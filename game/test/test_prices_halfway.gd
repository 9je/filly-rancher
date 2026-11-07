extends GutTest
## PENS, PERMITS, GEAR AND DECOR COST ABOUT 15% MORE (PS9, playtest 2026-11-05 item 69; the
## owner chose halfway). Food is untouched; every raised price is a round five.

const FOOD := ["apple", "carrot", "daisy", "daffodil", "hay"]
const WAS := {"permit_orchard": 150, "permit_everfree": 1200, "long_beam": 200,
	"decor_well": 1200, "bigger_saddlebag": 120}


func test_prices_are_up_by_about_fifteen_percent_and_round() -> void:
	for id: String in WAS:
		var item: Resource = load("res://data/shop/%s.tres" % id)
		var want := float(WAS[id]) * 1.15
		assert_almost_eq(float(item.cost), want, 2.5, id)
		assert_eq(int(item.cost) % 5, 0, "%s is a round five" % id)
	assert_eq(int(load("res://data/plots/pen_large.tres").cost), 175)
	assert_eq(int(load("res://data/plots/pen_grand.tres").cost), 550)


func test_food_costs_the_same() -> void:
	var want := {"apple": 30, "carrot": 30, "daisy": 30, "daffodil": 36, "hay": 20}
	for id: String in FOOD:
		assert_eq(int(load("res://data/shop/%s.tres" % id).cost), want[id], id)
