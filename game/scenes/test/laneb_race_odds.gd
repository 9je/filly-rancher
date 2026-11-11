extends SceneTree
## P9 W3 item 48: does the race follow its odds? For each roster pony entered at happiness 0.5,
## 20000 races: shown chance to win, measured wins, where she finishes on average, and how far
## behind the winner she crosses the line.
##   --headless -s res://scenes/test/laneb_race_odds.gd
const RaceCardScript := preload("res://systems/race_card.gd")
const CompanyRunnersScript := preload("res://systems/company_runners.gd")


func _initialize() -> void:
	var runners = CompanyRunnersScript.load_shipped()
	for id in ["rarity", "braeburn", "scootaloo", "fluttershy", "derpyhooves", "rainbowdash"]:
		var data: PonyData = load("res://data/ponies/%s.tres" % id)
		var entrant := {"name": id, "uid": &"x", "data_id": StringName(id), "speed": data.base_speed,
			"stamina": data.base_stamina, "spirit": data.base_spirit, "happiness": 0.5, "stock": {}}
		var field: Array[Dictionary] = RaceCardScript.build_field(entrant, runners)
		var chance: float = RaceCardScript.win_chances(field)[0]
		var wins := 0
		var place_sum := 0.0
		var last := 0
		var gap_sum := 0.0
		var n := 20000
		for k in n:
			var r: Dictionary = RaceCardScript.run(field, k * 7919 + 13)
			var order: Array = r["order"]
			var place: int = order.find(0)
			if place == 0:
				wins += 1
			if place == order.size() - 1:
				last += 1
			place_sum += place + 1
			gap_sum += float(r["times"][0]) - float(r["times"][order[0]])
		var ratings := []
		for e in field:
			ratings.append(snappedf(float(e["rating"]), 0.01))
		print("RACE %s shown=%.3f won=%.3f avg_place=%.2f last=%.3f avg_gap=%.2fs ratings=%s" % [id,
			chance, float(wins) / n, place_sum / n, float(last) / n, gap_sum / n, ratings])
	quit(0)
