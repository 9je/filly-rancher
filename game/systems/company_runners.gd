class_name CompanyRunners
extends Resource
## THE FIVE COMPANY OWNED RUNNERS at the Spectra Palace track, as authored data. Their
## names, their form, and the colours they are painted in.
##
## PARALLEL COLUMNS RATHER THAN A LIST OF SUB RESOURCES, the same shape
## game/systems/stock_palette.gd uses for its swatch rows and for the same reason: a .tres
## holding six flat arrays is a file a person can read and edit in a text editor, and a
## .tres holding five nested sub resources is not. is_valid() is what keeps the columns in
## step, and test_company_runners.gd asserts it against the shipped file.
##
## THEY ARE STOCK PONIES WITH JOB TITLES. Each one is built on one of the three hidden
## stock records (game/data/hidden/) and recoloured from the stock palette, so the track
## needs no new model and no new import; `base_ids` says which record and the colour columns
## say which swatches. Their names are the Company's, which is the joke.
##
## THEY ARE NOT COLLECTIBLE, NOT SPAWNED AND NOT OWNED. Nothing here mints a PonyInstance,
## nothing here reaches the Compendium, and no Company runner is ever a pony the player can
## catch. They exist to have form and to be beaten.

const SHIPPED_PATH := "res://data/casino/company_runners.tres"

## Player facing; no dashes.
@export var runner_names: Array[String] = []
@export var speeds: Array[float] = []
@export var staminas: Array[float] = []
@export var spirits: Array[float] = []

## Which hidden stock record each runner's body is built from.
@export var base_ids: Array[StringName] = []

## Indices into game/data/stock_palette.tres.
@export var coats: Array[int] = []
@export var manes: Array[int] = []
@export var eyes: Array[int] = []


static func load_shipped() -> CompanyRunners:
	return load(SHIPPED_PATH) as CompanyRunners


func count() -> int:
	return runner_names.size()


## Every column the same length, and at least one runner. A card that fails this would hand
## the race an entry with a name and no form.
func is_valid() -> bool:
	var n := count()
	if n <= 0:
		return false
	return speeds.size() == n and staminas.size() == n and spirits.size() == n \
		and base_ids.size() == n and coats.size() == n and manes.size() == n \
		and eyes.size() == n


## One runner as a dictionary, or an empty one for an index that is not on the card. An
## empty answer rather than an error, because the caller is a menu drawing rows and a menu
## that has drifted should draw nothing rather than take the game down.
func entry(index: int) -> Dictionary:
	if index < 0 or index >= count() or not is_valid():
		return {}
	return {
		"name": runner_names[index],
		"speed": speeds[index],
		"stamina": staminas[index],
		"spirit": spirits[index],
		"base_id": base_ids[index],
		"stock": {"coat": coats[index], "mane": manes[index], "eyes": eyes[index]},
	}
