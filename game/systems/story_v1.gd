class_name StoryV1
extends RefCounted
## THE v1 STORY STATE, ON TOP OF Story (game/systems/story.gd). Story already keeps the
## chapter, the flags and the mail; this adds the reveal, the path and the tallies the
## endings read, kept in Story.vars so they survive a save as themselves, and the dread dial
## as a pure function of all of it (STORY.md section 9).
##
## Chapters keep their old names and take v1 meanings: SUNNY is Act One, WEATHER is Act
## Two, CONTACT is Color Day (the reveal), COMPANY is the Factory path, RESISTANCE the
## Rescue path.

const PATH_FACTORY := "factory"
const PATH_RESCUE := "rescue"
const ALLIES: Array[String] = ["ally_pip", "ally_bramble", "ally_fennel"]
const PYLONS := 4


static func path(story: Story) -> String:
	return str(story.get_var("path", "")) if story != null else ""


static func revealed(story: Story) -> bool:
	return path(story) != ""


## The reveal's choice (STORY.md R.6): set the path, move the chapter onto it.
static func choose_path(story: Story, p: String) -> void:
	if story == null or revealed(story) or not (p in [PATH_FACTORY, PATH_RESCUE]):
		return
	story.set_var("path", p)
	story.set_flag("reveal_done")
	story.chapter = Story.Chapter.COMPANY if p == PATH_FACTORY else Story.Chapter.RESISTANCE


static func allies(story: Story) -> int:
	var n := 0
	for f in ALLIES:
		if story.has_flag(f):
			n += 1
	return n


## Ponies delivered since the reveal, read off the Pony Book's delivery log.
static func delivered_after_reveal(book: PonyBook) -> int:
	var n := 0
	if book == null:
		return 0
	for d: Dictionary in book.delivered:
		if bool(d.get("after_reveal", false)):
			n += 1
	return n


## Everything Endings.select() reads.
static func ending_input(story: Story, book: PonyBook) -> Dictionary:
	return {
		"path": path(story),
		"climax": story.has_flag("climax_done"),
		"placed": story.has_flag("placed"),
		"rescued": int(story.get_var("rescued", 0)),
		"delivered": delivered_after_reveal(book),
		"allies": allies(story),
		"clover": story.has_flag("clover_rescued"),
	}


## THE DREAD DIAL (0 cozy, 1 the Works at its worst). Act One is cozy; Act Two creeps a
## little with each delivery; the reveal's own scene drives itself; after it, the Factory
## path greys with every pony delivered and the Rescue path brightens with every pylon cut
## and every pony saved. An ending fixes it where its epilogue wants it.
static func dread(story: Story, book: PonyBook) -> float:
	if story == null:
		return 0.0
	if story.has_flag("ending_free"):
		return 0.0
	match path(story):
		PATH_FACTORY:
			return clampf(0.35 + 0.04 * float(delivered_after_reveal(book)), 0.35, 0.9)
		PATH_RESCUE:
			var cut: int = int(story.get_var("pylons_cut", 0))
			var saved: int = int(story.get_var("rescued", 0))
			return clampf(0.5 - 0.1 * float(cut) - 0.01 * float(saved), 0.05, 0.5)
	if story.chapter >= Story.Chapter.WEATHER:
		return clampf(0.05 + 0.015 * float(story.deliveries), 0.05, 0.22)
	return 0.0
