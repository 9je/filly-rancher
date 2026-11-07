extends GutTest
## MUSIC THAT FOLLOWS THE MOMENT, FINISHED (PS10, known gap G5; FS5.2: "Market and Depot music
## contexts; the duck at 4 dB"). At the Market counter the score turns to the town's carefree
## tune; at the Depot's counter the same tune is heard as if from behind the glass (a low
## pass on the music bus); anywhere else it is day, night or the casino as before. A sting
## ducks the bed 4 dB.

const MusicScript := preload("res://systems/music.gd")
const RanchScript := preload("res://world/ranch.gd")
const SoundScript := preload("res://systems/sound.gd")


func test_the_counters_have_their_own_music() -> void:
	assert_eq(RanchScript.music_context(&"ranch", false, true, false), &"market")
	assert_eq(RanchScript.music_context(&"ranch", true, false, true), &"depot", "even at night")
	assert_eq(RanchScript.music_context(&"ranch", false, false, false), &"day")
	assert_eq(RanchScript.music_context(&"ranch", true, false, false), &"night")
	assert_eq(RanchScript.music_context(SoundScript.ZONE_CASINO, false, false, false), &"casino")
	for ctx: StringName in [&"market", &"depot"]:
		assert_true(MusicScript.TRACKS.has(ctx), "%s has a track" % ctx)


func test_the_depot_is_heard_through_the_glass() -> void:
	var m: Node = MusicScript.new()
	add_child_autofree(m)
	await wait_frames(1)
	m.call("play_context", &"depot")
	assert_true(bool(m.call("muffled")), "the Depot muffles the score")
	m.call("play_context", &"market")
	assert_false(bool(m.call("muffled")), "the Market does not")


func test_the_duck_is_four_db() -> void:
	assert_eq(MusicScript.DUCK_DB, 4.0)
