class_name StoryWording
extends RefCounted
## THE WORDS THAT CHANGE WITH THE CHAPTER, and nothing else. The spec, on the Compendium's
## PROCESSED state: "Before the fork it renders as 'Delivered' with a smiley. The same
## state; only the words change with the chapter." So the state stays one state, the page
## stays one page, and the wording is a table.
##
## Static only, no state, no scene. Preload by path.
##
## THE REGISTER: cheerful corporate, and it curdles by degrees rather than by an announcement.
## SUNNY is a delivery with a smiley. WEATHER files it. The Company chapter is proud of the
## number. The Resistance chapter says the only honest thing anybody says about it. Nothing
## here is ever grim on screen and no word in it is the word this project does not use.

const StoryScript := preload("res://systems/story.gd")
const RequestBoardScript := preload("res://systems/request_board.gd")

## Indexed by Story.Chapter. One entry per chapter, checked by the test rather than trusted.
const PROCESSED_LABELS: Array[String] = [
	"Delivered :)",
	"Delivered, and filed",
	"Delivered, and filed",
	"Processed. Yield 94%",
	"Taken",
]

## The star on the pony the player named on the Employee Appreciation Survey. It reads as a
## commendation, which is the joke, and it is the same phrase the Requisition used.
const EMPLOYEES_CHOICE := "Employee's Choice"


static func processed_label(chapter: int) -> String:
	return PROCESSED_LABELS[clampi(chapter, 0, PROCESSED_LABELS.size() - 1)]


## The whole of what a PROCESSED row says: the chapter's word for it, plus the star when she
## is the one the player named. The star is APPENDED rather than substituted, so a reader
## who has learned what the first half means does not lose it.
static func processed_value(chapter: int, employees_choice: bool) -> String:
	var label: String = processed_label(chapter)
	return "%s   %s" % [label, EMPLOYEES_CHOICE] if employees_choice else label


## THE BOARD, CHAPTER BY CHAPTER. Keyed by RequestBoard.Kind, five entries each, in
## Story.Chapter order. The SUNNY column is byte identical to the sentences the board has
## printed since phase 2 slice 5: the wording moves, the board does not, and
## test_story_wording.gd pins the SUNNY column so a rewrite cannot drift the shipped one.
##
## {subject} is what the request is ABOUT (a personality and a region, a rarity of gem, a
## character's name), built by the board when it draws the request; {count} is how many.
## The frame around them is what the chapter changes: the ranch asks in SUNNY, the Company
## requisitions in COMPANY, and the town asks in RESISTANCE.
const BOARD_TEMPLATES := {
	RequestBoardScript.Kind.CATCH_ANY: [
		"Catch a pony with your magic beam.",
		"Catch a pony with your magic beam.",
		"Catch a pony. You are good at this now.",
		"Acquire one pony. Method at your discretion.",
		"Catch a pony. She stays caught, and she stays here.",
	],
	RequestBoardScript.Kind.PEN_ANY: [
		"Move a pony into a pen.",
		"Move a pony into a pen.",
		"Move a pony into a pen and see that she settles.",
		"House one pony pending collection.",
		"Move a pony into a pen. She is staying.",
	],
	RequestBoardScript.Kind.SELL_ANY: [
		"Sell a gem at the market.",
		"Sell a gem at the market.",
		"Sell a gem. The service charge will not pay itself.",
		"Liquidate one gem against your account.",
		"Sell a gem. The town needs the bits more than we do.",
	],
	RequestBoardScript.Kind.BRING_PERSONALITY_FROM_ZONE: [
		"Bring a {subject}.",
		"Bring a {subject}.",
		"Somepony is asking for a {subject}.",
		"Requisition: one {subject}.",
		"Bring a {subject} home, and keep her.",
	],
	RequestBoardScript.Kind.SELL_GEMS_OF_RARITY: [
		"Sell {count} {subject}.",
		"Sell {count} {subject}.",
		"Sell {count} {subject} while the price holds.",
		"Liquidate {count} {subject} against your account.",
		"Sell {count} {subject}. The town is buying.",
	],
	RequestBoardScript.Kind.SEE_CHARACTER: [
		"Find {subject} and get a good look at her.",
		"Locate {subject}. Description on file.",
		"Somepony is looking for {subject}.",
		"Locate {subject}. Registered arrival, bonus applies.",
		"Find {subject}, and do not tell anybody where she is.",
	],
}

## The line at the top of the board, in Story.Chapter order. One sentence that says whose
## board it is this week.
const BOARD_NOTES: Array[String] = [
	"Finish one to get a new one.",
	"Finish one to get a new one. Notices are filed weekly.",
	"Finish one to get a new one. Somepony has been reading these.",
	"Brightsky Weather Company, Partner Requisitions.",
	"Pinned over the Company's notices, in somepony else's hoofwriting.",
]


## What a request of `kind` says in `chapter`. A kind or chapter this build does not have
## falls back rather than answering an empty string, because a request with no text is a row
## the player cannot read.
static func board_text(kind: int, chapter: int, subject: String, count: int) -> String:
	var lines: Variant = BOARD_TEMPLATES.get(kind, null)
	if lines == null:
		return ""
	var list: Array = lines
	var template: String = String(list[clampi(chapter, 0, list.size() - 1)])
	return template.format({"subject": subject, "count": count})


static func board_note(chapter: int) -> String:
	return BOARD_NOTES[clampi(chapter, 0, BOARD_NOTES.size() - 1)]
