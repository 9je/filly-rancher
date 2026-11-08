extends GutTest
## A TOAST IS AN EVENT CARD (P8 S5): its picture comes from its own words, so the kind of news
## reads before the line does, and every picture it names is in the icon set.

const HudScript := preload("res://ui/hud.gd")


func test_the_news_picks_its_picture() -> void:
	assert_eq(HudScript.toast_icon_for("Lark Wish moved into the pen. It is now full."), "fence")
	assert_eq(HudScript.toast_icon_for("Shipment received: +26 bits"), "sold")
	assert_eq(HudScript.toast_icon_for("Caught Spitfire!"), "catch")
	assert_eq(HudScript.toast_icon_for("Post! The flag is up on your mailbox."), "letter")
	assert_eq(HudScript.toast_icon_for("Something else entirely"), "star")


func test_every_picture_named_is_in_the_set() -> void:
	for pair: Array in HudScript.TOAST_ICONS:
		assert_true(IconSet.has(String(pair[1])), "%s has no icon" % pair[1])
