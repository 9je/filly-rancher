class_name PonySurprise
extends RefCounted
## THE CREATOR'S "SURPRISE ME" (PT11; playtest 2026-11-05: "maybe random on pony creation?"),
## rolled here because nothing under game/ui/ may roll anything (test_casino_paint): a whole
## new look as indices the creator applies. `seed_value` below zero rolls a fresh one.

const PlayerLookScript := preload("res://systems/player_look.gd")
const MarkComposerScript := preload("res://systems/mark_composer.gd")


static func roll(seed_value: int, coats: int, manes: int, eyes: int, inks: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	var race := rng.randi_range(0, PlayerLookScript.RACE_NAMES.size() - 1)
	var talents := MarkComposerScript.talent_ids()
	return {
		"race": race,
		"mane_style": rng.randi_range(0, maxi(1, PlayerLookScript.style_count(race)) - 1),
		"coat": rng.randi_range(0, maxi(1, coats) - 1),
		"mane": rng.randi_range(0, maxi(1, manes) - 1),
		"eyes": rng.randi_range(0, maxi(1, eyes) - 1),
		"mane2": rng.randi_range(-1, manes - 1) if rng.randf() < 0.5 else -1,
		"tail": rng.randi_range(-1, manes - 1) if rng.randf() < 0.4 else -1,
		"motif": rng.randi_range(0, 2),
		"ink": rng.randi_range(0, maxi(1, inks) - 1),
		"talent": talents[rng.randi_range(0, talents.size() - 1)],
	}
