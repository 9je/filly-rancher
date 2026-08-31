class_name PlayerLook
extends RefCounted
## THE PONY THE PLAYER DESIGNED, AND THE NAME THE COMPANY KNOWS HER BY. Saved under the
## key "player" (game/systems/game_state.gd) and read by the creation screen, by the player
## model, and by every letter the Company writes.
##
## THE LOOK IS INDICES AND THE MARK IS A PNG. Coat, mane and eyes are indices into
## game/data/player_palette.tres for StockPalette's stated reason; the cutie mark is not a
## choice from a sheet, it is a drawing, so it is stored as the pixels themselves. As a
## BASE64 PNG rather than as a side file, because the whole design of this project's saves
## is one human readable JSON blob a player can paste to somebody (see save_io.gd's class
## comment) and a save that carried a companion image would stop being tradeable the moment
## it left the machine that wrote it. A sixty four square drawing is a few kilobytes.
##
## PNG BECAUSE PNG IS LOSSLESS. "Round trips pixel identical" is a promise the creation
## test asserts, and it is only true of a lossless format; the same drawing through a JPEG
## would come back subtly different every save.
##
## A BLANK MARK IS STORED AS THE EMPTY STRING, not as a PNG of nothing. A blank flank is a
## real look, it is what a version 4 save gets, and it should not cost the file anything.
##
## THE NAME IS SANITISED RATHER THAN MERELY CAPPED. It is interpolated into every Company
## letter, so the project's copy rule reaches it: no em dash, no hyphen, no control
## characters, no runs of whitespace, and never empty.

const MarkPaintScript := preload("res://systems/mark_paint.gd")

const DEFAULT_NAME := "Twilight"

## The longest name the box accepts. Letters.MAX_NAME_LENGTH mirrors this, and
## test_letters.gd renders every template at exactly this length.
const MAX_NAME_LENGTH := 16

## The shipped look a version 4 save loads with: a lavender coat, a dark mane and violet
## eyes, which is as near as game/data/player_palette.tres gets to the pony who used to
## stand in the player slot.
const DEFAULT_COAT := 3
const DEFAULT_MANE := 1
const DEFAULT_EYES := 4

## Named `player_name` rather than `name`, because `name` is a property of Node and a
## future refactor that made this a Node would shadow it silently.
var player_name := DEFAULT_NAME
var coat := DEFAULT_COAT
var mane := DEFAULT_MANE
var eyes := DEFAULT_EYES

## Which mane mesh she wears. Zero is the base model's own, which is the only one this
## slice ships; the field exists so a second sourced style is data rather than a schema
## change.
var mane_style := 0

var _mark: Image = null


static func default_look() -> PlayerLook:
	return PlayerLook.new()


## Trim, collapse, strip and cap. An empty result is DEFAULT_NAME, so there is no such thing
## as a nameless account.
static func sanitize_name(raw: String) -> String:
	var out := ""
	for i in raw.length():
		var c: String = raw[i]
		var code: int = raw.unicode_at(i)
		if code < 32 or code == 127:
			out += " "
			continue
		# The project's copy rule, applied at the one place a player can type into it.
		if c == "-" or code == 0x2014 or code == 0x2013:
			continue
		out += c
	while out.contains("  "):
		out = out.replace("  ", " ")
	out = out.strip_edges()
	if out.length() > MAX_NAME_LENGTH:
		out = out.substr(0, MAX_NAME_LENGTH)
	out = out.strip_edges()
	return out if not out.is_empty() else DEFAULT_NAME


## Her drawing. NEVER NULL: a look with no mark answers a blank canvas, so every caller can
## hand it straight to CutieMark.apply() without a null check.
func mark() -> Image:
	return MarkPaintScript.copy_of(_mark) if _mark != null else MarkPaintScript.blank()


func set_mark(image: Image) -> void:
	_mark = null if image == null else MarkPaintScript.copy_of(image)


func has_mark() -> bool:
	return _mark != null and not MarkPaintScript.is_blank(_mark)


func to_dict() -> Dictionary:
	return {
		"name": player_name,
		"coat": coat,
		"mane": mane,
		"eyes": eyes,
		"mane_style": mane_style,
		"mark_png": _encoded_mark(),
	}


func _encoded_mark() -> String:
	if not has_mark():
		return ""
	return Marshalls.raw_to_base64(_mark.save_png_to_buffer())


## Rebuild from a to_dict() dictionary. Every field is optional and falls back to this
## class's default, which is what makes a version 4 save load as Twilight with a blank
## mark and no migration branch of its own.
##
## A MARK THAT WILL NOT DECODE IS DROPPED, not fatal. A hand edited or truncated blob costs
## her the drawing and nothing else; the alternative is a save that refuses to load over a
## picture, which is the worst trade this file could make.
static func from_dict(d: Dictionary) -> PlayerLook:
	var out := PlayerLook.new()
	out.player_name = sanitize_name(str(d.get("name", DEFAULT_NAME)))
	out.coat = int(d.get("coat", DEFAULT_COAT))
	out.mane = int(d.get("mane", DEFAULT_MANE))
	out.eyes = int(d.get("eyes", DEFAULT_EYES))
	out.mane_style = maxi(0, int(d.get("mane_style", 0)))
	var encoded := str(d.get("mark_png", ""))
	if encoded.is_empty():
		return out
	# Checked BEFORE handing `encoded` to Marshalls.base64_to_raw(), which otherwise logs its
	# own loud native decode error (CryptoCore::b64_decode) for anything that is not valid
	# base64, on top of the push_warning below -- a hand-edited save should read as one calm
	# line in the log, not two, and game/test/test_player_look.gd pins that it is exactly one.
	if not _looks_like_base64(encoded):
		push_warning("PlayerLook: the saved cutie mark is not base64; loading a blank one.")
		return out
	var raw: PackedByteArray = Marshalls.base64_to_raw(encoded)
	if raw.is_empty():
		push_warning("PlayerLook: the saved cutie mark is not base64; loading a blank one.")
		return out
	var image := Image.new()
	if image.load_png_from_buffer(raw) != OK:
		push_warning("PlayerLook: the saved cutie mark is not a PNG; loading a blank one.")
		return out
	if image.get_width() != MarkPaintScript.SIZE or image.get_height() != MarkPaintScript.SIZE:
		image.resize(MarkPaintScript.SIZE, MarkPaintScript.SIZE, Image.INTERPOLATE_NEAREST)
	if image.get_format() != MarkPaintScript.FORMAT:
		image.convert(MarkPaintScript.FORMAT)
	out._mark = image
	return out


## Whether `s` is even SHAPED like base64: standard alphabet, padding ('=') only at the end
## and at most two of it, length a multiple of four. Not a claim that it decodes to
## anything useful -- only that it is worth handing to Marshalls.base64_to_raw() at all.
static func _looks_like_base64(s: String) -> bool:
	if s.is_empty() or s.length() % 4 != 0:
		return false
	var padding := 0
	for i in s.length():
		var code: int = s.unicode_at(i)
		if code == 0x3D:  # '='
			padding += 1
			continue
		if padding > 0:
			return false
		var is_upper := code >= 0x41 and code <= 0x5A
		var is_lower := code >= 0x61 and code <= 0x7A
		var is_digit := code >= 0x30 and code <= 0x39
		if not (is_upper or is_lower or is_digit or code == 0x2B or code == 0x2F):
			return false
	return padding <= 2
