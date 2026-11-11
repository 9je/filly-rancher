extends GutTest
## Items 39 and 71 (playtest 2026-11-10): UI never sits on a face. The placement is judged
## from real frames (Lane B round 3, lb5/talk1, lb5/fac1); these pin the picker's rule.

const FaceGuardScript := preload("res://ui/face_guard.gd")


func test_the_first_spot_clear_of_every_face_wins() -> void:
	var faces: Array[Rect2] = [Rect2(100, 100, 80, 80)]
	var spots: Array[Rect2] = [Rect2(110, 120, 60, 30), Rect2(300, 120, 60, 30), Rect2(0, 0, 60, 30)]
	assert_eq(FaceGuardScript.pick(spots, faces), 1)


func test_with_no_clear_spot_the_least_covering_wins() -> void:
	var faces: Array[Rect2] = [Rect2(0, 0, 100, 100)]
	var spots: Array[Rect2] = [Rect2(0, 0, 50, 50), Rect2(80, 80, 50, 50)]
	assert_eq(FaceGuardScript.pick(spots, faces), 1)


func test_a_clear_spot_is_kept_so_the_box_does_not_hop() -> void:
	var faces: Array[Rect2] = [Rect2(100, 100, 80, 80)]
	var spots: Array[Rect2] = [Rect2(300, 0, 60, 30), Rect2(0, 0, 60, 30)]
	assert_eq(FaceGuardScript.pick(spots, faces, 1), 1, "the last pick stays while still clear")
	faces.append(Rect2(0, 0, 70, 40))
	assert_eq(FaceGuardScript.pick(spots, faces, 1), 0, "and moves once a face comes under it")


func test_clamp_keeps_a_spot_on_screen_under_the_banner() -> void:
	var r: Rect2 = FaceGuardScript.clamp_rect(Rect2(-50, -50, 200, 100), Rect2(0, 0, 1600, 900), 32.0, 150.0)
	assert_eq(r.position, Vector2(32, 150))
	r = FaceGuardScript.clamp_rect(Rect2(1500, 850, 200, 100), Rect2(0, 0, 1600, 900), 32.0, 150.0)
	assert_eq(r.position, Vector2(1600 - 200 - 32, 900 - 100 - 32))
