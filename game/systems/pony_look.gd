class_name PonyLook
extends RefCounted
## WHAT ONE PONY LOOKS LIKE, completely: which donor body she wears, her race, every color,
## whether she is a foal, and her cutie mark (or none: a Drifter is blank-flanked). Every
## pony in the game is one of these, the player included; game/systems/pony_paint.gd puts
## it on a body and game/systems/pony_generator.gd makes them from a seed.
##
## Saved as a plain Dictionary (to_dict / from_dict) with colors as HTML strings, so a pony
## blob in a save stays readable and pasteable.

const VERSION := 2

var donor: StringName = &"pokeypierce"
var race: StringName = &"earth"
var coat: Color = Color(0.98, 0.86, 0.72)
var mane: Color = Color(0.85, 0.35, 0.45)
var mane2: Color = Color(0.95, 0.6, 0.6)
var tail: Color = Color(0.85, 0.35, 0.45)
var eyes: Color = Color(0.3, 0.55, 0.85)
var foal: bool = false
## The generated mark: {"talent": StringName, "motif": int, "a": Color, "b": Color}, or
## empty for a blank flank.
var mark: Dictionary = {}
## A player-drawn mark as a base64 PNG; wins over `mark` when set.
var mark_png: String = ""
## Rare variant id (&"" for an ordinary pony): &"pearl", &"starry", &"ember".
var variant: StringName = &""
var rng_seed: int = 0


func has_mark() -> bool:
	return not mark.is_empty() or not mark_png.is_empty()


func copy() -> PonyLook:
	return from_dict(to_dict())


func to_dict() -> Dictionary:
	var d := {
		"v": VERSION, "donor": String(donor), "race": String(race),
		"coat": coat.to_html(false), "mane": mane.to_html(false), "mane2": mane2.to_html(false),
		"tail": tail.to_html(false), "eyes": eyes.to_html(false), "foal": foal,
		"variant": String(variant), "seed": rng_seed,
	}
	if not mark.is_empty():
		d["mark"] = {
			"talent": String(mark.get("talent", "")), "motif": int(mark.get("motif", 0)),
			"a": (mark.get("a", Color.WHITE) as Color).to_html(false),
			"b": (mark.get("b", Color.WHITE) as Color).to_html(false),
		}
	if not mark_png.is_empty():
		d["mark_png"] = mark_png
	return d


static func from_dict(d: Dictionary) -> PonyLook:
	var l := PonyLook.new()
	if d.is_empty():
		return l
	l.donor = StringName(str(d.get("donor", l.donor)))
	l.race = StringName(str(d.get("race", l.race)))
	l.coat = _color(d.get("coat"), l.coat)
	l.mane = _color(d.get("mane"), l.mane)
	l.mane2 = _color(d.get("mane2"), l.mane)
	l.tail = _color(d.get("tail"), l.mane)
	l.eyes = _color(d.get("eyes"), l.eyes)
	l.foal = bool(d.get("foal", false))
	l.variant = StringName(str(d.get("variant", "")))
	l.rng_seed = int(d.get("seed", 0))
	var m: Variant = d.get("mark")
	if m is Dictionary and not (m as Dictionary).is_empty():
		var md: Dictionary = m
		l.mark = {
			"talent": StringName(str(md.get("talent", ""))), "motif": int(md.get("motif", 0)),
			"a": _color(md.get("a"), Color.WHITE), "b": _color(md.get("b"), Color.WHITE),
		}
	l.mark_png = str(d.get("mark_png", ""))
	return l


## Any stock record as a look: a v2 look dictionary as is, or a legacy palette-index triple
## ({coat, mane, eyes, mane_style} into game/data/stock_palette.tres, written before v2) as
## the same colors on the same donor, so a pony penned in an old save looks as she did.
## Legacy ponies were all unicorns built from the four-model mane pool.
static func from_stock(stock: Dictionary, palette_path: String = "res://data/stock_palette.tres") -> PonyLook:
	if is_look_dict(stock):
		return from_dict(stock)
	var l := PonyLook.new()
	var pal: Resource = load(palette_path) if ResourceLoader.exists(palette_path) else null
	if pal != null and pal.has_method("coat_at"):
		l.coat = pal.call("coat_at", int(stock.get("coat", 0)))
		l.mane = pal.call("mane_at", int(stock.get("mane", 0)))
		l.eyes = pal.call("eye_at", int(stock.get("eyes", 0)))
	l.mane2 = l.mane
	l.tail = l.mane
	const LEGACY_POOL: Array[StringName] = [&"pokeypierce", &"vinylscratch", &"shiningarmor", &"nightlight"]
	l.donor = LEGACY_POOL[posmod(int(stock.get("mane_style", 0)), LEGACY_POOL.size())]
	l.race = &"unicorn"
	l.rng_seed = hash(stock)
	return l


## True when `d` is a v2 look rather than a legacy stock index triple.
static func is_look_dict(d: Dictionary) -> bool:
	return int(d.get("v", 0)) >= VERSION


static func _color(v: Variant, fallback: Color) -> Color:
	if v is Color:
		return v
	if v is String and Color.html_is_valid(v):
		return Color.html(v)
	return fallback
