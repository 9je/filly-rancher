extends GutTest
## A FULL PEN SPREADS OUT (playtest 2026-11-05 item 65, "Full pen: ponies pile in one corner,
## overlap, push through the fence" [52]; and 17b, ponies merging). Eight residents of a Grand
## Pen, left for a minute and a half: they use the paddock rather than heaping in its middle,
## nobody stands inside anybody, and nobody is past the rails.

const PenScript := preload("res://world/pen.gd")
const PonyInstanceScript := preload("res://systems/pony_instance.gd")
const EIGHT := [&"twilight", &"rarity", &"pinkiepie", &"rainbowdash", &"applejack", &"fluttershy",
	&"lyra", &"bonbon"]


func before_all() -> void:
	PonyTraits.quirks_enabled = false


func after_all() -> void:
	PonyTraits.quirks_enabled = true


func _full_pen() -> Pen:
	var floor := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 1, 40)
	shape.shape = box
	shape.position = Vector3(0, -0.5, 0)
	floor.add_child(shape)
	floor.collision_layer = 0xFFFF
	add_child_autofree(floor)
	var pen: Pen = PenScript.new()
	pen.capacity = EIGHT.size()
	pen.slot_id = &"slot_spread"
	add_child_autofree(pen)
	for id: StringName in EIGHT:
		assert_true(pen.add_pony(PonyInstanceScript.create(id)))
	return pen


class Farmer:
	extends CharacterBody3D
	func is_sneaking() -> bool:
		return false


## The owner in [52]: outside the fence at a corner.
func _farmer_at_corner(pen: Pen) -> void:
	var body := Farmer.new()
	body.add_to_group(&"player")
	body.collision_layer = preload("res://world/collision_layers.gd").PLAYER
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.3
	shape.shape = capsule
	shape.position = Vector3(0.0, 0.65, 0.0)
	body.add_child(shape)
	add_child_autofree(body)
	body.global_position = pen.global_position + Vector3(Pen.HALF_EXTENT + 0.9, 0.0, Pen.HALF_EXTENT + 0.9)


func _measure(pen: Pen) -> Dictionary:
	var fps: Array[Dictionary] = []
	var centre := Vector2.ZERO
	var outside := 0
	var n := pen.ponies().size()
	for inst: PonyInstance in pen.ponies():
		var b := pen.body_for(inst.uid)
		fps.append(BodySpace.footprint_of(b))
		var local := pen.to_local(b.global_position)
		centre += Vector2(local.x, local.z) / n
		if absf(local.x) > Pen.HALF_EXTENT or absf(local.z) > Pen.HALF_EXTENT:
			outside += 1
	var touching := {}
	for i in fps.size():
		for j in range(i + 1, fps.size()):
			if BodySpace.overlap(fps[i], fps[j]) > INSIDE:
				touching["%d-%d" % [i, j]] = true
	return {"inside": touching, "outside": outside, "centre": centre.length()}


## Deeper than this, two bodies read as one inside the other (the footprint is 0.6 m wide).
const INSIDE := 0.15


## Ninety seconds; from the thirtieth, once a second: nobody past the rails, the herd not in
## one corner, nobody walking up to the farmer at the rails (how [52]'s heap formed: every
## curious resident made for the edge nearest him), and no two bodies inside each other for
## two checks running (a brush in passing is not a heap).
func _watch(pen: Pen) -> void:
	var last := {}
	for second in 90:
		await wait_physics_frames(60)
		if second < 30:
			continue
		var m := _measure(pen)
		assert_eq(int(m.outside), 0, "nobody past the rails at %d s" % second)
		for inst: PonyInstance in pen.ponies():
			assert_ne(int(pen.body_for(inst.uid).get("state")), Pony.State.APPROACH,
				"%s is not walking up to the farmer at the rails at %d s" % [inst.data_id, second])
		assert_lt(float(m.centre), 1.5, "the herd is not all in one corner at %d s" % second)
		for pair: String in m.inside:
			assert_false(last.has(pair), "two residents still inside each other at %d s (%s)" % [second, pair])
		last = m.inside


func test_eight_residents_keep_out_of_each_other() -> void:
	await _watch(_full_pen())


func test_with_the_farmer_at_a_corner_they_do_not_heap_against_it() -> void:
	var pen := _full_pen()
	_farmer_at_corner(pen)
	await _watch(pen)


## Mean distance from each resident to her nearest neighbour, centre to centre (pen-local, m).
func _nearest_mean(pen: Pen) -> float:
	var at: Array[Vector2] = []
	for inst: PonyInstance in pen.ponies():
		var l := pen.to_local(pen.body_for(inst.uid).global_position)
		at.append(Vector2(l.x, l.z))
	var sum := 0.0
	for i in at.size():
		var best := INF
		for j in at.size():
			if i != j:
				best = minf(best, at[i].distance_to(at[j]))
		sum += best
	return sum / float(at.size())


## The acceptance review of item 65: "at 60 to 75 s the residents are still one clump in the
## pen's middle, bodies crossing each other". A full pen keeps daylight between its residents:
## from the thirtieth second, every resident's nearest neighbour is on average more than a
## body's width and a half away (centres 1.3 m; a pony is 0.72 m wide and 1.6 m long), and the
## herd's average over the minute is wider still.
const SPREAD_EACH := 1.3
const SPREAD_MEAN := 1.6


func test_a_full_pen_keeps_daylight_between_its_residents() -> void:
	var pen := _full_pen()
	var worst := INF
	var total := 0.0
	var checks := 0
	for second in 90:
		await wait_physics_frames(60)
		if second < 30:
			continue
		var m := _nearest_mean(pen)
		worst = minf(worst, m)
		total += m
		checks += 1
	gut.p("nearest neighbour, mean per check: worst %.2f m, over the minute %.2f m" % [worst, total / checks])
	assert_gt(worst, SPREAD_EACH, "never a clump (worst check %.2f m)" % worst)
	assert_gt(total / checks, SPREAD_MEAN, "spread over the minute (%.2f m)" % (total / checks))
