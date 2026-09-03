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
